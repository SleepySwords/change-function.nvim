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

function M.open_ui(lines, node_name, handler)
  local popup = Popup({
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
  })

  -- mount/open the component
  popup:mount()

  -- unmount component when cursor leaves buffer
  popup:on(event.BufLeave, function()
    popup:unmount()
    vim.ui.select({ "Confirm", "Cancel" }, { prompt = "Are you sure?" }, function(i)
      if i == "Cancel" then
        return
      end
      handler(lines)
    end)
  end)

  popup:map("n", "<S-j>", function(_)
    move(popup.bufnr, lines, #lines, 1)
  end, { noremap = true })

  popup:map("n", "<S-k>", function(_)
    move(popup.bufnr, lines, 1, -1)
  end, { noremap = true })

  popup:map("n", "q", function(_)
    vim.cmd [[q]]
  end, { noremap = true })

  popup:map("n", "<enter>", function(_)
    vim.cmd [[q]]
  end, { noremap = true })

  update_lines(popup.bufnr, lines)
end

return M
