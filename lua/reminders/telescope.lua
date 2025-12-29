-- lua/reminders/telescope.lua
-- Telescope integration for reminder picker with preview and snooze

local M = {}

local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
	return M
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local entry_display = require("telescope.pickers.entry_display")

local time_parser = require("reminders.time_parser")
local reminder_list = require("reminders.reminder_list")

local fn = vim.fn

-- Snooze choices for the edit action
local snooze_choices = {
	"in 10 minutes",
	"in 1 hour",
	"in 2 hours",
	"1pm today",
	"tomorrow 6am",
	"in 2 days",
	"in 1 week",
	"in 2 weeks",
	"in 1 month",
}

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

local function update_reminder_in_file(reminder, new_datetime)
	-- Read the file
	local lines = fn.readfile(reminder.file)
	if not lines or #lines < reminder.line_number then
		vim.notify("Could not read file: " .. reminder.file, vim.log.levels.ERROR)
		return false
	end

	-- Update the line with new datetime
	local line = lines[reminder.line_number]
	local new_line = line:gsub("(%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ)", new_datetime)
	lines[reminder.line_number] = new_line

	-- Write back
	fn.writefile(lines, reminder.file)
	return true
end

local function open_snooze_picker(reminder, on_complete)
	pickers.new({}, {
		prompt_title = "Snooze Reminder",
		finder = finders.new_table({
			results = snooze_choices,
		}),
		sorter = conf.generic_sorter({}),
		layout_config = {
			width = 0.3,
			height = 0.4,
		},
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)

				if selection then
					local new_datetime = calculate_new_datetime(selection[1])
					if new_datetime and update_reminder_in_file(reminder, new_datetime) then
						vim.notify("Snoozed to " .. selection[1], vim.log.levels.INFO)
						if on_complete then
							on_complete()
						end
					end
				end
			end)
			return true
		end,
	}):find()
end

local function make_display(entry)
	local relative_time = entry.datetime and time_parser.time_until(entry.datetime) or ""

	-- Extract just the reminder text (after the colon)
	local reminder_text = entry.text:match(": (.*)$") or entry.text

	-- Fixed width for reminder text (50 chars max)
	local text_width = 50

	-- Truncate if too long
	if #reminder_text > text_width then
		reminder_text = reminder_text:sub(1, text_width - 3) .. "..."
	end

	local displayer = entry_display.create({
		separator = " │ ",
		items = {
			{ width = text_width },
			{ width = 25 },
		},
	})

	return displayer({
		reminder_text,
		{ relative_time, "Comment" },
	})
end

function M.reminder_picker(opts)
	opts = opts or {}
	local reminders = reminder_list.reminders or {}

	if #reminders == 0 then
		vim.notify("No reminders found.", vim.log.levels.INFO)
		return
	end

	-- Sort by datetime (oldest first by default for due reminders)
	table.sort(reminders, function(a, b)
		return (a.datetime or 0) < (b.datetime or 0)
	end)

	local function reopen_picker()
		-- Re-scan and reopen the picker
		if opts.scan_type == "upcoming" then
			reminder_list.scan_paths_upcoming(opts.paths)
		elseif opts.scan_type == "all" then
			reminder_list.scan_paths_all(opts.paths)
		else
			reminder_list.scan_paths(opts.paths)
		end
		M.reminder_picker(opts)
	end

	pickers.new(opts, {
		prompt_title = opts.prompt_title or "Reminders",
		finder = finders.new_table({
			results = reminders,
			entry_maker = function(entry)
				return {
					value = entry,
					display = make_display,
					ordinal = entry.text,
					filename = entry.file,
					lnum = entry.line_number,
					datetime = entry.datetime,
					text = entry.text,
				}
			end,
		}),
		sorter = conf.generic_sorter(opts),
		previewer = conf.grep_previewer(opts),
		attach_mappings = function(prompt_bufnr, map)
			-- Default action: open file at line
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)

				if selection then
					vim.cmd("edit " .. selection.filename)
					vim.cmd("normal! " .. selection.lnum .. "G")
				end
			end)

			-- 'e' to snooze/edit (normal mode only)
			map("n", "e", function()
				local selection = action_state.get_selected_entry()
				if selection then
					actions.close(prompt_bufnr)
					open_snooze_picker(selection.value, reopen_picker)
				end
			end)

			return true
		end,
	}):find()
end

return M
