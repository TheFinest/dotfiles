vim.keymap.set("n", "<leader>mi", ":MagmaInit python3<CR>");
vim.keymap.set("x", "<leader>me", ":<C-U>MagmaEvaluateVisual<CR>");
vim.keymap.set("n", "<leader>mel", ":MagmaEvaluateLine<CR>");
vim.keymap.set("n", "<leader>meo", ":noautocmd MagmaEnterOutput<CR>");
vim.keymap.set("n", "<leader>mr", ":MagmaReevaluateCell<CR>");

vim.cmd[[
let g:magma_image_provider = "none"
]]
