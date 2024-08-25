-- lua/reminders/timer.lua

local reminder = require('reminders.reminder')

local M = {}

-- Function to start the timer with provided paths
function M.start(paths)
    -- Use vim.loop to create a timer that triggers every 60 seconds
    local timer = vim.loop.new_timer()
    timer:start(0, 60000, vim.schedule_wrap(function()
        -- Trigger the scan function every minute
        M.scan_for_reminders(paths)
    end))
end

-- Function to scan for reminders in the provided paths
function M.scan_for_reminders(paths)
    for _, path in ipairs(paths) do
        -- Placeholder for scanning logic
        -- Iterate over files in the path and call reminder.scan_file
        print("Scanning for reminders in path: " .. path)
    end
end

return M
