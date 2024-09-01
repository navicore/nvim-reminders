local M = {}

-- Helper function to add seconds to the current time in UTC
local function add_time(seconds)
    return os.date("!%Y-%m-%dT%H:%M:%SZ", os.time() + seconds)
end

-- Table for time units and their corresponding seconds
local time_units = {
    minute = {single = "minute", plural = "minutes", seconds = 60},
    hour = {single = "hour", plural = "hours", seconds = 3600},
    day = {single = "day", plural = "days", seconds = 86400},
    week = {single = "week", plural = "weeks", seconds = 604800},       -- Added support for weeks
    month = {single = "month", plural = "months", seconds = 2592000},   -- Approximation (30 days)
    year = {single = "year", plural = "years", seconds = 31536000},     -- Approximation (365 days)
}

-- General function to parse expressions like "in 20 minutes", "in 1 hour", etc.
function M.parse_time_expression(expression)
    for _, unit in pairs(time_units) do
        local pattern = "in (%d+) " .. unit.single .. "[s]?"
        local match = string.match(expression, pattern)
        if match then
            return add_time(tonumber(match) * unit.seconds)
        end
    end
end

-- Function to parse "tomorrow"
function M.parse_tomorrow()
    local tomorrow = os.time() + time_units.day.seconds
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
        local next_target_day = os.time() + (days_ahead * time_units.day.seconds)
        return os.date("!%Y-%m-%dT00:00:00Z", next_target_day)
    end
end

-- Main function to parse any time expression
function M.parse(expression)
    return M.parse_time_expression(expression)
        or (expression == "tomorrow" and M.parse_tomorrow())
        or M.parse_next_weekday(expression)
end

function M.time_until(datetime)
    -- Extract components from the ISO 8601 string and convert them to strings or numbers as needed
    local year = tostring(datetime:sub(1, 4))
    local month = tostring(datetime:sub(6, 7))
    local day = tostring(datetime:sub(9, 10))
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
    local now = os.time({
        year = tostring(os.date("!%Y")),
        month = tostring(os.date("!%m")),
        day = tostring(os.date("!%d")),
        hour = tonumber(os.date("!%H")),
        min = tonumber(os.date("!%M")),
        sec = tonumber(os.date("!%S")),
        isdst = false
    })

    local diff = os.difftime(reminder_time, now)

    local is_past = diff < 0
    diff = math.abs(diff)

    local years = math.floor(diff / time_units.year.seconds)
    diff = diff % time_units.year.seconds

    local months = math.floor(diff / time_units.month.seconds)
    diff = diff % time_units.month.seconds

    local weeks = math.floor(diff / time_units.week.seconds)
    diff = diff % time_units.week.seconds

    local days = math.floor(diff / time_units.day.seconds)
    diff = diff % time_units.day.seconds

    local hours = math.floor(diff / time_units.hour.seconds)
    diff = diff % time_units.hour.seconds

    local minutes = math.floor(diff / time_units.minute.seconds)

    if years > 0 then
        return is_past and (years .. " years ago") or ("in " .. years .. " years")
    elseif months > 0 then
        return is_past and (months .. " months ago") or ("in " .. months .. " months")
    elseif weeks > 0 then
        return is_past and (weeks .. " weeks ago") or ("in " .. weeks .. " weeks")
    elseif days >= 2 then
        return is_past and (days .. " days ago") or ("in " .. days .. " days")
    else
        local parts = {}
        if days > 0 then table.insert(parts, days .. " days") end
        if hours > 0 then table.insert(parts, hours .. " hours") end
        if minutes > 0 then table.insert(parts, minutes .. " minutes") end

        if #parts == 0 then
            return is_past and "just now" or "in a moment"
        else
            return is_past and (table.concat(parts, " and ") .. " ago") or ("in " .. table.concat(parts, " and "))
        end
    end
end

return M
