-- lua/reminders/init.lua

local M = {}

-- Load required modules
local reminder = require('reminders.reminder')
local timer = require('reminders.timer')

-- Function to initialize the plugin
function M.setup()
    -- Set up a timer to scan for reminders every minute
    timer.start()
end

return M
