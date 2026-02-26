# bsv.nvim

A small **Lua-first Neovim plugin** for Bluespec SystemVerilog (BSV), including highlighting and LSP integration.

## Features

- Filetype detection for `.bsv` / `.BSV`
- Tree-sitter highlighting (preferred) via `queries/bsv/highlights.scm`
- Fallback Vim regex syntax highlighting via `syntax/bsv.vim`
- Built-in LSP config for [`blues-lsp`](https://crates.io/crates/blues-lsp)
- Minimal ftplugin: `commentstring=// %s`

## Requirements

- Neovim 0.11.x (latest stable recommended)
- For Tree-sitter highlighting: a BSV parser installed (see below)

## Installation

```bash
git clone https://github.com/ArchSerein/bsv-nvim.git ~/.config/nvim/plugins/bsv.nvim
nvim test.bsv
```

## Tree-sitter parser installation

This plugin ships only query files. You must install a BSV Tree-sitter parser separately.

Recommended grammar: https://github.com/yuyuranium/tree-sitter-bsv

```bash
git clone https://github.com/yuyuranium/tree-sitter-bsv
tree-sitter generate
cc -O2 -fPIC -c src/parser.c
cc -shared parser.o -o ~/.local/share/nvim/site/parser/bsv.so
```

## Snippets (LuaSnip)

This plugin ships a VSCode snippet package under `snippets/`.
To load it:

```lua
require("luasnip.loaders.from_vscode").lazy_load()
```

## LSP (`blues-lsp`)

This plugin ships an LSP config in `lsp/blues.lua` and an optional helper `require("bsv").setup` integration.

### Install `blues-lsp`

`blues-lsp` is published on crates.io, so you can install it with Cargo:

```bash
cargo install blues-lsp --locked
```

After installation, check which binary exists in your environment:

```bash
command -v blues-lsp || command -v blues
```

`bsv.nvim` defaults to `blues-lsp` and will automatically fall back to `blues` if needed.

### Neovim 0.11+ builtin LSP

```lua
require("bsv").setup({
  lsp = { enable = true },
})
```

### Manual setup with `nvim-lspconfig`

```lua
require("lspconfig").blues.setup({})
```

## lazy.nvim example

```lua
return {
  {
    dir = vim.fn.stdpath("config") .. "/plugins/bsv.nvim",
    name = "bsv.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("bsv").setup({
        lsp = {
          enable = true,
          -- optional: force binary if needed
          cmd = { "blues-lsp" },
        },
      })
    end,
  },
}
```
