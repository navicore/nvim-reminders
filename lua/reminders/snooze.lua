-- Shared snooze options and datetime calculation
local M = {}

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
	local current_time = os.time()
	local now = os.date("*t")
	local new_time

	if choice == "in 10 minutes" then
		new_time = current_time + 10 * 60
	elseif choice == "in 1 hour" then
		new_time = current_time + 1 * 60 * 60
	elseif choice == "in 2 hours" then
		new_time = current_time + 2 * 60 * 60
	elseif choice == "1pm today" then
		-- 1pm local time today
		new_time = os.time({ year = now.year, month = now.month, day = now.day, hour = 13, min = 0, sec = 0 })
	elseif choice == "Monday 6am" then
		-- Next Monday at 6am local time
		local days_until_monday = (2 - now.wday + 7) % 7
		if days_until_monday == 0 then
			days_until_monday = 7
		end -- Always next Monday
		new_time =
			os.time({ year = now.year, month = now.month, day = now.day + days_until_monday, hour = 6, min = 0, sec = 0 })
	elseif choice == "tomorrow 6am" then
		-- 6am local time tomorrow
		new_time = os.time({ year = now.year, month = now.month, day = now.day + 1, hour = 6, min = 0, sec = 0 })
	elseif choice == "in 2 days" then
		new_time = current_time + 2 * 24 * 60 * 60
	elseif choice == "in 1 week" then
		new_time = current_time + 7 * 24 * 60 * 60
	elseif choice == "in 2 weeks" then
		new_time = current_time + 14 * 24 * 60 * 60
	elseif choice == "in 1 month" then
		new_time = os.time({ year = now.year, month = now.month + 1, day = now.day })
	else
		return nil
	end

	return os.date("!%Y-%m-%dT%H:%M:%SZ", new_time)
end

return M
