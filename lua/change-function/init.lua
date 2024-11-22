---@class TextRange
---@field start {line: integer, character: integer}
---@field end {line: integer, character: integer}

---@class Text
---@field text string
---@field range TextRange

---@class Position
---@field bufnr integer
---@field location integer[]

---@class Argument Note: the `Argument[]` indicates the order of the NEW arguments,
---wheras the id provides the arguments of the OLD list
---@field line string The contents of this particular argument
---@field id string The index of this particular argument in all the arguments (before swapping)
---@field is_addition boolean
---@field is_deletion boolean

local ui = require("change-function.ui")
local config_manager = require("change-function.config")
local api = vim.api
local ts = vim.treesitter

local utils = require("change-function.utils")
local reference_position_to_position = utils.reference_position_to_position
local inside_range = utils.inside_range
local range_text = utils.range_text
local convert_win_cursor_to_position = utils.convert_win_cursor_to_position

local M = {}

IDENTIFYING_CAPTURES = { ["function_name"] = true, ["method_name"] = true }
ARGUMENT_CAPTURES = { ["parameter.inner"] = true, ["argument.inner"] = true }

---Gets the current query from the
---@param bufnr? integer The buffer to get the query from
---@return (vim.treesitter.Query)?
local function get_queries(bufnr)
  if bufnr == nil then
    bufnr = 0
  end
  return ts.query.get(
    vim.bo[bufnr].filetype,
    config_manager.config.queries[vim.bo[bufnr].filetype] or "textobjects"
  )
end

---Does this node match the query, and, if applicable, is the position
---inside the range of the identifying capture of this node.
---
---This uses max_start_depth of 1, this previously used to make matches
---not work as expected. This is because it would go to the parent node
---and the parent node contains the previous function as a `field`. This
---matches the field and returns without matching the actual function. Now
---we match based on if we are in range as well (if there exists an
---identifying capture). If there is no identifying capture, it will do the
---same behaviour (wrong matching), however, this is better than not matching
---at all.
---@param query_function vim.treesitter.Query The query to check for
---@param node TSNode The node of the function signature
---@param bufnr integer The buffer number of the buffer where the node resides.
---@param position integer[] The cursor of the expected function signature
---@return boolean valid The node is valid.
local function is_node_valid(query_function, node, bufnr, position)
  if
    query_function:iter_matches(
      node,
      bufnr,
      nil,
      nil,
      { all = true, max_start_depth = 1 }
    )() == nil
  then
    return false
  end

  local check_in_range = false
  for id, _ in pairs(IDENTIFYING_CAPTURES) do
    if vim.list_contains(query_function.captures, id) then
      check_in_range = true
    end
  end

  if not check_in_range then
    return true
  end

  for _, match, _ in
    query_function:iter_matches(
      node,
      bufnr,
      nil,
      nil,
      { all = true, max_start_depth = 1 }
    )
  do
    for id, nodes in pairs(match) do
      local capture_name = query_function.captures[id]

      for _, matched_node in ipairs(nodes) do
        local range, _ = range_text(matched_node, bufnr)
        if
          (IDENTIFYING_CAPTURES[capture_name] ~= nil)
          and inside_range(range, position)
        then
          return true
        end
      end
    end
  end

  return false
end

local function print_error(msg)
  vim.notify("Failed to swap: " .. msg, vim.log.levels.ERROR)
end

