##carrot
@variables+=
local log_filename

@define+=
function M.enable_log()
  log_filename = vim.fn.stdpath("data") .. "/carrot.log"
end

@define+=
function M.log(str)
  if log_filename then
    local f = io.open(log_filename, "a")
    date = os.date("%x %X")
    f:write("[" .. date .. "]: " .. str .. "\n")
    f:close()
  end
end
