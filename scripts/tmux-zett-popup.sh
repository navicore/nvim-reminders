#!/bin/bash
#
# tmux-zett-popup.sh - Open nvim with Telekasten goto_today in a tmux popup
#
# Usage: tmux-zett-popup.sh
#
# Add to tmux.conf:
#   bind -Troot MouseDown1Status if -F '#{==:#{mouse_status_range},zett}' { run-shell '/path/to/tmux-zett-popup.sh' }
#

# Open tmux popup with nvim running Telekasten goto_today
# -E closes popup when nvim exits
# -w and -h set width/height as percentage
tmux popup -E -w 80% -h 80% nvim -c "Telekasten goto_today"