---Get the parameters/arguments from the function signature.
---@param node TSNode The node of the function signature
---@param bufnr integer The buffer number of the buffer where the node resides.
---@param position integer[] The cursor of the expected function signature
---@return {range: TextRange, text: string}[]? The range of the arguments in the signature + the text it contains.
local function get_signature_info(node, bufnr, position)
  local query_function = get_queries(bufnr)

  if query_function == nil then
    print_error("Queries are not available for this filetype")
    return
  end

  while not is_node_valid(query_function, node, bufnr, position) do
    node = node:parent()
    if node == nil then
      print_error(
        string.format(
          "Could not find a function at (%d, %d) in the file %s",
          (position[1] + 1),
          (position[2] + 1),
          vim.api.nvim_buf_get_name(bufnr)
        )
      )
      return
    end
  end

  -- By default we will assume all treesitter matches are function calls (unless proven otherwise)
  local is_call = true
  local arguments = {}
  local ignore = {}
  for _, match, _ in
    query_function:iter_matches(
      node,
      bufnr,
      nil,
      nil,
      { all = true, max_start_depth = 1 }
    )
  do
    for id, nodes in pairs(match) do
      local capture_name = query_function.captures[id]

      for _, matched_node in ipairs(nodes) do
        local range, text = range_text(matched_node, bufnr)

        if capture_name == "function.outer" then
          is_call = false
        end

        if
          (IDENTIFYING_CAPTURES[capture_name] ~= nil)
          and not inside_range(range, position)
        then
          print_error(
            string.format(
              "Could not find a function at (%d, %d) in the file %s",
              (position[1] + 1),
              (position[2] + 1),
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

  vim.print(arguments, is_call)

  return arguments
end

---Get the text edits that need to be done to change an argument
---@param position Position position of where the change should be done
---@param changes Argument[] The swaps that are required to change
---@return {newText: string, range: TextRange}[]?
local function get_text_edits(position, changes)
  vim.fn.bufload(position.bufnr)

  local pos = position.location
  local matched_node = ts.get_node({
    pos = pos,
    bufnr = position.bufnr,
    lang = vim.bo[position.bufnr].filetype,
  })
  if matched_node == nil then
    print_error(
      string.format(
        "Could not find any nodes at the location (%d, %d) in the file %s",
        (pos[1] + 1),
        (pos[2] + 1),
        vim.api.nvim_buf_get_name(position.bufnr)
      )
    )
    return
  end

  local args = get_signature_info(matched_node, position.bufnr, pos)
  if args == nil then
    return
  end

  local new_args = vim.tbl_filter(function(change)
    return not change.is_deletion
  end, changes)

  local num_deletions = #changes - #new_args

  local num_additions = #vim.tbl_filter(function(e)
    return e.is_addition
  end, new_args)

  local text_edits = {}
  local to_add = ""
  for i, v in ipairs(new_args) do
    -- Don't include textedits that dot not change anything.
    if i ~= v.id then
      if #args < v.id then
        print_error(
          string.format(
            "Swapped argument does not exist at (%d, %d) in %s",
            pos[1] + 1,
            pos[2] + 1,
            vim.api.nvim_buf_get_name(position.bufnr)
          )
        )
        return
      end
      local text
      if v.is_addition then
        text = v.line
      else
        text = args[v.id].text
      end
      if #args < i then
        if v.is_addition then
          to_add = to_add .. ", " .. text
        else
          to_add = to_add .. ", " .. text
        end
      else
        table.insert(text_edits, {
          newText = text,
          range = args[i].range,
        })
      end
    end
  end

  if num_deletions > num_additions then
    local deletion_range = ((num_deletions - num_additions) >= #args)
        and {
          start = args[1].range["start"],
          ["end"] = args[#args].range["end"],
        }
      or {
        start = args[#args - (num_deletions - num_additions)].range["end"],
        ["end"] = args[#args].range["end"],
      }

    table.insert(text_edits, {
      newText = "",
      range = deletion_range,
    })
  else
    table.insert(text_edits, {
      newText = to_add,
      range = {
        start = args[#args].range["end"],
        ["end"] = args[#args].range["end"],
      },
    })
  end

  return text_edits
end

--- Updates the function declaration and calls at the position by applying text edits
--- according to the changes
--- @param positions Position[]
--- @param changes Argument[]
local function update_at_positions(positions, changes)
  local global_text_edits = {}
  for _, position in ipairs(positions) do
    local text_edits = get_text_edits(position, changes)
    if text_edits == nil then -- FIXME: add no strictness
      return
    end
    if #text_edits == 0 then
      vim.notify(
        string.format(
          "Did not find any Treesitter matches at (%d, %d) in %s (is this an error?)",
          position.location[1] + 1,
          position.location[2] + 1,
          vim.api.nvim_buf_get_name(position.bufnr)
        ),
        vim.log.levels.WARN
      )
    end

    for _, v in ipairs(text_edits) do
      if global_text_edits[position.bufnr] == nil then
        global_text_edits[position.bufnr] = {}
      end
      table.insert(global_text_edits[position.bufnr], v)
    end
  end

  for k, v in pairs(global_text_edits) do
    vim.lsp.util.apply_text_edits(v, k, "utf-16")
  end
end

---Changes the function signature using quickfix list to find other signatures
function M.change_function_via_qf()
  local list = vim.fn.getqflist({ idx = 0, items = true })
  local items = list.items
  local idx = list.idx
  local curr_entry = items[idx]

  local position = {}
  if
    config_manager.config.quickfix_source == "entry"
    or vim.bo.filetype == "qf"
  then
    position = {
      bufnr = curr_entry.bufnr,
      location = { curr_entry.lnum - 1, curr_entry.col - 1 },
    }
  else
    position = {
      bufnr = vim.api.nvim_get_current_buf(),
      location = {
        vim.api.nvim_win_get_cursor(0)[1] - 1,
        vim.api.nvim_win_get_cursor(0)[2],
      },
    }
  end

  local curr_node = ts.get_node({
    bufnr = position.bufnr,
    pos = position.location,
    lang = vim.bo[position.bufnr].filetype,
  })
  if curr_node ~= nil then
    local arguments =
      get_signature_info(curr_node, position.bufnr, position.location)
    if arguments == nil then
      return
    end

    local index = 0
    local lines = vim.tbl_map(function(i)
      index = index + 1
      return {
        line = i.text,
        id = index,
        is_deletion = false,
        is_addition = false,
      }
    end, arguments)

    ui.open_ui(
      lines,
      ts.get_node_text(curr_node, position.bufnr, {}),
      function(swapped_lines)
        local positions = vim
          .iter(items)
          :map(function(qf_entry)
            return {
              bufnr = qf_entry.bufnr,
              location = { qf_entry.lnum - 1, qf_entry.col - 1 },
            }
          end)
          :totable()

        update_at_positions(positions, swapped_lines)
      end
    )
  end
end

---Changes the function signature using lsp references to find other signatures
function M.change_function_via_lsp_references()
  local query_function = get_queries()

  local bufnr = api.nvim_get_current_buf()

  local method = "textDocument/references"
  local params = {
    textDocument = { uri = vim.uri_from_bufnr(bufnr) },
    position = convert_win_cursor_to_position(0),
    context = { includeDeclaration = true },
  }

  if query_function == nil then
    print_error("Could not find a query for this filetype")
    return
  end

  vim.lsp.buf_request_all(bufnr, method, params, function(results)
    for _, res in ipairs(results) do
      if res.error then
        print_error("An error occured while fetching references: " .. res.error)
        return
      end
    end

    local curr_node = ts.get_node()
    if curr_node == nil then
      return
    end

    local arguments = get_signature_info(curr_node, bufnr, {
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

    ui.open_ui(
      lines,
      ts.get_node_text(curr_node, bufnr, {}),
      function(swaped_lines)
        local positions = vim
          .iter(results)
          :map(function(res)
            return res.result
          end)
          :flatten()
          :map(function(location)
            return reference_position_to_position(location)
          end)
          :totable()

        update_at_positions(positions, swaped_lines)
      end
    )
  end)
end

---Change the function variable locations
function M.change_function()
  M.change_function_via_lsp_references()
end

---Setup this plugin for usage.
---@param opts? ChangeFunctionConfig
function M.setup(opts)
  config_manager.set_default(opts)
  ui.set_config(config_manager)
end

M.setup({})

return M
