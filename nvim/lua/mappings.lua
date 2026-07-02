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

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
