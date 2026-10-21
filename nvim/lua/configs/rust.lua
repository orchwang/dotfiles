-- rustaceanvim reads vim.g.rustaceanvim when a Rust buffer opens, so this
-- must be set before the plugin loads (plugins/init.lua `init`).
-- rust-analyzer comes from rustup (`make set-rust`: rust-analyzer + rust-src
-- components) so it always matches the active toolchain — not from Mason.
-- codelldb (Mason) on PATH is auto-detected for :RustLsp debuggables.

local function map(bufnr, lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = "Rust " .. desc })
end

local function rust_lsp(...)
  local args = { ... }
  return function()
    vim.cmd.RustLsp(args)
  end
end

vim.g.rustaceanvim = {
  server = {
    on_attach = function(_, bufnr)
      -- NvChad owns <leader>r* (ra = rename, rn = relative number), so the
      -- Rust-specific actions live under <leader>R.
      map(bufnr, "K", rust_lsp("hover", "actions"), "hover actions")
      map(bufnr, "<leader>ca", rust_lsp "codeAction", "code action")
      map(bufnr, "<leader>Rr", rust_lsp "runnables", "runnables")
      map(bufnr, "<leader>Rt", rust_lsp "testables", "testables")
      map(bufnr, "<leader>Rd", rust_lsp "debuggables", "debuggables")
      map(bufnr, "<leader>Re", rust_lsp "expandMacro", "expand macro")
      map(bufnr, "<leader>Rx", rust_lsp "explainError", "explain error")
      map(bufnr, "<leader>RD", rust_lsp "renderDiagnostic", "render diagnostic")
      map(bufnr, "<leader>Rc", rust_lsp "openCargo", "open Cargo.toml")
      map(bufnr, "<leader>Rp", rust_lsp "parentModule", "parent module")
      map(bufnr, "<leader>Ro", rust_lsp "openDocs", "open docs.rs")
    end,
    default_settings = {
      ["rust-analyzer"] = {
        -- Run clippy instead of `cargo check` on save.
        check = { command = "clippy" },
      },
    },
  },
}
