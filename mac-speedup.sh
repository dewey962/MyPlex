#!/bin/bash
# mac-speedup.sh — diagnose what's slowing a Mac down and apply safe, reversible fixes.
# Usage: bash mac-speedup.sh
# Every change asks first. Nothing here deletes personal files.

set -u

if [ "$(uname)" != "Darwin" ]; then
  echo "This script is for macOS only." >&2
  exit 1
fi

bold() { printf '\n\033[1m%s\033[0m\n' "$1"; }
ask() { printf '%s [y/N] ' "$1"; read -r reply; [ "$reply" = "y" ] || [ "$reply" = "Y" ]; }

bold "== System =="
sw_vers
echo "Uptime:$(uptime | sed 's/.*up/ up/')"
echo "(If uptime is many days, a restart alone often helps.)"

bold "== Disk space =="
df -h / | tail -1 | awk '{print "Used: "$3" of "$2" ("$5"), free: "$4}'
used_pct=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
if [ "$used_pct" -ge 85 ]; then
  echo "WARNING: disk is ${used_pct}% full. macOS slows down badly under ~15% free."
fi

bold "== Memory pressure =="
memory_pressure 2>/dev/null | grep -E "System-wide memory free percentage" || vm_stat | head -5
swap=$(sysctl -n vm.swapusage 2>/dev/null)
echo "Swap: $swap"

bold "== Top 10 processes by CPU =="
ps -Arco pid,%cpu,%mem,comm | head -11

bold "== Top 10 processes by memory =="
ps -Amco pid,%cpu,%mem,comm | head -11

bold "== Login items (apps that start at login) =="
osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null || echo "(could not read; check System Settings > General > Login Items)"

bold "== Background launch agents (third-party) =="
ls ~/Library/LaunchAgents /Library/LaunchAgents /Library/LaunchDaemons 2>/dev/null | grep -v '^com\.apple\.' | grep -v '^$'

bold "== Largest folders in your home directory =="
du -sh ~/Downloads ~/Library/Caches ~/Movies ~/Desktop ~/Documents ~/.Trash 2>/dev/null | sort -hr

bold "== Optional fixes =="

if ask "Empty the Trash?"; then
  rm -rf ~/.Trash/* 2>/dev/null
  echo "Trash emptied."
fi

if ask "Clear your user caches in ~/Library/Caches? (apps rebuild them; safe)"; then
  rm -rf ~/Library/Caches/* 2>/dev/null
  echo "User caches cleared."
fi

if ask "Reduce visual effects (transparency + motion) for snappier UI?"; then
  defaults write com.apple.universalaccess reduceTransparency -bool true
  defaults write com.apple.universalaccess reduceMotion -bool true
  echo "Done. Undo in System Settings > Accessibility > Display."
fi

if ask "Speed up Dock/Mission Control animations?"; then
  defaults write com.apple.dock autohide-delay -float 0
  defaults write com.apple.dock autohide-time-modifier -float 0.3
  defaults write com.apple.dock expose-animation-duration -float 0.15
  killall Dock
  echo "Done. Undo: defaults delete com.apple.dock autohide-delay (etc.) && killall Dock"
fi

if ask "Flush DNS cache? (fixes slow web lookups; needs your password)"; then
  sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder
  echo "DNS cache flushed."
fi

if ask "Check for macOS software updates?"; then
  softwareupdate -l
fi

bold "== Next steps =="
cat <<'EOF'
- Quit or uninstall anything hogging CPU/memory in the lists above.
- Remove unneeded Login Items: System Settings > General > Login Items.
- Close unused browser tabs/extensions (often the #1 memory user).
- Free disk space: Apple menu > About This Mac > More Info > Storage settings.
- Restart the Mac after making changes.
EOF
