local term = require("terminal.term")
local Job = require("terminal.job")
local Terminal = term.Terminal
local FloatTerminal = term.FloatTerminal
local bufop = require("terminal.bufop")

local M = {}

function M.setup() end

function M.open_cat()
    local ansi_file = "/home/abao/Documents/plugins/terminal.nvim/tests/ansi.txt"
    local t = Terminal:new()
    local job = Job:new({
        cmd = "cat",
        args = { ansi_file },
    })
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

return M
