#!/bin/bash
#
# tmux-reminders - Scan markdown files for due reminders
# Outputs formatted string for tmux status-right
#
# Usage: tmux-reminders.sh <path1> [path2] [path3] ...
#
# Example in tmux.conf:
#   set -g status-right '#(/path/to/tmux-reminders.sh ~/notes ~/zet)'
#
# Click support: clicking the reminder count opens ReminderScan in a popup
#

# Get the directory where this script lives (to find popup script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POPUP_SCRIPT="$SCRIPT_DIR/tmux-reminder-popup.sh"

if [[ $# -eq 0 ]]; then
    echo "Usage: tmux-reminders.sh <path1> [path2] ..." >&2
    exit 1
fi

# Get current time as Unix timestamp
now=$(date +%s)

count=0

for dir in "$@"; do
    # Expand ~ to home directory
    dir="${dir/#\~/$HOME}"

    [[ -d "$dir" ]] || continue

    # Scan only top-level .md files (no recursion)
    for file in "$dir"/*.md; do
        [[ -f "$file" ]] || continue

        # Find unchecked reminders with ISO 8601 timestamps
        while IFS= read -r line; do
            # Extract the timestamp (format: 2025-08-13T15:51:15Z)
            ts=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z')
            [[ -z "$ts" ]] && continue

            # Convert ISO 8601 to Unix timestamp
            # macOS date syntax - TZ=UTC ensures the Z suffix is honored
            if [[ "$(uname)" == "Darwin" ]]; then
                reminder_time=$(TZ=UTC date -jf "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null)
            else
                # Linux date syntax
                reminder_time=$(TZ=UTC date -d "$ts" +%s 2>/dev/null)
            fi
            [[ -z "$reminder_time" ]] && continue

            # Check if due (past or now)
            if [[ "$reminder_time" -le "$now" ]]; then
                ((count++))
            fi
        done < <(grep -E '^\* \[ \] #reminder' "$file" 2>/dev/null)
    done
done

# Output for tmux with click support
# Uses range=user|reminder to mark clickable region
# Requires this bind in tmux.conf:
#   bind -Troot MouseDown1Status if -F '#{==:#{mouse_status_range},reminder}' { run-shell '/path/to/tmux-reminder-popup.sh' }
if [[ "$count" -gt 0 ]]; then
    if [[ "$count" -eq 1 ]]; then
        label=" $count reminder "
    else
        label=" $count reminders "
    fi
    echo "#[fg=#131a24,bg=#f7768e,bold]#[range=user|reminder]${label}#[norange]#[fg=#f7768e,bg=#131a24]"
fi
