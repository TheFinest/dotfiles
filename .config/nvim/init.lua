require("thefinest")

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.guicursor = ""
vim.opt.scrolloff = 8
vim.opt.smartindent = true
vim.opt.backspace = "indent,eol,start"
vim.opt.termguicolors = true
vim.cmd "colorscheme solarized"
vim.opt.background = "light"
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true
vim.opt.updatetime = 50
vim.opt.title = true

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    {
        'nvim-telescope/telescope.nvim', 
        tag = '0.1.3', 
        dependencies = {'nvim-lua/plenary.nvim'}
    },
    {
        'nvim-treesitter/nvim-treesitter', 
        run = ':TSUpdate'
    },
    {
        'ThePrimeagen/harpoon',
        dependencies = {'nvim-lua/plenary.nvim'}
    },
    'mbbill/undotree',
    {
      'VonHeikemen/lsp-zero.nvim',
      branch = 'v2.x',
      dependencies = {
        -- LSP Support
        {'neovim/nvim-lspconfig'},             -- Required
        {'williamboman/mason.nvim'},           -- Optional
        {'williamboman/mason-lspconfig.nvim'}, -- Optional

        -- Autocompletion
        {'hrsh7th/nvim-cmp'},     -- Required
        {'hrsh7th/cmp-nvim-lsp'}, -- Required
        {'L3MON4D3/LuaSnip'},     -- Required
      }
    },
    {
        'benlubas/molten-nvim',
        version = '^1.0.0',
        build = ':UpdateRemotePlugins'
    }
})

