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
