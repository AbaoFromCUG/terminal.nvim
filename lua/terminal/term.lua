---@class terminal.ITerminal
---@field title string
---@field convert_eol? boolean convert `\n` to `\r\n`
---@field id number
---@field protected term_chan? number
---@field protected component? NuiPopup|NuiSplit
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
    if self.component then
        self.component:show()
        return
    end
    self:_layout()
    self.component:mount()
    local bufnr = self.component.bufnr
    local buf_name = string.format("term://%s", self.id)
    vim.api.nvim_buf_set_name(bufnr, buf_name)
    self.term_chan = vim.api.nvim_open_term(bufnr, {
        on_input = function(event, term, b, data)
            vim.print(vim.inspect(event))
            vim.print(vim.inspect(term))
            vim.print(vim.inspect(b))
            vim.print(vim.inspect(data))
        end,
    })
end

function ITerminal:_layout() end

function ITerminal:hide()
    self.component:hide()
end

function ITerminal:get_bufnr()
    return self.component.bufnr
end

function ITerminal:close()
    self.component:unmount()
    self.component = nil
end

function ITerminal:get_width()
    local winid = self.component.winid
    return vim.api.nvim_win_get_width(winid)
end

function ITerminal:get_height()
    local winid = self.component.winid
    return vim.api.nvim_win_get_height(winid)
end

---get line from buffer, or nil if the line index not exists
---@param index any
---@return string|nil
function ITerminal:get_line(index)
    local bufnr = self.component.bufnr
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    if index < line_count then
        local lines = vim.api.nvim_buf_get_lines(bufnr, index, index + 1, true)
        assert(#lines == 1)
        return lines[1]
    end
end

---@class terminal.NewTerminalArgs: terminal.NewITerminalArgs
---@field relative? nui_split_option_relative_type|nui_split_option_relative
---@field position? nui_split_option_position
---@field size? number|string|nui_split_option_size

---@class terminal.Terminal: terminal.ITerminal
---@field relative nui_split_option_relative_type|nui_split_option_relative
---@field position nui_split_option_position
---@field size number|string|nui_split_option_size

local Terminal = {}
Terminal.__index = Terminal
setmetatable(Terminal, {
    __index = ITerminal,
})

---Terminal constructor
---@param options? terminal.NewTerminalArgs
---@return terminal.Terminal
function Terminal:new(options)
    local default_options = { position = "bottom", size = "30%", relative = "win" }
    options = vim.tbl_deep_extend("keep", options or {}, default_options) --[[@as terminal.NewTerminalArgs]]
    local o = ITerminal.new(Terminal, options) --[[@as terminal.Terminal]]
    return o
end

function Terminal:_layout()
    local Split = require("nui.split")
    self.component = Split({
        relative = self.relative,
        position = self.position,
        size = self.size,
    })
end

---@class terminal.FloatTerminal: terminal.ITerminal
---@field position nui_popup_internal_position
---@field size nui_popup_internal_size
local FloatTerminal = {}
FloatTerminal.__index = FloatTerminal
setmetatable(FloatTerminal, {
    __index = ITerminal,
})

---@class terminal.NewFloatTerminalArgs: terminal.NewITerminalArgs
---@field position? nui_popup_internal_position
---@field size? nui_popup_internal_size

---FloatTerminal constructor
---@param options? terminal.NewFloatTerminalArgs
---@return terminal.FloatTerminal
function FloatTerminal:new(options)
    local default_options = { position = "50%", size = "80%", relative = "win" }
    options = vim.tbl_deep_extend("keep", options or {}, default_options) --[[@as terminal.NewFloatTerminalArgs]]

    local o = ITerminal.new(FloatTerminal, options)
    return o --[[@as terminal.FloatTerminal]]
end

function FloatTerminal:_layout()
    local Popup = require("nui.popup")
    self.component = Popup({
        position = self.position,
        size = self.size,
    })
end

local M = {
    ITerminal = ITerminal,
    Terminal = Terminal,
    FloatTerminal = FloatTerminal,
}

return M
