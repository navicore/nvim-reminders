-- lua/reminders/autocmds.lua
local M = {}

local time_parser = require('reminders.time_parser')
local virtual_text = require('reminders.virtual_text')

-- Function to convert natural language time to ISO 8601
local function convert_to_iso8601(text)
    local iso_time = time_parser.parse(text)
    if iso_time then
        return iso_time
    else
        return nil  -- or keep the original text if parsing fails
    end
end

-- Function to process the reminder line, rewrite time to ISO 8601, and ensure markdown prefix
local function process_reminder_line(line)
    -- Check if the line already contains a prefixed #reminder
    if line:match("%* %[%s?[ xX]?%s?%] #reminder") then
        -- Rewrite time for an existing prefixed #reminder
        return line:gsub("(#reminder) (.+):(%s)", function(reminder_prefix, time_expr, _)
            local iso_time = convert_to_iso8601(time_expr)
            local time_part = iso_time and iso_time or time_expr
            return reminder_prefix .. " " .. time_part .. ": "
        end)
    else
        -- Insert the prefix before the first occurrence of #reminder
        return line:gsub("(#reminder) (.+):(%s)", function(reminder_prefix, time_expr, _)
            local iso_time = convert_to_iso8601(time_expr)
            local time_part = iso_time and iso_time or time_expr
            return "* [ ] " .. reminder_prefix .. " " .. time_part .. ": "
        end)
    end
end

-- Function to process the current file
function M.process_file()
    local current_file = vim.fn.expand('%:p')

    for _, path in ipairs(require('reminders').config.paths) do
        if string.find(current_file, vim.fn.expand(path)) then
            local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            for i, line in ipairs(lines) do
                lines[i] = process_reminder_line(line)
            end
            vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
            break
        end
    end
end

-- Function to set up virtual text for the entire buffer
function M.update_virtual_text()
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    for i, line in ipairs(lines) do
        local datetime = line:match("#reminder (%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ)")
        if datetime then
            local countdown = time_parser.time_until(datetime)
            virtual_text.set_virtual_text(bufnr, i-1, countdown)
        end
    end
end

-- Set up autocmds for markdown files in the configured paths
function M.setup_autocmds()
    vim.cmd([[
        augroup Reminders
            autocmd!
            autocmd BufWritePre *.md lua require('reminders.autocmds').process_file()
            autocmd BufWritePost *.md lua require('reminders.autocmds').update_virtual_text()
            autocmd BufReadPost *.md lua require('reminders.autocmds').update_virtual_text()
        augroup END
    ]])
end

return M
