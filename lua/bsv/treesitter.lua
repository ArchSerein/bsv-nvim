-- lua/bsv/treesitter.lua
-- Helpers to register the BSV Tree-sitter parser with nvim-treesitter.
--
-- This file tries to support both:
-- - the newer nvim-treesitter API (main branch rewrite), and
-- - the older API (get_parser_configs()).
--
-- The recommended grammar is:
--   https://github.com/yuyuranium/tree-sitter-bsv

local M = {}

---@param opts? { url?: string }
function M.register(opts)
	opts = opts or {}
	local url = opts.url or "https://github.com/yuyuranium/tree-sitter-bsv"

	local ok, parsers = pcall(require, "nvim-treesitter.parsers")
	if not ok then
		return
	end

	-- Newer API (main rewrite): users are instructed to set this in a User TSUpdate autocmd.
	-- We do the same here so the config is available when :TSInstall runs.
	vim.api.nvim_create_autocmd("User", {
		pattern = "TSUpdate",
		callback = function()
			-- In the rewrite, parsers are stored directly on the module table.
			parsers.bsv = parsers.bsv or {}
			parsers.bsv.install_info = {
				url = url,
				files = { "src/parser.c", "src/scanner.c" },
				-- Safer default: generate parser.c from grammar.js if needed.
				generate = true,
				-- If the grammar repo contains queries, they can optionally be installed.
				-- But this plugin ships queries in queries/bsv/, so this is not required.
				-- queries = "queries",
			}
		end,
	})

	-- Older API (master branch): get_parser_configs() table.
	if type(parsers.get_parser_configs) == "function" then
		local cfgs = parsers.get_parser_configs()
		cfgs.bsv = cfgs.bsv or {}
		cfgs.bsv.install_info = {
			url = url,
			files = { "src/parser.c", "src/scanner.c" },
			generate = true,
		}
		cfgs.bsv.filetype = "bsv"
	end

	-- If parser name differs from filetype, register it. Here they match, but harmless.
	pcall(function()
		vim.treesitter.language.register("bsv", { "bsv" })
	end)
end

return M
