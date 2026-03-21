local lang = require("bsv.lang")

local M = {}

---@class bsv.ParserState
---@field in_block_comment boolean
---@field in_string boolean

local function trim(text)
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

M.trim = trim

---@param line string
---@return string?
function M.first_keyword(line)
  return line:match("^%s*([%a][%w]*)")
end

---@return bsv.ParserState
function M.new_parser_state()
  return {
    in_block_comment = false,
    in_string = false,
  }
end

---@return table
function M.new_state()
  return {
    decl_stack = {},
    decl_meta_stack = {},
    header_stack = {},
    block_depth = 0,
    brace_depth = 0,
    continuation_depth = 0,
    parser_state = M.new_parser_state(),
  }
end

---@param line string
---@param parser_state bsv.ParserState
---@return string, bsv.ParserState
function M.strip_analysis_code(line, parser_state)
  local out = {}
  local i = 1
  local in_block_comment = parser_state.in_block_comment
  local in_string = parser_state.in_string

  while i <= #line do
    if in_string then
      local j = i
      while j <= #line do
        local str_ch = line:sub(j, j)
        if str_ch == "\\" then
          j = j + 2
        elseif str_ch == '"' then
          i = j + 1
          in_string = false
          break
        else
          j = j + 1
        end
      end
      if in_string then
        return table.concat(out), {
          in_block_comment = in_block_comment,
          in_string = true,
        }
      end
    elseif in_block_comment then
      local stop = line:find("*/", i, true)
      if stop then
        i = stop + 2
        in_block_comment = false
      else
        return table.concat(out), {
          in_block_comment = true,
          in_string = false,
        }
      end
    else
      local pair = line:sub(i, i + 1)
      local ch = line:sub(i, i)

      if pair == "//" then
        break
      elseif pair == "/*" then
        local stop = line:find("*/", i + 2, true)
        if stop then
          i = stop + 2
        else
          return table.concat(out), {
            in_block_comment = true,
            in_string = false,
          }
        end
      elseif ch == '"' then
        local j = i + 1
        while j <= #line do
          local str_ch = line:sub(j, j)
          if str_ch == "\\" then
            j = j + 2
          elseif str_ch == '"' then
            j = j + 1
            break
          else
            j = j + 1
          end
        end
        table.insert(out, '""')
        if j > #line and line:sub(#line, #line) ~= '"' then
          return table.concat(out), {
            in_block_comment = in_block_comment,
            in_string = true,
          }
        end
        i = j
      else
        table.insert(out, ch)
        i = i + 1
      end
    end
  end

  return table.concat(out), {
    in_block_comment = in_block_comment,
    in_string = in_string,
  }
end

local function paren_delta(code)
  local delta = 0
  for ch in code:gmatch(".") do
    if ch == "(" then
      delta = delta + 1
    elseif ch == ")" then
      delta = delta - 1
    end
  end
  return delta
end

local function continuation_delta(code)
  local delta = 0
  for ch in code:gmatch(".") do
    if ch == "(" or ch == "[" then
      delta = delta + 1
    elseif ch == ")" or ch == "]" then
      delta = delta - 1
    end
  end
  return delta
end

local function record_brace_delta(code)
  local delta = 0
  for ch in code:gmatch(".") do
    if ch == "{" then
      delta = delta + 1
    elseif ch == "}" then
      delta = delta - 1
    end
  end
  return delta
end

local function ternary_delta(code)
  local paren_depth = 0
  local bracket_depth = 0
  local brace_depth = 0
  local question_index
  local colon_index

  for i = 1, #code do
    local ch = code:sub(i, i)
    if ch == "(" then
      paren_depth = paren_depth + 1
    elseif ch == ")" then
      paren_depth = math.max(paren_depth - 1, 0)
    elseif ch == "[" then
      bracket_depth = bracket_depth + 1
    elseif ch == "]" then
      bracket_depth = math.max(bracket_depth - 1, 0)
    elseif ch == "{" then
      brace_depth = brace_depth + 1
    elseif ch == "}" then
      brace_depth = math.max(brace_depth - 1, 0)
    elseif paren_depth == 0 and bracket_depth == 0 and brace_depth == 0 then
      if ch == "?" and question_index == nil then
        question_index = i
      elseif ch == ":" and colon_index == nil then
        colon_index = i
      end
    end
  end

  if question_index ~= nil and (colon_index == nil or question_index < colon_index) and code:match("%?%s*$") then
    return 1
  end
  if colon_index ~= nil and (question_index == nil or colon_index < question_index) then
    return -1
  end
  return 0
