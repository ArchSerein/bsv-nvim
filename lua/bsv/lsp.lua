local M = {}

---@class bsv.LspOpts
---@field name? string
---@field cmd? string[]
---@field root_markers? string[]

local defaults = {
	name = "blues",
	cmd = { "blues-lsp" },
	root_markers = { "blues_compdb.json", "blues.toml", ".git" },
}

---@param opts? bsv.LspOpts
function M.enable(opts)
	opts = vim.tbl_deep_extend("force", defaults, opts or {})

	if vim.fn.executable(opts.cmd[1]) ~= 1 then
		if opts.cmd[1] == "blues-lsp" and vim.fn.executable("blues") == 1 then
			opts.cmd = { "blues" }
		else
			vim.notify(
				("bsv.nvim: LSP server binary not found: %s"):format(opts.cmd[1]),
				vim.log.levels.WARN
			)
			return
		end
	end

	if vim.lsp.config and vim.lsp.enable then
		vim.lsp.config(opts.name, {
			cmd = opts.cmd,
			filetypes = { "bsv" },
			root_markers = opts.root_markers,
		})
		vim.lsp.enable(opts.name)
		return
	end

	local ok, lspconfig = pcall(require, "lspconfig")
	if not ok then
		vim.notify("bsv.nvim: Neovim 0.11+ or nvim-lspconfig is required for LSP", vim.log.levels.WARN)
		return
	end

	local root_dir
	if lspconfig.util and lspconfig.util.root_pattern then
		root_dir = lspconfig.util.root_pattern(table.unpack(opts.root_markers))
	end

	lspconfig[opts.name].setup({
		cmd = opts.cmd,
		filetypes = { "bsv" },
		root_dir = root_dir,
	})
end

return M
