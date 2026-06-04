#!/usr/bin/env bash
set -euo pipefail

osascript <<'OSA'
tell application "Terminal"
  set closedCount to 0
  repeat with w in windows
    set shouldClose to false
    repeat with t in tabs of w
      try
        set tabHistory to history of t
        if (tabHistory contains "start_macos_game_") and (busy of t is false) then
          set shouldClose to true
        end if
      end try
    end repeat
    if shouldClose then
      close w saving no
      set closedCount to closedCount + 1
    end if
  end repeat
end tell
return closedCount
OSA
