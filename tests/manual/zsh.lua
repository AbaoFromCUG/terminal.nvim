-- Run this test with :source %

local Job = require("terminal.job")
local term = require("terminal.term")
local FloatTerminal = term.FloatTerminal

local function open()
    local t = FloatTerminal:new({})
    t:open()
    assert(t)
    assert(t:get_width() > 0)
    assert(t:get_height() > 0)
    local job = Job:new({
        cmd = "zsh",
        pty = true,
        env = {
            TERM = vim.fn.getenv("TERM"),
        },
        width = t:get_width(),
        height = t:get_height(),
        backend = "jobstart",
    })
    job:watch_stdout(function(data)
        t:write(data)
    end)
    job:watch_exit(function()
        t:close()
    end)
    t:watch_input(function(data)
        job:write(data)
    end)
    assert(job:start())
end
open()
