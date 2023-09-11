local Path = require("plenary.path")

local M = {}

M.ansi_file = (Path:new(vim.loop.cwd()) / "tests/ansi.txt").filename

M.ansi_file_content = "\x1b[31;40;9mSimple ANSI file\n\x1b[35;40;4mJust cat me\n\x1b[0m"

M.ansi_hello = "\x1b[31;40;9mhello\x1b[0m"

function M.sleep(time_ms)
    local timer = vim.loop.new_timer()
    local is_timeout = false
    vim.loop.timer_start(timer, time_ms, 1, function()
        is_timeout = true
    end)
    vim.wait(time_ms + 1000, function()
        return is_timeout
    end, 100)
end

---combine Job and Terminal
---@param job terminal.Job
---@param t terminal.ITerminal
function M.bridge(job, t)
    if not job or job:get_status() ~= "ready" then
        return false, "job is not exists or status is not ready"
    end
    if not t then
        return false, "terminal is nil"
    end
    job:watch_stdout(function(data)
        t:write(data)
    end)
    t:watch_input(function(data)
        job:write(data)
    end)
    return true
end

return M
