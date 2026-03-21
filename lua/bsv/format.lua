local lang = require("bsv.lang")
local layout = require("bsv.layout")

local M = {}

local max_columns = 96

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

local trim = layout.trim
local first_keyword = layout.first_keyword

local function escape_lua_pattern(text)
  return (text:gsub("([^%%w])", "%%%1"))
end

local function find_matching_paren(text, open_index)
  local depth = 0
  local i = open_index
  while i <= #text do
    local ch = text:sub(i, i)
    if ch == '"' then
      i = i + 1
      while i <= #text do
        local str_ch = text:sub(i, i)
        if str_ch == "\\" then
          i = i + 2
        elseif str_ch == '"' then
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

local function split_top_level_csv(text)
  local items = {}
  local start_index = 1
  local paren_depth = 0
  local bracket_depth = 0
  local brace_depth = 0
  local i = 1

  while i <= #text do
    local ch = text:sub(i, i)
    if ch == '"' then
      i = i + 1
      while i <= #text do
        local str_ch = text:sub(i, i)
        if str_ch == "\\" then
          i = i + 2
        elseif str_ch == '"' then
          break
        else
          i = i + 1
        end
      end
    elseif ch == "(" then
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
    elseif ch == "," and paren_depth == 0 and bracket_depth == 0 and brace_depth == 0 then
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

local function find_top_level_keyword(text, keyword)
  local paren_depth = 0
  local bracket_depth = 0
  local brace_depth = 0
  local i = 1

  while i <= #text do
    local ch = text:sub(i, i)
    if ch == '"' then
      i = i + 1
      while i <= #text do
        local str_ch = text:sub(i, i)
        if str_ch == "\\" then
          i = i + 2
        elseif str_ch == '"' then
          break
        else
          i = i + 1
        end
      end
    elseif ch == "(" then
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
      local slice = text:sub(i)
      local start_pos = slice:find("^" .. keyword .. "%f[%W]")
      if start_pos ~= nil then
        return i + start_pos - 1
      end
    end
    i = i + 1
  end
end

local function parse_header_segments(text)
  local segments = {}
  local cursor = 1
  local i = 1

  while i <= #text do
    local hash_open = text:sub(i, i + 1) == "#("
    local open_index
    local open_token

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

