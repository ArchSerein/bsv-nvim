local M = {}

local config = {
  indent_width = 2,
  max_columns = 100,
  trim_trailing_whitespace = true,
}

local block_openers = {
  package = true,
  module = true,
  interface = true,
  method = true,
  rule = true,
  rules = true,
  ["function"] = true,
  instance = true,
  typeclass = true,
  action = true,
  actionvalue = true,
  begin = true,
  case = true,
}

local close_to_open = {
  endpackage = "package",
  endmodule = "module",
  endinterface = "interface",
  endmethod = "method",
  endrule = "rule",
  endrules = "rules",
  endfunction = "function",
  endinstance = "instance",
  endtypeclass = "typeclass",
  endaction = "action",
  endactionvalue = "actionvalue",
  endcase = "case",
  ["end"] = "begin",
  ["}"] = "{",
}

local binary_ops = {
  ["<-"] = true,
  ["<="] = true,
  [">="] = true,
  ["=="] = true,
  ["!="] = true,
  ["&&"] = true,
  ["||"] = true,
  ["="] = true,
  ["+"] = true,
  ["-"] = true,
  ["*"] = true,
  ["/"] = true,
  ["%"] = true,
  ["<"] = true,
  [">"] = true,
  ["<<"] = true,
  [">>"] = true,
  ["<<<"] = true,
  [">>>"] = true,
  ["&"] = true,
  ["|"] = true,
  ["^"] = true,
  ["~^"] = true,
  ["^~"] = true,
  ["?"] = true,
}

local unary_ops = {
  ["+"] = true,
  ["-"] = true,
  ["!"] = true,
  ["~"] = true,
  ["&"] = true,
  ["|"] = true,
  ["^"] = true,
}

local unary_prefix_words = {
  ["return"] = true,
}

local control_before_paren = {
  ["if"] = true,
  ["for"] = true,
  ["while"] = true,
  case = true,
  provisos = true,
  deriving = true,
  matches = true,
}

local multi_ops = {
  ">>>",
  "<<<",
  "<-",
  "<=",
  ">=",
  "==",
  "!=",
  "&&",
  "||",
  "<<",
  ">>",
  "~^",
  "^~",
  "::",
}

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function trim_trailing_whitespace(line)
  return (line:gsub("[ \t]+$", ""))
end

local function trim_trailing_lines(lines)
  local out = {}
  for i, line in ipairs(lines) do
    out[i] = trim_trailing_whitespace(line)
  end
  return out
end

local function word_pattern(word)
  return "%f[%w_$]" .. word .. "%f[^%w_$]"
end

local function has_word(s, word)
  return s:find(word_pattern(word)) ~= nil
end

local function starts_with_word(s, word)
  return s:find("^%s*" .. word_pattern(word)) ~= nil
end

local function starts_with_closer(s)
  local word = s:match("^%s*(end[%w_]*)%f[^%w_$]") or s:match("^%s*(end)%f[^%w_$]")
  if word and close_to_open[word] then
    return word
  end
  return nil
end

local function starts_with_brace_closer(s)
  return s:find("^%s*}") ~= nil
end

