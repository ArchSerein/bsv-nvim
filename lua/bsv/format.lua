-- lua/bsv/format.lua
-- Lightweight formatting helpers for Bluespec SystemVerilog (BSV).
-- Goals:
-- 1) Prefer LSP formatting when available.
-- 2) Provide a safe fallback style pass so `Format` works even without an LSP.
-- 3) Register a Conform formatter for LazyVim users if conform.nvim is installed.

local M = {}
local max_columns = 80

-- Indentation heuristics shared with indent/bsv.lua
local decl_openers = {
  package = true,
  module = true,
  interface = true,
  ["function"] = true,
  typeclass = true,
  instance = true,
  method = true,
  action = true,
  actionvalue = true,
  rule = true,
}

local decl_closers = {
  endpackage = true,
  endmodule = true,
  endinterface = true,
  endfunction = true,
  endtypeclass = true,
  endinstance = true,
  endmethod = true,
  endaction = true,
  endactionvalue = true,
  endrule = true,
}

local block_openers = {
  begin = true,
  action = true,
  actionvalue = true,
  seq = true,
  par = true,
  case = true,
  rules = true,
}

local block_closers = {
  ["end"] = true,
  endaction = true,
  endactionvalue = true,
  endseq = true,
  endpar = true,
  endcase = true,
  endrules = true,
}

local trailing_block_openers = {
  begin = true,
  action = true,
  actionvalue = true,
  seq = true,
  par = true,
}

local control_keywords = {
  ["if"] = true,
  ["for"] = true,
  ["while"] = true,
  ["case"] = true,
}

local paren_keywords = {
  ["if"] = true,
  ["for"] = true,
  ["while"] = true,
  ["case"] = true,
}

local protected_ops = {
  ["<-"] = "\1",
  ["<="] = "\2",
  [">="] = "\3",
  ["=="] = "\4",
  ["!="] = "\5",
  ["&&"] = "\6",
  ["||"] = "\7",
  ["<<"] = "\8",
  [">>"] = "\9",
}

local spaced_single_char_ops = {
  "+",
  "*",
  "/",
  "%",
  "<",
  ">",
}

local wrapped_header_keywords = {
  module = true,
  interface = true,
}

local blocked_wrap_continuations = {
  begin = true,
  action = true,
  actionvalue = true,
  seq = true,
  par = true,
  matches = true,
}

---@param text string
---@return string
local function escape_lua_pattern(text)
  return (text:gsub("([^%w])", "%%%1"))
end

---@param text string
---@return string
local function trim(text)
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

---@param line string
---@return string?
local function first_keyword(line)
  return line:match("^%s*([%a][%w]*)")
end

---@param line string
---@return boolean
local function is_decl_opener(line)
  local keyword = first_keyword(line)
  return keyword ~= nil and decl_openers[keyword] == true and line:match("[=;]%s*$") ~= nil
end

---@param line string
---@return boolean
local function is_decl_closer(line)
  local keyword = first_keyword(line)
  return keyword ~= nil and decl_closers[keyword] == true
end

---@param line string
---@return boolean
local function is_block_opener(line)
  local keyword = first_keyword(line)
  if keyword ~= nil and block_openers[keyword] == true then
    return true
  end

  for opener in pairs(trailing_block_openers) do
    if line:match("%f[%a]" .. opener .. "%f[%W]%s*$")
      or line:match("%f[%a]" .. opener .. "%f[%W]%s*//")
    then
      return true
    end
  end

  return false
end

---@param line string
---@return boolean
local function is_block_closer(line)
  local keyword = first_keyword(line)
  return keyword ~= nil and block_closers[keyword] == true
end

---@param line string
---@return boolean
local function is_brace_opener(line)
  return line:match("^%s*typedef%s+struct%s*{[^}]*$") ~= nil
    or line:match("^%s*typedef%s+enum%s*{[^}]*$") ~= nil
    or line:match("^%s*typedef%s+union%s+tagged%s*{[^}]*$") ~= nil
