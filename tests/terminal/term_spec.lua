local Terminal = require("terminal.term").Terminal
local FloatTerminal = require("terminal.term").FloatTerminal
local Job = require("terminal.job")
local Path = require("plenary.path")
local charset = require("terminal.charset")
local bufop = require("terminal.bufop")
local common = require("tests.terminal.common")

describe("inheritance", function()
    it("property", function()
        local t1 = Terminal:new({
            position = "top",
            title = "MyTerm",
        })
        local t2 = Terminal:new({
            title = "AnotherTerm",
        })
        -- print(vim.inspect(t1))
        assert.equals(t1.position, "top")
        assert.equals(t2.position, "bottom")
        assert.equals(t1.title, "MyTerm")
        assert.equals(t2.title, "AnotherTerm")
    end)
end)

describe("terminal", function()
    before_each(function()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local bufnr = vim.api.nvim_win_get_buf(win)
            if vim.api.nvim_buf_get_name(bufnr):match("term:.*") then
                vim.api.nvim_win_close(win, true)
            end
        end
    end)
    it("echo", function()
        local t = Terminal:new()
        local job = Job:new({
            cmd = "echo",
            args = { "hello" },
        })
        assert(common.bridge(job, t))
        t:open()
        assert(job:start())
        assert(job:wait())
        assert(vim.api.nvim_buf_is_valid(t:get_bufnr()))

        common.sleep(2000)

        assert.equals("hello", t:get_line(0))
    end)

    it("echo ANSI", function()
        local t = Terminal:new()
        local job = Job:new({
            cmd = "echo",
            args = { common.ansi_hello },
        })
        assert(common.bridge(job, t))
        t:open()
        assert(job:start())
        assert(job:wait())
        assert(vim.api.nvim_buf_is_valid(t:get_bufnr()))

        common.sleep(2000)

        assert.equals("hello", t:get_line(0))
    end)
    it("cat", function()
        local t = Terminal:new()
        local job = Job:new({
            cmd = "cat",
            args = { common.ansi_file },
        })
        assert(common.bridge(job, t))
        t:open()
        assert(job:start())
        assert(vim.api.nvim_buf_is_valid(t:get_bufnr()))

        common.sleep(2000)
        assert.equals("Simple ANSI file", t:get_line(0))
    end)

    it("shell", function()
        local t = Terminal:new({
            cmd = "bash",
        })
        t:open()
    end)
end)

describe("float terminal", function()
    describe("basic", function()
        it("inheritance", function()
            local t1 = FloatTerminal:new({
                title = "Term1",
            })
            -- print(vim.inspect(t1))
            local t2 = FloatTerminal:new()
            assert.equals(t1.title, "Term1")
            assert.equals(t2.title, "Terminal")
        end)
        it("shell", function()
            -- print(vim.inspect(Terminal.id2term))
        end)
    end)
end)
