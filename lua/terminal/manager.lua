local term = require("terminal.term")
local Job = require("terminal.job")
local util = require("terminal.util")
local Split = require("nui.split")

---@class terminal.SimpleManager
---@field protected component NuiSplit
---@field protected terminals terminal.AttachmentTerminal[]
local SimpleManager = {}
SimpleManager.__index = SimpleManager
setmetatable(SimpleManager, {})

---@class terminal.NewSimpleManagerArgs
---@field relative nui_split_option_relative_type|nui_split_option_relative
---@field position nui_split_option_position
---@field size number|string|nui_split_option_size

---TermManager conscturctor
---@param options? terminal.NewSimpleManagerArgs
---@return terminal.SimpleManager
function SimpleManager:new(options)
    options = vim.tbl_deep_extend("force", { relative = "win", position = "bottom", size = "30%" }, options or {})

    local o = {}
    ---@field NuiSplit
    o.component = Split({
        relative = options.relative,
        position = options.position,
        size = options.size,
        win_options = {
            number = false,
            relativenumber = false,
        },
    })
    o.terminals = {}
    setmetatable(o, SimpleManager)
    return o --[[@as terminal.SimpleManager]]
end

function SimpleManager:new_terminal()
    local t = term.AttachmentTerminal:new({
        winid = self.component.winid,
    })

    local job = Job:new({
        cmd = vim.o.shell,
        env = {
            TERM = vim.fn.getenv("TERM"),
            PATH = vim.fn.getenv("PATH"),
        },
        width = self:get_width(),
        height = self:get_height(),
        pty = true,
        backend = "jobstart",
    })
    job:watch_stdout(function(data)
        t:write(data)
    end)
    t:watch_input(function(data)
        job:write(data)
    end)
    job:watch_exit(function()
        if #self.terminals == 1 then
            self.terminals = {}
            t:close()
            return
        end
        local idx = assert(util.indexOf(self.terminals, t))
        table.remove(self.terminals, idx)
        self:active_terminal(math.min(idx, #self.terminals))
    end)
    t:open()
    job:start()

    table.insert(self.terminals, t)
    self:active_terminal(#self.terminals)
end

function SimpleManager:active_terminal(index)
    assert(index >= 1 and index <= #self.terminals)
    local terminal = self.terminals[index]
    vim.api.nvim_win_set_buf(self.component.winid, terminal.bufnr)
end

function SimpleManager:get_width()
    -- vim.api.nvim_buf_co
    return vim.api.nvim_win_get_width(self.component.winid)
end

function SimpleManager:get_height()
    return vim.api.nvim_win_get_height(self.component.winid)
end

function SimpleManager:open()
    if #self.terminals == 0 then
        self.component:mount()
        -- vim.api.nvim_win_set_option(self.component.winid, "number", false)
        -- vim.api.nvim_win_set_option(self.component.winid, "relativenumber", false)
        self:new_terminal()
    end
end

function SimpleManager:close()
    self.component:unmount()
end

function SimpleManager:show()
    self.component:show()
end

function SimpleManager:hide()
    self.component:hide()
end

function SimpleManager:get_terminals()
    return self.terminals
end

local StackTermManager = {}

return {
    SimpleManager = SimpleManager,
    StackTermManager = StackTermManager,
}
