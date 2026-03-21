local layout = require("bsv.layout")

local M = {}

function M.indentexpr()
  return layout.compute_indent(vim.v.lnum, vim.bo.shiftwidth, vim.fn.getline)
end

return M
