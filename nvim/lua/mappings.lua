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

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
