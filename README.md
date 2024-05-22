# change-function.nvim
What happens when you combine treesitter and lsp together.

![output](https://github.com/SleepySwords/change-function.nvim/assets/33922797/540489a7-958b-455c-8a0c-c974a8d05e98)

## Purpose

change-function.nvim allows you to swap function arguments or parameters and have it be updated for all references across a particular project.

## Installation
Use your favourite package manager to install `change-function.nvim`

### via Lazy
```lua
{
    'SleepySwords/change-function.nvim',
    dependencies = {
      'MunifTanjim/nui.nvim'
    }
}
```

## Usage
There is currently a singular function `change_function()` which opens up the menu, for example: binding it to a key. You may call setup to customise some options with nui and keybindings within `change-function.nvim`.

```lua
local change_function = require('change-function')

-- Default options
change_function.setup({
  nui = function(node_name)
    return {
      enter = true,
      focusable = true,
      border = {
        style = "rounded",
        text = {
          top = "Changing argument of " .. node_name,
        }
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

  mappings = {
    quit = 'q',
    quit2 = '<esc>',
    move_down = '<S-j>',
    move_up = '<S-k>',
    confirm = '<enter>',
  }
})

vim.api.nvim_set_keymap('n', '<leader>cr', '', {
  callback = change_function.change_function,
})
```

## Writing queries for different languages

`change-function.nvim` uses treesitter to find the location of argument and function parameters in order to swap them. Writing these queries to match the argument is fortunately quite simple.

The queries used are inside the `function_args_params.scm` files and are individual to each language. These files are stored in the runtime `queries` directory, so local configurations are also able to add or override them.

Using the `:InspectTree` command, observe how treesitter interperts the syntax tree. The items we want to find are the function declaration/call itself and the arguments within the function declaration/call.

Usually, they would have a similar name to `function_item` or `call_expression`.

We want to match the individual arguments from the query so they can be used. Usually, the multiple arguments are within the `arguments`/`parameters` field of the function declaration or call expression. To capture the individual arguments we want to append a capture, such as `@arg`, to the end of the query. As some parsers may use the expressions themselves (like: `binary_expression`), a placeholder value `(_)` could be used.

Ensure, you place both a function declaration and a call expression if your language supports it to update references across your project.

Putting this together for Rust
```query
; Matches the call arguments
(call_expression
    arguments: (arguments
        (_) @arg
    )
)

; Matches function declarations
(function_item
    parameters: (parameters
        (parameter) @param
    )
)

(function_signature_item
    parameters: (parameters
        (parameter) @param
    )
)
```

If you have written a nice query, please contribute it here :)

## Todo
- [x] Make a nicer UI with nui
- [x] Allow for customisability with nui
- [x] Refactor so `function_declaration.scm` and `function_call.scm` are the same.
- [ ] Find a better way to find the function declaration/call, rather than recursively calling parent to find the matched node (as this breaks when you try and use this on a value rather than a function).
- [ ] Add more queries for different languages
- [ ] One day maybe even the ability to add or remove function args (would probably have to be through specifying a seperator and using that to join arguments, as treesitter only provides the argument location)
