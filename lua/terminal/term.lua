---@alias InputCallback fun(data:string)

---merge default options
---@param default table<string, any>
---@param options table<string, any>
---@param properties string[]
local function merge_default(default, options, properties)
    for _, property in ipairs(properties) do
        if options[property] ~= nil then
            default[property] = options[property]
        end
    end
    return default
end

---@class terminal.ITerminal
---@field title string
---@field convert_eol? boolean convert `\n` to `\r\n`
---@field id number
---@field protected bufnr? number
---@field protected winid? number
---@field protected term_chan? number
---@field private data_hooks table<string|number, InputCallback>
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
---@field on_input fun(data: string)

---Terminal constructor
---@param options? terminal.NewITerminalArgs
---@return terminal.ITerminal
function ITerminal:new(options)
    assert(self ~= ITerminal, "ITerminal is abstract class")
    options = options or {}
    local o = {
        title = "Terminal",
        convert_eol = true,
        data_hooks = {},
    }
    merge_default(o, options, { "title", "cmd", "args", "convert_eol" })
    setmetatable(o, self)
    o.id = #ITerminal.id2term
    table.insert(ITerminal.id2term, o)
    o:watch_input(options.on_input)
    return o
end

---write data to terminal ouput directly
---@param data string
---@param callback? function
function ITerminal:write(data, callback)
    vim.schedule(function()
        if data ~= nil then
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

---add input watcher, if hook is nil,  will remove the watcher by key
---@param hook? InputCallback
---@param key? string
function ITerminal:watch_input(hook, key)
    if key then
        self.data_hooks[key] = hook
    end
    if hook then
        table.insert(self.data_hooks, hook)
    end
end

---open terminal
function ITerminal:open()
    local buf_name = string.format("term://%s", self.id)
    vim.api.nvim_buf_set_name(self.bufnr, buf_name)
    self.term_chan = vim.api.nvim_open_term(self.bufnr, {
        on_input = function(event, term, buf, data)
            assert(event == "input")
            assert(term == self.term_chan)
            assert(buf == self.bufnr)
            for key, hook in pairs(self.data_hooks) do
                assert(type(key) == "string" or type(key) == "number")
                hook(data)
            end
        end,
    })
end

function ITerminal:get_bufnr()
    return self.bufnr
end

function ITerminal:close()
    vim.fn.chanclose(self.term_chan)
    self.term_chan = nil
    self.data_hooks = {}
end

function ITerminal:get_width()
    return vim.api.nvim_win_get_width(self.winid)
end

function ITerminal:get_height()
    return vim.api.nvim_win_get_height(self.winid)
end

---get line from buffer, or nil if the line index not exists
---@param index number
---@return string|nil
function ITerminal:get_line(index)
    local line_count = vim.api.nvim_buf_line_count(self.bufnr)
    if index < line_count then
        local lines = vim.api.nvim_buf_get_lines(self.bufnr, index, index + 1, true)
        assert(#lines == 1)
        return lines[1]
    end
end

---@class terminal.DetachmentTerminal: terminal.ITerminal
---@field protected component? NuiPopup|NuiSplit

local DetachmentTerminal = {}
DetachmentTerminal.__index = DetachmentTerminal
setmetatable(DetachmentTerminal, {
    __index = ITerminal,
})

---@class terminal.NewDetachmentTerminalArgs: terminal.NewITerminalArgs

---comment
---@param options? terminal.NewDetachmentTerminalArgs
function DetachmentTerminal:new(options)
    local o = ITerminal.new(self, options)
    return o
end

function DetachmentTerminal:open()
    self.component:mount()
    self.bufnr = self.component.bufnr
    self.winid = self.component.winid
    ITerminal.open(self)
end

function DetachmentTerminal:close()
    ITerminal.close(self)
    self.component:unmount()
    self.bufnr = nil
    self.winid = nil
end

---@class terminal.Terminal: terminal.DetachmentTerminal
---@field relative nui_split_option_relative_type|nui_split_option_relative
---@field position nui_split_option_position
---@field size number|string|nui_split_option_size

local Terminal = {}
Terminal.__index = Terminal
setmetatable(Terminal, {
    __index = DetachmentTerminal,
})

---@class terminal.NewTerminalArgs: terminal.NewDetachmentTerminalArgs
---@field relative? nui_split_option_relative_type|nui_split_option_relative
---@field position? nui_split_option_position
---@field size? number|string|nui_split_option_size

---Terminal constructor
---@param options? terminal.NewTerminalArgs
---@return terminal.Terminal
function Terminal:new(options)
    local default_options = { position = "bottom", size = "30%", relative = "win" }
    options = vim.tbl_deep_extend("keep", options or {}, default_options) --[[@as terminal.NewTerminalArgs]]

    local o = DetachmentTerminal.new(self, options) --[[@as terminal.Terminal]]
    merge_default(o, options, { "position", "size", "relative" })
    return o
end

function Terminal:open()
    local Split = require("nui.split")
    self.component = Split({
        relative = self.relative,
        position = self.position,
        size = self.size,
        enter = true,
        win_options = {
            number = false,
            relativenumber = false,
        },
    })
    DetachmentTerminal.open(self)
end

---@class terminal.FloatTerminal: terminal.DetachmentTerminal
---@field position nui_popup_internal_position
---@field size nui_popup_internal_size
local FloatTerminal = {}
FloatTerminal.__index = FloatTerminal
setmetatable(FloatTerminal, {
    __index = DetachmentTerminal,
})

---@class terminal.NewFloatTerminalArgs: terminal.NewDetachmentTerminalArgs
---@field position? nui_popup_internal_position
---@field size? nui_popup_internal_size

---FloatTerminal constructor
---@param options? terminal.NewFloatTerminalArgs
---@return terminal.FloatTerminal
function FloatTerminal:new(options)
    local default_options = { position = "50%", size = "80%" }
    options = vim.tbl_deep_extend("keep", options or {}, default_options) --[[@as terminal.NewFloatTerminalArgs]]

    local o = DetachmentTerminal.new(self, options)
    merge_default(o, options, { "position", "size" })
    return o --[[@as terminal.FloatTerminal]]
end

function FloatTerminal:open()
    local Popup = require("nui.popup")
    self.component = Popup({
        position = self.position,
        size = self.size,
        enter = true,
    })
    DetachmentTerminal.open(self)
end

---@class terminal.AttachmentTerminal: terminal.ITerminal
---@field winid? number
local AttachmentTerminal = {}
AttachmentTerminal.__index = AttachmentTerminal
setmetatable(AttachmentTerminal, {
    __index = ITerminal,
})

---@class terminal.NewAttachmentTerminalArgs: terminal.NewITerminalArgs
---@field winid number

---AttachmentTerminal constructor
---@param options terminal.NewAttachmentTerminalArgs
---@return terminal.AttachmentTerminal
function AttachmentTerminal:new(options)
    local o = ITerminal.new(self, options)
    merge_default(o, options, { "winid" })
    return o --[[@as terminal.AttachmentTerminal]]
end

function AttachmentTerminal:open()
    self.bufnr = vim.api.nvim_create_buf(false, false)
    ITerminal.open(self)
end

function AttachmentTerminal:close()
    ITerminal.close(self)
    vim.api.nvim_buf_delete(self.bufnr, {})
    self.bufnr = nil
end

local M = {
    ITerminal = ITerminal,
    Terminal = Terminal,
    FloatTerminal = FloatTerminal,
    AttachmentTerminal = AttachmentTerminal,
}

return M
