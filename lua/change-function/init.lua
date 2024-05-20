local M = {}

-- local locals = require("nvim-treesitter.locals")
-- local ts_utils = require("nvim-treesitter.ts_utils")
-- local uv = vim.loop

local function make_position_param(win)
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))
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
  local text = (vim.api.nvim_buf_get_text(bufnr, row1, col1, row2, col2, {}));
  local newText = table.concat(text, "\n");
  return range, newText
end

--- Get the parameters/arguments from the function signature.
--- @param node TSNode The node of the function signature
--- @param bufnr integer The buffer number of the buffer where the node resides.
--- @return {}?
local function get_arguments(node, bufnr)
  local query_declare = vim.treesitter.query.get(vim.bo.filetype, "function_dec")
  local query_call = vim.treesitter.query.get(vim.bo.filetype, "function_call")

  if query_declare == nil or query_call == nil then
    vim.print("Queries are not available for this filetype")
    return
  end

  local arguments = {}
  for _, match, _ in query_call:iter_matches(node, bufnr, nil, nil, { all = true, max_start_depth = 1 }) do
    for _, nodes in pairs(match) do
      for _, matched_node in ipairs(nodes) do
        -- local type = matched_node:type()
        -- local row1, col1, row2, col2 = matched_node:range()
        -- vim.print({ type, row1, row2, col1, col2 })
        -- vim.print(range, text)
        local range, text = get_range_text(matched_node, bufnr);
        table.insert(arguments, {
          range = range,
          newText = text
        })
      end
    end
  end

  for _, match, _ in query_declare:iter_matches(node, bufnr, nil, nil, { all = true, max_start_depth = 1 }) do
    for _, nodes in pairs(match) do
      for _, matched_node in ipairs(nodes) do
        -- local type = matched_node:type()
        -- local row1, col1, row2, col2 = matched_node:range()
        -- vim.print({ type, row1, row2, col1, col2 })
        -- vim.print(range, text)
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

local function parse_query(loc, oldIndex, newIndex)
  local query_declare = vim.treesitter.query.get(vim.bo.filetype, "function_dec")
  local query_call = vim.treesitter.query.get(vim.bo.filetype, "function_call")

  if query_declare == nil or query_call == nil then
    vim.print("Queries are not available for this filetype")
    return
  end

  local bufnr = vim.uri_to_bufnr(loc["uri"])
  vim.fn.bufload(bufnr)

  local pos = { loc["range"]["start"]["line"], loc["range"]["start"]["character"] }
  local matched_node = (vim.treesitter.get_node({ pos = pos, bufnr = bufnr, lang = vim.bo.filetype }):parent())
  if matched_node == nil then
    vim.print("Node did not match")
    return
  end

  while query_call:iter_matches(matched_node, bufnr, nil, nil, { all = true, max_start_depth = 1 })() == nil
    and query_declare:iter_matches(matched_node, bufnr, nil, nil, { all = true, max_start_depth = 1 })() == nil do
    matched_node = (matched_node:parent())
    if matched_node == nil then
      vim.print("Node did not match")
      return
    end
  end

  local arguments = get_arguments(matched_node, bufnr);

  if arguments == nil or #arguments < 2 then
    return
  end

  vim.print(arguments)
  local swap = arguments[newIndex].newText;
  arguments[newIndex].newText = arguments[oldIndex].newText;
  arguments[oldIndex].newText = swap;
  vim.lsp.util.apply_text_edits(arguments, bufnr, "utf-8")
end

local function handle_lsp_reference(results, old, new)
  for _, res in ipairs(results) do
    if res.error then
      vim.print("An error occured: " .. res.error)
      return
    end
    for _, loc in ipairs(res.result) do
      parse_query(loc, old, new)
    end
  end
end

local function lsp_buf_request(buf, method, params)
  vim.lsp.buf_request_all(buf, method, params, function(results)
    local curr_node = vim.treesitter.get_node()
    if curr_node ~= nil then
      local node_text = vim.treesitter.get_node_text(curr_node, buf, {})
      vim.ui.input({ prompt = "Swap index for " .. node_text },
        function(i)
          if i == nil then
            return
          end
          vim.ui.input({ prompt = "New index for " .. node_text }, function(k)
            if k == nil then
              return
            end
            handle_lsp_reference(results, tonumber(i), tonumber(k))
          end)
        end)
    end
  end)
end

function M.change_function()
  local method = "textDocument/references"
  local params = {
    textDocument = { uri = vim.uri_from_bufnr(vim.api.nvim_get_current_buf()) },
    position = make_position_param(vim.api.nvim_get_current_win()),
  }
  params.context = { includeDeclaration = true }

  lsp_buf_request(vim.api.nvim_get_current_buf(), method, params)
end

return M
