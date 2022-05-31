-- Generated using ntangle.nvim
local M = {}
local bufnr

local code_node

local kernel, server, sock

local send_code

local client

local client_chunk = ""

local print_results = {}

local server_chunk = ""

local cell_idx = 1

local end_row

local log_filename

function M.create_new_block()
  local row, _ = unpack(vim.api.nvim_win_get_cursor(0))

  local lua_block = {
    "```lua",
    "",
    "```",
  }

  vim.api.nvim_buf_set_lines(0, row, row, true, lua_block)

  vim.api.nvim_win_set_cursor(0, {row+2, 0})
end

function M.execute_normal()
  local ft = vim.api.nvim_buf_get_option(0, "ft")

  if ft == "markdown" then
    local parser = vim.treesitter.get_parser()
    assert(parser , "Treesitter not enabled in current buffer!")

    local tree = parser:parse()
    local block_lang = ""
    assert(#tree > 0, "Parsing current buffer failed!")

    tree = tree[1]
    root = tree:root()

    local row, col = unpack(vim.api.nvim_win_get_cursor(0))


    local selected_node = tree:root():descendant_for_range(
      row-1, col, row-1, col)

    code_node = selected_node
    while code_node and code_node:type() ~= "fenced_code_block" do
      code_node = code_node:parent()
    end


    assert(code_node:type() == "fenced_code_block", "Cursor not on a fenced_code_block node!")

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


    if lang == "lua" then
      bufnr = vim.api.nvim_get_current_buf()
      if not kernel then
        kernel = vim.fn.jobstart({vim.v.progpath, '--embed', '--headless'}, {rpc = true})
        M.log(("kernel %s"):format(kernel))

        if log_filename then
          vim.rpcnotify(kernel, 'nvim_exec_lua', [[require"carrot".enable_log()]], {})
        end
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
              server_chunk = server_chunk .. chunk
              M.log("server rec " .. server_chunk )
              if server_chunk:find("\0") then
                local N, _ = server_chunk:find("\0")
                local msg = server_chunk:sub(1, N-1)

                vim.schedule(function()
                  _, _, end_row, _ = code_node:range()
                  local next_node = code_node:next_sibling()
                  if next_node and next_node:type() == "fenced_code_block" then
                    local start_row, _, end_row, _ = next_node:range()
                    vim.api.nvim_buf_set_lines(bufnr, start_row, end_row, true, {})
                  end

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

                end)

                server_chunk = server_chunk:sub(N+1)
              end

            else
              M.log("client closed.")
              sock:close()
              sock = nil
            end
          end)

          send_code()
          send_code = nil

        end)
        M.log("server started on port " .. server:getsockname().port)

        send_code = function()
          M.log("server send " .. table.concat(content, "\n"))
          sock:write(table.concat(content, "\n") .. "\0")
        end

        vim.rpcnotify(kernel, 'nvim_exec_lua', [[require"carrot".redefine_print()]], {})

        vim.rpcnotify(kernel, 'nvim_exec_lua', [[require"carrot".create_client(...)]], { server:getsockname().port })

      else
        M.log("server send " .. table.concat(content, "\n"))
        sock:write(table.concat(content, "\n") .. "\0")

      end
    else
      print("Unsupported language!")
    end
  else
    print("Unsupported filetype!")
  end
end

function M.create_client(port)
  client = vim.loop.new_tcp()

  client:connect("127.0.0.1", port, function(err)
    if err then
      M.log("client " .. err)
    end
    assert(not err, err)

    M.log("client started")
    client:read_start(function(err, chunk)
      assert(not err, err)
      if chunk then
        M.log("client rec " .. chunk)
        client_chunk = client_chunk .. chunk
        if client_chunk:find("\0") then
          local N, _ = client_chunk:find("\0")
          local lua_code = client_chunk:sub(1, N-1)

          print_results = {}


          vim.schedule(function()
            local f, errmsg = loadstring(lua_code)
            if not f then
              client:write(errmsg .. "\0")
            end

            if f then
              local success, errmsg = pcall(f)
              M.log(("client execute %s %s"):format(success, errmsg))

              if not success then
                client:write(errmsg .. "\0")
              end

              if success then
                M.log(vim.inspect(print_results))
                client:write(table.concat(print_results, "\n") .. "\0")
              end

            end
          end)

          client_chunk = client_chunk:sub(N+1)
        end

      end
    end)

  end)

end

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

function M.enable_log()
  log_filename = vim.fn.stdpath("data") .. "/carrot.log"
end

function M.log(str)
  if log_filename then
    local f = io.open(log_filename, "a")
    date = os.date("%x %X")
    f:write("[" .. date .. "]: " .. str .. "\n")
    f:close()
  end
end

function M.version()
  return "0.0.1"
end
return M
