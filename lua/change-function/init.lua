local ui = require("change-function.ui")
local config_manager = require("change-function.config")
local api = vim.api
local treesitter = vim.treesitter

local M = {}

local function make_position_param(win)
  local row, col = unpack(api.nvim_win_get_cursor(win))
  row = row - 1
  return { line = row, character = col }
end

--- get_range_text
--- @param node TSNode
--- @return {}, string
local function get_range_text(node, bufnr)
  local row1, col1, row2, col2 = node:range();
  local range = {
    start = {
      line = row1,
      character = col1,
    },
    ["end"] = {
      line = row2,
      character = col2,
    }
  }
  local text = (api.nvim_buf_get_text(bufnr, row1, col1, row2, col2, {}));
  local newText = table.concat(text, "\n");
  return range, newText
end

--- Get the parameters/arguments from the function signature.
--- @param node TSNode The node of the function signature
--- @param bufnr integer The buffer number of the buffer where the node resides.
--- @return table<any, any>?
local function get_arguments(node, bufnr)
  local query_function = treesitter.query.get(vim.bo.filetype, "function_args_params")

  if query_function == nil then
    vim.print("Queries are not available for this filetype")
    return
  end

  while query_function:iter_matches(node, bufnr, nil, nil, { all = true, max_start_depth = 0 })() == nil do
    node = node:parent()
    if node == nil then
      vim.print("Node did not match")
      return
    end
  end

  local arguments = {}
  for _, match, _ in query_function:iter_matches(node, bufnr, nil, nil, { all = true, max_start_depth = 0 }) do
    for _, nodes in pairs(match) do
      for _, matched_node in ipairs(nodes) do
        local range, text = get_range_text(matched_node, bufnr);
        table.insert(arguments, {
          range = range,
          newText = text
        })
      end
    end
  end

  return arguments
end

--- Get the text edits that need to be done
local function get_text_edits(loc, sorting)
  local bufnr = vim.uri_to_bufnr(loc["uri"])
  vim.fn.bufload(bufnr)

  local pos = { loc["range"]["start"]["line"], loc["range"]["start"]["character"] }
  local matched_node = treesitter.get_node({ pos = pos, bufnr = bufnr, lang = vim.bo.filetype }):parent()
  if matched_node == nil then
    vim.print("Node did not match")
    return
  end

  local text_edits = get_arguments(matched_node, bufnr);
  if text_edits == nil then
    return
  end
  local clone = vim.deepcopy(text_edits, true)
  for i, v in ipairs(sorting) do
    text_edits[i].newText = clone[v.id].newText
  end
  return text_edits
end

--- Handles the lsp results and apply text edits
local function handle_lsp_reference_result(results, sorting)
  local global_text_edits = {}
  for _, res in ipairs(results) do
    if res.error then
      vim.print("An error occured: " .. res.error)
      return
    end
    for _, loc in ipairs(res.result) do
      local text_edits = get_text_edits(loc, sorting)
      if text_edits ~= nil then
        for _, v in ipairs(text_edits) do
          if global_text_edits[vim.uri_to_bufnr(loc["uri"])] == nil then
            global_text_edits[vim.uri_to_bufnr(loc["uri"])] = {}
          end
          table.insert(global_text_edits[vim.uri_to_bufnr(loc["uri"])], v)
        end
      end
    end
  end

  for k, v in pairs(global_text_edits) do
    vim.lsp.util.apply_text_edits(v, k, 'UTF-8')
  end
end

local function lsp_buf_request(buf, method, params)
  local query_function = treesitter.query.get(vim.bo.filetype, "function_args_params")

  if query_function == nil then
    vim.print("Queries are not available for this filetype")
    return
  end

  vim.lsp.buf_request_all(buf, method, params, function(results)
    local curr_node = treesitter.get_node()
    if curr_node ~= nil then
      local arguments = get_arguments(curr_node, buf);
      if arguments == nil then
        return
      end
      local index = 0
      local lines = vim.tbl_map(function(i)
        index = index + 1
        return { lines = i.newText, id = index }
      end, arguments)
      ui.open_ui(lines, treesitter.get_node_text(curr_node, buf, {}), function()
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
    position = make_position_param(api.nvim_get_current_win()),
  }
  params.context = { includeDeclaration = true }

  lsp_buf_request(api.nvim_get_current_buf(), method, params)
end

function M.setup(opts)
  config_manager.set_default(opts)
  ui.set_config(config_manager)
end

M.setup({})

return M
