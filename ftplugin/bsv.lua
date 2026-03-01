vim.bo.commentstring = "// %s"

vim.bo.expandtab = true
vim.bo.shiftwidth = 2
vim.bo.tabstop = 2

-- Enable Tree-sitter highlighting if a parser is installed.
-- Safe: if no parser exists, this will no-op (pcall).
pcall(function()
	vim.treesitter.start()
end)

vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.wo.foldmethod = "expr"

-- Formatting: prefer LSP, fallback to heuristic reindent; also registers conform formatter.
do
	local ok, fmt = pcall(require, "bsv.format")
	if ok and fmt then
		fmt.setup_buffer()
	end
end
