local M = {}

-- Token types for the lexer
local TokenType = {
    MONTH = "MONTH",
    DAY = "DAY",
    YEAR = "YEAR",
    WEEKDAY = "WEEKDAY",
    HOUR = "HOUR",
    MINUTE = "MINUTE",
    AMPM = "AMPM",
    RELATIVE_NUM = "RELATIVE_NUM",
    RELATIVE_UNIT = "RELATIVE_UNIT",
    TODAY = "TODAY",
    TOMORROW = "TOMORROW",
    NEXT = "NEXT",
    IN = "IN",
    AT = "AT",
    ON = "ON",
    NUMBER = "NUMBER", -- Ambiguous number, resolved by assembler
}

-- Table for time units and their corresponding seconds
local time_units = {
    minute = { single = "minute", plural = "minutes", seconds = 60 },
    hour = { single = "hour", plural = "hours", seconds = 3600 },
    day = { single = "day", plural = "days", seconds = 86400 },
    week = { single = "week", plural = "weeks", seconds = 604800 },
    month = { single = "month", plural = "months", seconds = 2592000 },
    year = { single = "year", plural = "years", seconds = 31536000 },
}

-- Unit name to key mapping
local unit_names = {
    minute = "minute", minutes = "minute",
    hour = "hour", hours = "hour",
    day = "day", days = "day",
    week = "week", weeks = "week",
    month = "month", months = "month",
    year = "year", years = "year",
}

-- Month name lookup table (lowercase keys)
local month_names = {
    january = 1, jan = 1,
    february = 2, feb = 2,
    march = 3, mar = 3,
    april = 4, apr = 4,
    may = 5,
    june = 6, jun = 6,
    july = 7, jul = 7,
    august = 8, aug = 8,
    september = 9, sept = 9, sep = 9,
    october = 10, oct = 10,
    november = 11, nov = 11,
    december = 12, dec = 12,
}

-- Weekday name lookup table (lowercase keys) - Sunday = 1 per Lua convention
local weekday_names = {
    sunday = 1, sun = 1,
    monday = 2, mon = 2,
    tuesday = 3, tue = 3, tues = 3,
    wednesday = 4, wed = 4,
    thursday = 5, thu = 5, thur = 5, thurs = 5,
    friday = 6, fri = 6,
    saturday = 7, sat = 7,
}

-- Days per month (non-leap year)
local days_in_month = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

