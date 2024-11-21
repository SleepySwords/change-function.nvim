---@class Mappings
---@field quit? string | string[]
---@field move_down? string
---@field move_up? string
---@field confirm? string

---@class InternalMappings
---@field quit string | string[]
---@field move_down string
---@field move_up string
---@field confirm string

---@class ChangeFunctionConfig
---@field queries? table<string, string>
---@field nui? fun (node_name: string): NuiPopup
---@field mappings? Mappings
---@field quickfix_source? "entry" | "cursor"

---@class InternalChangeFunctionConfig
---@field queries table<string, string>
---@field nui fun (node_name: string): NuiPopup
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

  quickfix_source = "entry",

  mappings = {
    quit = { "q", "<Esc>" },
    move_down = "<S-j>",
    move_up = "<S-k>",
    confirm = "<enter>",
    delete_argument = "x",
    add_argument = "i",
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
