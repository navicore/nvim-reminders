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

end)

