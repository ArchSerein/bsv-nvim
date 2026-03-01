-- indent/bsv.lua
-- Simple indentation rules for BSV, derived from the VS Code language configuration
-- and augmented with common BSV block keywords (begin/end, action/endaction, etc.).

-- Neovim calls the indentexpr for each line.
-- We keep the logic conservative: only adjust indent by +/-shiftwidth.

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

local function first_keyword(line)
	return line:match("^%s*([%a][%w]*)")
end

local function is_decl_opener(line)
	local keyword = first_keyword(line)
	return keyword ~= nil
		and decl_openers[keyword] == true
		and line:match("[=;]%s*$") ~= nil
end

local function is_decl_closer(line)
	local keyword = first_keyword(line)
	return keyword ~= nil and decl_closers[keyword] == true
end

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

local function is_block_closer(line)
	local keyword = first_keyword(line)
	return keyword ~= nil and block_closers[keyword] == true
end

local function is_brace_opener(line)
	return line:match("^%s*typedef%s+struct%s*{[^}]*$") ~= nil
		or line:match("^%s*typedef%s+enum%s*{[^}]*$") ~= nil
		or line:match("^%s*typedef%s+union%s+tagged%s*{[^}]*$") ~= nil
end

local function is_brace_closer(line)
	return line:match("^%s*}") ~= nil
end

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

local function analyze_line(line, parser_state)
	local code
	code, parser_state = strip_analysis_code(line, parser_state)
	local keyword = first_keyword(code)
	return {
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

local function base_depth(state)
	return #state.decl_stack + state.block_depth + state.brace_depth
end

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
		local closes_header = header.paren_depth + info.paren_delta <= 0
			and info.ends_with_semicolon
		if closes_header then
			depth = header.base_depth
		elseif info.header_aligned then
			depth = header.base_depth
		else
			depth = header.base_depth + 1
		end
	end

	if depth < 0 then
		depth = 0
	end
	return depth
end

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

function _G.bsv_indentexpr()
	local lnum = vim.v.lnum
	if lnum <= 1 then
		return 0
	end

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

	for cur_lnum = 1, lnum do
		local line = vim.fn.getline(cur_lnum)
		local info
		info, state.parser_state = analyze_line(line, state.parser_state)
		if cur_lnum == lnum then
			local indent = indent_depth_for_line(state, info) * vim.bo.shiftwidth
			if state.continuation_depth > 0 and not info.starts_with_closing_delim then
				indent = indent + vim.bo.shiftwidth
			end
			return indent
		end
		advance_indent_state(state, info)
		state.continuation_depth = math.max(
			state.continuation_depth + info.continuation_delta + info.record_brace_delta
				- (info.opens_brace and 1 or 0)
				+ (info.closes_brace and 1 or 0),
			0
		)
	end

	return 0
end

vim.bo.indentexpr = "v:lua.bsv_indentexpr()"
vim.bo.indentkeys = table.concat({
	"0=end",
	"0=endaction",
	"0=endactionvalue",
	"0=endseq",
	"0=endpar",
	"0=endcase",
	"0=endrules",
	"0=endpackage",
	"0=endmodule",
	"0=endinterface",
	"0=endrule",
	"0=endfunction",
	"0=endtypeclass",
	"0=endinstance",
	"0=}",
}, ",")
