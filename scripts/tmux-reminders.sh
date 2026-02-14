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

# Skip when display is asleep (macOS) to allow system sleep
if [[ "$(uname)" == "Darwin" ]]; then
    _ps=$(pmset -g powerstate IOPMrootDomain 2>/dev/null | awk '/IOPMrootDomain/{print $3}')
    if [[ "$_ps" =~ ^[01]$ ]]; then
        echo "#[fg=#71839b,bg=#131a24,nobold]#[range=user|zett] Zett #[norange]"
        exit 0
    fi
fi

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
# "Zett" is always shown (range=user|zett) - opens Telekasten goto_today
# When reminders are due, a red count badge (range=user|reminder) is also shown
#   and "Zett" turns red for extra visibility
# Requires these binds in tmux.conf:
#   bind -Troot MouseDown1Status if -F '#{==:#{mouse_status_range},reminder}' { run-shell '/path/to/tmux-reminder-popup.sh' }
#   bind -Troot MouseDown1Status if -F '#{==:#{mouse_status_range},zett}' { run-shell '/path/to/tmux-zett-popup.sh' }
if [[ "$count" -gt 0 ]]; then
    # Red count badge (clickable for reminders) + red Zett (clickable for today's note)
    echo "#[fg=#131a24,bg=#f7768e,bold]#[range=user|reminder] ${count} #[norange]#[fg=#f7768e,bg=#131a24,bold]#[range=user|zett] Zett #[norange]"
else
    # No reminders - show subtle Zett button that opens Telekasten goto_today
    # Matches unselected tab style: grey text on dark background
    echo "#[fg=#71839b,bg=#131a24,nobold]#[range=user|zett] Zett #[norange]"
fi
