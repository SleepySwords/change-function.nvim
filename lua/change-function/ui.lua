local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event

local M = {}

local function update_lines(bufnr, lines)
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, #lines, false, vim.tbl_map(function(i)
    local new_line_char = string.find(i.lines, "\n")
    if new_line_char == nil then
      new_line_char = 0
    end
    return i.lines:sub(1, new_line_char - 1)
  end, lines))
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
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

function M.open_ui(lines, node_name, handler)
  local popup = Popup(M.config.nui(node_name))

  popup:mount()

  popup:on(event.BufLeave, function()
    popup:unmount()
  end)

  popup:map("n", M.config.mappings.move_down, function(_)
    move(popup.bufnr, lines, #lines, 1)
  end, { noremap = true })

  popup:map("n", M.config.mappings.move_up, function(_)
    move(popup.bufnr, lines, 1, -1)
  end, { noremap = true })

  popup:map("n", M.config.mappings.quit, function(_)
    vim.cmd [[q]]
  end, { noremap = true })

  popup:map("n", M.config.mappings.quit2, function(_)
    vim.cmd [[q]]
  end, { noremap = true })

  popup:map("n", M.config.mappings.confirm, function(_)
    vim.cmd [[q]]
    vim.ui.select({ "Confirm", "Cancel" }, { prompt = "Are you sure?" }, function(i)
      if i == "Cancel" then
        return
      end
      handler(lines)
    end)
  end, { noremap = true })

  update_lines(popup.bufnr, lines)
end

return M
