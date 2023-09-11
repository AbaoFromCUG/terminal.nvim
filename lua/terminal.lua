local term = require("terminal.term")
local manager = require("terminal.manager")
local Job = require("terminal.job")

---@class terminal
---@field manager terminal.SimpleManager
local M = {}

function M.setup()
    M.manager = manager.SimpleManager:new()
end

return M
