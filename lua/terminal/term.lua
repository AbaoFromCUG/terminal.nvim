---@class terminal.ITerminal
---@field title string
---@field convert_eol? boolean convert `\n` to `\r\n`
---@field id number
---@field protected term_buf? number
---@field protected term_chan? number
---@field protected term_win? number
---@field protected width? number
---@field protected height? number
local ITerminal = {
    id2term = {},
}
ITerminal.__index = ITerminal
setmetatable(ITerminal, {})

---@class terminal.NewITerminalArgs
---@field title? string
---@field cmd? string
---@field args? string[]
---@field convert_eol? boolean convert `\n` to `\r\n`

---Terminal constructor
---@param options? terminal.NewITerminalArgs
---@return terminal.ITerminal
function ITerminal:new(options)
    assert(self ~= ITerminal, "ITerminal is abstract class")
    local o = vim.tbl_deep_extend("force", { title = "Terminal", convert_eol = true }, options or {}) --[[@as terminal.ITerminal]]
    setmetatable(o, self)
    o.id = #ITerminal.id2term
    table.insert(ITerminal.id2term, o)
    return o
end

---write data to terminal ouput directly
---@param data string
---@param callback? function
function ITerminal:write(data, callback)
    vim.schedule(function()
        if data then
            if self.convert_eol then
                data = data:gsub("\n", "\r\n")
            end
            vim.api.nvim_chan_send(self.term_chan, data)
        end
        if callback then
            callback()
        end
    end)
end

---open terminal, abstract function
function ITerminal:open()
    self.term_buf = vim.api.nvim_create_buf(true, false)
    local buf_name = string.format("term://%s", self.id)
    vim.api.nvim_buf_set_name(self.term_buf, buf_name)
    self.term_chan = vim.api.nvim_open_term(self.term_buf, {
        on_input = function(event, term, b, data)
            vim.print(vim.inspect(arg))
        end,
    })
end

function ITerminal:get_width()
    return self.width
end

function ITerminal:get_height()
    return self.height
end

---get line from buffer, or nil if the line index not exists
---@param index any
---@return string|nil
function ITerminal:get_line(index)
    local line_count = vim.api.nvim_buf_line_count(self.term_buf)
    if index < line_count then
        local lines = vim.api.nvim_buf_get_lines(self.term_buf, index, index + 1, true)
        assert(#lines == 1)
        return lines[1]
    end
end

---@alias TerminalPoisiton 'top'|'bottom'|'left'|'right'

---@class terminal.NewTerminalArgs: terminal.NewITerminalArgs
---@field position? TerminalPoisiton default 'top'

---@class terminal.Terminal: terminal.ITerminal
---@field position TerminalPoisiton
local Terminal = {}
Terminal.__index = Terminal
setmetatable(Terminal, {
    __index = ITerminal,
})

---Terminal constructor
---@param options? terminal.NewTerminalArgs
---@return terminal.Terminal
function Terminal:new(options)
    options = vim.tbl_deep_extend("keep", options or {}, { position = "bottom" }) --[[@as terminal.NewTerminalArgs]]
    local o = ITerminal.new(Terminal, options) --[[@as terminal.Terminal]]
    return o
end

function Terminal:open()
    ITerminal.open(self)
    local output = vim.cmd("botright split")
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, self.term_buf)
    return self
end

---@class terminal.FloatTerminal: terminal.ITerminal
local FloatTerminal = {}
FloatTerminal.__index = FloatTerminal
setmetatable(FloatTerminal, {
    __index = ITerminal,
})

---@class terminal.NewFloatTerminalArgs: terminal.NewITerminalArgs

---FloatTerminal constructor
---@param options? terminal.NewFloatTerminalArgs
---@return terminal.FloatTerminal
function FloatTerminal:new(options)
    local o = ITerminal.new(FloatTerminal, options)
    return o --[[@as terminal.FloatTerminal]]
end

function FloatTerminal:open()
    ITerminal.open(self)
    self.width = math.ceil(math.min(vim.o.columns, math.max(80, vim.o.columns - 20)))
    self.height = math.ceil(math.min(vim.o.lines, math.max(20, vim.o.lines - 10)))
    self.term_win = vim.api.nvim_open_win(self.term_buf, true, { relative = "win", row = 10, col = 10, width = self.width, height = self.height })
    return self
end

local M = {
    ITerminal = ITerminal,
    Terminal = Terminal,
    FloatTerminal = FloatTerminal,
}

return M
