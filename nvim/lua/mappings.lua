require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

local hop = require("hop")
local directions = require("hop.hint").HintDirection

map("n", "s", function()
  hop.hint_char1({ direction = directions.AFTER_CURSOR })
end, { desc = "Hop forward" })

map("n", "S", function()
  hop.hint_char1({ direction = directions.BEFORE_CURSOR })
end, { desc = "Hop backward" })

map("n", "gw", function()
  hop.hint_words()
end, { desc = "Hop words" })

-- Telescope full-search (include .gitignore'd / hidden files).
-- The default <leader>ff / <leader>fw respect .gitignore; these are the escape hatch.
-- file_ignore_patterns = {} clears the defensive filter set in plugins/init.lua,
-- so .venv/node_modules/etc. show up here (and only here).
map("n", "<leader>fa", function()
  require("telescope.builtin").find_files {
    follow = true,
    no_ignore = true,
    hidden = true,
    file_ignore_patterns = {},
  }
end, { desc = "telescope find all files (incl. ignored)" })

map("n", "<leader>fA", function()
  require("telescope.builtin").live_grep {
    additional_args = { "--no-ignore-vcs", "--hidden" },
    file_ignore_patterns = {},
  }
end, { desc = "telescope live grep (incl. ignored)" })

-- lazygit floating terminal (NvChad 내장 nvchad.term 모듈 재사용, snacks 미도입).
-- cmd = "lazygit" → create()가 `lazygit; <shell>` 로 실행하므로 lazygit 종료 후엔
-- 같은 float에 셸 프롬프트가 남고, <leader>gg 로 토글하면 숨겨진다 (NvChad float term과 동일 동작).
-- lazygit 바이너리는 Makefile set-lazygit(Linux) / brew(macOS)로 이미 설치된 것을 사용.
map("n", "<leader>gg", function()
  require("nvchad.term").toggle { pos = "float", id = "lazygit", cmd = "lazygit" }
end, { desc = "git lazygit (float)" })

-- Mermaid 다이어그램을 ASCII 아트 플로트로 미리보기 (이미지 X, SSH/tmux 호환).
-- 구현: configs/mermaid.lua / 백엔드: mermaid-ascii(Go, make set-go-packages).
require("configs.mermaid").setup()
map("n", "<leader>mm", "<cmd>MermaidAscii<cr>", { desc = "mermaid ASCII 미리보기 (커서 근처 블록)" })

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
