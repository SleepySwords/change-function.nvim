local M = {}

--- Converts a position from the reference result and return a new position
--- @param position {}
--- @return Position
function M.reference_position_to_position(position)
  local bufnr = vim.uri_to_bufnr(position["uri"])
  return {
    bufnr = bufnr,
    location = { position["range"]["start"]["line"], position["range"]["start"]["character"] },
  }
end

function M.inside_range(range, pos)
  return range.start.line <= pos[1]
      and pos[1] <= range["end"].line
      and range.start.character <= pos[2]
      and pos[2] <= range["end"].character
end

--- Get the text and the range of a ndoe.
--- @param node TSNode
--- @return TextRange, string
function M.range_text(node, bufnr)
  local row1, col1, row2, col2 = node:range()
  local range = {
    start = {
      line = row1,
      character = col1,
    },
    ["end"] = {
      line = row2,
      character = col2,
    },
  }
  local buf_text = (vim.api.nvim_buf_get_text(bufnr, row1, col1, row2, col2, {}))
  local text = table.concat(buf_text, "\n")
  return range, text
end

function M.convert_win_cursor_to_position(win)
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))
  row = row - 1
  return { line = row, character = col }
end

return M
