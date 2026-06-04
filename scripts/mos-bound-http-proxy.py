#!/usr/bin/env python3
import argparse
import select
import socket
import sys
import threading
import urllib.parse


IP_BOUND_IF = 25
IPV6_BOUND_IF = 125


def log(message):
    print(message, flush=True)


def parse_host(value):
    if value.startswith("["):
        end = value.find("]")
        if end != -1:
            host = value[1:end]
            rest = value[end + 1 :]
            if rest.startswith(":"):
                return host, int(rest[1:])
            return host, None
    if ":" in value:
        host, port = value.rsplit(":", 1)
        if port.isdigit():
            return host, int(port)
    return value, None


def set_bound_interface(sock, iface):
    if not iface:
        return
    index = socket.if_nametoindex(iface)
    family = sock.family
    if family == socket.AF_INET:
        sock.setsockopt(socket.IPPROTO_IP, IP_BOUND_IF, index)
    elif family == socket.AF_INET6:
        sock.setsockopt(socket.IPPROTO_IPV6, IPV6_BOUND_IF, index)


def connect_direct(host, port, iface, overrides, timeout):
    target_host = overrides.get(host, host)
    last_error = None
    for family, socktype, proto, _canon, addr in socket.getaddrinfo(target_host, port, type=socket.SOCK_STREAM):
        sock = socket.socket(family, socktype, proto)
        try:
            sock.settimeout(timeout)
            set_bound_interface(sock, iface)
            sock.connect(addr)
            sock.settimeout(None)
            return sock
        except OSError as exc:
            last_error = exc
            sock.close()
    raise last_error or OSError(f"could not connect to {host}:{port}")


def split_headers(data):
    marker = data.find(b"\r\n\r\n")
    if marker == -1:
        return None, None
    return data[: marker + 4], data[marker + 4 :]


def read_headers(client):
    data = b""
    while b"\r\n\r\n" not in data and len(data) < 65536:
        chunk = client.recv(4096)
        if not chunk:
            break
        data += chunk
    return data


def rewrite_request(headers):
    text = headers.decode("iso-8859-1", errors="replace")
    lines = text.split("\r\n")
    if not lines or " " not in lines[0]:
        raise ValueError("bad request line")

    method, target, version = lines[0].split(" ", 2)
    host_header = None
    for line in lines[1:]:
        if line.lower().startswith("host:"):
            host_header = line.split(":", 1)[1].strip()
            break

    if method.upper() == "CONNECT":
        host, port = parse_host(target)
        return method, host, port or 443, None

    parsed = urllib.parse.urlsplit(target)
    if parsed.scheme and parsed.netloc:
        host, port = parse_host(parsed.netloc)
        port = port or (443 if parsed.scheme == "https" else 80)
        path = urllib.parse.urlunsplit(("", "", parsed.path or "/", parsed.query, ""))
    else:
        if not host_header:
            raise ValueError("missing Host header")
        host, port = parse_host(host_header)
        port = port or 80
        path = target or "/"

    lines[0] = f"{method} {path} {version}"
    return method, host, port, "\r\n".join(lines).encode("iso-8859-1")


def relay(left, right):
    peers = {left: right, right: left}
    while peers:
        sockets = list(peers)
        readable, _writable, _error = select.select(sockets, [], sockets, 60)
        if not readable:
            break
        for sock in readable:
            try:
                data = sock.recv(65536)
            except OSError:
                return
            if not data:
                other = peers.pop(sock, None)
                if other is not None:
                    try:
                        other.shutdown(socket.SHUT_WR)
                    except OSError:
                        pass
                continue
            other = peers.get(sock)
            if other is None:
                continue
            try:
                other.sendall(data)
            except OSError:
                return


def handle_http_client(client, addr, args, overrides):
    with client:
        try:
            first = read_headers(client)
            headers, body = split_headers(first)
            if headers is None:
                return
            method, host, port, rewritten = rewrite_request(headers)
            upstream = connect_direct(host, port, args.iface, overrides, args.timeout)
            with upstream:
                log(f"{addr[0]} -> {host}:{port} via {args.iface or 'default'}")
                if method.upper() == "CONNECT":
                    client.sendall(b"HTTP/1.1 200 Connection Established\r\n\r\n")
                else:
                    upstream.sendall(rewritten)
                    if body:
                        upstream.sendall(body)
                relay(client, upstream)
        except Exception as exc:
            log(f"{addr[0]} error: {exc}")
            try:
                client.sendall(b"HTTP/1.1 502 Bad Gateway\r\nConnection: close\r\nContent-Length: 0\r\n\r\n")
            except OSError:
                pass


def handle_tcp_client(client, addr, args, overrides):
    with client:
        try:
            upstream = connect_direct(args.tcp_host, args.tcp_port, args.iface, overrides, args.timeout)
            with upstream:
                log(f"{addr[0]} -> {args.tcp_host}:{args.tcp_port} via {args.iface or 'default'}")
                relay(client, upstream)
        except Exception as exc:
            log(f"{addr[0]} tcp error: {exc}")


def parse_overrides(values):
    overrides = {}
    for value in values:
        if "=" not in value:
            raise ValueError(f"bad override {value!r}; expected host=ip")
        host, ip = value.split("=", 1)
        overrides[host.strip()] = ip.strip()
    return overrides


def main():
    parser = argparse.ArgumentParser(description="Proxy with outbound traffic bound to a macOS interface.")
    parser.add_argument("--listen", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=18080)
    parser.add_argument("--iface", default="")
    parser.add_argument("--timeout", type=float, default=8)
    parser.add_argument("--resolve", action="append", default=[], help="Override DNS as host=ip.")
    parser.add_argument("--tcp-target", default="", help="Forward raw TCP to host:port instead of HTTP proxying.")
    args = parser.parse_args()
    overrides = parse_overrides(args.resolve)
    handler = handle_http_client

    if args.tcp_target:
        tcp_host, tcp_port = parse_host(args.tcp_target)
        if tcp_port is None:
            parser.error("--tcp-target must include a port, for example host:38101")
        args.tcp_host = tcp_host
        args.tcp_port = tcp_port
        handler = handle_tcp_client

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((args.listen, args.port))
    server.listen(128)
    if args.tcp_target:
        log(f"listening on {args.listen}:{args.port}; tcp target={args.tcp_target}; outbound iface={args.iface or 'default'}")
    else:
        log(f"listening on {args.listen}:{args.port}; outbound iface={args.iface or 'default'}")

    while True:
        client, addr = server.accept()
        thread = threading.Thread(target=handler, args=(client, addr, args, overrides), daemon=True)
        thread.start()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
