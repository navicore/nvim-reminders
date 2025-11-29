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

local parse_time_expression = require "reminders.time_parser".parse_time_expression
local parse = require "reminders.time_parser".parse

assert.are.are_function(parse)

describe("parse_time_expression", function()
    it("should return ISO 8601 datetime string for 'in 10 hours'", function()
        local expected = get_iso8601_datetime(10)
        local result = parse_time_expression("in 10 hours")
        assert.are.equal(expected, result)
    end)
    it("should return ISO 8601 datetime string for 'in 11 days'", function()
        local expected = get_iso8601_datetime(11 * 24)
        local result = parse_time_expression("in 11 days")
        assert.are.equal(expected, result)
    end)
    it("should return ISO 8601 datetime string for 'in 60 minutes'", function()
        local expected = get_iso8601_datetime(1)
        local result = parse_time_expression("in 60 minutes")
        assert.are.equal(expected, result)
    end)
    it("should return ISO 8601 datetime string for 'in 1 week'", function()
        local expected = get_iso8601_datetime(7 * 24)
        local result = parse_time_expression("in 1 week")
        assert.are.equal(expected, result)
    end)
end)

describe("parse", function()
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
    it("should return ISO 8601 datetime string for 'next Tuesday'", function()
        local expected_utc = "2023-10-14T00:00:00Z"
        local result = parse("next Tuesday")
        local success, err = compare_time(expected_utc, result)
        assert.is_true(success, err)
    end)

    -- Weekday without time tests (midnight local time → UTC varies by timezone)
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

    -- Time-first patterns
    it("should parse '6am tomorrow' with time before day", function()
        local result = parse("6am tomorrow")
        assert.is_not_nil(result)
        -- Should have 06:00 or 14:00 (depending on timezone conversion)
    end)

    it("should parse '9:30am tomorrow' with time before day", function()
        local result = parse("9:30am tomorrow")
        assert.is_not_nil(result)
    end)

    it("should parse 'tomorrow 6am' without 'at'", function()
        local result = parse("tomorrow 6am")
        assert.is_not_nil(result)
    end)

end)

describe("parse_named_date", function()
    local parse_named_date = require "reminders.time_parser".parse_named_date

    -- Helper: convert local time to expected UTC string
    local function local_to_utc(year, month, day, hour, minute)
        local local_time = os.time({year=year, month=month, day=day, hour=hour, min=minute, sec=0})
        return os.date("!%Y-%m-%dT%H:%M:%SZ", local_time)
    end

    it("should parse 'Jan 1' as a valid date", function()
        local result = parse_named_date("Jan 1")
        assert.is_not_nil(result)
        -- Should be Jan 1 at local midnight, converted to UTC
        assert.is_truthy(result:match("^%d%d%d%d%-01%-01T%d%d:%d%d:%d%dZ$"))
    end)

    it("should parse 'on Jan 1' as a valid date", function()
        local result = parse_named_date("on Jan 1")
        assert.is_not_nil(result)
        assert.is_truthy(result:match("^%d%d%d%d%-01%-01T%d%d:%d%d:%d%dZ$"))
    end)

    it("should parse 'January 1' as a valid date", function()
        local result = parse_named_date("January 1")
        assert.is_not_nil(result)
        assert.is_truthy(result:match("^%d%d%d%d%-01%-01T%d%d:%d%d:%d%dZ$"))
    end)

    it("should parse 'December 25, 2025' with explicit year", function()
        local result = parse_named_date("December 25, 2025")
        assert.is_not_nil(result)
        -- Midnight local → UTC (varies by timezone)
        local expected = local_to_utc(2025, 12, 25, 0, 0)
        assert.are.equal(expected, result)
    end)

    it("should parse 'Jan 1, 2026' with explicit year", function()
        local result = parse_named_date("Jan 1, 2026")
        assert.is_not_nil(result)
        local expected = local_to_utc(2026, 1, 1, 0, 0)
        assert.are.equal(expected, result)
    end)

    it("should parse 'Feb 14 at 6pm' with time", function()
        local result = parse_named_date("Feb 14 at 6pm")
        assert.is_not_nil(result)
        -- 6pm local → UTC (date may shift to Feb 15 depending on timezone)
        assert.is_truthy(result:match("^%d%d%d%d%-02%-1[45]T%d%d:%d%d:%d%dZ$"))
    end)

    it("should parse 'on March 15 at 9:30am' with time", function()
        local result = parse_named_date("on March 15 at 9:30am")
        assert.is_not_nil(result)
        assert.is_truthy(result:match("^%d%d%d%d%-03%-15T%d%d:%d%d:%d%dZ$"))
    end)

    it("should parse 'July 4th' with ordinal suffix", function()
        local result = parse_named_date("July 4th")
        assert.is_not_nil(result)
        assert.is_truthy(result:match("^%d%d%d%d%-07%-04T%d%d:%d%d:%d%dZ$"))
    end)

    it("should parse 'Dec 1st at 12pm' with ordinal and time", function()
        local result = parse_named_date("Dec 1st at 12pm")
        assert.is_not_nil(result)
        assert.is_truthy(result:match("^%d%d%d%d%-12%-01T%d%d:%d%d:%d%dZ$"))
    end)

    it("should parse 'September 2, 2025 at 3:30pm' full format", function()
        local result = parse_named_date("September 2, 2025 at 3:30pm")
        assert.is_not_nil(result)
        -- 3:30pm local → UTC
        local expected = local_to_utc(2025, 9, 2, 15, 30)
        assert.are.equal(expected, result)
    end)

    it("should return nil for invalid month name", function()
        local result = parse_named_date("Foo 15")
        assert.is_nil(result)
    end)

    it("should return nil for invalid day", function()
        local result = parse_named_date("Jan 32")
        assert.is_nil(result)
    end)
end)

