-- lua/reminders/init.lua

local M = {}

-- Function to get the default path
local function get_default_path()
    -- Get the current username and expand the default path
    local username = io.popen("whoami"):read("*a"):gsub("\n", "")
    return vim.fn.expand("~/git/" .. username .. "/zet")
end

-- Default configuration
local config = {
    paths = { get_default_path() }
}

-- Function to initialize the plugin with optional user configuration
function M.setup(user_config)
    -- Merge user configuration with default configuration
    if user_config and user_config.paths then
        config.paths = user_config.paths
    end
    
    -- Debug print to verify paths
    for _, path in ipairs(config.paths) do
        print("Scanning path: " .. path)
    end

    -- Set up a timer to scan for reminders every minute
    local timer = require('reminders.timer')
    timer.start(config.paths)
end

return M
