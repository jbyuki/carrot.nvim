-- Generated using ntangle.nvim
local M = {}
local bufnr

local code_node

local kernel, server, sock

local send_code

local client_chunk = ""

local print_results = {}

local server_chunk = ""

local end_row

local log_filename

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
                  while true do
                    local row_count = vim.api.nvim_buf_line_count(bufnr)
                    if end_row >= row_count then
                      break
                    end

                    local line = vim.api.nvim_buf_get_lines(bufnr, end_row, end_row+1, true)[1]
                    if line:match("^>") then
                      vim.api.nvim_buf_set_lines(bufnr, end_row, end_row+1, true, {})
                    else
                      break
                    end
                  end

                  local lines = vim.split(msg, "\n")
                  for i=1,#lines do
                    if #lines[i] > 0 then
                      lines[i] = "> " .. lines[i]
                    end
                  end
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
  local client = vim.loop.new_tcp()

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

          local f, errmsg = loadstring(lua_code)
          if not f then
            client:write(errmsg .. "\0")
          end

          if f then
            local success, errmsg = pcall(f)
            M.log(("client execute %s %s"):format(success, errmsg))

            if not success then
              client:write(errmsg .. "\n")
            end

            if success then
              M.log(vim.inspect(print_results))
              client:write(table.concat(print_results, "\n") .. "\0")
            end

          end
          client_chunk = client_chunk:sub(N+1)
        end

      end
    end)

  end)

end

function M.redefine_print()
  print = function(str)
    if type(str) ~= "string" then
      str = tostring(str)
    end
    table.insert(print_results, str)
  end
end

function M.enable_log()
  log_filename = vim.fn.stdpath("data") .. "/carrot.log"
end

function M.log(str)
  if log_filename then
    local f = io.open(log_filename, "a")
    f:write(str .. "\n")
    f:close()
  end
end

function M.version()
  return "0.0.1"
end
return M
