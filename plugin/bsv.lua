if vim.g.loaded_bsv_nvim == 1 then
  return
end
vim.g.loaded_bsv_nvim = 1

vim.api.nvim_create_user_command("BsvFormat", function(opts)
  local range = {}
  if opts.range and opts.range > 0 then
    range.start_line = opts.line1
    range.end_line = opts.line2
  end
  require("bsv.format").buffer(range)
end, {
  range = true,
  desc = "Format the current Bluespec buffer or selected range",
})

vim.api.nvim_create_user_command("BsvTrimTrailingWhitespace", function(opts)
  local range = {}
  if opts.range and opts.range > 0 then
    range.start_line = opts.line1
    range.end_line = opts.line2
  end
  require("bsv.format").trim_trailing_buffer(range)
end, {
  range = true,
  desc = "Trim trailing whitespace in the current Bluespec buffer or selected range",
})

vim.api.nvim_create_user_command("BsvFormatDisable", function()
  vim.b.bsv_format_on_save = false
end, {
  desc = "Disable Bluespec format-on-save for the current buffer",
})

vim.api.nvim_create_user_command("BsvFormatEnable", function()
  vim.b.bsv_format_on_save = true
end, {
  desc = "Enable Bluespec format-on-save for the current buffer",
})

if vim.g.bsv_auto_setup ~= false then
  require("bsv").setup(vim.g.bsv or {})
end
