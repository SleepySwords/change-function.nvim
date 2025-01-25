---@class Mappings
---@field quit? string
---@field quit2? string
---@field move_down? string
---@field move_up? string
---@field confirm? string

---@class InternalMappings
---@field quit string
---@field quit2 string
---@field move_down string
---@field move_up string
---@field confirm string

---@class ChangeFunctionConfig
---@field queries? table<string, string>
---@field nui? fun (node_name: string): NuiPopup
---@field ui? ChangeFunctionUiConfig
---@field mappings? Mappings
---@field quickfix_source? "entry" | "cursor"

---@class ChangeFunctionUiConfig
---@field disable_syntax_highlight string[] | boolean Table of filetypes to not syntax highlight. If `true`, disable syntax highlighting all filetypes. If `false`, enable syntax highlighting for all.

---@class InternalChangeFunctionConfig
---@field queries table<string, string>
---@field nui fun (node_name: string): NuiPopup
---@field ui ChangeFunctionUiConfig
---@field mappings Mappings
---@field quickfix_source "entry" | "cursor"
local defaults = {
  queries = {
    rust = "function_params",
    lua = "function_params",
    cpp = "function_params",
  },

  nui = function(node_name)
    return {
      enter = true,
      focusable = true,
      relative = "win",
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
    quit = "q",
    quit2 = "<esc>",
    move_down = "<S-j>",
    move_up = "<S-k>",
    confirm = "<enter>",
  },
}

---@class ConfigManager
---@field config InternalChangeFunctionConfig
local config_manager = {
  config = defaults,
}

function config_manager.set_default(user_defaults)
  config_manager.config = vim.tbl_deep_extend("keep", user_defaults, defaults)
end

return config_manager
