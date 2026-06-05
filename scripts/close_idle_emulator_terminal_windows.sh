#!/usr/bin/env bash
set -euo pipefail

osascript <<'OSA'
tell application "Terminal"
  set closedCount to 0
  set protectedNames to {"earnity_auto_claim", "cabal_unattended_48h", "qemu-system-aarch64"}

  repeat with w in windows
    set wname to name of w
    set tabsCount to count tabs of w
    set shouldClose to false

    if tabsCount is 0 then
      set shouldClose to true
    else
      set hasBusyTab to false
      set tabText to ""
      repeat with t in tabs of w
        try
          if busy of t then set hasBusyTab to true
        end try
        try
          set tabText to tabText & linefeed & (history of t)
        end try
      end repeat

      if hasBusyTab is false then
        if tabText contains "start_macos_game_" then set shouldClose to true
        if tabText contains "Emulator Terminal launcher:" then set shouldClose to true
        if wname contains "— -zsh" then set shouldClose to true
        if wname ends with "— 80×24" then set shouldClose to true
      end if
    end if

    repeat with protectedName in protectedNames
      if wname contains protectedName then set shouldClose to false
    end repeat

    if shouldClose then
      close w saving no
      set closedCount to closedCount + 1
    end if
  end repeat
end tell
return closedCount
OSA

# Terminal may leave empty UI shells behind when the profile is configured to
# keep windows open after shell exit. Close those visible empty shells via the UI.
osascript >/dev/null 2>&1 <<'OSA' || true
tell application "Terminal" to activate
delay 0.2
tell application "Terminal"
  repeat with w in windows
    try
      set wname to name of w
      if (visible of w) and (count tabs of w) is 1 and wname does not contain "earnity_auto_claim" and wname does not contain "qemu-system-aarch64" then
        set t to selected tab of w
        if (busy of t) is false and (wname contains "— -zsh" or wname ends with "— 80×24") then
          set frontmost of w to true
          delay 0.1
          tell application "System Events"
            tell process "Terminal" to keystroke "w" using command down
          end tell
        end if
      end if
    end try
  end repeat
end tell
OSA
