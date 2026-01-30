-- run via:
-- :PlenaryBustedFile tests/time_parser_spec.lua
-- or
-- :PlenaryBustedDirectory tests

local function to_utc(local_time)
    -- Assuming local_time is in the format "YYYY-MM-DDTHH:MM:SSZ"
    local pattern = "(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)Z"
    local year, month, day, hour, min, sec = local_time:match(pattern)
    local time = os.time({
        year = year,
        month = month,
        day = day,
        hour = hour,
        min = min,
        sec = sec,
        isdst = false
    })
    local utc_time = os.date("!%Y-%m-%dT%H:%M:%SZ", time)
    return utc_time
end

local function get_iso8601_datetime(hours_offset)
    local os_time = os.time() + (hours_offset * 3600)
    return os.date("!%Y-%m-%dT%H:%M:%SZ", os_time)
end

local function compare_time(expected, actual)
    local expected_hour = tonumber(expected:sub(12, 13))
    local expected_minute = tonumber(expected:sub(15, 16))
    local actual_hour = tonumber(actual:sub(12, 13))
    local actual_minute = tonumber(actual:sub(15, 16))

    if expected_hour == actual_hour and expected_minute == actual_minute then
        return true
    else
        return false, string.format("Expected time: %02d:%02d, but got: %02d:%02d", expected_hour, expected_minute, actual_hour, actual_minute)
    end
end

local parse = require "reminders.time_parser".parse
local tokenize = require "reminders.time_parser".tokenize

assert.are.are_function(parse)

describe("parse - relative expressions", function()
    it("should return ISO 8601 datetime string for 'in 10 hours'", function()
        local expected = get_iso8601_datetime(10)
        local result = parse("in 10 hours")
        assert.are.equal(expected, result)
    end)
    it("should return ISO 8601 datetime string for 'in 11 days'", function()
        local expected = get_iso8601_datetime(11 * 24)
        local result = parse("in 11 days")
        assert.are.equal(expected, result)
    end)
    it("should return ISO 8601 datetime string for 'in 60 minutes'", function()
        local expected = get_iso8601_datetime(1)
        local result = parse("in 60 minutes")
        assert.are.equal(expected, result)
    end)
    it("should return ISO 8601 datetime string for 'in 1 week'", function()
        local expected = get_iso8601_datetime(7 * 24)
        local result = parse("in 1 week")
        assert.are.equal(expected, result)
    end)
    it("should return ISO 8601 datetime string for 'in 2 weeks'", function()
        local expected = get_iso8601_datetime(14 * 24)
        local result = parse("in 2 weeks")
        assert.are.equal(expected, result)
    end)
    it("should return ISO 8601 datetime string for 'in 1 month'", function()
        local expected = get_iso8601_datetime(30 * 24)
        local result = parse("in 1 month")
        assert.are.equal(expected, result)
    end)
end)

describe("parse - today/tomorrow", function()
    it("should return ISO 8601 datetime string for 'tomorrow at 6am'", function()
        local expected_local = "2023-10-15T06:00:00Z"
        local expected_utc = to_utc(expected_local)
        local result = parse("tomorrow at 6am")
        local success, err = compare_time(expected_utc, result)
        assert.is_true(success, err)
    end)
    it("should return ISO 8601 datetime string for 'today at 6:30pm'", function()
        local expected_local = "2023-10-14T18:30:00Z"
        local expected_utc = to_utc(expected_local)
        local result = parse("today at 6:30pm")
        local success, err = compare_time(expected_utc, result)
        assert.is_true(success, err)
    end)

    -- Time-first patterns
    it("should parse '6am tomorrow' with time before day", function()
        local result = parse("6am tomorrow")
        assert.is_not_nil(result)
    end)

    it("should parse '9:30am tomorrow' with time before day", function()
        local result = parse("9:30am tomorrow")
        assert.is_not_nil(result)
    end)

    it("should parse 'tomorrow 6am' without 'at'", function()
        local result = parse("tomorrow 6am")
        assert.is_not_nil(result)
    end)

    it("should parse '1pm today' for snooze", function()
        local result = parse("1pm today")
        assert.is_not_nil(result)
    end)
end)

