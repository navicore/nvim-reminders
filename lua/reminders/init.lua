-- lua/reminders/init.lua
local M = {}
local reminder_list = require("reminders.reminder_list")
local time_parser = require("reminders.time_parser")
local api = vim.api
local fn = vim.fn
local has_devicons, devicons = pcall(require, "nvim-web-devicons")
local sort_order = "newest_to_oldest"

-- Table to store full reminder information
M.full_reminders = {}

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
		border = "rounded",
	}
	local win = api.nvim_open_win(bufnr, true, opts)
	return bufnr, win
end

local function split_reminder_text(text)
	local split_index = text:find(": ")
	if split_index then
		return text:sub(split_index + 2)
	else
		return text
	end
end

local function sort_reminders(reminders, order)
	if order == "newest_to_oldest" then
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
	local max_width_limit = 40

	for _, reminder in ipairs(reminders) do
		local short_path = fn.pathshorten(fn.fnamemodify(reminder.file, ":~:."))
		local reminder_text = reminder.text:match(":(.*)$") or reminder.text
		max_text_width = math.min(max_width_limit, math.max(max_text_width, #reminder_text))
		max_path_width = math.min(max_width_limit, math.max(max_path_width, #short_path))
	end
	return max_text_width, max_path_width
end

local function format_reminder(reminder, max_text_width, max_path_width, i)
	local short_path = fn.pathshorten(fn.fnamemodify(reminder.file, ":~:."))
	local icon = has_devicons and devicons.get_icon(reminder.file, fn.fnamemodify(reminder.file, ":e")) or "📄"
	local relative_time = reminder.datetime and time_parser.time_until(reminder.datetime) or ""
	local reminder_text = split_reminder_text(reminder.text)

	-- Ensure the reminder_text is exactly 40 characters (truncate or pad)
	if #reminder_text > 40 then
		reminder_text = reminder_text:sub(1, 40) -- Truncate if longer than 40 chars
	else
		reminder_text = reminder_text .. string.rep(" ", 40 - #reminder_text) -- Pad if shorter than 40 chars
	end

	local padded_path = string.format("%-" .. max_path_width .. "s", short_path)
	local display_text = string.format("%-3d %s %s %s | %s", i, icon, padded_path, reminder_text, relative_time)
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
	M.full_reminders = {} -- Clear previous reminders
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
			datetime = reminder.datetime,
		})
	end

	if #lines > 0 then
		api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
		api.nvim_buf_set_option(bufnr, "modifiable", false)
		api.nvim_buf_set_option(bufnr, "buftype", "nofile")

		local hl_ranges = calculate_highlight_ranges(lines)
		apply_syntax_highlighting(bufnr, lines, hl_ranges)

		-- Set keymaps
		api.nvim_buf_set_keymap(
			bufnr,
			"n",
			"<CR>",
			[[<cmd>lua require('reminders').open_reminder_item()<CR>]],
			{ noremap = true, silent = true }
		)
		api.nvim_buf_set_keymap(
			bufnr,
			"n",
			"q",
			[[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]],
			{ noremap = true, silent = true }
		)
		api.nvim_buf_set_keymap(
			bufnr,
			"n",
			"t",
			[[<cmd>lua require('reminders').toggle_sort_order()<CR>]],
			{ noremap = true, silent = true }
		)
	else
		api.nvim_win_close(win, true)
		print("No reminders found.")
	end
end

local function open_datetime_selector(line_nr)
	local choices = {
		"in 10 minutes",
		"in 1 hour",
		"in 2 hours",
		"1pm today",
		"tomorrow 6am",
		"in 2 days",
		"in 1 week",
		"in 2 weeks",
		"in 1 month",
		"quit",
	}

	require("telescope.pickers")
		.new({}, {
			prompt_title = "Select a time interval",
			finder = require("telescope.finders").new_table({
				results = choices,
			}),
			sorter = require("telescope.config").values.generic_sorter({}),
			layout_config = {
				width = 0.3, -- Adjust the width to 60% of the editor's width
			},
			attach_mappings = function(prompt_bufnr, map)
				map("i", "<CR>", function()
					local selection = require("telescope.actions.state").get_selected_entry()
					require("telescope.actions").close(prompt_bufnr)
					if selection[1] ~= "quit" then
						M.save_datetime(line_nr, selection[1])
					end
				end)
				return true
			end,
		})
		:find()
end

local function calculate_new_datetime(choice)
	local current_time = os.time()
	local now = os.date("*t")
	local new_time

	if choice == "in 10 minutes" then
		new_time = current_time + 10 * 60
	elseif choice == "in 1 hour" then
		new_time = current_time + 1 * 60 * 60
	elseif choice == "in 2 hours" then
		new_time = current_time + 2 * 60 * 60
	elseif choice == "1pm today" then
		-- 1pm local time today
		new_time = os.time({ year = now.year, month = now.month, day = now.day, hour = 13, min = 0, sec = 0 })
	elseif choice == "tomorrow 6am" then
		-- 6am local time tomorrow
		new_time = os.time({ year = now.year, month = now.month, day = now.day + 1, hour = 6, min = 0, sec = 0 })
	elseif choice == "in 2 days" then
		new_time = current_time + 2 * 24 * 60 * 60
	elseif choice == "in 1 week" then
		new_time = current_time + 7 * 24 * 60 * 60
	elseif choice == "in 2 weeks" then
		new_time = current_time + 14 * 24 * 60 * 60
	elseif choice == "in 1 month" then
		new_time = os.time({ year = now.year, month = now.month + 1, day = now.day })
	else
		return nil
	end

	return os.date("!%Y-%m-%dT%H:%M:%SZ", new_time)
end

local function update_reminder_datetime(line, new_datetime)
	return line:gsub("(%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ)", new_datetime)
end

function M.save_datetime(line_nr, choice)
	if not choice then
		print("Invalid choice. Not updating.")
		return
	end

	local line = vim.api.nvim_buf_get_lines(0, line_nr - 1, line_nr, false)[1]

	if not M.is_reminder(line) then
		print("Not a reminder line. Not updating.")
		return
	end

	local new_datetime = calculate_new_datetime(choice)

	if not new_datetime then
		print("Failed to calculate new datetime.")
		return
	end

	local new_line = update_reminder_datetime(line, new_datetime)

	vim.api.nvim_buf_set_lines(0, line_nr - 1, line_nr, false, { new_line })
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

function M.scan_reminders(upcoming)
	if upcoming then
		reminder_list.scan_paths_upcoming(M.config.paths)
	else
		reminder_list.scan_paths(M.config.paths)
	end

	-- Use Telescope if available, otherwise fall back to floating window
	local has_telescope = pcall(require, "telescope")
	if has_telescope then
		local telescope_reminders = require("reminders.telescope")
		telescope_reminders.reminder_picker({
			paths = M.config.paths,
			scan_type = upcoming and "upcoming" or "due",
			prompt_title = upcoming and "Upcoming Reminders" or "Due Reminders",
		})
	else
		show_reminders()
	end
end

function M.open_reminder_item()
	local current_line = api.nvim_win_get_cursor(0)[1]
	local reminder = M.full_reminders[current_line]

	if reminder then
		-- Close the floating window
		api.nvim_win_close(0, true)

		-- Open the file at the specified line
		vim.cmd("edit " .. reminder.file)
		vim.cmd("normal! " .. reminder.line_number .. "G")
	else
		print("No valid reminder selected.")
	end
end

-- Set up the user commands
api.nvim_create_user_command("ReminderScan", function()
	M.scan_reminders(false)
end, {})

api.nvim_create_user_command("ReminderScanUpcoming", function()
	M.scan_reminders(true)
end, {})

api.nvim_create_user_command("ReminderScanAll", function()
	reminder_list.scan_paths_all(M.config.paths)

	-- Use Telescope if available, otherwise fall back to floating window
	local has_telescope = pcall(require, "telescope")
	if has_telescope then
		local telescope_reminders = require("reminders.telescope")
		telescope_reminders.reminder_picker({
			paths = M.config.paths,
			scan_type = "all",
			prompt_title = "All Reminders",
		})
	else
		show_reminders()
	end
end, {})

vim.api.nvim_create_user_command("ReminderEdit", function()
	local line = vim.api.nvim_get_current_line()
	if not M.is_reminder(line) then
		print("Not a reminder line")
		return
	end

	local line_nr = vim.api.nvim_win_get_cursor(0)[1]

	open_datetime_selector(line_nr)
end, {})

vim.api.nvim_create_user_command("ReminderTmuxSetup", function()
	-- Find the plugin's installation path by looking for this file
	local script_path = debug.getinfo(1, "S").source:sub(2)
	local plugin_root = fn.fnamemodify(script_path, ":h:h:h")
	local tmux_script = plugin_root .. "/scripts/tmux-reminders.sh"
	local popup_script = plugin_root .. "/scripts/tmux-reminder-popup.sh"

	-- Build the paths argument string from config
	local paths_arg = ""
	if M.config and M.config.paths then
		local expanded_paths = {}
		for _, path in ipairs(M.config.paths) do
			table.insert(expanded_paths, fn.expand(path))
		end
		paths_arg = table.concat(expanded_paths, " ")
	end

	local lines = {
		"",
		"nvim-reminders tmux integration",
		string.rep("=", 40),
		"",
		"STATUS BAR (show clickable reminder count):",
		"",
		"  #(" .. tmux_script .. " " .. paths_arg .. ")",
		"",
		"Simple status-right example:",
		"",
		[[  set -g status-right '#(]] .. tmux_script .. " " .. paths_arg .. [[) %H:%M']],
		"",
		string.rep("-", 40),
		"",
		"CLICK SUPPORT (click reminder count to open popup):",
		"",
		"  bind -Troot MouseDown1Status if -F '#{==:#{mouse_status_range},reminder}' \\",
		"    { run-shell '" .. popup_script .. "' }",
		"",
		string.rep("-", 40),
		"",
		"KEYBINDING (prefix + r to open popup):",
		"",
		"  bind r run-shell '" .. popup_script .. "'",
		"",
		"See :help nvim-reminders-tmux for advanced styling.",
		"",
	}

	-- Display in a floating window for easy copying
	local width = math.floor(vim.o.columns * 0.8)
	local height = #lines + 2
	local bufnr = api.nvim_create_buf(false, true)
	local opts = {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = "minimal",
		border = "rounded",
	}
	local win = api.nvim_open_win(bufnr, true, opts)

	api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	api.nvim_buf_set_option(bufnr, "modifiable", false)
	api.nvim_buf_set_option(bufnr, "buftype", "nofile")

	-- Close with q
	api.nvim_buf_set_keymap(bufnr, "n", "q", [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]], { noremap = true, silent = true })
end, {})

-- Plugin setup function
function M.setup(user_config)
	M.config = {
		paths = { fn.expand("~/git/" .. io.popen("whoami"):read("*a"):gsub("\n", "") .. "/zet") },
		recursive_scan = false,
	}
	if user_config and user_config.paths then
		M.config.paths = user_config.paths
	end
	if user_config and user_config.recursive_scan then
		M.config.recursive_scan = user_config.recursive_scan
	end
	-- Set up autocmds for markdown files in the configured paths
	require("reminders.autocmds").setup_autocmds()
end

function M.is_reminder(line)
	return line:match("#reminder")
end

return M
