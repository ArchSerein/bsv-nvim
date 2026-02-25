# bsv.nvim

A small **Lua-first Neovim plugin** providing Bluespec SystemVerilog (BSV) syntax highlighting.

## Features

- Filetype detection for `.bsv` / `.BSV`
- Tree-sitter highlighting (preferred) via `queries/bsv/highlights.scm`
- Fallback Vim regex syntax highlighting via `syntax/bsv.vim`
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
