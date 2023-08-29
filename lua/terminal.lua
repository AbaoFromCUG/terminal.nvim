local term = require("terminal.term")
local Job = require("terminal.job")
local Terminal = term.Terminal
local FloatTerminal = term.FloatTerminal
local bufop = require("terminal.bufop")

local M = {}

function M.setup() end

---@type terminal.Terminal
local t

local function setupT()
    if not t then
        t = FloatTerminal:new()
        t:open()
    end
end

function M.open_cat()
    local ansi_file = "/home/abao/Documents/plugins/terminal.nvim/tests/ansi.txt"
    local job = Job:new({
        cmd = "cat",
        args = { ansi_file },
    })
    setupT()
    job:watch_stdout(function(data)
        t:write(data)
    end)
    t:open()
    assert(job:start())
    assert(job:wait())
    vim.defer_fn(function()
        local buf = t.term_buf
        local content = bufop.get_buf_content(buf)
        print(vim.inspect(content))
    end, 2000)
end

function M.open_less()
    local ansi_file = "/home/abao/Documents/plugins/terminal.nvim/tests/ansi.txt"
    setupT()
    local job = Job:new({
        cmd = "less",
        args = { ansi_file },
        pty = true,
        width = t:get_height(),
        height = t:get_height(),
    })
    job:watch_stdout(function(data)
        t:write(data)
    end)
    print(job:get_status())
    assert(job:start())

    vim.defer_fn(function()
        print(vim.inspect(t))
        local buf = t.term_buf
        local content = bufop.get_buf_content(buf)
        print(vim.inspect(content))
        job:shutdown()
    end, 2000)
end

return M
