-- indent/bsv.lua
-- Simple indentation rules for BSV, derived from the VS Code language configuration
-- and augmented with common BSV block keywords (begin/end, action/endaction, etc.).

-- Neovim calls the indentexpr for each line.
-- We keep the logic conservative: only adjust indent by +/-shiftwidth.

local function prev_nonblank(lnum)
	while lnum > 0 do
		local line = vim.fn.getline(lnum)
		if line:match("%S") then
			return lnum, line
		end
		lnum = lnum - 1
	end
	return 0, ""
end

local inc_decl_re = [[^%s*(module|interface|function|typeclass|instance|method|action|actionvalue|rule)[^=]*[=;]%s*$]]
local dec_decl_re = [[^%s*end(module|interface|function|typeclass|instance|method|action|actionvalue|rule)%s*$]]

local inc_block_re = [[^%s*(begin|action|actionvalue|seq|par|case|rules)%f[%W].*$]]
local dec_block_re = [[^%s*(end|endaction|endactionvalue|endseq|endpar|endcase|endrules)%f[%W].*$]]

function _G.bsv_indentexpr()
	local lnum = vim.v.lnum
	if lnum <= 1 then
		return 0
	end

	local cur = vim.fn.getline(lnum)
	local prev_lnum, prev = prev_nonblank(lnum - 1)
	if prev_lnum == 0 then
		return 0
	end

	local sw = vim.bo.shiftwidth
	local base = vim.fn.indent(prev_lnum)

	-- De-indent on closing keywords in the *current* line
	if cur:match(dec_decl_re) or cur:match(dec_block_re) then
		base = base - sw
	end

	-- Indent after opening constructs on the *previous* line
	if prev:match(inc_decl_re) or prev:match(inc_block_re) then
		base = base + sw
	end

	if base < 0 then
		base = 0
	end
	return base
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
}, ",")
