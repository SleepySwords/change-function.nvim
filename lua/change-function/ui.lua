local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event

local M = {}

---Update the line for the UI
---@param bufnr number The buffer to update the UI.
---@param lines Argument[] The lines to print.
---@param num_lines_update? integer The number of lines to update in the menu
local function update_lines(bufnr, lines, num_lines_update)
  if num_lines_update == nil then
    num_lines_update = #lines
  end
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(
    bufnr,
    0,
    num_lines_update,
    false,
    vim.tbl_map(function(i)
      local new_line_char = string.find(i.line, "\n")
      if new_line_char == nil then
        new_line_char = 0
      end
      if i.is_deletion then
        return i.line:sub(1, new_line_char - 1) .. " [Marked for deletion]"
      else
        return i.line:sub(1, new_line_char - 1)
      end
    end, lines)
  )
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

---Add the mappings for this popup window.
---@param popup NuiPopup
---@param mappings string | string[]
---@param handler string|fun():nil
local function add_mapping(popup, mappings, handler)
  if type(mappings) == "table" then
    for _, bind in pairs(mappings) do
      popup:map("n", bind, handler, { noremap = true })
    end
  else
    popup:map("n", mappings, handler, { noremap = true })
  end
end

---Open the UI to swap arguments
---@param lines Argument[] The arguments that will be displayed in this UI
---@param node_name string The title of this user interface
---@param handler fun(swapped_args: Argument[])
function M.open_ui(lines, node_name, handler)
  local popup = Popup(M.config.nui(node_name))

  popup:mount()

  popup:on(event.BufLeave, function()
    popup:unmount()
  end)

  add_mapping(popup, M.config.mappings.delete_argument, function()
    local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
    local previous_num_lines = #lines

    -- FIXME: All argument params should have a deleted field.
    if lines[row].is_addition then
      table.remove(lines, row)
    else
      if lines[row].is_deletion == nil then
        lines[row].is_deletion = true
      else
        lines[row].is_deletion = not lines[row].is_deletion
      end
    end

    update_lines(popup.bufnr, lines, previous_num_lines)
  end)

  add_mapping(popup, M.config.mappings.add_argument, function()
    vim.ui.input({
      prompt = "What argument to add to the function signature",
    }, function(signature)
      vim.ui.input({
        prompt = "What default value for the argumet",
      }, function(default_value)
        if default_value ~= nil then
          table.insert(lines, {
            line = default_value,
            declaration = signature,
            is_addition = true,
            is_deletion = false,
            id = -1,
          })

          update_lines(popup.bufnr, lines)
        end
      end)
    end)
  end)

  add_mapping(popup, M.config.mappings.move_up, function()
    move(popup.bufnr, lines, 1, -1)
  end)

  add_mapping(popup, M.config.mappings.move_down, function()
    move(popup.bufnr, lines, #lines, 1)
  end)

  add_mapping(popup, M.config.mappings.quit, function()
    vim.cmd([[q]])
  end)

  add_mapping(popup, M.config.mappings.confirm, function()
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
  end)

  update_lines(popup.bufnr, lines)
end

return M
