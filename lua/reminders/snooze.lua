-- Shared snooze options and datetime calculation
local M = {}

local time_parser = require("reminders.time_parser")

-- Snooze choices for edit/snooze actions
M.choices = {
	"in 10 minutes",
	"in 1 hour",
	"in 2 hours",
	"1pm today",
	"tomorrow 6am",
	"Monday 6am",
	"in 2 days",
	"in 1 week",
	"in 2 weeks",
	"in 1 month",
}

-- Calculate new datetime based on snooze choice
-- Returns ISO 8601 UTC datetime string
function M.calculate_new_datetime(choice)
	return time_parser.parse(choice)
end

return M
