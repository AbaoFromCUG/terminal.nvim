local Terminal = require("terminal.term").Terminal
local FloatTerminal = require("terminal.term").FloatTerminal
local Job = require("terminal.job")
local Path = require("plenary.path")
local charset = require("terminal.charset")
local bufop = require("terminal.bufop")
local common = require("tests.terminal.common")

describe("terminal", function()
    it("inheritance", function()
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
    describe("echo", function()
        it("raw", function()
            local t = Terminal:new()
            local job = Job:new({
                cmd = "echo",
                args = { "hello" },
            })
            assert(common.bridge(job, t))
            t:open()
            assert(job:start())
            assert(job:wait())

            common.sleep(2000)

            assert.is.True(t:get_line(100) == nil)
            assert.equals("hello", t:get_line(0))
        end)
        it("ANSI", function()
            local t = Terminal:new()
            local job = Job:new({
                cmd = "echo",
                args = { common.ansi_hello },
            })
            assert(common.bridge(job, t))
            t:open()
            assert(job:start())
            assert(job:wait())

            common.sleep(2000)
            assert.equals("hello", t:get_line(0))
        end)
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
