-- lua/bsv/init.lua
-- Optional user-facing setup (plugin works without calling setup()).

local M = {}

---@class bsv.SetupOpts
---@field treesitter? { register?: boolean, url?: string }
---@field silent? boolean

---@param opts? bsv.SetupOpts
function M.setup(opts)
	opts = opts or {}
	if opts.treesitter and opts.treesitter.register then
		require("bsv.treesitter").register(opts.treesitter)
	end
end

return M
