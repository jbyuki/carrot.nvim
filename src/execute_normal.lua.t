##carrot
@define+=
function M.execute_normal()
  @get_filetype
  if ft == "markdown" then
    @get_current_code_region_using_ts
    @get_language_of_current_code_region
    if lang == "lua" then
      bufnr = vim.api.nvim_get_current_buf()
      if not kernel then
        @spawn_neovim_instance
        @enable_debug_if_enabled_in_server
        @create_server
        @set_callback_to_send_first_code
        @redefine_print_in_instance
        @create_client_in_instance
      else
        @send_code_to_client
      end
    else
      print("Unsupported language!")
    end
  else
    print("Unsupported filetype!")
  end
end

@variables+=
local bufnr

@get_filetype+=
local ft = vim.api.nvim_buf_get_option(0, "ft")

@get_current_code_region_using_ts+=
local parser = vim.treesitter.get_parser()
assert(parser , "Treesitter not enabled in current buffer!")

local tree = parser:parse()
local block_lang = ""
assert(#tree > 0, "Parsing current buffer failed!")

tree = tree[1]
root = tree:root()

@get_cursor_position

local selected_node = tree:root():descendant_for_range(
  row-1, col, row-1, col)

@get_node_node_for_code_block

assert(code_node:type() == "fenced_code_block", "Cursor not on a fenced_code_block node!")

@get_node_node_for_code_block+=
code_node = selected_node
while code_node and code_node:type() ~= "fenced_code_block" do
  code_node = code_node:parent()
end

@variables+=
local code_node

@get_cursor_position+=
local row, col = unpack(vim.api.nvim_win_get_cursor(0))

@get_language_of_current_code_region+=
-- Example node structure for code_node
--
-- (fenced_code_block (fenced_code_block_delimiter) (info_string (language)) (code_fence_content) (fenced_code_block_delimiter))
local ts_query = [[
  (fenced_code_block 
    (info_string (language) @lang) 
    (code_fence_content) @content)
]]

local query = vim.treesitter.parse_query("markdown", ts_query)

local lang, content

for id, node, metadata in query:iter_captures(code_node, 0) do
  local name = query.captures[id]
  local start_row, start_col, end_row, end_col = node:range()
  local text = vim.api.nvim_buf_get_text(0, start_row, start_col, end_row, end_col, {})

  if name == "lang" then
    lang = text[1]
  elseif name == "content" then
    content = text
  end
end


@variables+=
local kernel, server, sock

@spawn_neovim_instance+=
kernel = vim.fn.jobstart({vim.v.progpath, '--embed', '--headless'}, {rpc = true})
M.log(("kernel %s"):format(kernel))

@create_server+=
local server = vim.loop.new_tcp()
server:bind("127.0.0.1", 0)
server:listen(128, function(err)
  assert(not err, err)  -- Check for errors.
  sock = vim.loop.new_tcp()
  server:accept(sock)  -- Accept client connection.

  M.log("client connected!")

  sock:read_start(function(err, chunk)
    assert(not err, err)  -- Check for errors.
    if chunk then
      @read_chunk_from_client
    else
      M.log("client closed.")
      sock:close()
      sock = nil
    end
  end)

  @send_first_code
end)
M.log("server started on port " .. server:getsockname().port)

@create_client_in_instance+=
vim.rpcnotify(kernel, 'nvim_exec_lua', [[require"carrot".create_client(...)]], { server:getsockname().port })

@variables+=
local send_code

@set_callback_to_send_first_code+=
send_code = function()
  M.log("server send " .. table.concat(content, "\n"))
  sock:write(table.concat(content, "\n") .. "\0")
end

@send_first_code+=
send_code()
send_code = nil

@send_code_to_client+=
M.log("server send " .. table.concat(content, "\n"))
sock:write(table.concat(content, "\n") .. "\0")

@define+=
function M.create_client(port)
  @create_tcp_client
  @connect_client
end

@variables+=
local client

@create_tcp_client+=
client = vim.loop.new_tcp()

@connect_client+=
client:connect("127.0.0.1", port, function(err)
  if err then
    M.log("client " .. err)
  end
  assert(not err, err)

  M.log("client started")
  @start_client_read
end)

@start_client_read+=
client:read_start(function(err, chunk)
  assert(not err, err)
  if chunk then
    M.log("client rec " .. chunk)
    @read_client_chunk
  end
end)

@variables+=
local client_chunk = ""

@read_client_chunk+=
client_chunk = client_chunk .. chunk
if client_chunk:find("\0") then
  local N, _ = client_chunk:find("\0")
  local lua_code = client_chunk:sub(1, N-1)

  @clear_print_list

  vim.schedule(function()
    @load_lua_code
    if f then
      @execute_lua_code
      @if_error_send_msg
      @if_success_send_prints
    end
  end)

  client_chunk = client_chunk:sub(N+1)
end

@load_lua_code+=
local f, errmsg = loadstring(lua_code)
if not f then
  client:write(errmsg .. "\0")
end

@execute_lua_code+=
local success, errmsg = pcall(f)
M.log(("client execute %s %s"):format(success, errmsg))

@if_error_send_msg+=
if not success then
  client:write(errmsg .. "\0")
end

@redefine_print_in_instance+=
vim.rpcnotify(kernel, 'nvim_exec_lua', [[require"carrot".redefine_print()]], {})

@variables+=
local print_results = {}

@clear_print_list+=
print_results = {}

@define+=
function M.redefine_print()
  print = function(...)
    local strs = {}
    for _, elem in ipairs({ ... }) do
      if type(elem) ~= "string" then
        elem = tostring(elem)
      end
      table.insert(strs, elem)
    end
    table.insert(print_results, table.concat(strs, " "))
  end
end

@if_success_send_prints+=
if success then
  M.log(vim.inspect(print_results))
  client:write(table.concat(print_results, "\n") .. "\0")
end

@variables+=
local server_chunk = ""

@read_chunk_from_client+=
server_chunk = server_chunk .. chunk
M.log("server rec " .. server_chunk )
if server_chunk:find("\0") then
  local N, _ = server_chunk:find("\0")
  local msg = server_chunk:sub(1, N-1)

  vim.schedule(function()
    @remove_previous_results
    @append_msg_to_markdown
  end)

  server_chunk = server_chunk:sub(N+1)
end

@variables+=
local cell_idx = 1

@append_msg_to_markdown+=
local lines = {}
table.insert(lines, ("```output[%d](%s)"):format(cell_idx, os.date("%x %X")))
cell_idx = cell_idx + 1
if not msg:match("^%s*$") then
  for line in vim.gsplit(msg, "\n") do
    table.insert(lines, line)
  end
end
table.insert(lines, "```")
vim.api.nvim_buf_set_lines(bufnr, end_row, end_row, true, lines)

@variables+=
local end_row

@remove_previous_results+=
_, _, end_row, _ = code_node:range()
local next_node = code_node:next_sibling()
if next_node and next_node:type() == "fenced_code_block" then
  local start_row, _, end_row, _ = next_node:range()
  vim.api.nvim_buf_set_lines(bufnr, start_row, end_row, true, {})
end

@enable_debug_if_enabled_in_server+=
if log_filename then
  vim.rpcnotify(kernel, 'nvim_exec_lua', [[require"carrot".enable_log()]], {})
end
