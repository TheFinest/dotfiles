-- ========================================================================== --
-- 1. GLOBAL SETTINGS (Set leader first)
-- ========================================================================== --
vim.g.mapleader = " "

-- UI & UX
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.guicursor = ""
vim.opt.scrolloff = 8
vim.opt.termguicolors = true
vim.opt.updatetime = 50
vim.opt.title = true

-- Tabs & Indent
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true

-- Persistent Undo
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

-- ========================================================================== --
-- 2. THE "SHUT UP" PROTOCOL (Stability & Silence)
-- ========================================================================== --
vim.opt.shortmess:append("FWIc")

-- Silence diagnostic noise (inline red text/icons)
vim.diagnostic.config({
    virtual_text = false, 
    signs = false,        
    underline = true,
    severity_sort = true,
})

-- Redirect all notifications to simple print statements to prevent UI hijacking
vim.notify = function(msg, log_level)
    if log_level == vim.log.levels.ERROR then
        vim.api.nvim_echo({{ "NVIM ERROR: " .. msg, "ErrorMsg" }}, true, {})
    end
end

-- ========================================================================== --
-- 3. PLUGIN BOOTSTRAP (lazy.nvim)
-- ========================================================================== --
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    -- The essentials
    'mbbill/undotree',
    'neovim/nvim-lspconfig',
}, {
    -- STABILITY LOCK: No auto-updates, no change notifications
    checker = { enabled = false },
    change_detection = { enabled = false },
    ui = { border = "rounded" },
})

-- ========================================================================== --
-- 4. MINIMAL LSP (Only for Jump to Definition)
-- ========================================================================== --
local status, lspconfig = pcall(require, 'lspconfig')
if status then
    -- List the servers you use. Ensure these are installed on your machine.
    local servers = { 'pyright', 'clangd', 'rust_analyzer', 'ts_ls' } 
    for _, lsp in ipairs(servers) do
        lspconfig[lsp].setup({
            on_attach = function(client, bufnr)
                local opts = { buffer = bufnr }
                vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
                vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
            end,
            -- Prevent the LSP from being too chatty
            flags = { debounce_text_changes = 150 },
        })
    end
end

-- ========================================================================== --
-- 5. KEYMAPS
-- ========================================================================== --
vim.keymap.set('n', '<leader>ut', vim.cmd.UndotreeToggle)

-- Movement & Quality of Life
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")
vim.keymap.set("x", "<leader>p", "\"_dp")

-- ========================================================================== --
-- 6. APPEARANCE & NATIVE FEATURES
-- ========================================================================== --
vim.cmd "colorscheme solarized"
vim.opt.background = "light"

-- NATIVE TREE-SITTER (The Protected Way)
-- This avoids the "nvim-treesitter" plugin churn by using the core engine.
vim.api.nvim_create_autocmd("FileType", {
  callback = function()
    -- Only attempt if it's a real file and not massive (performance safeguard)
    if vim.bo.buftype == "" and vim.api.nvim_buf_line_count(0) < 50000 then
        pcall(vim.treesitter.start) 
    end
  end,
})
