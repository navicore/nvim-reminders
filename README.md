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

Async Scanning not implemented

## Features

* Automatically converts natural language time expressions (e.g., "in 2 hours") to ISO 8601 format.
* Displays a human-readable countdown in virtual text.
* Supports configurable repository lists to scan for reminders.

## Feature Wishlist

* A DND Feature, recurring or 1 time
* calendar.vim rendering of reminders - tob to and click to open

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

and when you are ready for a quickfix list of reminders run `:ReminderScan`. Hit
<ENTER> on the reminder you want to address and to resolve it put a symbol
before the time - damage the parsing of it somehow. (looking for workflow
suggestions for something nicer).

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

## Contributions

Contributions are welcome! Please feel free to submit a pull request or open an
issue if you have any suggestions or bug reports.

