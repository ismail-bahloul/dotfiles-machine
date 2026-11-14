#!/bin/sh
# kitty-material-you-hook.sh
# Called by kde-material-you-colors (on_change_hook) on every Material You
# regeneration (wallpaper change). Delegates to material-you-refresh
# (single source of truth: kitty + btop + zed + prompt) and logs.
LOG="$HOME/.config/kitty/material-you-hook.log"
echo "$(date '+%F %T') hook" >> "$LOG"
"$HOME/.local/bin/material-you-refresh" >> "$LOG" 2>&1
exit 0
