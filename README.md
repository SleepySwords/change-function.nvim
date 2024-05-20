# change-function.nvim
What happens when you combine treesitter and lsp together.

## Purpose

change-function.nvim allows you to swap function arguments and have it be updated for all references across a particular project.

## Installation
Use your favourite package manager to install `change-function.nvim`
```lua
{
    "SleepySwords/change-function.nvim"
}
```

## Usage
There is currently a singular function `change_function()` which opens up the menu, for example: binding it to a key

```lua
local change_function = require("change-function")

vim.api.nvim_set_keymap("n", "<leader>cr", "", {
  callback = change_function.change_function,
})
```


## Todo
- [ ] Make a nicer UI with nui
- [ ] Find a better way than recursively calling parent to find the matched node (as this breaks when you try and use this on a value rather than a function).
- [ ] Add more queries for different languages
- [ ] One day maybe even the ability to add or remove function args (would probably have to be through specifying a seperator and using that to join arguments)
