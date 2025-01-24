local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event

local M = {}

local function update_lines(bufnr, lines, filetype)
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(
    bufnr,
    0,
    #lines,
    false,
    vim.tbl_map(function(i)
      local new_line_char = string.find(i.line, "\n")
      if new_line_char == nil then
        new_line_char = 0
      end
      return i.line:sub(1, new_line_char - 1)
    end, lines)
  )
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  vim.o.filetype = filetype
end

local function move(bufnr, lines, max_col, offset)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))

  if row == max_col then
    return
  end

  local swap = lines[row + offset]
  lines[row + offset] = lines[row]
  lines[row] = swap

  vim.api.nvim_win_set_cursor(0, { row + offset, col })

  update_lines(bufnr, lines)
end

function M.set_config(config_manager)
  M.config = config_manager.config
end

---Open the UI to swap arguments
---@param lines Argument[] The arguments that will be displayed in this UI
---@param node_name string The title of this user interface
---@param filetype string Filetype of the current file
---@param handler fun(swapped_args: Argument[])
function M.open_ui(lines, node_name, filetype, handler)
  local popup = Popup(M.config.nui(node_name))

  popup:mount()

  popup:on(event.BufLeave, function()
    popup:unmount()
  end)

  popup:map("n", M.config.mappings.move_down, function()
    move(popup.bufnr, lines, #lines, 1)
  end, { noremap = true })

  popup:map("n", M.config.mappings.move_up, function()
    move(popup.bufnr, lines, 1, -1)
  end, { noremap = true })

  popup:map("n", M.config.mappings.quit, function()
    vim.cmd([[q]])
  end, { noremap = true })

  popup:map("n", M.config.mappings.quit2, function()
    vim.cmd([[q]])
  end, { noremap = true })

  popup:map("n", M.config.mappings.confirm, function()
    vim.cmd([[q]])
    vim.ui.select(
      { "Confirm", "Cancel" },
      { prompt = "Are you sure?" },
      function(i)
        if i == "Confirm" then
          handler(lines)
        end
      end
    )
  end, { noremap = true })

  update_lines(popup.bufnr, lines, filetype)
end

return M
