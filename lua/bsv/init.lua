local M = {}

local defaults = {
  indent_width = 2,
  max_columns = 100,
  format_on_save = false,
  trim_trailing_whitespace = true,
}

M.config = vim.deepcopy(defaults)

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})

  local group = vim.api.nvim_create_augroup("bsv_nvim", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "bsv",
    callback = function(args)
      vim.bo[args.buf].commentstring = "// %s"
      vim.bo[args.buf].expandtab = true
      vim.bo[args.buf].shiftwidth = M.config.indent_width
      vim.bo[args.buf].tabstop = M.config.indent_width
      vim.bo[args.buf].softtabstop = M.config.indent_width
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePre", {
    group = group,
    pattern = { "*.bsv", "*.bs" },
    callback = function(args)
      if vim.b[args.buf].bsv_format_on_save == false then
        return
      end
      if vim.b[args.buf].bsv_format_on_save or M.config.format_on_save then
        require("bsv.format").buffer({
          bufnr = args.buf,
          trim_trailing_whitespace = M.config.trim_trailing_whitespace,
        })
      end
    end,
  })
end

M.format = require("bsv.format")

return M