end

---@param line string
---@return boolean
local function is_brace_closer(line)
  return line:match("^%s*}") ~= nil
end

---@class bsv.ParserState
---@field in_block_comment boolean
---@field in_string boolean

---@param line string
---@param parser_state bsv.ParserState
---@return string, bsv.ParserState
local function strip_analysis_code(line, parser_state)
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
        elseif str_ch == "\"" then
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
      elseif ch == "\"" then
        local j = i + 1
        while j <= #line do
          local str_ch = line:sub(j, j)
          if str_ch == "\\" then
            j = j + 2
          elseif str_ch == "\"" then
            j = j + 1
            break
          else
            j = j + 1
          end
        end
        table.insert(out, "\"\"")
        if j > #line and line:sub(#line, #line) ~= "\"" then
          in_string = true
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

---@param line string
---@return integer
local function paren_delta(line)
  local delta = 0
  for ch in line:gmatch(".") do
    if ch == "(" then
      delta = delta + 1
    elseif ch == ")" then
      delta = delta - 1
    end
  end
  return delta
end

---@param code string
---@return integer
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

---@param code string
---@return integer
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

---@param code string
---@return boolean
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

---@param line string
---@param parser_state bsv.ParserState
---@return table, bsv.ParserState
local function analyze_line(line, parser_state)
  local code
  code, parser_state = strip_analysis_code(line, parser_state)
  local keyword = first_keyword(code)
  return {
    code = code,
    keyword = keyword,
    blank = code:match("^%s*$") ~= nil,
    ends_with_semicolon = code:match(";%s*$") ~= nil,
    closes_decl = keyword ~= nil and decl_closers[keyword] == true,
    closes_block = keyword ~= nil and block_closers[keyword] == true,
    closes_brace = is_brace_closer(code),
    opens_block = is_block_opener(code),
    opens_brace = is_brace_opener(code),
    decl_kind = keyword ~= nil and decl_openers[keyword] == true and keyword or nil,
    paren_delta = paren_delta(code),
    header_aligned = code:match("^%s*%)") ~= nil or code:match("^%s*provisos%s*%(") ~= nil,
    has_top_level_assignment = has_top_level_assignment(code),
    continuation_delta = continuation_delta(code),
    record_brace_delta = record_brace_delta(code),
    starts_with_closing_delim = code:match("^%s*[])}]") ~= nil,
  }, parser_state
end

---@param state table
---@param info table
---@return boolean
local function is_scope_decl_line(state, info)
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
    if parent_decl == "interface" or parent_decl == "typeclass" then
      return false
    end
  end

  return true
end

---@param state table
---@return integer
local function base_depth(state)
  return #state.decl_stack + state.block_depth + state.brace_depth
end

---@param state table
---@param info table
---@return integer
local function indent_depth_for_line(state, info)
  local depth = base_depth(state)

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
    if closes_header then
      depth = header.base_depth
    elseif info.header_aligned then
      depth = header.base_depth
    else
      depth = header.base_depth + 1
    end
  end

  return math.max(depth, 0)
end

