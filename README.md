Neovim Reminders Plugin
===========

A Neovim plugin written in Lua to manage and display reminders directly in your
markdown notes. This plugin scans your configured repositories for reminders in
the format:

```markdown
#reminder datetime: text
```

I use the very nice
[renerocksai/telekasten.nvim](https://github.com/nvim-telekasten/telekasten.nvim)
for my notes and my `nvim-reminders` plugin adds reminders w/o the mess of UI
pop-ups or device sync because I only want the reminders when I'm in nvim AND
ready for them.

## Features

* Automatically converts natural language time expressions (e.g., "in 2 hours") to ISO 8601 format.
* Displays a human-readable countdown in virtual text.
* Rewrites reminders with check-boxes
* Supports configurable repository lists to scan for reminders.
* **Telescope integration** with preview pane for context-aware reminder browsing
* **Snooze reminders** directly from the picker with `e` key
* **Tmux integration** with clickable status bar count and popup support

## Installation

### Using Lazy.nvim

To install with Lazy, add the following to your Neovim configuration:

```lua
require('lazy').setup({
    {
        'navicore/nvim-reminders',  -- Replace with the actual GitHub repo path
        config = function()
            require('reminders').setup({
                paths = {
                    "~/path/to/your/notes",
                    "~/another/path/to/notes"
                }
            })
        end
    }
})
```

### Using Packer.nvim

To install with Packer, add the following to your packer setup:

```lua
use {
    'navicore/nvim-reminders',  -- Replace with the actual GitHub repo path
    config = function()
        require('reminders').setup({
            paths = {
                "~/path/to/your/notes",
                "~/another/path/to/notes"
            }
        })
    end
}
```

### Using Vim-Plug

To install with Vim-Plug, add the following to your .vimrc or init.vim:

```vim
Plug 'navicore/nvim-reminders'  -- Replace with the actual GitHub repo path
lua << EOF
require('reminders').setup({
    paths = {
        "~/path/to/your/notes",
        "~/another/path/to/notes"
    }
})
EOF
```

## Usage

Create reminders in your `*.md` files as:

```markdown
#reminder in 2 hours: check logs for errors
```

and when you are ready run `:ReminderScan`. This opens a Telescope picker with
a preview pane showing the file context for each reminder.

**Picker keybindings:**
- `<CR>` - Jump to the reminder in its file
- `e` (normal mode) - Snooze the reminder (opens time picker, then refreshes list)
- `<Esc>` - Enter normal mode
- `<C-c>` - Close picker

To resolve a reminder, jump to it and check the checkbox with an 'x': `[x]`

for example:

This reminder: 

#reminder in 2 minutes: this is a test reminder!

Becomes:

* [ ] #reminder 2024-09-14T04:34:31Z: this is a test reminder!

Once you resolve it by checking the checkbox it becomes:

* [x] #reminder 2024-09-14T04:34:31Z: this is a test reminder!

### Customizing the Repository List

By default, the plugin scans the directory `~/git/USERNAME/zet`, where
`USERNAME` is your system username. You can customize this by passing a list of
paths to the setup function in your Neovim configuration:

```lua
require('reminders').setup({
    paths = {
        "~/path/to/your/notes",
        "~/another/path/to/notes"
    }
})
```

### Customizing the File Scanning

Normally, if you have a lot of notes that you archive to sub directories you don't
want to keep scanning those previous years of notes for reminders.  The default
is that the plugin will not scan sub directories of your notes paths.

However, if you do want to scan sub directories for reminders, use the
`scan_recursively` setting.

```lua
require('reminders').setup({
    scan_recursively = true
})
```


### Supported Time Expressions

The plugin supports the following natural language time expressions, which will
be automatically converted to ISO 8601 format:

```
    in X minutes
    in X hours
    in X days
    tomorrow
    next Monday (or any other weekday)
```

### Example Reminder

You can add reminders to your markdown files in the following format:

```markdown
#reminder in 2 hours: Follow up on the meeting notes
```

Upon saving the file, this will automatically be converted to:

```markdown
#reminder 2024-08-25T14:00:00Z: Follow up on the meeting notes
```

And the plugin will display a virtual text next to it showing something like:

```markdown
#reminder 2024-08-25T14:00:00Z: Follow up on the meeting notes : in 2 hours
```

## Tmux Integration

The plugin includes shell scripts for tmux integration:
- **Status bar count** - Shows due reminder count (clickable!)
- **Popup window** - Opens ReminderScan in a floating tmux popup without disrupting your panes

### Quick Setup

Run `:ReminderTmuxSetup` in Neovim to get copy-paste ready configuration
snippets with the correct paths for your setup.

### Status Bar

Add the reminder count to your status bar. The script outputs nothing when no
reminders are due, and shows a red highlighted count when reminders need attention.

```tmux
set -g status-right '#(/path/to/nvim-reminders/scripts/tmux-reminders.sh ~/notes) %H:%M'
```

### Popup with Keybinding

Open ReminderScan in a tmux popup with `prefix + r`:

```tmux
bind r run-shell '/path/to/nvim-reminders/scripts/tmux-reminder-popup.sh'
```

The popup opens nvim with the Telescope picker, and closes automatically when
you quit nvim - your panes stay untouched underneath.

### Click Support

Make the status bar reminder count clickable (requires tmux 3.0+):

```tmux
bind -Troot MouseDown1Status if -F '#{==:#{mouse_status_range},reminder}' \
  { run-shell '/path/to/nvim-reminders/scripts/tmux-reminder-popup.sh' } \
  { select-window -t = }
```

Now clicking the red "2 reminders" text opens the popup directly!

### Advanced Styling (Powerline)

For a more polished look with powerline-style glyphs and the Nightfox color
scheme:

```tmux
set -g status-right "#[fg=#131a24,bg=#131a24,nobold,nounderscore,noitalics]#[fg=#719cd6,bg=#131a24] #{prefix_highlight} #(/path/to/nvim-reminders/scripts/tmux-reminders.sh ~/notes ~/zet)#[fg=#aeafb0,bg=#131a24,nobold,nounderscore,noitalics]#[fg=#131a24,bg=#aeafb0] %Y-%m-%d  %I:%M %p #[fg=#719cd6,bg=#aeafb0,nobold,nounderscore,noitalics]#[fg=#131a24,bg=#719cd6,bold] #h "
```

### Platform Support

The scripts support both macOS and Linux.

### Note for Oil.nvim Users

If you use Oil.nvim as your default file explorer, add this check to your Oil
config to prevent it from opening when nvim is launched with commands:

```lua
vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
        local has_startup_commands = vim.tbl_contains(vim.v.argv, "-c") or vim.tbl_contains(vim.v.argv, "+")
        if vim.fn.argc() == 0 and not has_startup_commands then
            vim.cmd('Oil')
        end
    end
})
```

## Unit Tests and CI

test locally by running editor command:

```
:PlenaryBustedDirectory tests
```

or cli command:
```
git clone --depth 1 https://github.com/nvim-lua/plenary.nvim ../plenary.nvim
make
```
The installation of plenary this way is weak.  TODO: have the `Makefile` lazily
install plenary somewhere both the local use-case and CI can use it.

Testing via cli is enabled by:

  1. `Makefile`
  2. `scripts/minimal_init.vim`
  3. `tests/*spec.lua` files

CI running tests is enabled by the above plus:

  1. `.github/workflows/ci.yaml`

## Contributions

Contributions are welcome! Please feel free to submit a pull request or open an
issue if you have any suggestions or bug reports.