end

local function is_brace_opener(line)
  return record_brace_delta(line) > 0
end

local function is_brace_closer(line)
  return line:match("^%s*}") ~= nil
end

local function is_block_opener(line)
  local keyword = M.first_keyword(line)
  if keyword ~= nil and lang.block_openers[keyword] == true then
    return true
  end

  for opener in pairs(lang.trailing_block_openers) do
    if line:match("%f[%a]" .. opener .. "%f[%W]%s*$")
      or line:match("%f[%a]" .. opener .. "%f[%W]%s*//")
    then
      return true
    end
  end

  return false
end

local function has_top_level_assignment(code)
  local paren_depth_local = 0
  local bracket_depth = 0
  local brace_depth = 0

  for i = 1, #code do
    local ch = code:sub(i, i)
    if ch == "(" then
      paren_depth_local = paren_depth_local + 1
    elseif ch == ")" then
      paren_depth_local = math.max(paren_depth_local - 1, 0)
    elseif ch == "[" then
      bracket_depth = bracket_depth + 1
    elseif ch == "]" then
      bracket_depth = math.max(bracket_depth - 1, 0)
    elseif ch == "{" then
      brace_depth = brace_depth + 1
    elseif ch == "}" then
      brace_depth = math.max(brace_depth - 1, 0)
    elseif ch == "=" and paren_depth_local == 0 and bracket_depth == 0 and brace_depth == 0 then
      local prev = i > 1 and code:sub(i - 1, i - 1) or ""
      local next_ch = i < #code and code:sub(i + 1, i + 1) or ""
      if prev ~= "<" and prev ~= ">" and prev ~= "!" and prev ~= "=" and next_ch ~= "=" then
        return true
      end
    end
  end

  return false
end

local function is_interface_impl_decl(code)
  if code:match("^%s*interface%f[%W]") == nil then
    return false
  end

  local body = code:match("^%s*interface%s+(.+)$")
  if body == nil then
    return false
  end

  body = body:gsub("%s*;%s*$", "")
  body = body:gsub("%f[%a]provisos%s*%b()", "")
  body = body:gsub("#%s*%b()", "")

  local ident_count = 0
  for _ in body:gmatch("[_%a][_%w']*") do
    ident_count = ident_count + 1
    if ident_count >= 2 then
      return true
    end
  end

  return false
end

---@param line string
---@param parser_state bsv.ParserState
---@return table, bsv.ParserState
function M.analyze_line(line, parser_state)
  local code
  code, parser_state = M.strip_analysis_code(line, parser_state)
  local keyword = M.first_keyword(code)
  local stripped_line = trim(line)

  return {
    code = code,
    keyword = keyword,
    blank = stripped_line == "",
    comment_only = stripped_line ~= "" and code:match("^%s*$") ~= nil,
    ends_with_semicolon = code:match(";%s*$") ~= nil,
    closes_decl = keyword ~= nil and lang.decl_closers[keyword] == true,
    closes_block = keyword ~= nil and lang.block_closers[keyword] == true,
    closes_brace = is_brace_closer(code),
    opens_block = is_block_opener(code),
    opens_brace = is_brace_opener(code),
    decl_kind = keyword ~= nil and lang.decl_openers[keyword] == true and keyword or nil,
    paren_delta = paren_delta(code),
    header_aligned = code:match("^%s*%)") ~= nil or code:match("^%s*provisos%s*%(") ~= nil,
    has_top_level_assignment = has_top_level_assignment(code),
    interface_impl_decl = is_interface_impl_decl(code),
    continuation_delta = continuation_delta(code),
    record_brace_delta = record_brace_delta(code),
    ternary_delta = ternary_delta(code),
    starts_with_closing_delim = code:match("^%s*[])}]") ~= nil,
  }, parser_state
end

function M.base_depth(state)
  return #state.decl_stack + state.block_depth + state.brace_depth
end

