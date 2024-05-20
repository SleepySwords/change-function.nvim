local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event

local function open_ui(handler)
  local popup = Popup({
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
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

  local lines = { "Hello World", "Ad", "iaowejf" }

  -- unmount component when cursor leaves buffer
  popup:on(event.BufLeave, function()
    popup:unmount()
    handler(lines)
  end)

  popup:map("n", "<S-j>", function(_)
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))

    if row == #lines then
      return
    end

    local swap = lines[row + 1]
    lines[row + 1] = lines[row]
    lines[row] = swap

    vim.api.nvim_win_set_cursor(0, { row + 1, col })

    vim.api.nvim_set_option_value("modifiable", true, { buf = popup.bufnr })
    vim.api.nvim_buf_set_lines(popup.bufnr, 0, #lines, false, lines)
  end, { noremap = true })

  popup:map("n", "<S-k>", function(_)
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))

    if row == 1 then
      return
    end

    local swap = lines[row - 1]
    lines[row - 1] = lines[row]
    lines[row] = swap

    vim.api.nvim_win_set_cursor(0, { row - 1, col })

    vim.api.nvim_set_option_value("modifiable", true, { buf = popup.bufnr })
    vim.api.nvim_buf_set_lines(popup.bufnr, 0, #lines, false, lines)
  end, { noremap = true })

  popup:map("n", "q", function(_)
    vim.cmd [[q]]
  end, { noremap = true })

  -- set content
  vim.api.nvim_set_option_value("modifiable", true, { buf = popup.bufnr })
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, #lines, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = popup.bufnr })
end

open_ui(function()

end)
