local term = require("terminal.term")
local Job = require("terminal.job")
local util = require("terminal.util")
local Split = require("nui.split")

---@class terminal.SimpleManager
---@field protected component NuiSplit
---@field protected terminals terminal.AttachmentTerminal[]
---@field protected active_index? number
---@field protected term2job {[terminal.AttachmentTerminal]: terminal.Job[]}
---@field protected relative nui_split_option_relative_type|nui_split_option_relative
---@field protected position nui_split_option_position
---@field protected size number|string|nui_split_option_size

local SimpleManager = {}
SimpleManager.__index = SimpleManager
setmetatable(SimpleManager, {})

---@class terminal.NewSimpleManagerArgs
---@field relative? nui_split_option_relative_type|nui_split_option_relative
---@field position? nui_split_option_position
---@field size? number|string|nui_split_option_size

---TermManager conscturctor
---@param options? terminal.NewSimpleManagerArgs
---@return terminal.SimpleManager
function SimpleManager:new(options)
    local o = vim.tbl_deep_extend("force", { relative = "win", position = "bottom", size = "30%" }, options or {})
    o.terminals = {}
    o.term2job = {}
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
    job:watch_exit(function(exit_code, signal)
        print(vim.inspect(exit_code))
        print(vim.inspect(signal))

        -- if #self.terminals == 1 then
        --     self:close_terminal(1)
        --     self:hide()
        --     return
        -- end
        -- local idx = assert(util.indexOf(self.terminals, t))
        -- self:close_terminal(idx)
        -- self:active_terminal(math.min(idx, #self.terminals))
    end)
    t:open()
    job:start()
    table.insert(self.terminals, t)
    self.term2job[t] = { job }
    self:active_terminal(#self.terminals)
end

function SimpleManager:close_terminal(index)
    assert(index >= 1 and index <= #self.terminals, #self.terminals)
    local t = self.terminals[index]
    for _, j in ipairs(self.term2job[t]) do
        j:shutdown()
    end
    t:close()
    table.remove(self.terminals, index)
    self.term2job[t] = nil
end

function SimpleManager:active_terminal(index)
    assert(index >= 1 and index <= #self.terminals)
    local terminal = self.terminals[index]
    vim.api.nvim_win_set_buf(self.component.winid, terminal.bufnr)
    self.active_index = index
end

function SimpleManager:get_width()
    return vim.api.nvim_win_get_width(self.component.winid)
end

function SimpleManager:get_height()
    return vim.api.nvim_win_get_height(self.component.winid)
end

function SimpleManager:open()
    if self.component == nil then
        self.component = Split({
            relative = self.relative,
            position = self.position,
            size = self.size,
            win_options = {
                number = false,
                relativenumber = false,
            },
        })
        self.component:mount()
        self:new_terminal()
    else
        self:show()
    end
end

function SimpleManager:close()
    while #self.terminals > 0 do
        self:close_terminal(1)
    end
    self.component:unmount()
end

function SimpleManager:show()
    self.component:show()
    for _, t in ipairs(self.terminals) do
        t.winid = self.component.winid
    end
    self:active_terminal(self.active_index)
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
}
