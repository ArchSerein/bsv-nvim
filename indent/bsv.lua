local indent = require("bsv.indent")
local lang = require("bsv.lang")

function _G.bsv_indentexpr()
  return indent.indentexpr()
end

vim.bo.indentexpr = "v:lua.bsv_indentexpr()"
vim.bo.indentkeys = lang.default_indentkeys
