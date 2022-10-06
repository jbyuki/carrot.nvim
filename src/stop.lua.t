##carrot
@define+=
function M.stop()
  @clear_queue
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
