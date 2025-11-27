#!/bin/bash
#
# tmux-reminder-popup.sh - Open nvim with ReminderScan in a tmux popup
#
# Usage: tmux-reminder-popup.sh
#
# Add to tmux.conf:
#   bind r run-shell "/path/to/tmux-reminder-popup.sh"
#
# Uses your normal nvim config (which should have reminders plugin configured)
#

# Open tmux popup with nvim running ReminderScan
# -E closes popup when nvim exits
# -w and -h set width/height as percentage
tmux popup -E -w 80% -h 80% nvim -c "ReminderScan"
