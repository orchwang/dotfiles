return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  {
    "jay-babu/mason-nvim-dap.nvim",
    dependencies = {
      "mason-org/mason.nvim",
      "mfussenegger/nvim-dap",
    },
    opts = {
      -- Installation is centralized in mason-tool-installer to avoid race conditions.
      ensure_installed = {},
      automatic_installation = false,
      handlers = {},
    },
  },

  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason-org/mason.nvim" },
    cmd = {
      "MasonToolsInstall",
      "MasonToolsInstallSync",
      "MasonToolsUpdate",
      "MasonToolsUpdateSync",
      "MasonToolsClean",
    },
    opts = {
      ensure_installed = {
        -- LSP
        "html-lsp",
        "css-lsp",
        "pyright",
        -- ruff LSP is provided by system ruff (uv on Linux, Homebrew on macOS).
        "rust-analyzer",
        { "gopls", condition = function()
          return vim.fn.executable "go" == 1
        end },
        "typescript-language-server",

        -- DAP
        "js-debug-adapter",

        -- Linter
        "eslint_d",

        -- Formatter
        "stylua",
        "prettier",
        "rustfmt",
        { "goimports", condition = function()
          return vim.fn.executable "go" == 1
        end },
        { "gofumpt", condition = function()
          return vim.fn.executable "go" == 1
        end },

        -- DAP adapters/binaries (for nvim-dap configs)
        "debugpy",
        { "delve", condition = function()
          return vim.fn.executable "go" == 1
        end },
        "codelldb",
      },
      auto_update = false,
      -- make set-nvim-tools runs :MasonToolsInstallSync in headless mode.
      -- Keep startup auto-install disabled to prevent duplicate install jobs.
      run_on_start = false,
      integrations = {
        ["mason-lspconfig"] = true,
        ["mason-null-ls"] = true,
        ["mason-nvim-dap"] = false,
      },
    },
  },

  {
    "mfussenegger/nvim-dap",
    cmd = {
      "DapContinue",
      "DapToggleBreakpoint",
      "DapStepOver",
      "DapStepInto",
      "DapStepOut",
      "DapReloadProjectConfig",
    },
    keys = {
      {
        "<F5>",
        function()
          require("dap").continue()
        end,
        desc = "DAP Continue/Start",
      },
      {
        "<F9>",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = "DAP Toggle Breakpoint",
      },
      {
        "<F10>",
        function()
          require("dap").step_over()
        end,
        desc = "DAP Step Over",
      },
      {
        "<F11>",
        function()
          require("dap").step_into()
        end,
        desc = "DAP Step Into",
      },
      {
        "<F12>",
        function()
          require("dap").step_out()
        end,
        desc = "DAP Step Out",
      },
      {
        "<leader>dB",
        function()
          require("dap").set_breakpoint(vim.fn.input "Breakpoint condition: ")
        end,
        desc = "DAP Conditional Breakpoint",
      },
      {
        "<leader>dl",
        function()
          require("dap").set_breakpoint(nil, nil, vim.fn.input "Log point message: ")
        end,
        desc = "DAP Log Point",
      },
      {
        "<leader>dr",
        function()
          require("dap").repl.open()
        end,
        desc = "DAP REPL",
      },
      {
        "<leader>du",
        function()
          require("dapui").toggle()
        end,
        desc = "DAP UI Toggle",
      },
    },
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "theHamsta/nvim-dap-virtual-text",
      "mxsdev/nvim-dap-vscode-js",
    },
    config = function()
      require "configs.dap"
    end,
  },

  {
    "phaazon/hop.nvim",
    branch = "v2",
    config = function()
      require("hop").setup()
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "markdown", "markdown_inline" },
    },
  },

  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    ft = { "markdown" },
    opts = {},
  },

  {
    "3rd/image.nvim",
    ft = { "markdown" },
    opts = {
      backend = "kitty",
      processor = "magick_cli",
      tmux_show_only_in_active_window = true,
    },
  },

  {
    "3rd/diagram.nvim",
    dependencies = { "3rd/image.nvim" },
    ft = { "markdown" },
    opts = {
      renderer_options = {
        mermaid = { theme = "dark" },
      },
    },
  },

  {
    "nvim-tree/nvim-tree.lua",
    opts = {
      filters = {
        git_ignored = false,
      },
    },
  },

  {
    "nvim-telescope/telescope.nvim",
    opts = {
      defaults = {
        vimgrep_arguments = {
          "rg",
          "-L",
          "--color=never",
          "--no-heading",
          "--with-filename",
          "--line-number",
          "--column",
          "--smart-case",
          "--no-ignore-vcs",
          "--hidden",
        },
      },
      pickers = {
        find_files = {
          no_ignore = true,
          hidden = true,
        },
        live_grep = {
          additional_args = { "--no-ignore-vcs", "--hidden" },
        },
      },
    },
  },
}
