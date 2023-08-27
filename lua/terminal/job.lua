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
---@field exitcode? number
---@field private shared_stdout table<string|number, StdoutCallback>
---@field private shared_stderr table<string|number, StdoutCallback>
---@field private shared_exit table<string|number, ExitCallback>
---@field private status JobStatus
---@field private stdin? uv_pipe_t
---@field private stdout? uv_pipe_t
---@field private stderr? uv_pipe_t
local Job = {}

---@class terminal.NewJobArgs
---@field cmd string
---@field args? any[]
---@field cwd? string
---@field env? string[]
---@field on_stdout? StdoutCallback
---@field on_stderr? StderrCallback
---@field on_exit? ExitCallback

---Job constructor
---@param options terminal.NewJobArgs
---@return terminal.Job
function Job:new(options)
    local o = {} --[[@as terminal.Job]]
    self.__index = self
    setmetatable(o, self)
    o.cmd = options.cmd
    o.args = options.args
    o.cwd = options.cwd
    o.env = options.env
    o.status = "ready"
    o.shared_stdout = {}
    o.shared_stderr = {}
    o.shared_exit = {}
    o:watch_stdout(options.on_stdout)
    o:watch_stderr(options.on_stderr)
    o:watch_exit(options.on_exit)
    return o
end

---add shared stdout watcher, if hook is nil,  will remove the watcher by key
---@param hook? StdoutCallback
---@param key? string
function Job:watch_stdout(hook, key)
    if key then
        self.shared_stdout[key] = hook
    end
    if hook then
        table.insert(self.shared_stdout, hook)
    end
end

---add shared stderr watcher, if hook is nil,  will remove the watcher by key
---@param hook? StderrCallback
---@param key? string
function Job:watch_stderr(hook, key)
    if key then
        self.shared_stderr[key] = hook
    end
    if hook then
        table.insert(self.shared_stderr, hook)
    end
end

---add shared exit watcher, if hook is nil,  will remove the watcher by key
---@param hook? ExitCallback
---@param key? string
function Job:watch_exit(hook, key)
    if key then
        self.shared_exit[key] = hook
    end
    if hook then
        table.insert(self.shared_exit, hook)
    end
end

function Job:start()
    if self.status ~= "ready" then
        return false, string.format("The job status is %, can't start", self.status)
    end

    self.stdin = uv.new_pipe()
    self.stdout = uv.new_pipe()
    self.stderr = uv.new_pipe()

    self.handle, self.pid = uv.spawn(self.cmd, {
        args = self.args,
        cwd = self.cwd,
        env = self.env,
        stdio = { self.stdin, self.stdout, self.stderr },
    }, function(code, signal) -- on exit
        for key, hook in pairs(self.shared_exit) do
            assert(type(key) == "string" or type(key) == "number")
            self.exitcode = code
            hook(code, signal)
        end
        self.status = "shutdown"
    end)
    if not self.handle then
        self.status = "error"
        return false, self.pid
    end
    self.status = "running"

    uv.read_start(self.stdout, function(err, data)
        assert(not err, err)
        for key, hook in pairs(self.shared_stdout) do
            assert(type(key) == "string" or type(key) == "number")
            hook(data)
        end
    end)

    uv.read_start(self.stderr, function(err, data)
        assert(not err, err)
        for key, hook in pairs(self.shared_stderr) do
            assert(type(key) == "string" or type(key) == "number")
            hook(data)
        end
    end)

    return self
end

---get job status
---@return JobStatus
function Job:get_status()
    return self.status
end

---write content to stdin pipe
---@param content any
function Job:write(content)
    if self.status ~= "running" then
        return false, string.format("The job status is %, can't write to stdin", self.status)
    end
    uv.write(self.stdin, content)
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
end

function Job:shutdown()
    self.stdin:close()
    self.stdout:close()
    self.stderr:close()
    uv.close(self.handle)
end

return Job
