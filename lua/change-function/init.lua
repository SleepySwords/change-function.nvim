---@class TextRange
---@field start {line: integer, character: integer}
---@field end {line: integer, character: integer}

---@class Text
---@field text string
---@field range TextRange

---@class Position
---@field bufnr integer
---@field location integer[]

---@class Change Note: the `Change[]` indicates the order of the NEW arguments,
---wheras the id provides the arguments of the OLD list
---@field display_line string The contents of this particular argument
---@field default_call string? If this is an addition, what should the default call value be called
---@field declaration string? If this is an addition, what should the declaration be called
---@field id string The index of this particular argument in all the arguments (before swapping)
---@field flag integer

local ui = require("change-function.ui")
local config_manager = require("change-function.config")
local api = vim.api
local ts = vim.treesitter

local utils = require("change-function.utils")
local reference_position_to_position = utils.reference_position_to_position
local inside_range = utils.inside_range
local range_text = utils.range_text
local convert_win_cursor_to_position = utils.convert_win_cursor_to_position

local ChangeFlag = utils.ChangeFlag

local M = {}

IDENTIFYING_CAPTURES = { ["function_name"] = true, ["method_name"] = true }
ARGUMENT_CAPTURES = { ["parameter.inner"] = true, ["argument.inner"] = true }

PARAMETER_INITAL_INSERTION = "parameter.initial_insertion"

---Gets the current query from the
---@param bufnr? integer The buffer to get the query from
---@return (vim.treesitter.Query)?
local function get_queries(bufnr)
  bufnr = bufnr or 0

  local config = config_manager.config.languages[vim.bo[bufnr].filetype]

  local query
  if type(config) == "table" then
    query = config.query_file
  elseif type(config) == "string" then
    query = config
  end

  return ts.query.get(vim.bo[bufnr].filetype, query or "textobjects")
end

---Gets the current query from the
---@param bufnr? integer The buffer to get the query from
---@return string?
local function get_argument_seperator(bufnr)
  bufnr = bufnr or 0

  local config = config_manager.config.languages[vim.bo[bufnr].filetype]

  if type(config) == "table" then
    return config.argument_seperator
  elseif type(config) == "string" then
    return
  end
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

---@class SignatureInfo
---@field arguments {range: TextRange, text: string}[] The arguments and the text of those arguments
---@field insertion_point? {line: integer, character: integer} The place to insert the first argument (if it exists).
---@field is_call boolean Whether or not this signature is a function call or a function signature

---Get the parameters/arguments from the function signature.
---@param node TSNode The node of the function signature
---@param bufnr integer The buffer number of the buffer where the node resides.
---@param position integer[] The cursor of the expected function signature
---@return SignatureInfo? info The range of the arguments in the signature + the text it contains.
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
  local first_argument = nil
  -- NOTE: Maybe figure out a better way to find the order rather than comparing lines ranges
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

        if ARGUMENT_CAPTURES[capture_name] ~= nil then
          table.insert(arguments, {
            range = range,
            text = text,
          })
        end
        if capture_name == "parameter.inner.ignore" then
          table.insert(ignore, range)
        end

        if capture_name == PARAMETER_INITAL_INSERTION then
          first_argument = range.start
        end
      end
    end
  end

  for _, v in ipairs(ignore) do
    arguments = vim.tbl_filter(function(i)
      return not vim.deep_equal(i.range, v)
    end, arguments)
  end

  table.sort(arguments, function(a, b)
    if a.range.start.line == b.range.start.line then
      return a.range.start.character < b.range.start.character
    else
      return a.range.start.line < b.range.start.line
    end
  end)

  return {
    arguments = arguments,
    is_call = is_call,
    insertion_point = first_argument,
  }
end

