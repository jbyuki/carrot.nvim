vim.cmd [[command! CarrotEval lua require"carrot".execute_normal()]]
vim.cmd [[command! CarrotNewBlock lua require"carrot".create_new_block()]]
vim.cmd [[command! CarrotStop lua require"carrot".stop()]]
vim.cmd [[command! CarrotRunAll lua require"carrot".execute_all()]]
