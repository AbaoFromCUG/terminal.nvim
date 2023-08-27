local Terminal = require("terminal.terminal").Terminal
local FloatTerminal = require("terminal.terminal").FloatTerminal

describe("terminal", function()
    describe("basic", function()
        it("inheritance", function()
            local t1 = Terminal:new({
                position = "top",
                title = "MyTerm",
            })
            local t2 = Terminal:new({
                title = "AnotherTerm",
            })
            assert.equals(t1.position, "top")
            assert.equals(t2.position, "bottom")
            assert.equals(t1.title, "MyTerm")
            assert.equals(t2.title, "AnotherTerm")
        end)

        it("shell", function()
            local t = Terminal:new({
                cmd = "bash",
            })
            t:open()
        end)
    end)
end)

describe("float terminal", function()
    describe("basic", function()
        it("inheritance", function()
            local t1 = FloatTerminal:new({
                title = "Term1",
            })
            local t2 = FloatTerminal:new()
            assert.equals(t1.title, "Term1")
            assert.equals(t2.title, "Terminal")
        end)
        it("shell", function()
            local t = FloatTerminal:new({ title = "shell" })
            -- t:open()
        end)
    end)
end)
