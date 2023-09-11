local uv = vim.loop

---@alias StdoutCallback fun(data:string)
---@alias StderrCallback fun(data:string)
---@alias ExitCallback fun(code: number, signal: number)
---@alias JobStatus 'ready'|'running'|'shutdown'|'error'

---@class terminal.Job
---@field cmd string
---@field args? any[]
---@field cwd? string
---@field env? string[]
---@field pty boolean
---@field width? number width of pty terminal
---@field height? number height of pty terminal
---@field exitcode? number
---@field private stdout_hooks table<string|number, StdoutCallback>
---@field private stderr_hooks table<string|number, StdoutCallback>
---@field private exit_hooks table<string|number, ExitCallback>
---@field private status JobStatus
---@field private handle number|table<uv_process_t, uv_pipe_t, uv_pipe_t, uv_pipe_t>
---@field backend "spawn"|"jobstart"
local Job = {}
Job.__index = Job

---@class terminal.NewJobArgs
---@field cmd string
---@field args? any[] arguments, which will tostring when start
---@field cwd? string
---@field env? string[]
---@field pty? boolean
---@field width? number width of pty terminal
---@field height? number height of pty terminal
---@field backend? "spawn"|"jobstart"
---@field on_stdout? StdoutCallback
---@field on_stderr? StderrCallback
---@field on_exit? ExitCallback

---Job constructor
---@param options terminal.NewJobArgs
---@return terminal.Job
function Job:new(options)
    local default_options = {
        status = "ready",
        backend = "spawn",
        pty = false,
        stdout_hooks = {},
        stderr_hooks = {},
        exit_hooks = {},
    }
    local o = vim.tbl_deep_extend("force", default_options, options or {}) --[[@as terminal.Job]]
    setmetatable(o, self)
    o:watch_stdout(options.on_stdout)
    o:watch_stderr(options.on_stderr)
    o:watch_exit(options.on_exit)
    return o
end

---add stdout watcher, if hook is nil,  will remove the watcher by key
---@param hook? StdoutCallback
---@param key? string
function Job:watch_stdout(hook, key)
    if key then
        self.stdout_hooks[key] = hook
    end
    if hook then
        table.insert(self.stdout_hooks, hook)
    end
end

---add stderr watcher, if hook is nil,  will remove the watcher by key
---@param hook? StderrCallback
---@param key? string
function Job:watch_stderr(hook, key)
    if key then
        self.stderr_hooks[key] = hook
    end
    if hook then
        table.insert(self.stderr_hooks, hook)
    end
end

---add exit watcher, if hook is nil,  will remove the watcher by key
---@param hook? ExitCallback
---@param key? string
function Job:watch_exit(hook, key)
    if key then
        self.exit_hooks[key] = hook
    end
    if hook then
        table.insert(self.exit_hooks, hook)
    end
end

---start job
---@return boolean|self
---@return string? err string
function Job:start()
    if self.status ~= "ready" then
        return false, string.format("The job status is %, can't start", self.status)
    end
    if self.backend == "spawn" then
        return self:_spawn()
    else
        return self:_jobstart()
    end
end

function Job:_on_stdout(data)
    for key, hook in pairs(self.stdout_hooks) do
        assert(type(key) == "string" or type(key) == "number")
        hook(data)
    end
end

function Job:_on_stderr(data)
    for key, hook in pairs(self.stderr_hooks) do
        assert(type(key) == "string" or type(key) == "number")
        hook(data)
    end
end

function Job:_on_exit(code, signal)
    for key, hook in pairs(self.exit_hooks) do
        assert(type(key) == "string" or type(key) == "number")
        hook(code, signal)
    end
end

