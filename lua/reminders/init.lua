-- lua/reminders/init.lua

local M = {}

local reminder_list = require('reminders.reminder_list')

-- Table to map buffer numbers to filenames
M.bufnr_to_filename = {}

-- Function to display reminders in the quickfix list
local function show_reminders()
    local items = {}
    M.bufnr_to_filename = {}  -- Clear previous mappings

    for _, reminder in ipairs(reminder_list.reminders) do
        local bufnr = vim.fn.bufnr(reminder.file, true)  -- Ensure buffer is loaded
        M.bufnr_to_filename[bufnr] = vim.fn.fnamemodify(reminder.file, ":p")  -- Map buffer to filename

        table.insert(items, {
            bufnr = bufnr,  -- Use buffer number
            lnum = reminder.line_number,
            text = reminder.text,
        })
    end

    if #items > 0 then
        vim.fn.setqflist({}, 'r', {
            title = 'Reminders',
            items = items
        })
        vim.cmd('copen')
    else
        print("No due reminders found.")
    end
end

-- Function to scan for reminders and display them
function M.scan_reminders()
    reminder_list.scan_paths(M.config.paths)
    show_reminders()
end

-- Custom function to open quickfix item using filename from mapping
function M.open_quickfix_item()
    local qf_idx = vim.fn.line('.')  -- Get the current cursor position in the quickfix window
    local qf_list = vim.fn.getqflist()  -- Get the current quickfix list
    local qf_entry = qf_list[qf_idx]  -- Access the corresponding entry

    if qf_entry and qf_entry.bufnr and M.bufnr_to_filename[qf_entry.bufnr] then
        local filename = M.bufnr_to_filename[qf_entry.bufnr]  -- Retrieve the correct filename
        vim.cmd('edit ' .. filename)
        vim.api.nvim_win_set_cursor(0, { qf_entry.lnum, 0 })
    else
        print("No valid quickfix item selected or quickfix list is empty.")
    end
end

-- Map Enter in quickfix window to the custom function
vim.cmd([[
    augroup RemindersQuickfix
        autocmd!
        autocmd FileType qf nnoremap <buffer> <CR> :lua require('reminders').open_quickfix_item()<CR>
    augroup END
]])

-- Set up the user command
vim.api.nvim_create_user_command('RemindersScan', function()
    M.scan_reminders()
end, {})

-- Plugin setup function
function M.setup(user_config)
    M.config = {
        paths = { vim.fn.expand("~/git/" .. io.popen("whoami"):read("*a"):gsub("\n", "") .. "/zet") }
    }
    if user_config and user_config.paths then
        M.config.paths = user_config.paths
    end

    -- Set up autocmds for markdown files in the configured paths
    require('reminders.autocmds').setup_autocmds(M.config.paths)

end

return M
