-- lua/reminders/virtual_text.lua

local M = {}

-- Function to set virtual text for a reminder line
function M.set_virtual_text(bufnr, line_nr, text)
    vim.api.nvim_buf_clear_namespace(bufnr, 0, 0, -1)
    vim.api.nvim_buf_set_virtual_text(bufnr, 0, line_nr, {{text, "Comment"}}, {})
end

-- Function to update virtual text for all reminders in the buffer
function M.update_virtual_text()
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    for i, line in ipairs(lines) do
        local datetime = line:match("#reminder (%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ)")
        if datetime then
            local countdown = require('reminders.time_parser').time_until(datetime)
            M.set_virtual_text(bufnr, i-1, countdown)
        end
    end
end

return M

