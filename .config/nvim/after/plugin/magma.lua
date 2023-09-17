vim.keymap.set("n", "<leader>r", ":MagmaEvaluateOperator<CR>")
vim.keymap.set("n", "<leader>rr", ":MagmaEvaluateLine<CR>")

vim.cmd[[
let g:magma_image_provider = "none"
]]
