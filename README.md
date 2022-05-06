# carrot.nvim ![license](https://img.shields.io/github/license/jbyuki/carrot.nvim) ![version](https://img.shields.io/badge/version-0.0.1-blue)

Markdown evaluator for Neovim Lua code blocks. 

It allows to output the result in the markdown. This is nice because it allows to save and share the code with the results.

This is still _work-in-progress_ but the main code evaluation functionnalities should be working.

The plugins tries to be **not intrusive**. It won't redefine `print()` to redirect the result, it uses a subprocess neovim to evaluate the code in a sandboxed environnement.

It also tries to keep the spirit of Markdown files and show results in a simple but pleasing way.

![carrot screenshot](https://raw.githubusercontent.com/jbyuki/gifs/main/carrot.png)

## Prerequisites

* Neovim 0.7.0+
* Tree-sitter : [nvim-treesitter/nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
* Markdown parser : Install with `TSInstall markdown`.

Make sure that the markdown parser is installed with:

```lua
local buf = vim.api.nvim_create_buf(false, true)
local parser = vim.treesitter.get_parser(buf, "markdown")
assert(parser, "The markdown parser is not installed.")
print("OK")
```
```output[13]
OK
```

## Usage 

* Hover the cursor over a lua code block
* Execute `:CarrotEval`

## Examples

* [example.md](test/example.md)
* [internals.md](test/internals.md)

