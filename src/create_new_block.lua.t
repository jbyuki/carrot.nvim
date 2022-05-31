##carrot
@define+=
function M.create_new_block()
  @get_cursor_location
  @append_new_lua_block
  @place_cursor_inside_block
end

@get_cursor_location+=
local row, _ = unpack(vim.api.nvim_win_get_cursor(0))

@append_new_lua_block+=
local lua_block = {
  "```lua",
  "",
  "```",
}

vim.api.nvim_buf_set_lines(0, row, row, true, lua_block)

@place_cursor_inside_block+=
vim.api.nvim_win_set_cursor(0, {row+2, 0})
