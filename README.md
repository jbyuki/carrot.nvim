# carrot.nvim

Execute Neovim Lua code inside Markdown.


```lua
print("Hover a code block and execute it.")
```
> Hover a code block and execute it.

## Prerequisites

* Neovim 0.7.0+
* Tree-sitter : [nvim-treesitter/nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
* Markdown parser : Install with `TSInstall markdown`.

Make sure that the markdown parser is installed with:

```lua
local buf = vim.api.nvim_create_buf(false, true)
local parser = vim.treesitter.get_parser(buf, "markdown")
print(parser)
```
> table: 0x016d2946f6c8

## Usage 

* Hover the cursor over a lua code block
* Execute `:CarrotEval`

## Examples

* [example.md](test/example.md)
