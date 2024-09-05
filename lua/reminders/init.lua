-- lua/reminders/init.lua
local M = {}
local reminder_list = require('reminders.reminder_list')
local time_parser = require('reminders.time_parser')
local api = vim.api
local fn = vim.fn
local has_devicons, devicons = pcall(require, "nvim-web-devicons")
local sort_order = "newest_to_oldest"

-- Table to store full reminder information
M.full_reminders = {}

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

local function split_reminder_text(text)
    local split_index = text:find(': ')
    if split_index then
        return text:sub(split_index + 2)
    else
        return text
    end
end

local function sort_reminders(reminders, sort_order)
    if sort_order == "newest_to_oldest" then
        table.sort(reminders, function(a, b)
            return (a.datetime or 0) > (b.datetime or 0)
        end)
    else
        table.sort(reminders, function(a, b)
            return (a.datetime or 0) < (b.datetime or 0)
        end)
    end
    return reminders
end

local function calculate_max_widths(reminders)
    local max_text_width = 0
    local max_path_width = 0
    for _, reminder in ipairs(reminders) do
        local short_path = fn.pathshorten(fn.fnamemodify(reminder.file, ":~:."))
        local reminder_text = reminder.text:match(":(.*)$") or reminder.text
        max_text_width = math.max(max_text_width, #reminder_text)
        max_path_width = math.max(max_path_width, #short_path)
    end
    return max_text_width, max_path_width
end

local function format_reminder(reminder, max_text_width, max_path_width, i)
    local short_path = fn.pathshorten(fn.fnamemodify(reminder.file, ":~:."))
    local icon = has_devicons and devicons.get_icon(reminder.file, fn.fnamemodify(reminder.file, ":e")) or "📄"
    local relative_time = reminder.datetime and time_parser.time_until(reminder.datetime) or ""
    local reminder_text = split_reminder_text(reminder.text)
    local padded_text = string.format("%-" .. max_text_width .. "s", reminder_text)
    local padded_path = string.format("%-" .. max_path_width .. "s", short_path)
    local display_text = string.format("%s %s %s %s %s", i, icon, padded_path, padded_text, relative_time)
    return display_text
end

local function calculate_highlight_ranges(lines)
    local hl_ranges = {}
    for i, _ in ipairs(lines) do
        local index_end = #tostring(i)
        local icon_end = index_end + 1 + #lines[i]:match("^%d+ (.)") -- Assumes icon is single character
        local path_end = lines[i]:find("%s+", icon_end + 1) - 1
        local text_end = lines[i]:find("%s+%S+$") - 1

        table.insert(hl_ranges, {
            { start = 0, finish = index_end, group = "Number" },
            { start = index_end + 1, finish = icon_end, group = "Special" },
            { start = icon_end + 1, finish = path_end, group = "Directory" },
            { start = path_end + 1, finish = text_end, group = "String" },
            { start = text_end + 1, finish = -1, group = "Comment" },
        })
    end
    return hl_ranges
end

local function apply_syntax_highlighting(bufnr, lines, hl_ranges)
    for i, ranges in ipairs(hl_ranges) do
        for _, range in ipairs(ranges) do
            local line_length = #lines[i]
            local start = math.min(range.start, line_length)
            local finish = math.min(range.finish, line_length)
            if start < finish then
                api.nvim_buf_add_highlight(bufnr, -1, range.group, i - 1, start, finish)
            end
        end
    end
end

local function show_reminders()
    local bufnr, win = create_floating_window()
    M.full_reminders = {}  -- Clear previous reminders
    local lines = {}

    local sorted_reminders = sort_reminders(reminder_list.reminders, sort_order)
    local max_text_width, max_path_width = calculate_max_widths(sorted_reminders)

    for i, reminder in ipairs(sorted_reminders) do
        local display_text = format_reminder(reminder, max_text_width, max_path_width, i)
        table.insert(lines, display_text)

        -- Store full information
        table.insert(M.full_reminders, {
            file = fn.fnamemodify(reminder.file, ":p"),
            line_number = reminder.line_number,
            text = reminder.text,
            datetime = reminder.datetime
        })
    end

    if #lines > 0 then
        api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        api.nvim_buf_set_option(bufnr, 'modifiable', false)
        api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')

        local hl_ranges = calculate_highlight_ranges(lines)
        apply_syntax_highlighting(bufnr, lines, hl_ranges)

        -- Set keymaps
        api.nvim_buf_set_keymap(bufnr, 'n', '<CR>', [[<cmd>lua require('reminders').open_reminder_item()<CR>]], { noremap = true, silent = true })
        api.nvim_buf_set_keymap(bufnr, 'n', 'q', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]], { noremap = true, silent = true })
        api.nvim_buf_set_keymap(bufnr, 'n', 't', [[<cmd>lua require('reminders').toggle_sort_order()<CR>]], { noremap = true, silent = true })

        -- Load the help file
        local plugin_dir = vim.fn.stdpath('data') .. '/lazy/nvim-reminders'
        local doc_dir = plugin_dir .. '/doc'
        vim.cmd('helptags ' .. doc_dir)
    else
        api.nvim_win_close(win, true)
        print("No reminders found.")
    end
end

function M.toggle_sort_order()
    if sort_order == "newest_to_oldest" then
        sort_order = "oldest_to_newest"
    else
        sort_order = "newest_to_oldest"
    end
    -- Close the current floating window
    api.nvim_win_close(0, true)
    show_reminders()
end

-- Function to scan for reminders and display them
function M.scan_reminders(upcoming)
    if upcoming then
        reminder_list.scan_paths_upcoming(M.config.paths)
    else
        reminder_list.scan_paths(M.config.paths)
    end
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
api.nvim_create_user_command('ReminderScan', function()
    M.scan_reminders(false)
end, { })
api.nvim_create_user_command('ReminderScanUpcoming', function()
    M.scan_reminders(true)
end, { })
api.nvim_create_user_command('ReminderScanAll', function()
    reminder_list.scan_paths_all(M.config.paths)
    show_reminders()
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
