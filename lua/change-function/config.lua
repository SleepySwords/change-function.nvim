---@enum MappingName
local mapping_default = {
  quit = "q",
  quit2 = "<esc>",
  move_down = "<S-j>",
  move_up = "<S-k>",
  confirm = "<enter>",
}

---@enum QuickFixSource
local quick_fix_source = {
  entry = "entry",
  cursor = "cursor",
}

---@class ChangeFunctionConfig
---@field queries? table<string, string>
---@field nui? fun (node_name: string): NuiPopup
---@field mappings? table<MappingName, string>
---@field quickfix_source? QuickFixSource

local defaults = {

  queries = {
    rust = "function_params",
    lua = "function_params",
  },

  nui = function(node_name)
    return {
      enter = true,
      focusable = true,
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
    quit = "q",
    quit2 = "<esc>",
    move_down = "<S-j>",
    move_up = "<S-k>",
    confirm = "<enter>",
  },
}
local config = {}

function config.set_default(user_defaults)
  config.config = vim.tbl_deep_extend("keep", user_defaults, defaults)
end

return config
