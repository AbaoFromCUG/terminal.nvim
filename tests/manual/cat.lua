-- Run this test with :source %

local Job = require("terminal.job")
local term = require("terminal.term")
local bufop = require("terminal.bufop")
local FloatTerminal = term.FloatTerminal
local common = require("tests.terminal.common")

local function open()
    local t = FloatTerminal:new({})
    t:open()
    local job = Job:new({
        cmd = "cat",
        args = { common.ansi_file },
    })
    assert(common.bridge(job, t))
    -- job:watch_stdout(function(data)
    --     t:write(data)
    -- end)
    -- t:watch_input(function(data)
    --     job:write(data)
    -- end)
    job:start()
    common.sleep(2000)
    print(vim.inspect(bufop.get_buf_content(t:get_bufnr())))
end
open()
