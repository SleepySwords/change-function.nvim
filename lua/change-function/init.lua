--- @class TextRange
--- @field start {line: integer, character: integer}
--- @field end {line: integer, character: integer}

--- @class Text
--- @field text string
--- @field range TextRange

local ui = require("change-function.ui")
local config_manager = require("change-function.config")
local api = vim.api
local ts = vim.treesitter

local M = {}

IDENTIFYING_CAPTURES = { ["function_name"] = true, ["method_name"] = true }
ARGUMENT_CAPTURES = { ["parameter.inner"] = true, ["argument.inner"] = true }

local function get_queries()
  return ts.query.get(vim.bo.filetype, config_manager.config.queries[vim.bo.filetype] or "textobjects")
end

local function make_win_cursor_position(win)
  local row, col = unpack(api.nvim_win_get_cursor(win))
  row = row - 1
  return { line = row, character = col }
end

local function print_error(msg)
  vim.notify("Failed to swap: " .. msg, vim.log.levels.ERROR)
end

--- Get the text and the range of a ndoe.
--- @param node TSNode
--- @return TextRange, string
local function range_text(node, bufnr)
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
  local buf_text = (api.nvim_buf_get_text(bufnr, row1, col1, row2, col2, {}))
  local text = table.concat(buf_text, "\n")
  return range, text
end

local function inside_range(range, pos)
  return range.start.line <= pos[1]
    and pos[1] <= range["end"].line
    and range.start.character <= pos[2]
    and pos[2] <= range["end"].character
end

--- Get the parameters/arguments from the function signature.
--- @param node TSNode The node of the function signature
--- @param bufnr integer The buffer number of the buffer where the node resides.
--- @param cursor table<integer, integer> The cursor of this even..
--- @return table<any, Text>?
local function get_arguments(node, bufnr, cursor)
  local query_function = get_queries()

  if query_function == nil then
    print_error("Queries are not available for this filetype")
    return
  end

  while query_function:iter_matches(node, bufnr, nil, nil, { all = true, max_start_depth = 0 })() == nil do
    node = node:parent()
    if node == nil then
      print_error(
        string.format(
          "Could not find a function at (%d, %d) in the file %s",
          (cursor[1] + 1),
          (cursor[2] + 1),
          vim.api.nvim_buf_get_name(bufnr)
        )
      )
      return
    end
  end

  local arguments = {}
  local ignore = {}
  for _, match, _ in query_function:iter_matches(node, bufnr, nil, nil, { all = true, max_start_depth = 0 }) do
    for id, nodes in pairs(match) do
      local capture_name = query_function.captures[id]

      for _, matched_node in ipairs(nodes) do
        local range, text = range_text(matched_node, bufnr)

        if (IDENTIFYING_CAPTURES[capture_name] ~= nil) and not inside_range(range, cursor) then
          print_error(
            string.format(
              "Could not find a function at (%d, %d) in the file %s",
              (cursor[1] + 1),
              (cursor[2] + 1),
              vim.api.nvim_buf_get_name(bufnr)
            )
          )
          return
        end

        if ARGUMENT_CAPTURES[capture_name] ~= nil then
          table.insert(arguments, {
            range = range,
            text = text,
          })
        end
        if capture_name == "parameter.inner.ignore" then
          table.insert(ignore, range)
        end
      end
    end
  end

  for _, v in ipairs(ignore) do
    arguments = vim.tbl_filter(function(i)
      return not vim.deep_equal(i.range, v)
    end, arguments)
  end

  return arguments
end

--- Get the text edits that need to be done to change an argument
--- @param loc {} location of where the change should be done
--- @param changes {} The swaps that are required to change
--- @return {}?
local function get_text_edits(loc, changes)
  local bufnr = vim.uri_to_bufnr(loc["uri"])
  vim.fn.bufload(bufnr)

  local pos = { loc["range"]["start"]["line"], loc["range"]["start"]["character"] }
  local matched_node = ts.get_node({ pos = pos, bufnr = bufnr, lang = vim.bo.filetype })
  if matched_node == nil then
    print_error(
      string.format(
        "Could not find any nodes at the location (%d, %d) in the file %s",
        (pos[1] + 1),
        (pos[2] + 1),
        vim.api.nvim_buf_get_name(bufnr)
      )
    )
    return
  end

  local args = get_arguments(matched_node, bufnr, pos)
  if args == nil then
    return
  end

  local text_edits = {}
  for i, v in ipairs(changes) do
    -- Don't include textedits that dot not change anything.
    if i ~= v.id then
      if #args < v.id then
        print_error(
          string.format(
            "Swapped argument does not exist at (%d, %d) in %s",
            pos[1] + 1,
            pos[2] + 1,
            vim.api.nvim_buf_get_name(bufnr)
          )
        )
        return
      end
      table.insert(text_edits, {
        newText = args[v.id].text,
        range = args[i].range,
      })
    end
  end

  return text_edits
end

--- Handles the lsp results and apply text edits
local function handle_lsp_reference_result(results, changes)
  local global_text_edits = {}
  for _, res in ipairs(results) do
    if res.error then
      print_error("An error occured while fetching references: " .. res.error)
      return
    end

    for _, loc in ipairs(res.result) do
      local text_edits = get_text_edits(loc, changes)
      if text_edits == nil then
        return
      end
      if #text_edits == 0 then
        vim.notify(
          string.format(
            "Did not find any Treesitter matches at (%d, %d) in %s (is this an error?)",
            loc["range"]["start"]["line"] + 1,
            loc["range"]["start"]["character"] + 1,
            loc["uri"]
          ),
          vim.log.levels.WARN
        )
      end

      for _, v in ipairs(text_edits) do
        if global_text_edits[vim.uri_to_bufnr(loc["uri"])] == nil then
          global_text_edits[vim.uri_to_bufnr(loc["uri"])] = {}
        end
        table.insert(global_text_edits[vim.uri_to_bufnr(loc["uri"])], v)
      end
    end
  end

  for k, v in pairs(global_text_edits) do
    vim.lsp.util.apply_text_edits(v, k, "UTF-8")
  end
end

local function make_lsp_request(buf, method, params)
  local query_function = get_queries()

  if query_function == nil then
    print_error("Could not find a query for this filetype")
    return
  end

  vim.lsp.buf_request_all(buf, method, params, function(results)
    local curr_node = ts.get_node()

    if curr_node ~= nil then
      local arguments = get_arguments(curr_node, buf, {
        vim.api.nvim_win_get_cursor(0)[1] - 1,
        vim.api.nvim_win_get_cursor(0)[2],
      })
      if arguments == nil then
        return
      end

      local index = 0
      local lines = vim.tbl_map(function(i)
        index = index + 1
        return { line = i.text, id = index }
      end, arguments)

      ui.open_ui(lines, ts.get_node_text(curr_node, buf, {}), function()
        handle_lsp_reference_result(results, lines)
      end)
    end
  end)
end

--- Change the function variable locations
function M.change_function()
  local method = "textDocument/references"
  local params = {
    textDocument = { uri = vim.uri_from_bufnr(api.nvim_get_current_buf()) },
    position = make_win_cursor_position(api.nvim_get_current_win()),
  }
  params.context = { includeDeclaration = true }

  make_lsp_request(api.nvim_get_current_buf(), method, params)
end

function M.setup(opts)
  config_manager.set_default(opts)
  ui.set_config(config_manager)
end

M.setup({})

return M
