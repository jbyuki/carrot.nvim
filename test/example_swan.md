## Example swan

[swan.lua](https://github.com/jbyuki/swan.lua) is a math symbolic toolbox. Let's try
to use it to do some calculation.

```lua
swan = require"swan"
x = swan.sym "x"
exp = 2*x^2
print(exp)
```
> 2x^2

```lua
print(exp:derivate(x))
```
> 2x

```lua
y = swan.sym "y"
print(y)
```
> y