local function split_inline_comment(line)
  local parser_state = layout.new_parser_state()
  local out = {}
  local i = 1

  while i <= #line do
    if parser_state.in_string then
      local j = i
      while j <= #line do
        local ch = line:sub(j, j)
        if ch == "\\" then
          j = j + 2
        elseif ch == '"' then
          parser_state.in_string = false
          break
        else
          j = j + 1
        end
      end
      table.insert(out, line:sub(i, math.min(j, #line)))
      i = j + 1
    elseif parser_state.in_block_comment then
      local stop = line:find("*/", i, true)
      if stop then
        table.insert(out, line:sub(i, stop + 1))
        i = stop + 2
        parser_state.in_block_comment = false
      else
        return line, nil
      end
    else
      local pair = line:sub(i, i + 1)
      local ch = line:sub(i, i)
      if pair == "//" then
        return table.concat(out), line:sub(i)
      elseif pair == "/*" then
        local stop = line:find("*/", i + 2, true)
        if stop then
          table.insert(out, line:sub(i, stop + 1))
          i = stop + 2
        else
          return line, nil
        end
      elseif ch == '"' then
        parser_state.in_string = true
      end
      if i <= #line then
        table.insert(out, ch)
        i = i + 1
      end
    end
  end

  return table.concat(out), nil
end

local function normalize_record_colons(code)
  local leading_keyword = first_keyword(code)
  if leading_keyword == "import" or leading_keyword == "export" then
    return code
  end

  local colon_index
  local paren_depth = 0
  local bracket_depth = 0
  local brace_depth = 0
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
    elseif ch == ":" and paren_depth == 0 and bracket_depth == 0 and brace_depth == 0 then
      local prefix = trim(code:sub(1, i - 1))
      if prefix ~= "" and not prefix:find("?", 1, true) then
        colon_index = i
      end
      break
    end
  end

  if colon_index == nil then
    return code
  end

  local left = trim(code:sub(1, colon_index - 1))
  local right = trim(code:sub(colon_index + 1))
  if right == "" then
    return left .. ":"
  end
  return left .. ": " .. right
end

local function normalize_code_chunk(code, sw)
  if code == "" then
    return code
  end

  local leading_keyword = first_keyword(code)
  code = code:gsub("\t", string.rep(" ", sw))
  code = code:gsub("%s+([,;%)%]}])", "%1")
  code = code:gsub("%s*,%s*", ", ")
  code = code:gsub(";%s*(%S)", "; %1")

  for keyword in pairs(lang.control_keywords) do
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
  code = code:gsub("([_%a][_%w']*)%s+%(", function(word)
    if lang.paren_keywords[word] then
      return word .. " ("
    end
    return word .. "("
  end)
  code = code:gsub("%(%s+", "(")
  code = code:gsub("%s+%)", ")")

  for op, token in pairs(lang.protected_ops) do
    code = code:gsub("%s*" .. escape_lua_pattern(op) .. "%s*", " " .. token .. " ")
  end

  code = code:gsub("%s*=%s*", " = ")

  if leading_keyword ~= "import" then
    for _, op in ipairs(lang.spaced_single_char_ops) do
      code = code:gsub("%s*" .. escape_lua_pattern(op) .. "%s*", " " .. op .. " ")
    end
  end

  for op, token in pairs(lang.protected_ops) do
    code = code:gsub(token, op)
  end

  code = code:gsub("%s*::%s*", "::")
  code = code:gsub("([_%w%)%]])%s*{", "%1 {")
  code = code:gsub("%(%s*%*", "(*")
  code = code:gsub("%*%s*%)", "*)")
  code = normalize_record_colons(code)
  code = code:gsub("%s+%?%s+", " ? ")
  code = code:gsub("%s+$", "")

  return code
end

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
        elseif str_ch == '"' then
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
        if j <= #line and line:sub(j - 1, j - 1) == '"' then
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
          if next_pair == "//" or next_pair == "/*" or next_ch == '"' then
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

local function normalize_lines(lines, sw)
  local out = {}
  local parser_state = layout.new_parser_state()
  for i, line in ipairs(lines) do
    out[i], parser_state = normalize_line(line, sw, parser_state)
  end
  return out
end

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
      return layout.is_scope_decl_line(state, header_info)
    end
    return false
  end

  if info.decl_kind ~= nil and info.ends_with_semicolon and info.paren_delta <= 0 then
    return layout.is_scope_decl_line(state, info)
  end
  if info.decl_kind ~= nil and not info.ends_with_semicolon then
    return true
  end
  return info.opens_block or info.opens_brace
end

local function is_top_level_function_open(state, info)
  return info.decl_kind == "function"
    and layout.is_scope_decl_line(state, info)
    and layout.base_depth(state) == 0
    and #state.header_stack == 0
end

local function is_top_level_function_close(state, info)
  return info.keyword == "endfunction"
    and #state.decl_stack == 1
    and state.decl_stack[#state.decl_stack] == "function"
    and state.block_depth == 0
    and state.brace_depth == 0
    and #state.header_stack == 0
end

local function normalize_blank_lines(lines)
  local out = {}
  local state = layout.new_state()
  local pending_blank = false
  local prev_nonblank_meta

  for _, line in ipairs(lines) do
    local info
    info, state.parser_state = layout.analyze_line(line, state.parser_state)

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
      layout.advance_state(state, info)
      prev_nonblank_meta = current_meta
    end
  end

  while #out > 0 and out[#out] == "" do
    table.remove(out)
  end

  return out
end

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
          or (current_keyword ~= nil and (lang.decl_openers[current_keyword] or current_keyword == "import" or current_keyword == "export"))

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
          and lang.decl_closers[prev_keyword]
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
    table.insert(out, (first and indent or continuation_indent) .. head)
    current = trim(current:sub(break_at + 1))
    first = false
  end

  table.insert(out, (first and indent or continuation_indent) .. current)
  return out
end

local function wrap_ternary_line(line, indent, continuation_indent)
  local code, comment = split_inline_comment(trim(line))
  local q_index
  local c_index
  local paren_depth = 0
  local bracket_depth = 0
  local brace_depth = 0

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
    elseif ch == "?" and paren_depth == 0 and bracket_depth == 0 and brace_depth == 0 then
      q_index = i
    elseif ch == ":" and q_index ~= nil and paren_depth == 0 and bracket_depth == 0 and brace_depth == 0 then
      c_index = i
      break
    end
  end

  if q_index == nil or c_index == nil then
    return nil
  end

  local lhs = trim(code:sub(1, q_index - 1))
  local true_branch = trim(code:sub(q_index + 1, c_index - 1))
  local false_branch = trim(code:sub(c_index + 1))
  if lhs == "" or true_branch == "" or false_branch == "" then
    return nil
  end

  local out = {
    indent .. lhs,
    continuation_indent .. "? " .. true_branch,
    continuation_indent .. ": " .. false_branch,
  }

  if comment ~= nil then
    out[#out] = out[#out] .. " " .. comment:gsub("^//%s*", "// ")
  end

  return out
end

local function wrap_expression_lines(lines, sw)
  local out = {}
  for _, line in ipairs(lines) do
    local indent = line:match("^(%s*)") or ""
    local stripped = trim(line)

    if line == "" or line:find("//", 1, true) ~= nil and #line <= max_columns then
      table.insert(out, line)
    elseif #line <= max_columns then
      table.insert(out, line)
    else
      local continuation_indent = indent .. string.rep(" ", sw)
      local wrapped = wrap_ternary_line(line, indent, continuation_indent)
      if wrapped ~= nil then
        vim.list_extend(out, wrapped)
      else
        vim.list_extend(out, wrap_generic_long_line(stripped, indent, continuation_indent))
      end
    end
  end
  return out
end

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

local function resolve_shiftwidth(_)
  return 2
end

local function try_lsp_format(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/formatting" })
  if #clients == 0 then
    return false
  end
  vim.lsp.buf.format({ bufnr = bufnr, async = false })
  return true
end

local function format_lines(lines, sw)
  lines = normalize_lines(lines, sw)
  lines = wrap_long_lines(lines, sw)
  lines = layout.reindent_lines(lines, sw)
  lines = normalize_blank_lines(lines)
  lines = normalize_layout_spacing(lines)
  lines = wrap_expression_lines(lines, sw)
  return lines
end

function M.format_buffer(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  if try_lsp_format(bufnr) then
    return
  end

  local sw = resolve_shiftwidth(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, format_lines(lines, sw))
end

function M.register_conform()
  local ok, conform = pcall(require, "conform")
  if not ok then
    return
  end

  conform.formatters = conform.formatters or {}
  conform.formatters_by_ft = conform.formatters_by_ft or {}

  if not conform.formatters.bsvfmt then
    conform.formatters.bsvfmt = {
      meta = {
        url = "https://github.com/ArchSerein/bsv.nvim",
        description = "Bluespec formatter with conservative spacing and indentation",
      },
      format = function(_, ctx, lines, callback)
        if try_lsp_format(ctx.buf) then
          lines = vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false)
        else
          lines = format_lines(lines, resolve_shiftwidth(ctx.buf))
        end
        callback(nil, lines)
      end,
    }
  end

  if not conform.formatters_by_ft.bsv then
    conform.formatters_by_ft.bsv = { "bsvfmt" }
  end
end

function M.setup_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.bo[bufnr].formatexpr = "v:lua.vim.lsp.formatexpr()"
  M.register_conform()
end

return M
