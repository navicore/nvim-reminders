-- lua/reminders/init.lua
local M = {}
local reminder_list = require('reminders.reminder_list')
local api = vim.api
local fn = vim.fn
local has_devicons, devicons = pcall(require, "nvim-web-devicons")

-- Table to store full reminder information
M.full_reminders = {}

-- Helper function to get relative time string
local function get_relative_time(timestamp)
    local now = os.time()
    local diff = os.difftime(timestamp, now)
    local days = math.floor(math.abs(diff) / (24 * 60 * 60))
    
    if diff > 0 then
        return days == 0 and "Today" or string.format("In %d days", days)
    else
        return days == 0 and "Overdue" or string.format("%d days ago", days)
    end
end

-- Function to create a floating window
local function create_floating_window()
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)
    local bufnr = api.nvim_create_buf(false, true)
    local opts = {
        relative = "editor",
        width = width,
        height = height,
        col = math.floor((vim.o.columns - width) / 2),
        row = math.floor((vim.o.lines - height) / 2),
        style = "minimal",
        border = "rounded"
    }
    local win = api.nvim_open_win(bufnr, true, opts)
    return bufnr, win
end

-- Function to display reminders in a floating window
local function show_reminders()
    local bufnr, win = create_floating_window()
    M.full_reminders = {}  -- Clear previous reminders
    local lines = {}
    local hl_ranges = {}

    for i, reminder in ipairs(reminder_list.reminders) do
        local short_path = fn.pathshorten(fn.fnamemodify(reminder.file, ":~:."))
        local icon = has_devicons and devicons.get_icon(reminder.file, fn.fnamemodify(reminder.file, ":e")) or "📄"
        local relative_time = reminder.date and get_relative_time(reminder.date) or ""
        
        local display_text = string.format("%d %s %s %s %s", 
            i, icon, short_path, reminder.text, relative_time)
        table.insert(lines, display_text)
        
        -- Store full information
        table.insert(M.full_reminders, {
            file = fn.fnamemodify(reminder.file, ":p"),
            line_number = reminder.line_number,
            text = reminder.text,
            date = reminder.date
        })
        
        -- Store highlight ranges
        local icon_end = #tostring(i) + 1 + #icon
        local path_end = icon_end + #short_path + 1
        table.insert(hl_ranges, {
            { start = 0, finish = #tostring(i), group = "Number" },
            { start = #tostring(i) + 1, finish = icon_end, group = "Special" },
            { start = icon_end + 1, finish = path_end, group = "Directory" },
            { start = path_end + 1, finish = -#relative_time - 1, group = "String" },
            { start = -#relative_time, finish = -1, group = "Comment" },
        })
    end
    
    if #lines > 0 then
        api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        api.nvim_buf_set_option(bufnr, 'modifiable', false)
        api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
        
        -- Apply syntax highlighting
        for i, ranges in ipairs(hl_ranges) do
            for _, range in ipairs(ranges) do
                api.nvim_buf_add_highlight(bufnr, -1, range.group, i - 1, range.start, range.finish)
            end
        end
        
        -- Set keymaps
        api.nvim_buf_set_keymap(bufnr, 'n', '<CR>', [[<cmd>lua require('reminders').open_reminder_item()<CR>]], { noremap = true, silent = true })
        api.nvim_buf_set_keymap(bufnr, 'n', 'q', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]], { noremap = true, silent = true })
    else
        api.nvim_win_close(win, true)
        print("No due reminders found.")
    end
end

-- Function to scan for reminders and display them
function M.scan_reminders()
    reminder_list.scan_paths(M.config.paths)
    show_reminders()
end

-- Function to open reminder item from the floating window
function M.open_reminder_item()
    local current_line = api.nvim_win_get_cursor(0)[1]
    local reminder = M.full_reminders[current_line]

    if reminder then
        -- Close the floating window
        api.nvim_win_close(0, true)

        -- Open the file at the specified line
        vim.cmd('edit ' .. reminder.file)
        vim.cmd('normal! ' .. reminder.line_number .. 'G')
    else
        print("No valid reminder selected.")
    end
end

-- Set up the user command
api.nvim_create_user_command('RemindersScan', function()
    M.scan_reminders()
end, {})

-- Plugin setup function
function M.setup(user_config)
    M.config = {
        paths = { fn.expand("~/git/" .. io.popen("whoami"):read("*a"):gsub("\n", "") .. "/zet") }
    }
    if user_config and user_config.paths then
        M.config.paths = user_config.paths
    end
    -- Set up autocmds for markdown files in the configured paths
    require('reminders.autocmds').setup_autocmds(M.config.paths)
end

return M
