# bsv.nvim

Neovim runtime support for Bluespec SystemVerilog (`.bsv` and `.bs`) based on the Bluespec SystemVerilog reference guide in this repository.

## Features

- Filetype detection for Bluespec files.
- Syntax highlighting for BSV keywords, SystemVerilog-reserved identifiers, comments, strings, numeric literals, compiler directives, attributes, and system tasks.
- Indentation support for common BSV block keywords.
- `:BsvFormat` formatter command with a conservative Google-style profile:
  - 2-space indentation by default.
  - Spaces around binary operators.
  - Compact function/type application such as `foo(x)` and `Bit#(32)`.
  - Trimmed trailing whitespace.
- Save-time formatting is disabled by default. Use `:BsvFormat` to format manually.

The formatter is intentionally conservative. It does not reorder declarations, wrap expressions, or attempt semantic rewrites.

## Setup

With a plugin manager, load this directory as a normal Neovim plugin. The plugin auto-registers commands and default settings.

Optional configuration:

```lua
require("bsv").setup({
  indent_width = 2,
  max_columns = 100,
  format_on_save = false,
  trim_trailing_whitespace = true,
})
```

Enable format-on-save per buffer:

```vim
:BsvFormatEnable
```

Format manually:

```vim
:BsvFormat
```

Trim only trailing whitespace:

```vim
:BsvTrimTrailingWhitespace
```

Visual selections are supported:

```vim
:'<,'>BsvFormat
```
