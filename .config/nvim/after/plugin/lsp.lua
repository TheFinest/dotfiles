local lsp = require('lsp-zero').preset({})

lsp.on_attach(function(client, bufnr)
  -- see :help lsp-zero-keybindings
  -- to learn the available actions
  lsp.default_keymaps({buffer = bufnr})
end)

-- (Optional) Configure lua language server for neovim
require('lspconfig').lua_ls.setup(lsp.nvim_lua_ls())
require('lspconfig').pyright.setup{
    settings = {
        pyright = {
            autoImportCompletion = true,
        },
        python = {
            analysis = {
                typeCheckingMode = 'off'
            }
        }
    }
}

lsp.setup()

local cmp = require('cmp')

cmp.setup({
  cmp.setup {
    mapping = {
      ["<CR>"] = cmp.mapping.confirm({ select = true, behavior = cmp.ConfirmBehavior.Replace }),
    }
  }
})
