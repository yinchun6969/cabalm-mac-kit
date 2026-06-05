#!/usr/bin/env bash
set -euo pipefail

delay="${1:-0.8}"
self_tty="$(tty 2>/dev/null || true)"
if [ -z "$self_tty" ] || [ "$self_tty" = "not a tty" ]; then
  exit 0
fi

(
  sleep "$delay"
  osascript >/dev/null 2>&1 <<OSA || true
tell application "Terminal"
  repeat with w in windows
    try
      repeat with t in tabs of w
        try
          if (tty of t) is "$self_tty" then
            close w saving no
            return
          end if
        end try
      end repeat
    end try
  end repeat
end tell
OSA
) >/dev/null 2>&1 &
