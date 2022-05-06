## Example

Let's check the neovim version

```lua
print(vim.inspect(vim.version()))
```
```output[4](05/06/22 13:48:57)
{
  api_compatible = 0,
  api_level = 9,
  api_prerelease = true,
  major = 0,
  minor = 7,
  patch = 0
}
```

Printing is done with a regular print.

```lua
print("Hello world!")
```
```output[3](05/06/22 13:48:55)
Hello world!
```

We can also print multiple lines

```lua
for i=1,10 do
  print(i)
end
```
```output[2](05/06/22 13:48:52)
1
2
3
4
5
6
7
8
9
10
```

In case of an error, it's simply print out.

```lua
local a =
```
```output[1](05/06/22 13:48:46)
[string "local a =..."]:2: unexpected symbol near '<eof>'
```
