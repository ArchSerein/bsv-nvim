-- lua/bsv/init.lua
-- Optional user-facing setup (plugin works without calling setup()).

local M = {}

---@class bsv.SetupOpts
---@field treesitter? { register?: boolean, url?: string }
---@field lsp? { enable?: boolean, name?: string, cmd?: string[], root_markers?: string[] }
---@field format? { enable?: boolean }
---@field silent? boolean

---@param opts? bsv.SetupOpts
function M.setup(opts)
	opts = opts or {}
	if opts.treesitter and opts.treesitter.register then
		require("bsv.treesitter").register(opts.treesitter)
	end

	if opts.lsp and opts.lsp.enable then
		require("bsv.lsp").enable(opts.lsp)
	end

	if not opts.format or opts.format.enable ~= false then
		require("bsv.format").setup_buffer()
	end
end

return M
