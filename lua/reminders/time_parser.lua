-- lua/reminders/time_parser.lua

local M = {}

-- Helper function to add seconds to the current time in UTC
local function add_time(seconds)
    return os.date("!%Y-%m-%dT%H:%M:%SZ", os.time() + seconds)
end

-- Function to parse expressions like "in 20 minutes"
function M.parse_minutes(expression)
    local minutes = string.match(expression, "in (%d+) minute[s]?")
    if minutes then
        return add_time(tonumber(minutes) * 60)
    end
end

-- Function to parse expressions like "in 1 hour"
function M.parse_hours(expression)
    local hours = string.match(expression, "in (%d+) hours")
    if hours then
        return add_time(tonumber(hours) * 3600)
    end
end

-- Function to parse expressions like "in 1 day"
function M.parse_days(expression)
    local days = string.match(expression, "in (%d+) days")
    if days then
        return add_time(tonumber(days) * 86400)
    end
end

-- Function to parse "tomorrow"
function M.parse_tomorrow()
    local tomorrow = os.time() + 86400
    return os.date("!%Y-%m-%dT00:00:00Z", tomorrow)
end

-- Function to parse "next Monday"
function M.parse_next_weekday(expression)
    local days_of_week = {
        sunday = 1,
        monday = 2,
        tuesday = 3,
        wednesday = 4,
        thursday = 5,
        friday = 6,
        saturday = 7,
    }

    local today = os.date("!*t").wday  -- Use UTC
    local next_day = string.match(expression, "next (%a+)")

    if next_day and days_of_week[next_day:lower()] then
        local target_wday = days_of_week[next_day:lower()]
        local days_ahead = (target_wday - today + 7) % 7
        days_ahead = days_ahead == 0 and 7 or days_ahead
        local next_target_day = os.time() + (days_ahead * 86400)
        return os.date("!%Y-%m-%dT00:00:00Z", next_target_day)
    end
end

-- Main function to parse any time expression
function M.parse(expression)
    return M.parse_minutes(expression)
        or M.parse_hours(expression)
        or M.parse_days(expression)
        or (expression == "tomorrow" and M.parse_tomorrow())
        or M.parse_next_weekday(expression)
end

-- Function to calculate the time difference and return a human-readable string
function M.time_until(datetime)
    -- Extract components from the ISO 8601 string
    local year = tonumber(datetime:sub(1, 4))
    local month = tonumber(datetime:sub(6, 7))
    local day = tonumber(datetime:sub(9, 10))
    local hour = tonumber(datetime:sub(12, 13))
    local min = tonumber(datetime:sub(15, 16))
    local sec = tonumber(datetime:sub(18, 19))

    -- Construct the reminder time as a UTC time
    local reminder_time = os.time({
        year = year,
        month = month,
        day = day,
        hour = hour,
        min = min,
        sec = sec,
        isdst = false  -- Disable daylight saving time adjustments
    })

    -- Get the current time in UTC
    local now = os.time(os.date("!*t"))
    local diff = os.difftime(reminder_time, now)

    if diff <= 0 then
        return "now"
    end

    local days = math.floor(diff / 86400)
    diff = diff % 86400
    local hours = math.floor(diff / 3600)
    diff = diff % 3600
    local minutes = math.floor(diff / 60)

    local parts = {}
    if days > 0 then table.insert(parts, days .. " days") end
    if hours > 0 then table.insert(parts, hours .. " hours") end
    if minutes > 0 then table.insert(parts, minutes .. " minutes") end

    return "in " .. table.concat(parts, " and ")
end

return M
