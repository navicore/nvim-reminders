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

-- Month name lookup table (lowercase keys)
local month_names = {
    jan = 1, january = 1,
    feb = 2, february = 2,
    mar = 3, march = 3,
    apr = 4, april = 4,
    may = 5,
    jun = 6, june = 6,
    jul = 7, july = 7,
    aug = 8, august = 8,
    sep = 9, sept = 9, september = 9,
    oct = 10, october = 10,
    nov = 11, november = 11,
    dec = 12, december = 12,
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

-- Function to parse "on  at 11:00am"
function M.parse_full_date_time(expression)
    -- Patterns to match different date and time formats
    local patterns = {
        -- Date with time and am/pm (e.g., "11/1/24 9am")
        {"^%s*(%d+)%/(%d+)%/(%d+)%s+(%d+):(%d+)([ap]m)%s*$", {"month_str", "day_str", "year_str", "hour_str", "minute_str", "ampm"}},
        {"^%s*(%d+)%/(%d+)%/(%d+)%s+(%d+)([ap]m)%s*$", {"month_str", "day_str", "year_str", "hour_str", "ampm"}},
        -- Date with time in 24-hour format (e.g., "9/30/2024 8:15")
        {"^%s*(%d+)%/(%d+)%/(%d+)%s+(%d+):(%d+)%s*$", {"month_str", "day_str", "year_str", "hour_str", "minute_str"}},
        {"^%s*(%d+)%/(%d+)%/(%d+)%s+(%d+)%s*$", {"month_str", "day_str", "year_str", "hour_str"}},
        -- Date only (e.g., "10/01/2024")
        {"^%s*(%d+)%/(%d+)%/(%d+)%s*$", {"month_str", "day_str", "year_str"}},
    }

    for _, pattern_info in ipairs(patterns) do
        local pattern = pattern_info[1]
        local captures = pattern_info[2]
        local match = {string.match(expression, pattern)}
        if #match > 0 then
            local data = {}
            for i, capture_name in ipairs(captures) do
                data[capture_name] = match[i]
            end

            local month_str = data.month_str
            local day_str = data.day_str
            local year_str = data.year_str
            local hour_str = data.hour_str or "0"
            local minute_str = data.minute_str or "0"
            local ampm = data.ampm

            local month = tonumber(month_str)
            local day = tonumber(day_str)
            local year = tonumber(year_str)
            local hour = tonumber(hour_str)
            local minute = tonumber(minute_str)

            -- Adjust year: if year is two digits, assume it's 2000+
            if year < 100 then
                year = year + 2000
            end

            -- Adjust hour based on am/pm if provided
            if ampm then
                ampm = ampm:lower()
                if ampm == "pm" and hour ~= 12 then
                    hour = hour + 12
                elseif ampm == "am" and hour == 12 then
                    hour = 0
                end
            end

            -- Validate date components
            if month < 1 or month > 12 or day < 1 or day > 31 then
                return nil  -- Invalid date
            end

            -- Construct the target time in UTC
            local target_time = os.time({
                year = tostring(year),
                month = tostring(month),
                day = tostring(day),
                hour = hour,
                min = minute,
                sec = 0,
                isdst = false
            })

            -- Ensure the time is valid
            if target_time then
                return os.date("!%Y-%m-%dT%H:%M:%SZ", target_time)
            end
        end
    end

    return nil
end

-- Function to parse "on Monday at 11:00am"
function M.parse_on_weekday_at_time(expression)
    local days_of_week = {
        sunday = 1,
        monday = 2,
        tuesday = 3,
        wednesday = 4,
        thursday = 5,
        friday = 6,
        saturday = 7,
    }

    -- List of patterns to match different expressions
    local patterns = {
        -- With 'on' and 'at', with time and am/pm
        {"^on%s+(%a+)%s+at%s+(%d+):(%d+)([ap]m)%s*$", {"day_str", "hour_str", "minute_str", "ampm"}},
        {"^on%s+(%a+)%s+at%s+(%d+)([ap]m)%s*$", {"day_str", "hour_str", "ampm"}},
        {"^on%s+(%a+)%s+at%s+(%d+):(%d+)%s*$", {"day_str", "hour_str", "minute_str"}},
        {"^on%s+(%a+)%s+at%s+(%d+)%s*$", {"day_str", "hour_str"}},
        -- Without 'at', directly time after day
        {"^on%s+(%a+)%s+(%d+):(%d+)([ap]m)%s*$", {"day_str", "hour_str", "minute_str", "ampm"}},
        {"^on%s+(%a+)%s+(%d+)([ap]m)%s*$", {"day_str", "hour_str", "ampm"}},
        {"^on%s+(%a+)%s+(%d+)%s*$", {"day_str", "hour_str"}},
        -- With 'next' keyword
        {"^next%s+(%a+)%s+at%s+(%d+):(%d+)([ap]m)%s*$", {"day_str", "hour_str", "minute_str", "ampm"}},
        {"^next%s+(%a+)%s+at%s+(%d+)([ap]m)%s*$", {"day_str", "hour_str", "ampm"}},
        {"^next%s+(%a+)%s+at%s+(%d+):(%d+)%s*$", {"day_str", "hour_str", "minute_str"}},
        {"^next%s+(%a+)%s+at%s+(%d+)%s*$", {"day_str", "hour_str"}},
        {"^next%s+(%a+)%s+(%d+):(%d+)([ap]m)%s*$", {"day_str", "hour_str", "minute_str", "ampm"}},
        {"^next%s+(%a+)%s+(%d+)([ap]m)%s*$", {"day_str", "hour_str", "ampm"}},
        {"^next%s+(%a+)%s+(%d+)%s*$", {"day_str", "hour_str"}},
        -- Without 'on' or 'next'
        {"^(%a+)%s+at%s+(%d+):(%d+)([ap]m)%s*$", {"day_str", "hour_str", "minute_str", "ampm"}},
        {"^(%a+)%s+at%s+(%d+)([ap]m)%s*$", {"day_str", "hour_str", "ampm"}},
        {"^(%a+)%s+at%s+(%d+)%s*$", {"day_str", "hour_str"}},
        {"^(%a+)%s+(%d+):(%d+)([ap]m)%s*$", {"day_str", "hour_str", "minute_str", "ampm"}},
        {"^(%a+)%s+(%d+)([ap]m)%s*$", {"day_str", "hour_str", "ampm"}},
        {"^(%a+)%s+(%d+)%s*$", {"day_str", "hour_str"}},
    }

    -- Iterate over each pattern
    for _, pattern_info in ipairs(patterns) do
        local pattern = pattern_info[1]
        local captures = pattern_info[2]
        local match = {string.match(expression, pattern)}
        if #match > 0 then
            local data = {}
            for i, capture_name in ipairs(captures) do
                data[capture_name] = match[i]
            end

            local day_str = data.day_str
            local hour_str = data.hour_str
            local minute_str = data.minute_str or "0"
            local ampm = data.ampm

            if day_str and hour_str then
                local target_wday = days_of_week[day_str:lower()]
                if not target_wday then
                    return nil
                end

                local hour = tonumber(hour_str)
                local minute = tonumber(minute_str)

                -- Adjust hour based on am/pm if provided
                if ampm then
                    ampm = ampm:lower()
                    if ampm == "pm" and hour ~= 12 then
                        hour = hour + 12
                    elseif ampm == "am" and hour == 12 then
                        hour = 0
                    end
                end

                -- Construct the UTC timestamp manually
                local now_utc = os.date("!*t")

                -- Determine if 'next' was in the expression
                local is_next = expression:lower():find("^%s*on%s+next%s+") or expression:lower():find("^%s*next%s+")

                -- Calculate days ahead
                local days_ahead = (target_wday - now_utc.wday + 7) % 7
                if days_ahead == 0 then
                    if is_next or (hour < now_utc.hour or (hour == now_utc.hour and minute <= now_utc.min)) then
                        days_ahead = 7  -- Move to next week if time has already passed today
                    end
                end

                -- Construct the target time
                local target_time = os.time({
                    year = now_utc.year,
                    month = now_utc.month,
                    day = now_utc.day + days_ahead,
                    hour = hour,
                    min = minute,
                    sec = 0,
                    isdst = false
                })

                return os.date("!%Y-%m-%dT%H:%M:%SZ", target_time)
            end
        end
    end

    return nil
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

-- Function to parse "today at X" or "tomorrow at X"
function M.parse_specific_day_with_time(expression)
    -- Match patterns like "today at 6:30am" or "tomorrow at 6am"
    local patterns = {
        {"^(today)%s+at%s+(%d+):(%d+)([ap]m)$", {"day", "hour_str", "minute_str", "ampm"}}, -- HH:MM am/pm
        {"^(today)%s+at%s+(%d+)([ap]m)$", {"day", "hour_str", "ampm"}},                   -- HH am/pm
        {"^(tomorrow)%s+at%s+(%d+):(%d+)([ap]m)$", {"day", "hour_str", "minute_str", "ampm"}}, -- HH:MM am/pm
        {"^(tomorrow)%s+at%s+(%d+)([ap]m)$", {"day", "hour_str", "ampm"}}                -- HH am/pm
    }

    for _, pattern_info in ipairs(patterns) do
        local pattern = pattern_info[1]
        local captures = pattern_info[2]
        local match = {string.match(expression, pattern)}
        if #match > 0 then
            local data = {}
            for i, capture_name in ipairs(captures) do
                data[capture_name] = match[i]
            end

            local day = data.day
            local hour_str = data.hour_str
            local minute_str = data.minute_str or "0" -- Default to 0 minutes if not provided
            local ampm = data.ampm

            local hour = tonumber(hour_str)
            local minute = tonumber(minute_str)

            -- Adjust hour based on am/pm
            if ampm then
                ampm = ampm:lower()
                if ampm == "pm" and hour ~= 12 then
                    hour = hour + 12
                elseif ampm == "am" and hour == 12 then
                    hour = 0
                end
            end

            -- Determine the base date (today or tomorrow)
            local base_time = os.time()
            if day == "tomorrow" then
                base_time = base_time + time_units.day.seconds
            end

            -- Get local time components for the base day
            local local_time = os.date("*t", base_time)
            local_time.hour = hour
            local_time.min = minute
            local_time.sec = 0

            -- Convert to UTC and format as ISO 8601
            local target_time = os.time(local_time)
            return os.date("!%Y-%m-%dT%H:%M:%SZ", target_time)
        end
    end

    return nil
end

-- Helper to strip ordinal suffixes (1st -> 1, 2nd -> 2, etc.)
local function strip_ordinal(day_str)
    local result = day_str:gsub("([0-9]+)[stndrh]+", "%1")
    return result
end

-- Helper to determine the next occurrence of a month/day
local function next_occurrence(month, day, hour, minute)
    local now = os.date("!*t")
    local year = now.year

    -- Build target date for this year
    local target = os.time({
        year = year,
        month = month,
        day = day,
        hour = hour or 0,
        min = minute or 0,
        sec = 0,
        isdst = false
    })

    -- If target is in the past, use next year
    local now_time = os.time({
        year = now.year,
        month = now.month,
        day = now.day,
        hour = now.hour,
        min = now.min,
        sec = now.sec,
        isdst = false
    })

    if target <= now_time then
        target = os.time({
            year = year + 1,
            month = month,
            day = day,
            hour = hour or 0,
            min = minute or 0,
            sec = 0,
            isdst = false
        })
    end

    return target
end

-- Function to parse named date expressions like "Jan 1", "on January 15", "Dec 25, 2025"
function M.parse_named_date(expression)
    -- Patterns to match various named date formats
    -- Order matters: more specific patterns first
    -- Note: ordinal suffixes (st, nd, rd, th) are optional and handled separately
    local patterns = {
        -- "on Jan 1 at 9:30am" or "January 1 at 9:30am"
        {"^on%s+(%a+)%s+(%d+)%a*%s+at%s+(%d+):(%d+)%s*([ap]m)%s*$", {"month_str", "day_str", "hour_str", "minute_str", "ampm"}},
        {"^(%a+)%s+(%d+)%a*%s+at%s+(%d+):(%d+)%s*([ap]m)%s*$", {"month_str", "day_str", "hour_str", "minute_str", "ampm"}},
        -- "on Jan 1 at 9am" or "January 1 at 9am"
        {"^on%s+(%a+)%s+(%d+)%a*%s+at%s+(%d+)%s*([ap]m)%s*$", {"month_str", "day_str", "hour_str", "ampm"}},
        {"^(%a+)%s+(%d+)%a*%s+at%s+(%d+)%s*([ap]m)%s*$", {"month_str", "day_str", "hour_str", "ampm"}},
        -- "on Jan 1 at 9:30" or "January 1 at 9:30" (24-hour)
        {"^on%s+(%a+)%s+(%d+)%a*%s+at%s+(%d+):(%d+)%s*$", {"month_str", "day_str", "hour_str", "minute_str"}},
        {"^(%a+)%s+(%d+)%a*%s+at%s+(%d+):(%d+)%s*$", {"month_str", "day_str", "hour_str", "minute_str"}},
        -- "on Jan 1 at 9" (24-hour)
        {"^on%s+(%a+)%s+(%d+)%a*%s+at%s+(%d+)%s*$", {"month_str", "day_str", "hour_str"}},
        {"^(%a+)%s+(%d+)%a*%s+at%s+(%d+)%s*$", {"month_str", "day_str", "hour_str"}},
        -- "January 1, 2026 at 9:30am"
        {"^(%a+)%s+(%d+)%a*,?%s+(%d%d%d%d)%s+at%s+(%d+):(%d+)%s*([ap]m)%s*$", {"month_str", "day_str", "year_str", "hour_str", "minute_str", "ampm"}},
        -- "January 1, 2026 at 9am"
        {"^(%a+)%s+(%d+)%a*,?%s+(%d%d%d%d)%s+at%s+(%d+)%s*([ap]m)%s*$", {"month_str", "day_str", "year_str", "hour_str", "ampm"}},
        -- "January 1, 2026" (with comma, optional)
        {"^(%a+)%s+(%d+)%a*,?%s+(%d%d%d%d)%s*$", {"month_str", "day_str", "year_str"}},
        -- "on Jan 1" or "Jan 1" (no year, defaults to next occurrence)
        {"^on%s+(%a+)%s+(%d+)%a*%s*$", {"month_str", "day_str"}},
        {"^(%a+)%s+(%d+)%a*%s*$", {"month_str", "day_str"}},
    }

    for _, pattern_info in ipairs(patterns) do
        local pattern = pattern_info[1]
        local captures = pattern_info[2]
        local match = {string.match(expression, pattern)}

        if #match > 0 then
            local data = {}
            for i, capture_name in ipairs(captures) do
                data[capture_name] = match[i]
            end

            local month_str = data.month_str
            local day_str = data.day_str
            local year_str = data.year_str
            local hour_str = data.hour_str
            local minute_str = data.minute_str or "0"
            local ampm = data.ampm

            -- Look up month number
            local month = month_names[month_str:lower()]
            if not month then
                return nil -- Not a valid month name
            end

            local day = tonumber(strip_ordinal(day_str))
            local hour = hour_str and tonumber(hour_str) or 0
            local minute = tonumber(minute_str)

            -- Validate day
            if not day or day < 1 or day > 31 then
                return nil
            end

            -- Adjust hour based on am/pm if provided
            if ampm then
                ampm = ampm:lower()
                if ampm == "pm" and hour ~= 12 then
                    hour = hour + 12
                elseif ampm == "am" and hour == 12 then
                    hour = 0
                end
            end

            local target_time
            if year_str then
                -- Explicit year provided - construct UTC time directly
                local year = tonumber(year_str)
                if year < 100 then
                    year = year + 2000
                end
                -- Use os.time to get a timestamp, then format as UTC
                -- We need to account for local timezone offset
                local utc_time = os.time({
                    year = year,
                    month = month,
                    day = day,
                    hour = hour,
                    min = minute,
                    sec = 0,
                })
                -- Format directly as the UTC time we want (treating input as UTC)
                return string.format("%04d-%02d-%02dT%02d:%02d:00Z", year, month, day, hour, minute)
            else
                -- No year, use next occurrence
                target_time = next_occurrence(month, day, hour, minute)
                if target_time then
                    -- Get the date components and format as UTC
                    local t = os.date("*t", target_time)
                    return string.format("%04d-%02d-%02dT%02d:%02d:00Z", t.year, t.month, t.day, hour, minute)
                end
            end
        end
    end

    return nil
end

-- Main function to parse any time expression
function M.parse(expression)
    return M.parse_time_expression(expression)
        or M.parse_on_weekday_at_time(expression)
        or M.parse_next_weekday(expression)
        or M.parse_named_date(expression)
        or M.parse_full_date_time(expression)
        or M.parse_specific_day_with_time(expression)
end

function M.time_until(datetime)
    -- Extract components from the ISO 8601 string and convert them to strings or numbers as needed
    local year = tonumber(datetime:sub(1, 4))
    local month = tonumber(datetime:sub(6, 7))
    local day = tonumber(datetime:sub(9, 10))
    local hour = tonumber(datetime:sub(12, 13))
    local min = tonumber(datetime:sub(15, 16))
    local sec = tonumber(datetime:sub(18, 19))

    -- Construct the reminder time as a UTC time
    local reminder_time = os.time({
        year = tostring(year),
        month = tostring(month),
        day = tostring(day),
        hour = hour,
        min = min,
        sec = sec,
        isdst = false  -- Disable daylight saving time adjustments
    })

    local now_utc = os.date("!*t")
    local now = os.time({
        year = now_utc.year,
        month = now_utc.month,
        day = now_utc.day,
        hour = now_utc.hour,
        min = now_utc.min,
        sec = now_utc.sec,
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

    local function pluralize(value, unit)
        if value == 1 then
            return value .. " " .. unit.single
        elseif value > 1 then
            return value .. " " .. unit.plural
        end
    end

    if years > 0 then
        return is_past and (pluralize(years, time_units.year) .. " ago") or ("in over " .. pluralize(years, time_units.year))
    elseif months > 0 then
        return is_past and (pluralize(months, time_units.month) .. " ago") or ("in over " .. pluralize(months, time_units.month))
    elseif weeks > 0 then
        return is_past and (pluralize(weeks, time_units.week) .. " ago") or ("in over " .. pluralize(weeks, time_units.week))
    elseif days >= 2 then
        return is_past and (pluralize(days, time_units.day) .. " ago") or ("in " .. pluralize(days, time_units.day))
    else
        local parts = {}
        if days > 0 then table.insert(parts, pluralize(days, time_units.day)) end
        if hours > 0 then table.insert(parts, pluralize(hours, time_units.hour)) end
        if minutes > 0 then table.insert(parts, pluralize(minutes, time_units.minute)) end

        if #parts == 0 then
            return is_past and "just now" or "in a moment"
        else
            return is_past and (table.concat(parts, " and ") .. " ago") or ("in " .. table.concat(parts, " and "))
        end
    end
end

return M