function Job:_spawn()
    local cmd = tostring(self.cmd)
    local args = {}
    for _, arg in ipairs(self.args or {}) do
        table.insert(args, tostring(arg))
    end
    local env = {}
    for key, value in pairs(self.env or {}) do
        table.insert(env, key .. "=" .. value)
    end

    local stdin = uv.new_pipe() --[[@as uv_pipe_t]]
    local stdout = uv.new_pipe() --[[@as uv_pipe_t]]
    local stderr = uv.new_pipe() --[[@as uv_pipe_t]]

    local handle = uv.spawn(cmd, {
        args = args,
        cwd = self.cwd,
        env = env,
        stdio = { stdin, stdout, stderr },
    }, function(code, signal) -- on exit
        self.exitcode = code
        self.status = "shutdown"
        self:_on_exit(code, signal)
    end)
    if not handle then
        self.status = "error"
        return false --[[@as string]]
    end
    self.handle = { handle, stdin, stdout, stderr }
    self.status = "running"

    assert(uv.read_start(stdout, function(err, data)
        assert(not err, err)
        self:_on_stdout(data)
    end))

    assert(uv.read_start(stderr, function(err, data)
        assert(not err, err)
        self:_on_stderr(data)
    end))
    return true
end

function Job:_jobstart()
    local cmd = {
        tostring(self.cmd),
    }
    for _, arg in ipairs(self.args or {}) do
        table.insert(cmd, tostring(arg))
    end
    local chan
    chan = vim.fn.jobstart(cmd, {
        cwd = tostring(self.cwd or vim.loop.cwd()),
        env = self.env or vim.empty_dict(),
        pty = self.pty,
        width = self.width,
        height = self.height,
        on_stdout = function(chan_id, data, name)
            assert(chan_id == chan)
            assert(name == "stdout")
            if #data == 1 and data[1] == "" then
                self:_on_stdout()
                return
            end
            data = table.concat(data, "\n")
            self:_on_stdout(data)
        end,
        on_stderr = function(chan_id, data, name)
            assert(chan_id == chan)
            assert(name == "stderr")

            if #data == 1 and data[1] == "" then
                self:_on_stderr()
                return
            end
            self:_on_stderr(data)
        end,
        on_exit = function(job_id, exit_code, event_type)
            assert(job_id == chan)
            assert(event_type == "exit")
            self.status = "shutdown"
            if exit_code >= 128 then
                self:_on_exit(0, exit_code - 128)
            else
                self:_on_exit(exit_code, 0)
            end
        end,
        -- stdout_buffered = true,
        -- stderr_buffered = true,
    })
    if chan == nil then
        return false, "failed to call jobstart"
    elseif chan == 0 then
        return false, "invalid arguments"
    elseif chan == -1 then
        return false, "cmd is not executable"
    end

    self.handle = chan
    self.status = "running"
    return true
end

---get job status
---@return JobStatus
function Job:get_status()
    return self.status
end

---write content to stdin pipe
---@param data string
function Job:write(data)
    if self.status ~= "running" then
        return false, string.format("The job status is %s, can't write to stdin", self.status)
    end
    if self.backend == "spawn" then
        local stdin = self.handle[2]
        uv.write(stdin, data)
    else
        vim.fn.chansend(self.handle, data)
    end
    return true
end

---wait until job shutdown
---@param timeout_ms? number default 5000ms
---@param interval_ms? number default 10ms
function Job:wait(timeout_ms, interval_ms)
    timeout_ms = timeout_ms or 5000
    interval_ms = interval_ms or 10

    vim.wait(timeout_ms, function()
        return self:get_status() == "shutdown"
    end, interval_ms)
    if self:get_status() == "shutdown" then
        return true
    end
    return false, "job's status is " .. self:get_status()
end

---shutdown process with signal
---@param signal any
function Job:shutdown(signal)
    if self.backend == "spawn" then
        local handle, stdin, stdout, stderr = self.handle[1], self.handle[2], self.handle[3], self.handle[4]
        uv.close(stdout)
        uv.close(stderr)
        uv.close(stdin)
        uv.process_kill(handle, signal or "sigterm")
    else
        vim.fn.jobstop(self.handle)
    end
end

return Job
