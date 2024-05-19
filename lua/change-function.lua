local M = {}

local locals = require("nvim-treesitter.locals")
local ts_utils = require("nvim-treesitter.ts_utils")
local uv = vim.loop

local lsp = require("vim.lsp")

local function make_position_param(win, buf)
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))
  row = row - 1
  return { line = row, character = col }
end

local query_declare = vim.treesitter.query.parse(
  "lua",
  [[
(function_declaration
	parameters: (parameters
		name: (identifier) @param
	)
)
]]
)

local query_call = vim.treesitter.query.parse(
  "lua",
  [[
(function_call
  arguments: (arguments
	 (_) @arg
   )
)
]]
)

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

local function parse_query(loc)
  local pos = { loc["range"]["start"]["line"], loc["range"]["start"]["character"] }
  local p_node = (vim.treesitter.get_node({ pos = pos }):parent())
  if p_node == nil then
    return
  end
  local textEdits = {}
  for _, match, _ in query_call:iter_matches(p_node, 0, nil, nil, { all = true, max_start_depth = 1 }) do
    for _, nodes in pairs(match) do
      for _, node in ipairs(nodes) do
        local type = node:type()
        local row1, col1, row2, col2 = node:range()
        vim.print({ type, row1, row2, col1, col2 })
        local range, text = get_range_text(node, 0);
        vim.print(range, text)
        table.insert(textEdits, {
          range = range,
          newText = text
        })
      end
    end
  end
  -- vim.print(textEdits)
  -- local new = textEdits[2].newText;
  -- textEdits[2].newText = textEdits[1].newText;
  -- textEdits[1].newText = new;
  -- vim.lsp.util.apply_text_edits(textEdits, 0, "utf-8")

  for _, match, _ in query_declare:iter_matches(p_node, 0, nil, nil, { all = true, max_start_depth = 1 }) do
    for _, nodes in pairs(match) do
      for _, node in ipairs(nodes) do
        local type = node:type()
        local row1, col1, row2, col2 = node:range()
        vim.print({ type, row1, row2, col1, col2 })
        local range, text = get_range_text(node, 0);
        vim.print(range, text)
        table.insert(textEdits, {
          range = range,
          newText = text
        })
      end
    end
  end

  vim.print(textEdits)
  local new = textEdits[2].newText;
  textEdits[2].newText = textEdits[1].newText;
  textEdits[1].newText = new;
  vim.lsp.util.apply_text_edits(textEdits, vim.api.nvim_get_current_buf(), "utf-8")
end

local function lsp_buf_request(buf, method, params, handler)
  lsp.buf_request_all(buf, method, params, function(err)
    for _, res in ipairs(err) do
      if res.error then
        return
      end
      for _, loc in ipairs(res.result) do
        parse_query(loc)
      end
    end
  end)
end

function M.change_function()
  local method = "textDocument/references"
  local params = {
    textDocument = { uri = vim.uri_from_bufnr(vim.api.nvim_get_current_buf()) },
    position = make_position_param(vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()),
  }
  params.context = { includeDeclaration = true }

  lsp_buf_request(vim.api.nvim_get_current_buf(), method, params, function(err, result)
    if err then
      vim.print("an error happened getting references: " .. err.message)
      return
    end
    if result == nil or #result == 0 then
      return
    end
    local ret = M.locations_to_items({ result }, 0)
    vim.print(ret)
  end)
end

vim.api.nvim_set_keymap("n", "<leader>v", "", {
  callback = M.change_function,
})

return M
