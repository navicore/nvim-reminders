-- lua/reminders/reminder_list.lua
local M = {}
local time_parser = require('reminders.time_parser')

-- A list to store reminders that are due or past
M.reminders = {}

-- Function to scan a file for reminders and add them to the list based on the condition
local function scan_file(file_path, upcoming, all_reminders)
    local lines = vim.fn.readfile(file_path)
    for i, line in ipairs(lines) do
        local datetime = line:match("#reminder (%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ)")
        if datetime then
            local time_diff = time_parser.time_until(datetime)
            if all_reminders then
                -- Add all reminders to the list
                table.insert(M.reminders, {
                    file = file_path,
                    line_number = i,
                    text = line,
                    datetime = datetime
                })
            elseif upcoming then
                -- Check if the reminder is within the next 7 days
                local time_diff = time_parser.time_until(datetime)
                if time_diff:find("in %d+ days") or time_diff:find("in %d+ hours") or time_diff:find("in %d+ minutes") then
                    table.insert(M.reminders, {
                        file = file_path,
                        line_number = i,
                        text = line,
                        datetime = datetime
                    })
                end
            else
                -- Check if the reminder is due or past
                if time_diff:find("now") or time_diff:find(" ago") or time_diff:find("in 0 minutes") then
                    table.insert(M.reminders, {
                        file = file_path,
                        line_number = i,
                        text = line,
                        datetime = datetime
                    })
                end
            end
        end
    end
end

-- Function to scan all configured paths for due reminders
function M.scan_paths(paths)
    M.reminders = {}  -- Clear the list before scanning
    for _, path in ipairs(paths) do
        local files = vim.fn.globpath(path, "**/*.md", false, true)
        for _, file in ipairs(files) do
            scan_file(file, false, false)  -- Pass false for upcoming and all_reminders
        end
    end
end
-- Function to scan all configured paths for upcoming reminders
function M.scan_paths_upcoming(paths)
    M.reminders = {}  -- Clear the list before scanning
    for _, path in ipairs(paths) do
        local files = vim.fn.globpath(path, "**/*.md", false, true)
        for _, file in ipairs(files) do
            scan_file(file, true, false)  -- Pass true for upcoming and false for all_reminders
        end
    end
end

-- Function to scan all configured paths for all reminders
function M.scan_paths_all(paths)
    M.reminders = {}  -- Clear the list before scanning
    for _, path in ipairs(paths) do
        local files = vim.fn.globpath(path, "**/*.md", false, true)
        for _, file in ipairs(files) do
            scan_file(file, false, true)  -- Pass false for upcoming and true for all_reminders
        end
    end
end

return M
