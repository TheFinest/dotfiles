vim.keymap.set("n", "<leader>mi", ":MoltenInit python3<CR>");
vim.keymap.set("x", "<leader>me", ":<C-U>MoltenEvaluateVisual<CR>");
vim.keymap.set("n", "<leader>mel", ":MoltenEvaluateLine<CR>");
vim.keymap.set("n", "<leader>meo", ":noautocmd MoltenEnterOutput<CR>");
vim.keymap.set("n", "<leader>mr", ":MoltenReevaluateCell<CR>");

vim.cmd[[
let g:molten_image_provider = "none"
]]
