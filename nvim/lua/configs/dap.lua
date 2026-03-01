local dap = require "dap"
local dapui = require "dapui"

local uv = vim.uv

local function is_file(path)
  return path and uv.fs_stat(path) ~= nil
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "nvim-dap" })
end

local function find_executable(candidates)
  local found

  for _, candidate in ipairs(candidates) do
    if candidate:find("/") then
      if is_file(candidate) then
        found = candidate
        break
      end
    else
      local resolved = vim.fn.exepath(candidate)
      if resolved ~= "" then
        found = resolved
        break
      end
    end
  end

  return found
end

local function resolve_executable(candidates)
  return find_executable(candidates) or candidates[1]
end

local function config_identity(config)
  local parts = {
    config.name or "",
    config.type or "",
    config.request or "",
    type(config.program) == "string" and config.program or "",
    type(config.module) == "string" and config.module or "",
    type(config.cwd) == "string" and config.cwd or "",
  }

  return table.concat(parts, "|")
end

local function append_unique_configurations(ft, items)
  if type(items) ~= "table" then
    return
  end

  dap.configurations[ft] = dap.configurations[ft] or {}

  local seen = {}
  for _, existing in ipairs(dap.configurations[ft]) do
    seen[config_identity(existing)] = true
  end

  for _, item in ipairs(items) do
    local id = config_identity(item)
    if not seen[id] then
      table.insert(dap.configurations[ft], item)
      seen[id] = true
    end
  end
end

local function clear_project_overlay_configurations()
  for ft, items in pairs(dap.configurations) do
    local kept = {}
    for _, item in ipairs(items) do
      if not item.__project_overlay then
        table.insert(kept, item)
      end
    end
    dap.configurations[ft] = kept
  end
end

local function setup_ui()
  dapui.setup {}
  require("nvim-dap-virtual-text").setup {}

  dap.listeners.after.event_initialized["dapui_config"] = function()
    dapui.open()
  end

  dap.listeners.before.event_terminated["dapui_config"] = function()
    dapui.close()
  end

  dap.listeners.before.event_exited["dapui_config"] = function()
    dapui.close()
  end
end

local function setup_keymaps()
  local map = vim.keymap.set

  map("n", "<F5>", dap.continue, { desc = "DAP Continue/Start" })
  map("n", "<F9>", dap.toggle_breakpoint, { desc = "DAP Toggle Breakpoint" })
  map("n", "<F10>", dap.step_over, { desc = "DAP Step Over" })
  map("n", "<F11>", dap.step_into, { desc = "DAP Step Into" })
  map("n", "<F12>", dap.step_out, { desc = "DAP Step Out" })

  map("n", "<leader>dB", function()
    dap.set_breakpoint(vim.fn.input "Breakpoint condition: ")
  end, { desc = "DAP Conditional Breakpoint" })

  map("n", "<leader>dl", function()
    dap.set_breakpoint(nil, nil, vim.fn.input "Log point message: ")
  end, { desc = "DAP Log Point" })

  map("n", "<leader>dr", dap.repl.open, { desc = "DAP REPL" })
  map("n", "<leader>du", dapui.toggle, { desc = "DAP UI Toggle" })
end

local function setup_adapters()
  local debugpy_python = resolve_executable {
    vim.fn.stdpath "data" .. "/mason/packages/debugpy/venv/bin/python",
    "python3",
    "python",
  }

  dap.adapters.python = {
    type = "executable",
    command = debugpy_python,
    args = { "-m", "debugpy.adapter" },
  }

  local delve = resolve_executable {
    vim.fn.stdpath "data" .. "/mason/bin/dlv",
    "dlv",
  }

  dap.adapters.go = function(callback, config)
    if config.request == "attach" and config.mode == "remote" then
      callback {
        type = "server",
        host = config.host or "127.0.0.1",
        port = config.port or "38697",
      }
    else
      callback {
        type = "server",
        port = "${port}",
        executable = {
          command = delve,
          args = { "dap", "-l", "127.0.0.1:${port}" },
        },
      }
    end
  end

  local codelldb = resolve_executable {
    vim.fn.stdpath "data" .. "/mason/bin/codelldb",
    "codelldb",
  }

  dap.adapters.codelldb = {
    type = "server",
    port = "${port}",
    executable = {
      command = codelldb,
      args = { "--port", "${port}" },
    },
  }
end