-- Check if a year is a leap year
local function is_leap_year(year)
    return (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
end

-- Get days in a specific month/year
local function get_days_in_month(month, year)
    if month == 2 and is_leap_year(year) then
        return 29
    end
    return days_in_month[month]
end

-- Helper function to add seconds to the current time in UTC
local function add_time(seconds)
    return os.date("!%Y-%m-%dT%H:%M:%SZ", os.time() + seconds)
end

-- Strip ordinal suffixes (1st -> 1, 2nd -> 2, etc.)
local function strip_ordinal(str)
    local result = str:gsub("([0-9]+)[stndrh]+", "%1")
    return result
end

-- Tokenize the input expression
function M.tokenize(expression)
    local tokens = {}
    local pos = 1
    local input = expression:lower():gsub("^%s+", ""):gsub("%s+$", "")

    while pos <= #input do
        -- Skip whitespace
        local ws = input:match("^%s+", pos)
        if ws then
            pos = pos + #ws
        end

        if pos > #input then
            break
        end

        local matched = false

        -- 1. Keywords
        for _, kw in ipairs({ "tomorrow", "today", "next", "in", "at", "on" }) do
            local pattern = "^" .. kw .. "(%A)"
            local rest = input:match(pattern, pos)
            if rest or input:sub(pos, pos + #kw - 1) == kw and pos + #kw - 1 == #input then
                local token_type
                if kw == "tomorrow" then
                    token_type = TokenType.TOMORROW
                elseif kw == "today" then
                    token_type = TokenType.TODAY
                elseif kw == "next" then
                    token_type = TokenType.NEXT
                elseif kw == "in" then
                    token_type = TokenType.IN
                elseif kw == "at" then
                    token_type = TokenType.AT
                elseif kw == "on" then
                    token_type = TokenType.ON
                end
                table.insert(tokens, { type = token_type, value = kw })
                pos = pos + #kw
                matched = true
                break
            end
        end

        if not matched then
            -- 2. Month names (full before abbreviated)
            for name, num in pairs(month_names) do
                local pattern = "^" .. name .. "(%A)"
                local rest = input:match(pattern, pos)
                if rest or (input:sub(pos, pos + #name - 1) == name and (pos + #name - 1 == #input or not input:sub(pos + #name, pos + #name):match("%a"))) then
                    table.insert(tokens, { type = TokenType.MONTH, value = num })
                    pos = pos + #name
                    matched = true
                    break
                end
            end
        end

        if not matched then
            -- 3. Weekday names (full before abbreviated)
            for name, num in pairs(weekday_names) do
                local pattern = "^" .. name .. "(%A)"
                local rest = input:match(pattern, pos)
                if rest or (input:sub(pos, pos + #name - 1) == name and (pos + #name - 1 == #input or not input:sub(pos + #name, pos + #name):match("%a"))) then
                    table.insert(tokens, { type = TokenType.WEEKDAY, value = num })
                    pos = pos + #name
                    matched = true
                    break
                end
            end
        end

        if not matched then
            -- 4. Time units
            for name, key in pairs(unit_names) do
                local pattern = "^" .. name .. "(%A)"
                local rest = input:match(pattern, pos)
                if rest or (input:sub(pos, pos + #name - 1) == name and (pos + #name - 1 == #input or not input:sub(pos + #name, pos + #name):match("%a"))) then
                    table.insert(tokens, { type = TokenType.RELATIVE_UNIT, value = key })
                    pos = pos + #name
                    matched = true
                    break
                end
            end
        end

        if not matched then
            -- 5. AM/PM
            local ampm = input:match("^(a%.?m%.?)", pos) or input:match("^(p%.?m%.?)", pos)
            if ampm then
                local val = ampm:sub(1, 1) == "a" and "am" or "pm"
                table.insert(tokens, { type = TokenType.AMPM, value = val })
                pos = pos + #ampm
                matched = true
            end
        end

        if not matched then
            -- 6. Compound patterns

            -- Time with colon and optional am/pm: 6:30am, 6:30, 14:30
            local h, m, ap = input:match("^(%d+):(%d+)([ap]m)", pos)
            if h and m and ap then
                table.insert(tokens, { type = TokenType.HOUR, value = tonumber(h) })
                table.insert(tokens, { type = TokenType.MINUTE, value = tonumber(m) })
                table.insert(tokens, { type = TokenType.AMPM, value = ap })
                pos = pos + #h + 1 + #m + 2
                matched = true
            end

            if not matched then
                h, m = input:match("^(%d+):(%d+)", pos)
                if h and m then
                    table.insert(tokens, { type = TokenType.HOUR, value = tonumber(h) })
                    table.insert(tokens, { type = TokenType.MINUTE, value = tonumber(m) })
                    pos = pos + #h + 1 + #m
                    matched = true
                end
            end

            -- Time with am/pm attached: 6am, 12pm
            if not matched then
                h, ap = input:match("^(%d+)([ap]m)", pos)
                if h and ap then
                    table.insert(tokens, { type = TokenType.HOUR, value = tonumber(h) })
                    table.insert(tokens, { type = TokenType.AMPM, value = ap })
                    pos = pos + #h + 2
                    matched = true
                end
            end

            -- Slash date: 2/20/26, 02/20/2026
            if not matched then
                local mon, day, yr = input:match("^(%d+)/(%d+)/(%d+)", pos)
                if mon and day and yr then
                    table.insert(tokens, { type = TokenType.MONTH, value = tonumber(mon) })
                    table.insert(tokens, { type = TokenType.DAY, value = tonumber(day) })
                    local year_val = tonumber(yr)
                    if year_val < 100 then
                        year_val = year_val + 2000
                    end
                    table.insert(tokens, { type = TokenType.YEAR, value = year_val })
                    pos = pos + #mon + 1 + #day + 1 + #yr
                    matched = true
                end
            end
        end

        if not matched then
            -- 7. Bare numbers (with optional ordinal suffix)
            local num_str = input:match("^(%d+)[stndrh]*", pos)
            if num_str then
                local full_match = input:match("^%d+[stndrh]*", pos)
                table.insert(tokens, { type = TokenType.NUMBER, value = tonumber(strip_ordinal(num_str)) })
                pos = pos + #full_match
                matched = true
            end
        end

        if not matched then
            -- Skip comma and other punctuation
            local punct = input:match("^[,]+", pos)
            if punct then
                pos = pos + #punct
                matched = true
            end
        end

        if not matched then
            -- Unknown character, skip it
            pos = pos + 1
        end
    end

    return tokens
end

-- Resolve ambiguous NUMBER tokens based on context
local function resolve_numbers(tokens)
    local resolved = {}
    local i = 1

    while i <= #tokens do
        local token = tokens[i]
        local prev = resolved[#resolved]
        local next_token = tokens[i + 1]

        if token.type == TokenType.NUMBER then
            -- After IN and before RELATIVE_UNIT -> RELATIVE_NUM
            if prev and prev.type == TokenType.IN and next_token and next_token.type == TokenType.RELATIVE_UNIT then
                table.insert(resolved, { type = TokenType.RELATIVE_NUM, value = token.value })
            -- After MONTH -> DAY
            elseif prev and prev.type == TokenType.MONTH then
                table.insert(resolved, { type = TokenType.DAY, value = token.value })
            -- Before AMPM -> HOUR
            elseif next_token and next_token.type == TokenType.AMPM then
                table.insert(resolved, { type = TokenType.HOUR, value = token.value })
            -- After DAY and is 4 digits or >= 100 -> YEAR
            elseif prev and prev.type == TokenType.DAY and (token.value >= 100 or token.value >= 2000) then
                local year_val = token.value
                if year_val < 100 then
                    year_val = year_val + 2000
                end
                table.insert(resolved, { type = TokenType.YEAR, value = year_val })
            -- After DAY and small number, could be year (2-digit)
            elseif prev and prev.type == TokenType.DAY and token.value < 100 then
                table.insert(resolved, { type = TokenType.YEAR, value = token.value + 2000 })
            -- Standalone number after HOUR (no minute yet) -> MINUTE
            elseif prev and prev.type == TokenType.HOUR then
                table.insert(resolved, { type = TokenType.MINUTE, value = token.value })
            else
                -- Keep as NUMBER for now, assembler will handle or error
                table.insert(resolved, token)
            end
        else
            table.insert(resolved, token)
        end
        i = i + 1
    end

    return resolved
end

-- Convert 12-hour time to 24-hour
local function convert_to_24h(hour, ampm)
    if ampm == "am" then
        if hour == 12 then
            return 0
        end
        return hour
    elseif ampm == "pm" then
        if hour == 12 then
            return 12
        end
        return hour + 12
    end
    return hour
end

-- Find token by type
local function find_token(tokens, token_type)
    for _, t in ipairs(tokens) do
        if t.type == token_type then
            return t
        end
    end
    return nil
end

-- Check if tokens contain a type
local function has_token(tokens, token_type)
    return find_token(tokens, token_type) ~= nil
end

-- Assemble datetime from resolved tokens
function M.assemble(tokens, opts)
    opts = opts or {}
    local default_hour = opts.default_hour or 0
    local default_minute = opts.default_minute or 0

    -- Resolve ambiguous numbers
    tokens = resolve_numbers(tokens)

    -- Extract components
    local in_token = find_token(tokens, TokenType.IN)
    local rel_num = find_token(tokens, TokenType.RELATIVE_NUM)
    local rel_unit = find_token(tokens, TokenType.RELATIVE_UNIT)
    local month_token = find_token(tokens, TokenType.MONTH)
    local day_token = find_token(tokens, TokenType.DAY)
    local year_token = find_token(tokens, TokenType.YEAR)
    local weekday_token = find_token(tokens, TokenType.WEEKDAY)
    local today_token = find_token(tokens, TokenType.TODAY)
    local tomorrow_token = find_token(tokens, TokenType.TOMORROW)
    local next_token = find_token(tokens, TokenType.NEXT)
    local hour_token = find_token(tokens, TokenType.HOUR)
    local minute_token = find_token(tokens, TokenType.MINUTE)
    local ampm_token = find_token(tokens, TokenType.AMPM)

    -- 1. Relative expression: "in X units"
    if in_token and rel_num and rel_unit then
        local unit = time_units[rel_unit.value]
        if unit then
            return add_time(rel_num.value * unit.seconds), nil
        end
    end

    -- Also handle relative without "in" if we have RELATIVE_NUM and RELATIVE_UNIT
    if rel_num and rel_unit and not month_token and not weekday_token then
        local unit = time_units[rel_unit.value]
        if unit then
            return add_time(rel_num.value * unit.seconds), nil
        end
    end

    -- Get hour and minute with defaults
    local function get_time()
        local hour = hour_token and hour_token.value or default_hour
        local minute = minute_token and minute_token.value or default_minute

        if ampm_token then
            hour = convert_to_24h(hour, ampm_token.value)
        end

        return hour, minute
    end

    -- 2. Specific date: month + day (optional year)
    if month_token and day_token then
        local month = month_token.value
        local day = day_token.value

        -- Validate month
        if month < 1 or month > 12 then
            return nil, "Invalid month: " .. month
        end

        -- Determine year
        local year
        if year_token then
            year = year_token.value
        else
            -- Use next occurrence
            local now = os.date("*t")
            year = now.year

            -- Check if date has passed this year
            local hour, minute = get_time()
            local target = os.time({
                year = year,
                month = month,
                day = day,
                hour = hour,
                min = minute,
                sec = 0,
            })

            if target <= os.time() then
                year = year + 1
            end
        end

        -- Validate day for the month/year
        local max_days = get_days_in_month(month, year)
        if day < 1 or day > max_days then
            return nil, string.format("Invalid day %d for month %d", day, month)
        end

        local hour, minute = get_time()

        local target_time = os.time({
            year = year,
            month = month,
            day = day,
            hour = hour,
            min = minute,
            sec = 0,
        })

        return os.date("!%Y-%m-%dT%H:%M:%SZ", target_time), nil
    end

    -- 3. Weekday: optional "next"
    if weekday_token then
        local target_wday = weekday_token.value
        local now_local = os.date("*t")
        local hour, minute = get_time()

        local days_ahead = (target_wday - now_local.wday + 7) % 7

        if days_ahead == 0 then
            -- Same day - check if time has passed or "next" was specified
            if next_token then
                days_ahead = 7
            else
                local target_today = os.time({
                    year = now_local.year,
                    month = now_local.month,
                    day = now_local.day,
                    hour = hour,
                    min = minute,
                    sec = 0,
                })
                if target_today <= os.time() then
                    days_ahead = 7
                end
            end
        end

        local target_time = os.time({
            year = now_local.year,
            month = now_local.month,
            day = now_local.day + days_ahead,
            hour = hour,
            min = minute,
            sec = 0,
        })

        return os.date("!%Y-%m-%dT%H:%M:%SZ", target_time), nil
    end

    -- 4. Today/tomorrow
    if today_token or tomorrow_token then
        local base_time = os.time()
        if tomorrow_token then
            base_time = base_time + time_units.day.seconds
        end

        local local_time = os.date("*t", base_time)
        local hour, minute = get_time()

        local target_time = os.time({
            year = local_time.year,
            month = local_time.month,
            day = local_time.day,
            hour = hour,
            min = minute,
            sec = 0,
        })

        return os.date("!%Y-%m-%dT%H:%M:%SZ", target_time), nil
    end

    -- Check for ambiguous standalone number
    if has_token(tokens, TokenType.NUMBER) and not has_token(tokens, TokenType.HOUR) then
        return nil, "Ambiguous number without context"
    end

    return nil, "Could not parse expression"
end

-- Main function to parse any time expression
-- Returns: datetime_string, nil (success) OR nil, error_message (failure)
function M.parse(expression, opts)
    if not expression or expression == "" then
        return nil, "Empty expression"
    end

    local tokens = M.tokenize(expression)

    if #tokens == 0 then
        return nil, "No valid tokens found"
    end

    return M.assemble(tokens, opts)
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
        isdst = false, -- Disable daylight saving time adjustments
    })

    local now_utc = os.date("!*t")
    local now = os.time({
        year = now_utc.year,
        month = now_utc.month,
        day = now_utc.day,
        hour = now_utc.hour,
        min = now_utc.min,
        sec = now_utc.sec,
        isdst = false,
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
        return is_past and (pluralize(years, time_units.year) .. " ago")
            or ("in over " .. pluralize(years, time_units.year))
    elseif months > 0 then
        return is_past and (pluralize(months, time_units.month) .. " ago")
            or ("in over " .. pluralize(months, time_units.month))
    elseif weeks > 0 then
        return is_past and (pluralize(weeks, time_units.week) .. " ago")
            or ("in over " .. pluralize(weeks, time_units.week))
    elseif days >= 2 then
        return is_past and (pluralize(days, time_units.day) .. " ago") or ("in " .. pluralize(days, time_units.day))
    else
        local parts = {}
        if days > 0 then
            table.insert(parts, pluralize(days, time_units.day))
        end
        if hours > 0 then
            table.insert(parts, pluralize(hours, time_units.hour))
        end
        if minutes > 0 then
            table.insert(parts, pluralize(minutes, time_units.minute))
        end

        if #parts == 0 then
            return is_past and "just now" or "in a moment"
        else
            return is_past and (table.concat(parts, " and ") .. " ago") or ("in " .. table.concat(parts, " and "))
        end
    end
end

return M
