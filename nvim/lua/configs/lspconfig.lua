require("nvchad.configs.lspconfig").defaults()

local servers = {
  "html",
  "cssls",
  "pyright",
  "ruff",
  "rust_analyzer",
  "gopls",
  "ts_ls",
  "marksman",
}
vim.lsp.enable(servers)

-- read :h vim.lsp.config for changing options of lsp servers
