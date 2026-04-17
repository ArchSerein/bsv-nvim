vim.bo.commentstring = "// %s"
vim.bo.comments = "s1:/*,mb:*,ex:*/,://"
vim.bo.expandtab = true
vim.bo.shiftwidth = vim.g.bsv_shiftwidth or 2
vim.bo.tabstop = vim.g.bsv_tabstop or vim.bo.shiftwidth
vim.bo.softtabstop = vim.bo.shiftwidth

vim.b.undo_ftplugin = table.concat({
  "setlocal commentstring<",
  "setlocal comments<",
  "setlocal expandtab<",
  "setlocal shiftwidth<",
  "setlocal tabstop<",
  "setlocal softtabstop<",
}, " | ")
