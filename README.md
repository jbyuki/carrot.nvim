## carrot.nvim

Execute Neovim Lua code inside markdown.

```lua
print("Hello carrot.nvim!")
```
> Hello carrot.nvim!


### Features

This is still a work-in-progress. More features to come.

* Execute cell and append result
* Asynchronous evaluation

### Prerequisites

* Neovim 0.7.0+
* Tree-sitter : [nvim-treesitter/nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
* Markdown parser : Install with `TSInstall markdown`.

### Usage 

* Hover the cursor over a lua code block
* Execute `:CarrotEval`

### Examples

* [example.md](test/example.md)
* [example_swan.md](test/example_swan.md)

### Name

I like carrots. They are good.

### Related

There are more mature plugins that have similar functionnalities.

Some examples:

* [jubnzv/mdeval.nvim](https://github.com/jubnzv/mdeval.nvim) - Run code blocks in Markdown.
* [bfredl/nvim-luadev](https://github.com/bfredl/nvim-luadev) - Execute Neovim Lua with a proper REPL.
* [ii14/nrepl.nvim](https://github.com/ii14/nrepl.nvim) - Cool plugin which offers seamless REPL experience for Neovim Lua and Vimscript.
