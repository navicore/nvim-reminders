-- lua/reminders/init.lua

local M = {}

-- Load required modules
local reminder = require('reminders.reminder')
local timer = require('reminders.timer')
local autocmds = require('reminders.autocmds')

-- Default configuration
M.config = {
    paths = { vim.fn.expand("~/git/" .. io.popen("whoami"):read("*a"):gsub("\n", "") .. "/zet") }
}

-- Function to initialize the plugin with optional user configuration
function M.setup(user_config)
    -- Merge user configuration with default configuration
    if user_config and user_config.paths then
        M.config.paths = user_config.paths
    end

    -- Set up autocmds for markdown files in the configured paths
    autocmds.setup_autocmds(M.config.paths)
    
    -- Set up a timer to scan for reminders every minute
    timer.start(M.config.paths)
end

return M
