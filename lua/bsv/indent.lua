local M = {}

local increase_re = [[^\s*(module|interface|function|typeclass|instance|method|action|actionvalue|rule)[^=]*[=;]\s*$]]
local decrease_re = [[^\s*end(module|interface|function|typeclass|instance|method|action|actionvalue|rule)\s*$]]

function M.indentexpr()
	local lnum = vim.v.lnum
	if lnum == 1 then
		return 0
	end

	local prev_lnum = vim.fn.prevnonblank(lnum - 1)
	if prev_lnum == 0 then
		return 0
	end

	local prevline = vim.fn.getline(prev_lnum)
	local line = vim.fn.getline(lnum)
	local base = vim.fn.indent(prev_lnum)

	if line:match(decrease_re) then
		base = base - vim.bo.shiftwidth
	end

	if prevline:match(increase_re) then
		base = base + vim.bo.shiftwidth
	end

	return base < 0 and 0 or base
end

return M