---Get the text edits that need to be done to change an argument
---@param position Position position of where the change should be done
---@param changes Change[] The swaps that are required to change
---@return {newText: string, range: TextRange}[]?
local function get_text_edits(position, changes)
  vim.fn.bufload(position.bufnr)

  local pos = position.location
  vim.treesitter.get_parser(position.bufnr):parse()
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

  local signature_info = get_signature_info(matched_node, position.bufnr, pos)
  if signature_info == nil then
    return
  end

  local args = signature_info.arguments

  -- NOTE: All the existing function argument ranges so they can be used to swap
  -- and we do not have to rebuild the entire argument ranges.
  local existing_ranges = vim.tbl_map(function(arg)
    return arg.range
  end, args)

  -- NOTE: `change.id <= #args` is to check if the deleted argument is in this signature,
  -- if not we cannot count it.
  local num_deletions = #vim.tbl_filter(function(change)
    return change.flag == ChangeFlag.DELETION and change.id <= #args
  end, changes)

  local num_additions = #vim.tbl_filter(function(e)
    return e.flag == ChangeFlag.ADDITION
  end, changes)

  local argument_difference = num_additions - num_deletions

  local args_length = #args + argument_difference

  local current_arg = 1

  local function get_text(index)
    local v = changes[index]

    if v ~= nil then
      if v.flag ~= ChangeFlag.NORMAL or i ~= v.id then
        if v.flag == ChangeFlag.NORMAL and #args < v.id then
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
        if v.flag == ChangeFlag.ADDITION then
          if signature_info.is_call then
            text = v.default_call or v.display_line
          else
            text = v.declaration or v.display_line
          end
        else
          text = args[v.id].text
        end
        return text
      end
    else
      if num_deletions > 0 or num_additions > 0 then
        -- NOTE: the current_arg is only changed by the num_additions,
        -- num_deletions does not change the pointer of the current_arg
        -- (as it previously existed in the signature)
        return args[index - num_additions].text
      end
    end
  end

  local text_edits = {}
  for i, a in ipairs(existing_ranges) do
    -- NOTE: Don't include textedits that do not change anything.
    if i > args_length then
      break
    end

    while
      current_arg <= #changes
      and changes[current_arg].flag == ChangeFlag.DELETION
    do
      current_arg = current_arg + 1
    end

    local text = get_text(current_arg)
    if text ~= nil then
      table.insert(text_edits, {
        newText = text,
        range = a,
      })
    else
      return
    end

    current_arg = current_arg + 1
  end

  if argument_difference == 0 then
    return text_edits
  end

  if argument_difference < 0 then
    local deletion_range = (-argument_difference >= #args)
        and {
          start = args[1].range["start"],
          ["end"] = args[#args].range["end"],
        }
      or {
        start = args[#args + argument_difference].range["end"],
        ["end"] = args[#args].range["end"],
      }

    table.insert(text_edits, {
      newText = "",
      range = deletion_range,
    })
  end

  if argument_difference > 0 then
    local addition = ""
    local argument_seperator = get_argument_seperator(position.bufnr)
    if argument_seperator == nil then
      print_error(
        string.format(
          "Cannot add an argument as there is no argument seperator for the language %s",
          vim.bo[position.bufnr].filetype
        )
      )
      return
    end

    for i = 1, argument_difference do
      local text = get_text(current_arg + i - 1)
      if text == nil then
        return
      end
      addition = addition .. argument_seperator .. text
    end

    local range
    if #args == 0 then
      addition = addition:sub(#argument_seperator + 1)
      if signature_info.insertion_point == nil then
        print_error(
          "The place for the first argument cannot be found, ensure the `"
            .. PARAMETER_INITAL_INSERTION
            .. "` capture has been set."
        )
        return
      end
      range = {
        start = signature_info.insertion_point,
        ["end"] = signature_info.insertion_point,
      }
    else
      range = {
        start = args[#args].range["end"],
        ["end"] = args[#args].range["end"],
      }
    end
    table.insert(text_edits, {
      newText = addition,
      range = range,
    })
  end

  return text_edits
end

--- Updates the function declaration and calls at the position by applying text edits
--- according to the changes
--- @param positions Position[]
--- @param changes Change[]
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

local function change_function_internal(bufnr, location, positions)
  local node = ts.get_node({
    bufnr = bufnr,
    pos = location,
    lang = vim.bo[bufnr].filetype,
  })
  if node == nil then
    return
  end

  local signature_info = get_signature_info(node, bufnr, location)
  if signature_info == nil then
    return
  end

  local arguments = signature_info.arguments

  local index = 0
  local lines = vim.tbl_map(function(i)
    index = index + 1
    return {
      display_line = i.text,
      id = index,
      flag = ChangeFlag.NORMAL,
    }
  end, arguments)

  ui.open_ui(
    lines,
    ts.get_node_text(node, bufnr, {}),
    vim.o.filetype,
    function(swapped_lines)
      update_at_positions(positions, swapped_lines)
    end
  )
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

  local positions = vim
    .iter(items)
    :map(function(qf_entry)
      return {
        bufnr = qf_entry.bufnr,
        location = { qf_entry.lnum - 1, qf_entry.col - 1 },
      }
    end)
    :totable()

  change_function_internal(position.bufnr, position.location, positions)
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

    local cursor_pos = {
      vim.api.nvim_win_get_cursor(0)[1] - 1,
      vim.api.nvim_win_get_cursor(0)[2],
    }

    change_function_internal(bufnr, cursor_pos, positions)
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
