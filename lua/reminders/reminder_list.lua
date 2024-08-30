-- lua/reminders/reminder_list.lua

local M = {}

local time_parser = require('reminders.time_parser')

-- A list to store reminders that are due or past
M.reminders = {}

-- Function to scan a file for reminders and add them to the list if due
local function scan_file(file_path)
    local lines = vim.fn.readfile(file_path)
    for i, line in ipairs(lines) do
        local datetime = line:match("#reminder (%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ)")
        if datetime then
            local time_diff = time_parser.time_until(datetime)
            if time_diff:find(" ago") or time_diff:find("in 0 minutes") then
                table.insert(M.reminders, {
                    file = file_path,
                    line_number = i,
                    text = line
                })
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
            scan_file(file)
        end
    end
end

return M