function M.is_scope_decl_line(state, info)
  if info.decl_kind == nil then
    return false
  end
  if not info.ends_with_semicolon or info.paren_delta > 0 then
    return true
  end
  if info.has_top_level_assignment then
    return false
  end

  if info.decl_kind == "method" then
    local parent_decl = state.decl_stack[#state.decl_stack]
    if parent_decl == "typeclass" then
      return false
    end
    if parent_decl == "interface" then
      local parent_meta = state.decl_meta_stack[#state.decl_meta_stack]
      if type(parent_meta) ~= "table" or not parent_meta.allows_method_scope then
        return false
      end
    end
  end

  return true
end

local function push_decl(state, kind, info)
  local meta = false
  if kind == "interface" then
    meta = {
      allows_method_scope = info.interface_impl_decl == true,
    }
  end
  table.insert(state.decl_stack, kind)
  table.insert(state.decl_meta_stack, meta)
end

local function pop_decl(state)
  if #state.decl_stack > 0 then
    table.remove(state.decl_stack)
    table.remove(state.decl_meta_stack)
  end
end

function M.indent_depth_for_line(state, info)
  local depth = M.base_depth(state)

  if info.closes_decl then
    depth = depth - 1
  end
  if info.closes_block then
    depth = depth - 1
  end
  if info.closes_brace then
    depth = depth - 1
  end

  local header = state.header_stack[#state.header_stack]
  if header then
    local closes_header = header.paren_depth + info.paren_delta <= 0 and info.ends_with_semicolon
    if closes_header or info.header_aligned then
      depth = header.base_depth
    else
      depth = header.base_depth + 1
    end
  end

  return math.max(depth, 0)
end

function M.advance_state(state, info)
  if info.closes_decl then
    pop_decl(state)
  end
  if info.closes_block and state.block_depth > 0 then
    state.block_depth = state.block_depth - 1
  end
  if info.closes_brace and state.brace_depth > 0 then
    state.brace_depth = state.brace_depth - 1
  end

  local header = state.header_stack[#state.header_stack]
  if header then
    header.code = header.code .. " " .. info.code
    header.paren_depth = header.paren_depth + info.paren_delta
    if header.paren_depth <= 0 and info.ends_with_semicolon then
      table.remove(state.header_stack)
      local header_info = {
        decl_kind = header.kind,
        ends_with_semicolon = true,
        paren_delta = 0,
        has_top_level_assignment = header.has_top_level_assignment,
        interface_impl_decl = header.kind == "interface" and is_interface_impl_decl(header.code),
      }
      if M.is_scope_decl_line(state, header_info) then
        push_decl(state, header.kind, header_info)
      end
    end
  elseif info.decl_kind ~= nil then
    if info.ends_with_semicolon and info.paren_delta <= 0 and M.is_scope_decl_line(state, info) then
      push_decl(state, info.decl_kind, info)
    elseif not (info.ends_with_semicolon and info.paren_delta <= 0) then
      table.insert(state.header_stack, {
        kind = info.decl_kind,
        base_depth = M.base_depth(state),
        paren_depth = math.max(info.paren_delta, 0),
        has_top_level_assignment = info.has_top_level_assignment,
        code = info.code,
      })
    end
  end

  if info.opens_block then
    state.block_depth = state.block_depth + 1
  end
  if info.opens_brace then
    state.brace_depth = state.brace_depth + 1
  end
end

function M.indent_columns_for_line(state, info, sw)
  local indent = M.indent_depth_for_line(state, info) * sw
  if state.continuation_depth > 0
    and not info.starts_with_closing_delim
    and not info.closes_decl
    and not info.closes_block
    and not info.closes_brace
  then
    indent = indent + sw
  end
  return indent
end

function M.advance_continuation(state, info)
  state.continuation_depth = math.max(
    state.continuation_depth + info.continuation_delta + info.record_brace_delta + (info.ternary_delta or 0)
      - (info.opens_brace and 1 or 0)
      + (info.closes_brace and 1 or 0),
    0
  )
end

function M.reindent_lines(lines, sw)
  local out = {}
  local state = M.new_state()

  for i, line in ipairs(lines) do
    local info
    info, state.parser_state = M.analyze_line(line, state.parser_state)

    if line:match("^%s*$") then
      out[i] = ""
    else
      local indent = M.indent_columns_for_line(state, info, sw)
      out[i] = string.rep(" ", indent) .. line:match("^%s*(.*)$")
    end

    M.advance_state(state, info)
    M.advance_continuation(state, info)
  end

  return out
end

function M.compute_indent(lnum, sw, getline)
  if lnum <= 1 then
    return 0
  end

  local state = M.new_state()
  for cur_lnum = 1, lnum do
    local info
    info, state.parser_state = M.analyze_line(getline(cur_lnum), state.parser_state)
    if cur_lnum == lnum then
      return M.indent_columns_for_line(state, info, sw)
    end
    M.advance_state(state, info)
    M.advance_continuation(state, info)
  end

  return 0
end

return M
