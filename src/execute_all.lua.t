##carrot
@define+=
function M.execute_all()
  @get_filetype
  if ft == "markdown" then
    @get_all_code_blocks
    @queue_code_execution_run_all
    local bufnr = vim.api.nvim_get_current_buf()
    if not kernel then
      @spawn_neovim_instance
      @enable_debug_if_enabled_in_server
      @create_server
      @redefine_print_in_instance
      @create_client_in_instance
    else
      @run_next_in_queue
    end
  end
end

@get_all_code_blocks+=
@get_ts_tree
@get_all_fenced_code_blocks

@get_all_fenced_code_blocks+=
local ts_query = [[
  (fenced_code_block 
    (info_string (language) @lang) 
    (code_fence_content) @content) @block
]]

local query = vim.treesitter.parse_query("markdown", ts_query)
local contents = {}
local nodes = {}

for pattern, match, metadata in query:iter_matches(root, 0) do
  local lang, content, block
  for id, node in pairs(match) do
    @get_lang_and_content
    if name == "block" then
      block = node
    end
  end


  if lang == "lua" then
    table.insert(contents, content)
    table.insert(nodes, block)
  end
end

@variables+=
local fifo = {}

@clear_queue+=
fifo = {}

@queue_code_execution_run_all+=
for i=#nodes,1,-1 do
  table.insert(fifo, {
    contents[i], nodes[i]
  })
end

@variables+=
local last_node

@run_next_in_queue+=
if #fifo > 0 then
  vim.schedule(function()
    local content, node = unpack(fifo[#fifo])
    table.remove(fifo)
    last_node = node

    M.log("server send " .. table.concat(content, "\n"))
    sock:write(table.concat(content, "\n") .. "\0")
  end)
end


@add_current_to_queue+=
table.insert(fifo, {
  content, code_node
})