describe("parse - weekdays", function()
    it("should return ISO 8601 datetime string for 'next Tuesday'", function()
        local result = parse("next Tuesday")
        assert.is_not_nil(result)
        -- Verify it's a valid ISO 8601 datetime
        assert.is_truthy(result:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"))
    end)

    it("should parse 'Sunday' as next Sunday at local midnight", function()
        local result = parse("Sunday")
        assert.is_not_nil(result)
        -- Verify it's a valid ISO 8601 datetime
        assert.is_truthy(result:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"))
    end)

    it("should parse 'on Sunday' as next Sunday at local midnight", function()
        local result = parse("on Sunday")
        assert.is_not_nil(result)
        assert.is_truthy(result:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"))
    end)

    it("should parse 'on Monday' as next Monday at local midnight", function()
        local result = parse("on Monday")
        assert.is_not_nil(result)
        assert.is_truthy(result:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"))
    end)

    it("should parse 'Monday 6am' for snooze", function()
        local result = parse("Monday 6am")
        assert.is_not_nil(result)
    end)

    it("should parse 'next Monday at 9am'", function()
        local result = parse("next Monday at 9am")
        assert.is_not_nil(result)
    end)

    it("should parse 'on Tuesday at 3pm'", function()
        local result = parse("on Tuesday at 3pm")
        assert.is_not_nil(result)
    end)
end)

describe("parse - named dates", function()
    -- Helper: convert local time to expected UTC string
    local function local_to_utc(year, month, day, hour, minute)
        local local_time = os.time({year=year, month=month, day=day, hour=hour, min=minute, sec=0})
        return os.date("!%Y-%m-%dT%H:%M:%SZ", local_time)
    end

    it("should parse 'Jan 1' as a valid date", function()
        local result = parse("Jan 1")
        assert.is_not_nil(result)
        -- Should be Jan 1 at local midnight, converted to UTC
        assert.is_truthy(result:match("^%d%d%d%d%-01%-01T%d%d:%d%d:%d%dZ$"))
    end)

    it("should parse 'on Jan 1' as a valid date", function()
        local result = parse("on Jan 1")
        assert.is_not_nil(result)
        assert.is_truthy(result:match("^%d%d%d%d%-01%-01T%d%d:%d%d:%d%dZ$"))
    end)

    it("should parse 'January 1' as a valid date", function()
        local result = parse("January 1")
        assert.is_not_nil(result)
        assert.is_truthy(result:match("^%d%d%d%d%-01%-01T%d%d:%d%d:%d%dZ$"))
    end)

    it("should parse 'December 25, 2025' with explicit year", function()
        local result = parse("December 25, 2025")
        assert.is_not_nil(result)
        -- Midnight local → UTC (varies by timezone)
        local expected = local_to_utc(2025, 12, 25, 0, 0)
        assert.are.equal(expected, result)
    end)

    it("should parse 'Jan 1, 2026' with explicit year", function()
        local result = parse("Jan 1, 2026")
        assert.is_not_nil(result)
        local expected = local_to_utc(2026, 1, 1, 0, 0)
        assert.are.equal(expected, result)
    end)

    it("should parse 'Feb 14 at 6pm' with time", function()
        local result = parse("Feb 14 at 6pm")
        assert.is_not_nil(result)
        -- 6pm local → UTC (date may shift to Feb 15 depending on timezone)
        assert.is_truthy(result:match("^%d%d%d%d%-02%-1[45]T%d%d:%d%d:%d%dZ$"))
    end)

    it("should parse 'on March 15 at 9:30am' with time", function()
        local result = parse("on March 15 at 9:30am")
        assert.is_not_nil(result)
        assert.is_truthy(result:match("^%d%d%d%d%-03%-15T%d%d:%d%d:%d%dZ$"))
    end)

    it("should parse 'July 4th' with ordinal suffix", function()
        local result = parse("July 4th")
        assert.is_not_nil(result)
        assert.is_truthy(result:match("^%d%d%d%d%-07%-04T%d%d:%d%d:%d%dZ$"))
    end)

    it("should parse 'Dec 1st at 12pm' with ordinal and time", function()
        local result = parse("Dec 1st at 12pm")
        assert.is_not_nil(result)
        assert.is_truthy(result:match("^%d%d%d%d%-12%-01T%d%d:%d%d:%d%dZ$"))
    end)

    it("should parse 'September 2, 2025 at 3:30pm' full format", function()
        local result = parse("September 2, 2025 at 3:30pm")
        assert.is_not_nil(result)
        -- 3:30pm local → UTC
        local expected = local_to_utc(2025, 9, 2, 15, 30)
        assert.are.equal(expected, result)
    end)
end)

describe("parse - numeric dates", function()
    local function local_to_utc(year, month, day, hour, minute)
        local local_time = os.time({year=year, month=month, day=day, hour=hour, min=minute, sec=0})
        return os.date("!%Y-%m-%dT%H:%M:%SZ", local_time)
    end

    it("should parse '2/20/26' as a valid date", function()
        local result = parse("2/20/26")
        assert.is_not_nil(result)
        local expected = local_to_utc(2026, 2, 20, 0, 0)
        assert.are.equal(expected, result)
    end)

    it("should parse '02/20/2026' as a valid date", function()
        local result = parse("02/20/2026")
        assert.is_not_nil(result)
        local expected = local_to_utc(2026, 2, 20, 0, 0)
        assert.are.equal(expected, result)
    end)

    it("should parse '2/20/26 9am'", function()
        local result = parse("2/20/26 9am")
        assert.is_not_nil(result)
        local expected = local_to_utc(2026, 2, 20, 9, 0)
        assert.are.equal(expected, result)
    end)

    it("should parse '12/25/2025 8:30am'", function()
        local result = parse("12/25/2025 8:30am")
        assert.is_not_nil(result)
        local expected = local_to_utc(2025, 12, 25, 8, 30)
        assert.are.equal(expected, result)
    end)
end)

describe("parse - word order flexibility", function()
    it("should parse 'Feb 20 6am' (date time)", function()
        local result = parse("Feb 20 6am")
        assert.is_not_nil(result)
    end)

    it("should parse '6am Feb 20' (time date)", function()
        local result = parse("6am Feb 20")
        assert.is_not_nil(result)
    end)

    it("should parse 'on Feb 20 at 6am'", function()
        local result = parse("on Feb 20 at 6am")
        assert.is_not_nil(result)
    end)

    it("should parse 'Feb 20 at 6am' without 'on'", function()
        local result = parse("Feb 20 at 6am")
        assert.is_not_nil(result)
    end)

    it("should parse '6:30pm tomorrow'", function()
        local result = parse("6:30pm tomorrow")
        assert.is_not_nil(result)
    end)

    it("should parse 'tomorrow 6:30pm'", function()
        local result = parse("tomorrow 6:30pm")
        assert.is_not_nil(result)
    end)
end)

describe("parse - default_hour option", function()
    local function local_to_utc(year, month, day, hour, minute)
        local local_time = os.time({year=year, month=month, day=day, hour=hour, min=minute, sec=0})
        return os.date("!%Y-%m-%dT%H:%M:%SZ", local_time)
    end

    it("should use default_hour when no time specified", function()
        local result = parse("Feb 20, 2026", {default_hour = 8})
        assert.is_not_nil(result)
        local expected = local_to_utc(2026, 2, 20, 8, 0)
        assert.are.equal(expected, result)
    end)

    it("should use default_hour and default_minute", function()
        local result = parse("Feb 20, 2026", {default_hour = 9, default_minute = 30})
        assert.is_not_nil(result)
        local expected = local_to_utc(2026, 2, 20, 9, 30)
        assert.are.equal(expected, result)
    end)

    it("should override default when time is specified", function()
        local result = parse("Feb 20, 2026 at 3pm", {default_hour = 8})
        assert.is_not_nil(result)
        local expected = local_to_utc(2026, 2, 20, 15, 0)
        assert.are.equal(expected, result)
    end)

    it("should default to midnight when no opts provided", function()
        local result = parse("Feb 20, 2026")
        assert.is_not_nil(result)
        local expected = local_to_utc(2026, 2, 20, 0, 0)
        assert.are.equal(expected, result)
    end)

    it("should use default_hour for weekday without time", function()
        local result = parse("Monday", {default_hour = 9})
        assert.is_not_nil(result)
        -- Verify it has 09:XX or 17:XX depending on timezone
        assert.is_truthy(result:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"))
    end)
end)

describe("parse - error cases", function()
    it("should return nil and error for empty expression", function()
        local result, err = parse("")
        assert.is_nil(result)
        assert.is_not_nil(err)
    end)

    it("should return nil and error for nil expression", function()
        local result, err = parse(nil)
        assert.is_nil(result)
        assert.is_not_nil(err)
    end)

    it("should return nil and error for invalid month name", function()
        local result, err = parse("Foo 15")
        assert.is_nil(result)
        assert.is_not_nil(err)
    end)

    it("should return nil and error for Feb 31 (invalid day)", function()
        local result, err = parse("Feb 31, 2026")
        assert.is_nil(result)
        assert.is_truthy(err:match("Invalid day"))
    end)

    it("should return nil and error for Apr 31 (invalid day)", function()
        local result, err = parse("Apr 31, 2026")
        assert.is_nil(result)
        assert.is_truthy(err:match("Invalid day"))
    end)

    it("should allow Feb 29 in leap year", function()
        local result = parse("Feb 29, 2024")
        assert.is_not_nil(result)
    end)

    it("should reject Feb 29 in non-leap year", function()
        local result, err = parse("Feb 29, 2025")
        assert.is_nil(result)
        assert.is_truthy(err:match("Invalid day"))
    end)

    it("should return nil and error for ambiguous standalone number", function()
        local result, err = parse("15")
        assert.is_nil(result)
        assert.is_not_nil(err)
    end)
end)

describe("tokenize", function()
    it("should tokenize 'in 10 minutes'", function()
        local tokens = tokenize("in 10 minutes")
        assert.are.equal(3, #tokens)
        assert.are.equal("IN", tokens[1].type)
        assert.are.equal("NUMBER", tokens[2].type)
        assert.are.equal(10, tokens[2].value)
        assert.are.equal("RELATIVE_UNIT", tokens[3].type)
        assert.are.equal("minute", tokens[3].value)
    end)

    it("should tokenize 'Feb 20 at 6am'", function()
        local tokens = tokenize("Feb 20 at 6am")
        assert.are.equal(5, #tokens)
        assert.are.equal("MONTH", tokens[1].type)
        assert.are.equal(2, tokens[1].value)
        assert.are.equal("NUMBER", tokens[2].type)
        assert.are.equal(20, tokens[2].value)
        assert.are.equal("AT", tokens[3].type)
        assert.are.equal("HOUR", tokens[4].type)
        assert.are.equal(6, tokens[4].value)
        assert.are.equal("AMPM", tokens[5].type)
        assert.are.equal("am", tokens[5].value)
    end)

    it("should tokenize '6:30am tomorrow'", function()
        local tokens = tokenize("6:30am tomorrow")
        assert.are.equal(4, #tokens)
        assert.are.equal("HOUR", tokens[1].type)
        assert.are.equal(6, tokens[1].value)
        assert.are.equal("MINUTE", tokens[2].type)
        assert.are.equal(30, tokens[2].value)
        assert.are.equal("AMPM", tokens[3].type)
        assert.are.equal("am", tokens[3].value)
        assert.are.equal("TOMORROW", tokens[4].type)
    end)

    it("should tokenize '2/20/26 9am'", function()
        local tokens = tokenize("2/20/26 9am")
        assert.are.equal(5, #tokens)
        assert.are.equal("MONTH", tokens[1].type)
        assert.are.equal(2, tokens[1].value)
        assert.are.equal("DAY", tokens[2].type)
        assert.are.equal(20, tokens[2].value)
        assert.are.equal("YEAR", tokens[3].type)
        assert.are.equal(2026, tokens[3].value)
        assert.are.equal("HOUR", tokens[4].type)
        assert.are.equal(9, tokens[4].value)
        assert.are.equal("AMPM", tokens[5].type)
    end)

    it("should tokenize weekday names", function()
        local tokens = tokenize("next Monday")
        assert.are.equal(2, #tokens)
        assert.are.equal("NEXT", tokens[1].type)
        assert.are.equal("WEEKDAY", tokens[2].type)
        assert.are.equal(2, tokens[2].value)
    end)
end)

describe("snooze choices", function()
    local snooze = require "reminders.snooze"

    it("should parse all snooze choices", function()
        for _, choice in ipairs(snooze.choices) do
            local result = snooze.calculate_new_datetime(choice)
            assert.is_not_nil(result, "Failed to parse: " .. choice)
            assert.is_truthy(result:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"),
                "Invalid format for: " .. choice .. " got: " .. tostring(result))
        end
    end)
end)
