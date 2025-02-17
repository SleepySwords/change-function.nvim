# change-function.nvim
What happens when you combine treesitter and lsp together.

![output](https://github.com/SleepySwords/change-function.nvim/assets/33922797/540489a7-958b-455c-8a0c-c974a8d05e98)

## Purpose

change-function.nvim allows you to swap function arguments or parameters and
have it be updated for all references across a particular project.

## Installation
Use your favourite package manager to install `change-function.nvim`

### via Lazy
```lua
{
    'SleepySwords/change-function.nvim',
    dependencies = {
      'MunifTanjim/nui.nvim',
      'nvim-treesitter/nvim-treesitter',
      'nvim-treesitter/nvim-treesitter-textobjects', -- Not required, however provides fallback `textobjects.scm`
    }
}
```

## Usage
There are currently different ways to use this plugin. One automatically using
LSP references (this is the default when using the `change_function()` function), 
the other uses the quickfix list as a source of the functions to change.

### Automatically via LSP references.

This is the default version when running `change_function()`. It allows for a
quick way to change function arguments, but sacrifices flexibility.

1. Run the `require("change-function").change_function_via_lsp_references()` or
   `require("change-function").change_function()` command to open up the
   reorganisation window.
2. Swap whatever arguments you need using the specified mappings.
3. Press enter and confirm

### Using the quickfix list.

1. Add your references using a command, for example
   `vim.lsp.references({includeDeclaration = true})`
2. Modify the quickfix list with whatever workflow you currently use.
3. Run the `:lua require("change-function").change_function_via_qf()` command to
   open up the reorganisation window.
4. Swap whatever arguments you need using the specified mappings.
5. Press enter and confirm

The quickfix list method allows for
- Much more flexibility, as you can use existing quickfix workflows and use
  plugins such as `nvim-bqf`, `quicker.nvim` or `listish.nvim` to be able to
  modify the list and include references that you want to change.
- Allows you to be able to see what the functions that will be changed before
  actually running the command.

```lua
local change_function = require('change-function')

-- Default options
change_function.setup({
  languages = {
    rust = {
      query_file = "function_params",
      argument_seperator = ", ",
    },
  },

  nui = function(node_name)
    return {
      enter = true,
      focusable = true,
      relative = "win",
      zindex = 50,
      border = {
        style = "rounded",
        text = {
          top = "Changing argument of " .. node_name,
        },
      },
      position = "50%",
      size = {
        width = "40%",
        height = "20%",
      },
      buf_options = {
        modifiable = false,
        readonly = false,
      },
    }
  end,

  ui = {
    disable_syntax_highlight = false,
  },

  quickfix_source = "entry",

  mappings = {
    quit = { "q", "<Esc>" },
    move_down = "<S-j>",
    move_up = "<S-k>",
    confirm = "<enter>",
    delete_argument = "x",
    add_argument = "i",
  },
})

vim.api.nvim_set_keymap('n', '<leader>crl', '', {
  callback = change_function.change_function,
})

vim.api.nvim_set_keymap('n', '<leader>crq', '', {
  callback = change_function.change_function_via_qf,
})
```
## [Writing queries for different languages](/docs/query_creation.md)

## Todo
- [x] Make a nicer UI with nui
- [x] Allow for customisability with nui
- [x] Refactor so `function_declaration.scm` and `function_call.scm` are the
  same.
- [x] Find a better way to find the function declaration/call, rather than
  recursively calling parent to find the matched node (as this breaks when you
  try and use this on a value rather than a function).
- [ ] Add more queries for different languages
- [ ] One day maybe even the ability to add or remove function args (would
  probably have to be through specifying a seperator and using that to join
  arguments, as treesitter only provides the argument location)
