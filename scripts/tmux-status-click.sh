#!/bin/bash
#
# tmux-status-click.sh - Dispatcher for status bar clicks
#
# Usage in tmux.conf:
#   bind -Troot MouseDown1Status run-shell '/path/to/tmux-status-click.sh "#{mouse_status_range}"'
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
range="$1"

case "$range" in
    reminder)
        "$SCRIPT_DIR/tmux-reminder-popup.sh"
        ;;
    zett)
        "$SCRIPT_DIR/tmux-zett-popup.sh"
        ;;
    *)
        # Default: select window (let tmux handle it)
        ;;
esac