local function setup_js_adapter()
  local ok, vscode = pcall(require, "dap-vscode-js")
  if not ok then
    notify("dap-vscode-js plugin is not available; JS/TS debugging is disabled", vim.log.levels.WARN)
    return
  end

  local debugger_path = vim.fn.stdpath "data" .. "/mason/packages/js-debug-adapter"
  local debugger_cmd = find_executable {
    vim.fn.stdpath "data" .. "/mason/bin/js-debug-adapter",
    "js-debug-adapter",
  }

  local has_debugger_path = is_file(debugger_path)
  local has_debugger_cmd = debugger_cmd ~= nil

  if not has_debugger_path and not has_debugger_cmd then
    notify("js-debug-adapter is not installed. Run :MasonInstall js-debug-adapter", vim.log.levels.WARN)
    return
  end

  local setup_options = {
    adapters = {
      "pwa-node",
      "node-terminal",
      "pwa-chrome",
      "pwa-msedge",
      "pwa-extensionHost",
    },
  }

  if has_debugger_path then
    setup_options.debugger_path = debugger_path
  end

  if has_debugger_cmd then
    setup_options.debugger_cmd = { debugger_cmd }
  end

  vscode.setup(setup_options)
end

local function setup_base_configurations()
  local python = {
    {
      type = "python",
      request = "launch",
      name = "Python: current file",
      program = "${file}",
      cwd = "${workspaceFolder}",
      console = "integratedTerminal",
      justMyCode = true,
    },
    {
      type = "python",
      request = "launch",
      name = "Python: module",
      module = function()
        return vim.fn.input "Python module: "
      end,
      cwd = "${workspaceFolder}",
      console = "integratedTerminal",
      justMyCode = true,
    },
  }

  append_unique_configurations("python", python)

  local js_ts = {
    {
      type = "pwa-node",
      request = "launch",
      name = "Node: current file",
      program = "${file}",
      cwd = "${workspaceFolder}",
      sourceMaps = true,
      protocol = "inspector",
      console = "integratedTerminal",
    },
    {
      type = "pwa-node",
      request = "attach",
      name = "Node: attach process",
      processId = require("dap.utils").pick_process,
      cwd = "${workspaceFolder}",
    },
  }

  for _, ft in ipairs { "javascript", "javascriptreact", "typescript", "typescriptreact" } do
    append_unique_configurations(ft, vim.deepcopy(js_ts))
  end

  local go = {
    {
      type = "go",
      name = "Go: debug package",
      request = "launch",
      program = "${workspaceFolder}",
      cwd = "${workspaceFolder}",
    },
    {
      type = "go",
      name = "Go: debug current file",
      request = "launch",
      program = "${file}",
      cwd = "${workspaceFolder}",
    },
  }

  append_unique_configurations("go", go)

  local rust = {
    {
      type = "codelldb",
      request = "launch",
      name = "Rust: launch executable",
      program = function()
        local cwd = vim.fn.getcwd()
        local default = cwd .. "/target/debug/" .. vim.fn.fnamemodify(cwd, ":t")
        return vim.fn.input("Path to executable: ", default, "file")
      end,
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
      args = {},
    },
  }

  append_unique_configurations("rust", rust)
end

local function find_project_root()
  local root = vim.fs.find(".git", { upward = true, path = vim.fn.getcwd() })[1]
  if root then
    return vim.fs.dirname(root)
  end

  return vim.fn.getcwd()
end

local function load_project_overlay(path)
  if not is_file(path) then
    return
  end

  local ok, config = pcall(dofile, path)
  if not ok then
    notify("Failed to load " .. path .. ": " .. config, vim.log.levels.WARN)
    return
  end

  if type(config) ~= "table" then
    notify("Skipping " .. path .. ": file must return a Lua table", vim.log.levels.WARN)
    return
  end

  if type(config.adapters) == "table" then
    for name, adapter in pairs(config.adapters) do
      dap.adapters[name] = adapter
    end
  end

  if type(config.configurations) == "table" then
    for ft, items in pairs(config.configurations) do
      local scoped = {}
      for _, item in ipairs(items) do
        local copied = vim.deepcopy(item)
        copied.__project_overlay = path
        table.insert(scoped, copied)
      end
      append_unique_configurations(ft, scoped)
    end
  end
end

local function setup_project_overlays()
  clear_project_overlay_configurations()

  local root = find_project_root()
  local base_dir = root .. "/.nvim"

  load_project_overlay(base_dir .. "/dap.lua")
  load_project_overlay(base_dir .. "/dap.local.lua")
end

local function setup_project_overlay_autoload()
  local group = vim.api.nvim_create_augroup("DapProjectOverlay", { clear = true })
  vim.api.nvim_create_autocmd("DirChanged", {
    group = group,
    callback = setup_project_overlays,
  })

  vim.api.nvim_create_user_command("DapReloadProjectConfig", setup_project_overlays, {
    desc = "Reload project-local DAP configuration",
  })
end

setup_ui()
setup_keymaps()
setup_adapters()
setup_js_adapter()
setup_base_configurations()
setup_project_overlays()
setup_project_overlay_autoload()
