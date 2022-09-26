##carrot
@define+=
function M.stop()
  @close_neovim_instance
  @close_server
end

@close_neovim_instance+=
if kernel then
  vim.fn.jobstop(kernel)
  kernel = nil
end

@close_server+=
if server then
  server:close()
  server = nil
end