---@param state table
---@param info table
local function advance_indent_state(state, info)
  if info.closes_decl and #state.decl_stack > 0 then
    table.remove(state.decl_stack)
  end
  if info.closes_block and state.block_depth > 0 then
    state.block_depth = state.block_depth - 1
  end
  if info.closes_brace and state.brace_depth > 0 then
    state.brace_depth = state.brace_depth - 1
  end

  local header = state.header_stack[#state.header_stack]
  if header then
    header.paren_depth = header.paren_depth + info.paren_delta
    if header.paren_depth <= 0 and info.ends_with_semicolon then
      table.remove(state.header_stack)
      local header_info = {
        decl_kind = header.kind,
        ends_with_semicolon = true,
        paren_delta = 0,
        has_top_level_assignment = header.has_top_level_assignment,
      }
      if is_scope_decl_line(state, header_info) then
        table.insert(state.decl_stack, header.kind)
      end
    end
  elseif info.decl_kind ~= nil then
    if info.ends_with_semicolon and info.paren_delta <= 0 and is_scope_decl_line(state, info) then
      table.insert(state.decl_stack, info.decl_kind)
    elseif not (info.ends_with_semicolon and info.paren_delta <= 0) then
      table.insert(state.header_stack, {
        kind = info.decl_kind,
        base_depth = base_depth(state),
        paren_depth = math.max(info.paren_delta, 0),
        has_top_level_assignment = info.has_top_level_assignment,
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

---@param code string
---@param sw integer
---@return string
local function normalize_code_chunk(code, sw)
  if code == "" then
    return code
  end

  local leading_keyword = first_keyword(code)
  code = code:gsub("\t", string.rep(" ", sw))
  code = code:gsub("%s+([,;%)%]}])", "%1")
  code = code:gsub("%s*,%s*", ", ")
  code = code:gsub(";%s*(%S)", "; %1")

  for keyword in pairs(control_keywords) do
    code = code:gsub("(%f[%a]" .. keyword .. ")%s*%(", "%1 (")
  end

  for _, keyword in ipairs({ "begin", "action", "actionvalue", "seq", "par" }) do
    code = code:gsub("%)%s*" .. keyword .. "%f[%W]", ") " .. keyword)
    code = code:gsub("(%f[%a]else)%s*" .. keyword .. "%f[%W]", "%1 " .. keyword)
  end
  code = code:gsub("%)%s*if%s*%(", ") if (")
  code = code:gsub("(%f[%a]rule%s+[%a_][%w_']*)%s*%(", "%1 (")
  code = code:gsub("(%f[%a]case%s*%b())%s*matches%f[%W]", "%1 matches")
  code = code:gsub("(%f[%a]provisos)%s*%(", "%1(")

  code = code:gsub("([%a_][%w_']*)%s+%(", function(word)
    if paren_keywords[word] then
      return word .. " ("
    end
    return word .. "("
  end)
  code = code:gsub("(%f[%a]rule%s+[%a_][%w_']*)%(", "%1 (")
  code = code:gsub("%(%s+", "(")
  code = code:gsub("%s+%)", ")")

  for op, token in pairs(protected_ops) do
    code = code:gsub("%s*" .. escape_lua_pattern(op) .. "%s*", " " .. token .. " ")
  end

  code = code:gsub("%s*=%s*", " = ")

  if leading_keyword ~= "import" then
    for _, op in ipairs(spaced_single_char_ops) do
      code = code:gsub("%s*" .. escape_lua_pattern(op) .. "%s*", function()
        return " " .. op .. " "
      end)
    end
  end

  for op, token in pairs(protected_ops) do
    code = code:gsub(token, op)
  end
  code = code:gsub("%s*::%s*", "::")

  if leading_keyword ~= "import" and leading_keyword ~= "export" then
    local colon_index
    do
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
        elseif ch == ":" and paren_depth_local == 0 and bracket_depth == 0 and brace_depth == 0 then
          local prefix = trim(code:sub(1, i - 1))
          if prefix ~= "" and not prefix:find("?", 1, true) then
            colon_index = i
          end
          break
        end
      end
    end

    if colon_index ~= nil then
      local left = trim(code:sub(1, colon_index - 1))
      local right = trim(code:sub(colon_index + 1))
      code = left .. ":"
      if right ~= "" then
        code = code .. " " .. right
      end
    end
  end

  return code
end

---@param text string
---@return integer?
local function find_matching_paren(text, open_index)
  local depth = 0
  local i = open_index
  while i <= #text do
    local ch = text:sub(i, i)
    if ch == "\"" then
      i = i + 1
      while i <= #text do
        local str_ch = text:sub(i, i)
        if str_ch == "\\" then
          i = i + 2
        elseif str_ch == "\"" then
          break
        else
          i = i + 1
        end
      end
    elseif ch == "(" then
      depth = depth + 1
    elseif ch == ")" then
      depth = depth - 1
      if depth == 0 then
        return i
      end
    end
    i = i + 1
  end
end

---@param text string
---@return string[]
local function split_top_level_csv(text)
  local items = {}
  local start_index = 1
  local paren_depth_local = 0
  local bracket_depth = 0
  local brace_depth = 0
  local i = 1

  while i <= #text do
    local ch = text:sub(i, i)
    if ch == "\"" then
      i = i + 1
      while i <= #text do
        local str_ch = text:sub(i, i)
        if str_ch == "\\" then
          i = i + 2
        elseif str_ch == "\"" then
          break
        else
          i = i + 1
        end
      end
    elseif ch == "(" then
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
    elseif ch == "," and paren_depth_local == 0 and bracket_depth == 0 and brace_depth == 0 then
      table.insert(items, trim(text:sub(start_index, i - 1)))
      start_index = i + 1
    end
    i = i + 1
  end

  local tail = trim(text:sub(start_index))
  if tail ~= "" then
    table.insert(items, tail)
  end
  return items
end

---@param text string
---@param keyword string
---@return integer?
local function find_top_level_keyword(text, keyword)
  local paren_depth_local = 0
  local bracket_depth = 0
  local brace_depth = 0
  local i = 1

  while i <= #text do
    local ch = text:sub(i, i)
    if ch == "\"" then
      i = i + 1
      while i <= #text do
        local str_ch = text:sub(i, i)
        if str_ch == "\\" then
          i = i + 2
        elseif str_ch == "\"" then
          break
        else
          i = i + 1
        end
      end
    elseif ch == "(" then
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
    elseif paren_depth_local == 0 and bracket_depth == 0 and brace_depth == 0 then
      local slice = text:sub(i)
      local start_pos, end_pos = slice:find("^" .. keyword .. "%f[%W]")
      if start_pos ~= nil then
        return i + start_pos - 1
      end
    end
    i = i + 1
  end
end

---@param text string
---@return table?, string?
local function parse_header_segments(text)
  local segments = {}
  local cursor = 1
  local i = 1

  while i <= #text do
    local hash_open = text:sub(i, i + 1) == "#("
    local open_index = nil
    local open_token = nil

    if hash_open then
      open_index = i + 1
      open_token = "#("
    elseif text:sub(i, i) == "(" then
      open_index = i
      open_token = "("
    end

    if open_index ~= nil then
      local close_index = find_matching_paren(text, open_index)
      if close_index == nil then
        return nil, nil
      end

      table.insert(segments, {
        prefix = trim(text:sub(cursor, i - 1)),
        open_token = open_token,
        inner = trim(text:sub(open_index + 1, close_index - 1)),
      })

      cursor = close_index + 1
      i = close_index
    end

    i = i + 1
  end

  if #segments == 0 then
    return nil, nil
  end

  return segments, trim(text:sub(cursor))
end

---@param indent string
---@param inner string
---@param sw integer
---@return string[]
local function wrap_csv_body(indent, inner, sw)
  local out = {}
  local items = split_top_level_csv(inner)
  if #items == 0 and inner ~= "" then
    items = { trim(inner) }
  end

  for index, item in ipairs(items) do
    local suffix = index < #items and "," or ""
    table.insert(out, indent .. string.rep(" ", sw) .. item .. suffix)
  end

  return out
end

---@param line string
---@param sw integer
---@return string[]?
local function wrap_module_or_interface_header(line, sw)
  if line:find("//", 1, true) ~= nil then
    return nil
  end

  local indent, stripped = line:match("^(%s*)(.-)%s*$")
  local keyword = first_keyword(stripped)
  if keyword == nil or not wrapped_header_keywords[keyword] or #stripped <= max_columns then
    return nil
  end
  if not stripped:match(";%s*$") then
    return nil
  end

  local header = trim(stripped:sub(1, -2))
  local provisos_inner
  local provisos_at = find_top_level_keyword(header, "provisos")
  if provisos_at ~= nil then
    local open_index = header:find("(", provisos_at, true)
    if open_index == nil then
      return nil
    end
    local close_index = find_matching_paren(header, open_index)
    if close_index == nil or trim(header:sub(close_index + 1)) ~= "" then
      return nil
    end
    provisos_inner = trim(header:sub(open_index + 1, close_index - 1))
    header = trim(header:sub(1, provisos_at - 1))
  end

  local segments, tail = parse_header_segments(header)
  if segments == nil or tail ~= "" then
    return nil
  end

  local out = {}
  table.insert(out, indent .. segments[1].prefix .. segments[1].open_token)
  vim.list_extend(out, wrap_csv_body(indent, segments[1].inner, sw))

  for index = 2, #segments do
    table.insert(out, indent .. ")" .. segments[index].prefix .. segments[index].open_token)
    vim.list_extend(out, wrap_csv_body(indent, segments[index].inner, sw))
  end

  if provisos_inner ~= nil then
    table.insert(out, indent .. ")")
    table.insert(out, indent .. "provisos(")
    vim.list_extend(out, wrap_csv_body(indent, provisos_inner, sw))
    table.insert(out, indent .. ");")
  else
    table.insert(out, indent .. ");")
  end

  return out
end

---@param lines string[]
---@param sw integer
---@return string[]
local function wrap_long_lines(lines, sw)
  local out = {}
  for _, line in ipairs(lines) do
    local wrapped = wrap_module_or_interface_header(line, sw)
    if wrapped ~= nil then
      vim.list_extend(out, wrapped)
    else
      table.insert(out, line)
    end
  end
  return out
end

---@param line string
---@param sw integer
---@param parser_state bsv.ParserState
---@return string, bsv.ParserState
local function normalize_line(line, sw, parser_state)
  if line:match("^%s*$") then
    return "", parser_state
  end

  local out = {}
  local i = 1
  local inline_comment
  local in_block_comment = parser_state.in_block_comment
  local in_string = parser_state.in_string

  while i <= #line do
    if in_string then
      local j = i
      while j <= #line do
        local str_ch = line:sub(j, j)
        if str_ch == "\\" then
          j = j + 2
        elseif str_ch == "\"" then
          table.insert(out, line:sub(i, j))
          i = j + 1
          in_string = false
          break
        else
          j = j + 1
        end
      end
      if in_string then
        table.insert(out, line:sub(i))
        return table.concat(out), {
          in_block_comment = in_block_comment,
          in_string = true,
        }
      end
    elseif in_block_comment then
      local stop = line:find("*/", i, true)
      if stop then
        table.insert(out, line:sub(i, stop + 1))
        i = stop + 2
        in_block_comment = false
      else
        table.insert(out, line:sub(i))
        return table.concat(out), {
          in_block_comment = true,
          in_string = false,
        }
      end
    else
      local pair = line:sub(i, i + 1)
      local ch = line:sub(i, i)

      if pair == "//" then
        inline_comment = line:sub(i)
        break
      elseif pair == "/*" then
        local stop = line:find("*/", i + 2, true)
        if stop then
          table.insert(out, line:sub(i, stop + 1))
          i = stop + 2
        else
          table.insert(out, line:sub(i))
          return table.concat(out), {
            in_block_comment = true,
            in_string = false,
          }
        end
      elseif ch == "\"" then
        local j = i + 1
        while j <= #line do
          local str_ch = line:sub(j, j)
          if str_ch == "\\" then
            j = j + 2
          elseif str_ch == "\"" then
            j = j + 1
            break
          else
            j = j + 1
          end
        end
        if j <= #line and line:sub(j - 1, j - 1) == "\"" then
          table.insert(out, line:sub(i, math.min(j - 1, #line)))
          i = j
        else
          table.insert(out, line:sub(i))
          return table.concat(out), {
            in_block_comment = in_block_comment,
            in_string = true,
          }
        end
      else
        local j = i
        while j <= #line do
          local next_pair = line:sub(j, j + 1)
          local next_ch = line:sub(j, j)
          if next_pair == "//" or next_pair == "/*" or next_ch == "\"" then
            break
          end
          j = j + 1
        end
        table.insert(out, normalize_code_chunk(line:sub(i, j - 1), sw))
        i = j
      end
    end
  end

  local formatted = table.concat(out):gsub("%s+$", "")
  if inline_comment then
    inline_comment = inline_comment:gsub("^//%s*", "// ")
    if formatted:match("%S") then
      formatted = formatted .. " " .. inline_comment
    else
      formatted = inline_comment
    end
  end

  return formatted, {
    in_block_comment = in_block_comment,
    in_string = in_string,
  }
end

---@param lines string[]
---@param sw integer
---@return string[]
local function normalize_lines(lines, sw)
  local out = {}
  local parser_state = {
    in_block_comment = false,
    in_string = false,
  }
  for i, line in ipairs(lines) do
    out[i], parser_state = normalize_line(line, sw, parser_state)
  end
  return out
end

---@param state table
---@param info table
---@return boolean
local function line_opens_scope(state, info)
  local header = state.header_stack[#state.header_stack]
  if header then
    if header.paren_depth + info.paren_delta <= 0 and info.ends_with_semicolon then
      local header_info = {
        decl_kind = header.kind,
        ends_with_semicolon = true,
        paren_delta = 0,
        has_top_level_assignment = header.has_top_level_assignment,
      }
      return is_scope_decl_line(state, header_info)
    end
    return false
  end
  if info.decl_kind ~= nil and info.ends_with_semicolon and info.paren_delta <= 0 then
    return is_scope_decl_line(state, info)
  end
  if info.decl_kind ~= nil and not info.ends_with_semicolon then
    return true
  end
  return info.opens_block or info.opens_brace
end

---@param state table
---@param info table
---@return boolean
local function is_top_level_function_open(state, info)
  return info.decl_kind == "function"
    and is_scope_decl_line(state, info)
    and base_depth(state) == 0
    and #state.header_stack == 0
end

---@param state table
---@param info table
---@return boolean
local function is_top_level_function_close(state, info)
  return info.keyword == "endfunction"
    and #state.decl_stack == 1
    and state.decl_stack[#state.decl_stack] == "function"
    and state.block_depth == 0
    and state.brace_depth == 0
    and #state.header_stack == 0
end

---@param lines string[]
---@return string[]
local function normalize_blank_lines(lines)
  local out = {}
  local state = {
    decl_stack = {},
    header_stack = {},
    block_depth = 0,
    brace_depth = 0,
    parser_state = {
      in_block_comment = false,
      in_string = false,
    },
  }
  local pending_blank = false
  local prev_nonblank_meta

  for _, line in ipairs(lines) do
    local info
    info, state.parser_state = analyze_line(line, state.parser_state)

    if info.blank then
      pending_blank = prev_nonblank_meta ~= nil
    else
      local current_meta = {
        closes_scope_line = info.closes_decl or info.closes_block or info.closes_brace,
        opens_scope_line = line_opens_scope(state, info),
        top_level_function_open = is_top_level_function_open(state, info),
        top_level_function_close = is_top_level_function_close(state, info),
      }

      local want_function_spacing = prev_nonblank_meta ~= nil
        and prev_nonblank_meta.top_level_function_close
        and current_meta.top_level_function_open

      if pending_blank then
        local keep_blank = want_function_spacing
          or (
            prev_nonblank_meta ~= nil
            and not prev_nonblank_meta.opens_scope_line
            and not current_meta.closes_scope_line
          )
        if keep_blank then
          table.insert(out, "")
        end
        pending_blank = false
      elseif want_function_spacing then
        table.insert(out, "")
      end

      table.insert(out, line)
      advance_indent_state(state, info)
      prev_nonblank_meta = current_meta
    end
  end

  while #out > 0 and out[#out] == "" do
    table.remove(out)
  end

  return out
end

---@param lines string[]
---@return string[]
local function normalize_layout_spacing(lines)
  local out = {}
  local prev_nonblank

  for _, line in ipairs(lines) do
    local stripped = trim(line)
    if stripped == "" then
      table.insert(out, line)
    else
      if #out > 0 and out[#out] ~= "" and prev_nonblank ~= nil then
        local prev_keyword = first_keyword(prev_nonblank)
        local current_keyword = first_keyword(stripped)
        local prev_indent = #(prev_nonblank:match("^(%s*)") or "")
        local current_indent = #(line:match("^(%s*)") or "")
        local current_is_attr = stripped:match("^%(%*") ~= nil
        local current_starts_decl = current_is_attr
          or stripped:match("^typedef%s+") ~= nil
          or (current_keyword ~= nil and (decl_openers[current_keyword] or current_keyword == "import" or current_keyword == "export"))

        local need_blank = false
        if prev_keyword == "package" and current_starts_decl then
          need_blank = true
        elseif (prev_keyword == "import" or prev_keyword == "export")
          and current_starts_decl
          and current_keyword ~= "import"
          and current_keyword ~= "export"
        then
          need_blank = true
        elseif prev_keyword ~= nil
          and decl_closers[prev_keyword]
          and current_starts_decl
          and current_indent == prev_indent
        then
          need_blank = true
        end

        if need_blank then
          table.insert(out, "")
        end
      end

      table.insert(out, line)
      prev_nonblank = line
    end
  end

  return out
end

---Produce a reindented copy of lines using simple keyword heuristics.
---@param lines string[]
---@param sw integer
---@return string[]
local function reindent_lines(lines, sw)
  local out = {}
  local state = {
    decl_stack = {},
    header_stack = {},
    block_depth = 0,
    brace_depth = 0,
    continuation_depth = 0,
    parser_state = {
      in_block_comment = false,
      in_string = false,
    },
  }

  for i, line in ipairs(lines) do
    local info
    info, state.parser_state = analyze_line(line, state.parser_state)

    if line:match("^%s*$") then
      out[i] = ""
    else
      local indent = indent_depth_for_line(state, info) * sw
      if state.continuation_depth > 0 and not info.starts_with_closing_delim then
        indent = indent + sw
      end
      local stripped = line:match("^%s*(.*)$")
      out[i] = string.rep(" ", indent) .. stripped
    end

    advance_indent_state(state, info)
    state.continuation_depth = math.max(
      state.continuation_depth + info.continuation_delta + info.record_brace_delta
        - (info.opens_brace and 1 or 0)
        + (info.closes_brace and 1 or 0),
      0
    )
  end
  return out
end

---@param line string
---@param indent string
---@param continuation_indent string
---@return string[]
local function wrap_generic_long_line(line, indent, continuation_indent)
  local out = {}
  local current = trim(line)
  local first = true

  while #current + #(first and indent or continuation_indent) > max_columns do
    local limit = max_columns - #(first and indent or continuation_indent)
    if limit <= 0 then
      break
    end

    local break_at
    for i = math.min(#current, limit), 1, -1 do
      if current:sub(i, i) == " " then
        local remainder = trim(current:sub(i + 1))
        local blocked = false
        for keyword in pairs(blocked_wrap_continuations) do
          if remainder:match("^" .. keyword .. "%f[%W]") then
            blocked = true
            break
          end
        end
        if not blocked then
          break_at = i
          break
        end
      end
    end
    if break_at == nil or break_at <= 1 then
      break
    end

    local head = trim(current:sub(1, break_at - 1))
    local prefix = first and indent or continuation_indent
    table.insert(out, prefix .. head)
    current = trim(current:sub(break_at + 1))
    first = false
  end

  local prefix = first and indent or continuation_indent
  table.insert(out, prefix .. current)
  return out
end

---@param lines string[]
---@param sw integer
---@return string[]
local function wrap_expression_lines(lines, sw)
  local out = {}
  local in_block_comment = false
  local parser_state = {
    in_block_comment = false,
    in_string = false,
  }
  local continuation_depth = 0

  for _, line in ipairs(lines) do
    local info
    info, parser_state = analyze_line(line, parser_state)
    local indent = line:match("^(%s*)") or ""
    local stripped = trim(line)

    if line == "" or parser_state.in_block_comment or parser_state.in_string or line:find("//", 1, true) ~= nil or #line <= max_columns then
      table.insert(out, line)
    else
      local continuation_indent = indent .. string.rep(" ", sw)
      vim.list_extend(out, wrap_generic_long_line(line, indent, continuation_indent))
    end

    continuation_depth = math.max(
      continuation_depth + info.continuation_delta + info.record_brace_delta
        - (info.opens_brace and 1 or 0)
        + (info.closes_brace and 1 or 0),
      0
    )
    if stripped == "" then
      continuation_depth = continuation_depth
    end
  end

  return out
end

---Resolve shiftwidth, defaulting to the 2-space indent expected by `bsv-style.md`.
---@param bufnr integer
---@return integer
local function resolve_shiftwidth(bufnr)
  -- Stick to two-space indentation for BSV regardless of user overrides.
  return 2
end

---Try to run LSP formatting for the buffer.
---@param bufnr integer
---@return boolean did_run
local function try_lsp_format(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/formatting" })
  if #clients == 0 then
    return false
  end
  vim.lsp.buf.format({ bufnr = bufnr, async = false })
  return true
end

---Format the current buffer: prefer LSP, fallback to style normalization + reindent.
---@param opts? { bufnr?: integer, async?: boolean }
function M.format_buffer(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  if try_lsp_format(bufnr) then
    return
  end

  local sw = resolve_shiftwidth(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  lines = normalize_lines(lines, sw)
  lines = wrap_long_lines(lines, sw)
  lines = reindent_lines(lines, sw)
  lines = normalize_blank_lines(lines)
  lines = normalize_layout_spacing(lines)
  lines = wrap_expression_lines(lines, sw)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end

---Register a Conform formatter (no-op if conform.nvim is absent).
function M.register_conform()
  local ok, conform = pcall(require, "conform")
  if not ok then
    return
  end

  if not conform.formatters then
    conform.formatters = {}
  end

  if not conform.formatters.bsvfmt then
    conform.formatters.bsvfmt = {
      meta = {
        url = "https://github.com/ArchSerein/bsv.nvim",
        description = "Bluespec: prefer LSP formatting, fallback to style normalization",
      },
      format = function(_, ctx, lines, callback)
        if try_lsp_format(ctx.buf) then
          lines = vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false)
        else
          lines = normalize_lines(lines, resolve_shiftwidth(ctx.buf))
          lines = wrap_long_lines(lines, resolve_shiftwidth(ctx.buf))
          lines = reindent_lines(lines, resolve_shiftwidth(ctx.buf))
          lines = normalize_blank_lines(lines)
          lines = normalize_layout_spacing(lines)
          lines = wrap_expression_lines(lines, resolve_shiftwidth(ctx.buf))
        end
        callback(nil, lines)
      end,
    }
  end

  if not conform.formatters_by_ft.bsv then
    conform.formatters_by_ft.bsv = { "bsvfmt" }
  end
end

---Buffer-local setup for formatting defaults.
---@param bufnr? integer
function M.setup_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  -- Use LSP formatexpr when available; it safely no-ops otherwise.
  vim.bo[bufnr].formatexpr = "v:lua.vim.lsp.formatexpr()"
  M.register_conform()
end

return M
