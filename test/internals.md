## Internals.md

This document briefly explains how [carrot.nvim]() works by providing short Lua snippets of the most important part of the plugin.

### Execute Lua code as string

Let's see how we can execute Lua code. Lua provides the [loadstring](https://www.lua.org/pil/8.html) function which allows to execute lua code in a string.

```lua
local code = "a = 2"
f = loadstring(code)
print(f)
```
```output[1]
function: 0x0199e8fa2a70
```

The loadstring takes as parameter the code as a string and returns a function. We can call the function to execute the code. This seems a little odd to do, why is not the lua code directly executed, but actually it allows to catch any syntax error in the code. If for example, we pass a incorrect code to `loadstring`, we get:

```lua
local code = "a = "
f, errmsg = loadstring(code)
print(f)
print(errmsg)
```
```output[2]
nil
[string "a = "]:1: unexpected symbol near '<eof>'
```

A second return value indicates the syntax error. So we have to make sure this is not the case.

OK, let's assume the code is correct and run the function.

```lua
local code = "a=2"
f = loadstring(code)
f()
print(a)
```
```output[3]
2
```

It behaves normally i.e. the code executed with loadstring live in the same environnement as the host code. The value of a can be set in the code and print out afterwards.

### Redefine `print()`

If it was that easy, the resulting code would be much shorter. Unfortunately, we have to do some acrobatic to get back the print result and put in the markdown. There is no easy way to get programmatically what was printed in Neovim. Fortunately, there are some workaround. 

The first thing to notice is that `print()` in Lua is actually a global symbol like any other which can be redefined by the user. But it would be very unwise of a plugin to touch this global symbol without the user knowing it. It could interfere with other plugins or create very difficult to debug bugs. Instead, we have to be more clever.

We need to create a whole separate Lua environnement where we can freely redefine `print()` and execute Lua code without touching the main user's environnement. There are mainly two possible ways:

* Make a thread with `vim.loop.new_thread`. The code executed in a thread has a separate Lua environnement in the new Neovim versions.
* Spawn a whole new Neovim instance.

The thread approach is interesting because it's "lightweight" in terms of code and execution. The only issue is that the code execution in a thread is very limited. 
  * It does not support every function that Neovim Lua has. This is mainly due to the thread not having its own event loop.
  * The thread can communicate to the main thread with `vim.loop.new_async` and `async_send`, but the opposite is not possible. We need bidirectional communication.
  * The thread cannot be yielded or resumed.

The main advantage is that redefining `print()` does not affect the main Lua environnement but the problems are too limiting.

The other approach is used in [carrot.nvim](). It is actually not that hard to spawn a new Neovim instance. It is further documented in `:help rpc`. We use the function `jobstart` to create an instance of neovim (as a separate OS process), because we don't need to display anything, we pass `--headless` and `--embed` is used so that stdin/stdout are used to pass msgpack-RPC to the neovim instance. It returns a channel. It's just a number.

```lua
local kernel = vim.fn.jobstart({vim.v.progpath, '--embed', '--headless'}, {rpc = true})
print(kernel)
vim.fn.jobstop(kernel)
```
```output[4]
3
```

We can communicate to this Neovim instance by using the RPC protocol. This allows to execute any API function, in particular for Lua, we are interested in `nvim_exec_lua`.

```lua
local kernel = vim.fn.jobstart({vim.v.progpath, '--embed', '--headless'}, {rpc = true})
local ret = vim.rpcrequest(kernel, "nvim_exec_lua", [[return "hello from child process"]], {})
print(ret)
vim.fn.jobstop(kernel)
```
```output[5]
hello from child process
```

Any value which is returned by the Lua code can be retrieved with the return value of `rpcrequest`. It shows that we can nicely execute lua code in a separate environnement. This opens a lot of possibilities. Let's have a process opened and do some experiments.

```lua
kernel = vim.fn.jobstart({vim.v.progpath, '--embed', '--headless'}, {rpc = true})
vim.rpcrequest(kernel, "nvim_exec_lua", [[function foo() return "hello world" end]], {})
```
```output[6]
```

This defines a function. We can now call it later because the environnement is preserved.

```lua
local ret = vim.rpcrequest(kernel, "nvim_exec_lua", [[return foo()]], {})
print(ret)
```
```output[7]
hello world
```

We can redefine `print()` safely without touching the user's environnement.

```lua
vim.rpcrequest(kernel, "nvim_exec_lua", [[
  print = function(str) 
    last_print = str .. " :)"
  end
]], {})
```
```output[8]
```

Now, let's try calling the redefined print.

```lua
vim.rpcrequest(kernel, "nvim_exec_lua", [[
  print("hello")
]], {})
```
```output[9]
```

And we can get the printed string back.

```lua
local ret = vim.rpcrequest(kernel, "nvim_exec_lua", [[
  return last_print
]], {})
print(ret)
```
```output[11]
hello :)
```