local function strip_strings(code)
  local out = {}
  local i = 1
  while i <= #code do
    local ch = code:sub(i, i)
    if ch == '"' then
      out[#out + 1] = '""'
      i = i + 1
      while i <= #code do
        local c = code:sub(i, i)
        if c == "\\" then
          i = i + 2
        elseif c == '"' then
          i = i + 1
          break
        else
          i = i + 1
        end
      end
    else
      out[#out + 1] = ch
      i = i + 1
    end
  end
  return table.concat(out)
end

local function split_code_comment(line, in_block_comment)
  if in_block_comment then
    local close_at = line:find("%*/", 1)
    if close_at then
      return "", line, false
    end
    return "", line, true
  end

  local i = 1
  while i <= #line do
    local ch = line:sub(i, i)
    local next_two = line:sub(i, i + 1)
    if ch == '"' then
      i = i + 1
      while i <= #line do
        local c = line:sub(i, i)
        if c == "\\" then
          i = i + 2
        elseif c == '"' then
          i = i + 1
          break
        else
          i = i + 1
        end
      end
    elseif next_two == "//" then
      return line:sub(1, i - 1), line:sub(i), false
    elseif next_two == "/*" then
      return line:sub(1, i - 1), line:sub(i), not line:find("%*/", i + 2)
    else
      i = i + 1
    end
  end

  return line, nil, false
end

local function tokenize(code)
  local tokens = {}
  local i = 1

  while i <= #code do
    local ch = code:sub(i, i)
    local rest = code:sub(i)

    if ch:match("%s") then
      i = i + 1
    elseif ch == '"' then
      local j = i + 1
      while j <= #code do
        local c = code:sub(j, j)
        if c == "\\" then
          j = j + 2
        elseif c == '"' then
          j = j + 1
          break
        else
          j = j + 1
        end
      end
      tokens[#tokens + 1] = code:sub(i, j - 1)
      i = j
    else
      local number = rest:match("^%d*'[sS]?[bBoOdDhH][%w_%?]+")
        or rest:match("^'[01]")
        or rest:match("^%d+%.%d*([eE][+-]?%d+)?")
        or rest:match("^%d+")
      if number and number ~= "" then
        tokens[#tokens + 1] = number
        i = i + #number
      else
        local ident = rest:match("^[%a_$][%w_$]*")
        if ident then
          tokens[#tokens + 1] = ident
          i = i + #ident
        else
          local op
          for _, candidate in ipairs(multi_ops) do
            if rest:sub(1, #candidate) == candidate then
              op = candidate
              break
            end
          end
          if op and op ~= "" then
            tokens[#tokens + 1] = op
            i = i + #op
          else
            tokens[#tokens + 1] = ch
            i = i + 1
          end
        end
      end
    end
  end

  return tokens
end

local function is_wordish(tok)
  if not tok then
    return false
  end
  return tok:match("^[%w_$]") ~= nil or tok:sub(1, 1) == '"' or tok:find("^'")
end

local function is_unary_context(prev)
  return not prev
    or prev == "("
    or prev == "["
    or prev == "{"
    or prev == ","
    or prev == ";"
    or prev == ":"
    or prev == "?"
    or binary_ops[prev]
end

local function is_unary_operator_context(prev)
  return is_unary_context(prev) or unary_prefix_words[prev] == true
end

local function needs_space(prev, curr, prevprev)
  if not prev then
    return false
  end

  if prev == "." or curr == "." or prev == "#" or curr == "#" then
    return false
  end
  if curr == "," or curr == ";" or curr == ")" or curr == "]" or curr == "}" then
    return false
  end
  if prev == "(" or prev == "[" or prev == "{" then
    return false
  end
  if curr == "(" then
    return control_before_paren[prev] == true
  end
  if curr == "[" then
    return false
  end
  if prev == "," or prev == ";" then
    return true
  end
  if (prev == ")" or prev == "]") and is_wordish(curr) then
    return true
  end
  if curr == ":" then
    return false
  end
  if prev == ":" then
    return curr ~= ":" and curr ~= "]"
  end
  if curr == "::" or prev == "::" then
    return false
  end
  if binary_ops[curr] then
    if unary_ops[curr] and is_unary_operator_context(prev) then
      return not (not prev or prev == "(" or prev == "[" or prev == "{")
    end
    return true
  end
  if binary_ops[prev] then
    if unary_ops[prev] and is_unary_operator_context(prevprev) then
      return false
    end
    return true
  end
  if is_wordish(prev) and is_wordish(curr) then
    return true
  end

  return false
end

local function format_code(code)
  local trimmed = trim(code)
  if trimmed == "" then
    return ""
  end

  if trimmed:find("^`") or trimmed:find("^%(%*") or trimmed:find("%*%)$") then
    return trimmed
  end

  local tokens = tokenize(trimmed)
  local out = {}
  local prev_token
  local prevprev_token
  for _, tok in ipairs(tokens) do
    if needs_space(prev_token, tok, prevprev_token) then
      out[#out + 1] = " "
    end
    out[#out + 1] = tok
    prevprev_token = prev_token
    prev_token = tok
  end

  return table.concat(out)
end

local function pop_stack(stack, close_word)
  local wanted = close_to_open[close_word]
  if not wanted then
    return
  end

  for i = #stack, 1, -1 do
    local entry = stack[i]
    if entry == wanted or (wanted == "interface" and entry:find("^interface")) then
      for _ = #stack, i, -1 do
        table.remove(stack)
      end
      return
    end
  end

  if #stack > 0 then
    table.remove(stack)
  end
end

local function classify_interface(stack)
  local top = stack[#stack]
  if top == "module" or top == "method" or top == "rule" or top == "action" or top == "actionvalue" then
    return "interface_def"
  end
  return "interface_decl"
end

local function should_open_method(stack)
  return stack[#stack] ~= "interface_decl"
end

local function is_subinterface_declaration(stack, code)
  if stack[#stack] ~= "interface_decl" then
    return false
  end
  if not code:find("^%s*interface%f[%W]") or not code:find(";%s*$") then
    return false
  end

  local words = 0
  for _ in code:gmatch("%f[%w_$][%a_$][%w_$]*%f[^%w_$]") do
    words = words + 1
    if words >= 3 then
      return true
    end
  end
  return false
end

local function push_openers(stack, code, opts)
  opts = opts or {}
  local stripped = strip_strings(code)
  if stripped:find("^%s*`") then
    return
  end

  local ignored_first_closer = false
  for word in stripped:gmatch("%f[%w_$]([%a_][%w_$]*)%f[^%w_$]") do
    if close_to_open[word] then
      if opts.ignore_first_closer and not ignored_first_closer then
        ignored_first_closer = true
      else
        pop_stack(stack, word)
      end
    elseif block_openers[word] then
      if word == "interface" then
        if not stripped:find("=") and not is_subinterface_declaration(stack, stripped) then
          stack[#stack + 1] = classify_interface(stack)
        end
      elseif word == "method" then
        if should_open_method(stack) then
          stack[#stack + 1] = "method"
        end
      elseif word == "action" then
        if not has_word(stripped, "endaction") then
          stack[#stack + 1] = "action"
        end
      elseif word == "actionvalue" then
        if not has_word(stripped, "endactionvalue") then
          stack[#stack + 1] = "actionvalue"
        end
      else
        stack[#stack + 1] = word
      end
    end
  end
end

local function update_brace_stack(stack, code, opts)
  opts = opts or {}
  local ignored_first_closer = false
  local i = 1

  while i <= #code do
    local ch = code:sub(i, i)
    if ch == "{" then
      stack[#stack + 1] = "{"
    elseif ch == "}" then
      if opts.ignore_first_closer and not ignored_first_closer then
        ignored_first_closer = true
      else
        pop_stack(stack, "}")
      end
    end
    i = i + 1
  end
end

local function format_lines(lines, opts)
  opts = vim.tbl_deep_extend("force", config, opts or {})
  local indent_width = opts.indent_width
  local stack = {}
  local formatted = {}
  local in_block_comment = false

  for _, line in ipairs(lines) do
    local code, comment
    line = opts.trim_trailing_whitespace and trim_trailing_whitespace(line) or line
    code, comment, in_block_comment = split_code_comment(line, in_block_comment)

    local stripped_code = strip_strings(code or "")
    local close_word = starts_with_closer(stripped_code)
    if close_word then
      pop_stack(stack, close_word)
    end
    local close_brace = starts_with_brace_closer(stripped_code)
    if close_brace then
      pop_stack(stack, "}")
    end

    local level = #stack
    if starts_with_word(stripped_code, "else") and level > 0 then
      level = level - 1
    end

    local indent = string.rep(" ", math.max(level, 0) * indent_width)
    local body = format_code(code or "")

    if body == "" and comment then
      formatted[#formatted + 1] = indent .. trim(comment)
    elseif comment then
      formatted[#formatted + 1] = indent .. body .. " " .. trim(comment)
    elseif body == "" then
      formatted[#formatted + 1] = ""
    else
      formatted[#formatted + 1] = indent .. body
    end

    push_openers(stack, stripped_code, { ignore_first_closer = close_word ~= nil })
    update_brace_stack(stack, stripped_code, { ignore_first_closer = close_brace })
  end

  return formatted
end

function M.lines(lines, opts)
  local user_config = {}
  local ok, bsv = pcall(require, "bsv")
  if ok and bsv.config then
    user_config = bsv.config
  end
  return format_lines(lines, vim.tbl_deep_extend("force", user_config, opts or {}))
end

function M.trim_trailing_lines(lines)
  return trim_trailing_lines(lines)
end

function M.trim_trailing_buffer(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local start_line = opts.start_line or 1
  local end_line = opts.end_line or vim.api.nvim_buf_line_count(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local trimmed = trim_trailing_lines(lines)

  local view = vim.fn.winsaveview()
  vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, trimmed)
  vim.fn.winrestview(view)
end

function M.buffer(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local start_line = opts.start_line or 1
  local end_line = opts.end_line or vim.api.nvim_buf_line_count(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local formatted = M.lines(lines, opts)

  local view = vim.fn.winsaveview()
  vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, formatted)
  vim.fn.winrestview(view)
end

return M
