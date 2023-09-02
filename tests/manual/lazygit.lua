-- Run this test with :source %

local Job = require("terminal.job")
local term = require("terminal.term")
local FloatTerminal = term.FloatTerminal
local bufop = require("terminal.bufop")
local common = require("tests.terminal.common")

---@type terminal.FloatTerminal
local t

local function open_terminal()
    if not t then
        t = FloatTerminal:new({
            -- convert_eol = false
        })
        t:open()
    end
end

local function hide_terminal()
    t:hide()
end

local function open()
    open_terminal()
    assert(t)
    assert(t:get_width() > 0)
    assert(t:get_height() > 0)
    local job = Job:new({
        cmd = "lazygit",
        pty = true,
        width = t:get_width(),
        height = t:get_height(),
        backend = "jobstart",
    })
    job:watch_stdout(function(data)
        t:write(data)
    end)
    print(vim.inspect(common.ansi_file_content))
    assert(job:start())

    vim.defer_fn(function()
        local content = bufop.get_buf_content(t:get_bufnr())
        -- print(vim.inspect(content))
        job:shutdown()
    end, 2000)
end
open()
