local Job = require("terminal.job")

---@class terminal.ITerminal
---@field title string
---@field cmd? string
---@field args? string[]
---@field env? string[]
---@field cwd? string
---@field protected job? terminal.Job top level job, such bash or lazygit for lazygit tool
---@field protected term_chan number
---@field protected win? number
local ITerminal = {}

---@class terminal.NewITerminalArgs
---@field title? string
---@field cmd? string
---@field args? string[]

---Terminal constructor
---@param options? terminal.NewITerminalArgs
---@return terminal.ITerminal
function ITerminal:new(options)
    local o = vim.tbl_deep_extend("force", { title = "Terminal" }, options or {}) --[[@as terminal.ITerminal]]
    self.__index = self
    setmetatable(o, self)
    return o
end

---atatch job to terminal
---@param job terminal.Job
function ITerminal:attach_job(job)
    assert(job:get_status() == "ready", "only ready status job can attach to terminal")
    job.on_stdout = vim.schedule_wrap(function(data)
        vim.api.nvim_chan_send(self.term_chan, data)
    end)
end

---open terminal, abstract function
function ITerminal:open() end

---@alias TerminalPoisiton 'top'|'bottom'|'left'|'right'

---@class terminal.Terminal: terminal.ITerminal
---@field position TerminalPoisiton
local Terminal = {}

---@class terminal.NewTerminalArgs: terminal.NewITerminalArgs
---@field position? TerminalPoisiton default 'top'

---FloatTerminal constructor
---@param options? terminal.NewTerminalArgs
---@return terminal.Terminal
function Terminal:new(options)
    options = vim.tbl_deep_extend("force", { position = "bottom" }, options or {}) --[[@as terminal.NewTerminalArgs]]
    local o = ITerminal:new(options) --[[@as terminal.Terminal]]
    self.__index = self
    setmetatable(o, self)
    return o
end

function Terminal:open()
    local buf = vim.api.nvim_create_buf(true, false)

    self.term_chan = vim.api.nvim_open_term(buf, {
        on_input = function()
            vim.print(arg)
        end,
    })
end

---@class terminal.FloatTerminal: terminal.ITerminal
local FloatTerminal = {}

---@class terminal.NewFloatTerminalArgs: terminal.NewITerminalArgs

---FloatTerminal constructor
---@param options? terminal.NewFloatTerminalArgs
---@return terminal.FloatTerminal
function FloatTerminal:new(options)
    local o = options or ITerminal:new(options)
    self.__index = self
    setmetatable(o, self)
    return o --[[@as terminal.FloatTerminal]]
end

function FloatTerminal:open()
    self.job = Job:new({
        cmd = self.cmd,
        args = self.args,
        cwd = self.cwd,
        env = self.env,
    })
    local buf = vim.api.nvim_create_buf(true, false)
    local width = math.ceil(math.min(vim.o.columns, math.max(80, vim.o.columns - 20)))
    local height = math.ceil(math.min(vim.o.lines, math.max(20, vim.o.lines - 10)))
    self.win = vim.api.nvim_open_win(buf, true, { relative = "win", row = 10, col = 10, width = width, height = height })

    self.term_chan = vim.api.nvim_open_term(buf, {
        on_input = function()
            vim.print(vim.inspect(arg))
        end,
    })
    self.job:watch_stdout(function(data)
        vim.api.nvim_chan_send(self.term_chan, data)
    end)
    self.job:start()
end

return {
    ITerminal = ITerminal,
    Terminal = Terminal,
    FloatTerminal = FloatTerminal,
}
