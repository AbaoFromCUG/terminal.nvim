-- Run this test with :source %

local SimpleManager = require("terminal.manager").SimpleManager

local manager = SimpleManager:new()

vim.keymap.set("n", "<leader>to", function()
    manager:open()
end)

vim.keymap.set("n", "<leader>th", function()
    manager:hide()
end)

vim.keymap.set("n", "<leader>ts", function()
    manager:show()
end)
