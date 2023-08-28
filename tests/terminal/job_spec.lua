local spy = require("luassert.spy")
local Job = require("terminal.job")
local charset = require("terminal.charset")
local common = require("tests.terminal.common")

describe("basic", function()
    it("status", function()
        -- local stdout = spy.new(function() end)
        local job = Job:new({
            cmd = "sleep",
            args = { 1 },
        })
        assert.equals("ready", job:get_status())
        assert(job:start())
        assert.equals("running", job:get_status())
        job:wait()
        assert.equals("shutdown", job:get_status())
    end)

    it("cwd", function()
        local s = spy.new(function() end)
        local job = Job:new({
            cmd = "pwd",
            cwd = "/tmp",
            on_stdout = function(data)
                if data then
                    s(data)
                end
            end,
        })
        assert(job:start())
        job:wait()
        assert.spy(s).was.called_with("/tmp\n")
    end)

    it("env", function()
        local s = spy.new(function() end)
        local job = Job:new({
            cmd = "bash",
            args = { "-c", "echo $JOB_SPEC" },
            env = { "JOB_SPEC=SPEC_VALUE" },
            on_stdout = function(data)
                if data then
                    s(data)
                end
            end,
        })
        assert(job:start())
        job:wait()
        assert.spy(s).was.called_with("SPEC_VALUE\n")
    end)
end)

describe("stdio", function()
    describe("stdout", function()
        -- echo hello
        it("echo", function()
            local s = spy.new(function() end)
            local job = Job:new({
                cmd = "echo",
                args = { "hello" },
                on_stdout = function(data)
                    if data then
                        s(data)
                    else
                        --stdout end
                    end
                end,
            })
            assert(job:start())
            job:wait()
            assert.spy(s).was.called_with("hello\n")
        end)

        -- echo "\x1b[31;40;9mhello\x1b[0m"
        it("echo ANSI", function()
            local raw = spy.new(function() end)
            local scrubed = spy.new(function() end)
            local job = Job:new({
                cmd = "echo",
                args = { common.ansi_hello },
                on_stdout = function(data)
                    if data then
                        raw(data)
                        scrubed(charset.scrub_ansi(data))
                    else
                        --stdout end
                    end
                end,
            })
            assert(job:start())
            job:wait()
            assert.spy(raw).was.called_with(string.format("%s\n", common.ansi_hello))
            assert.spy(scrubed).was.called_with("hello\n")
        end)

        -- cat tests/ansi.txt
        it("cat ANSI file", function()
            local s = spy.new(function() end)
            local job = Job:new({
                cmd = "cat",
                args = { common.ansi_file },
                on_stdout = function(data)
                    if data then
                        s(data)
                    else
                        --stdout end
                    end
                end,
            })
            assert(job:start())
            job:wait()
            -- readfile keep ANSI code
            local contents = vim.fn.readfile(common.ansi_file)
            -- readfile will ignore last line NL
            local content = table.concat(contents, "\n") .. "\n"
            assert.spy(s).was.called_with(content)
        end)
    end)

    describe("stdin", function()
        -- echo hello |cat
        it("cat", function()
            local s = spy.new(function() end)
            local job = Job:new({
                cmd = "cat",
                on_stdout = function(data)
                    if data then
                        s(data)
                    else
                        --stdout end
                    end
                end,
            })
            assert(job:start())
            job:write("hello")
            job:wait(1000)
            job:shutdown()
            assert.spy(s).was.called_with("hello")
        end)

        -- echo "\x1b[31;40;9mhello\x1b[0m" |cat
        it("cat ANSI", function()
            local raw = spy.new(function() end)
            local scrubed = spy.new(function() end)
            local job = Job:new({
                cmd = "cat",
                on_stdout = function(data)
                    if data then
                        raw(data)
                        scrubed(charset.scrub_ansi(data))
                    else
                        --stdout end
                    end
                end,
            })
            assert(job:start())
            job:write(common.ansi_hello)
            job:wait(1000)
            job:shutdown()
            assert.spy(raw).was.called_with(string.format("%s", common.ansi_hello))
            assert.spy(scrubed).was.called_with("hello")
        end)
    end)

    describe("shareed", function()
        it("stdout", function()
            local normal = {}
            local watched = {}
            local job = Job:new({
                cmd = "echo",
                args = { "hello" },
                on_stdout = function(data)
                    table.insert(normal, data)
                end,
            })
            job:watch_stdout(function(data)
                table.insert(watched, data)
            end)
            assert(job:start())
            job:wait()
            assert.are.same(normal, watched)
        end)
        it("stderr", function()
            local normal = {}
            local watched = {}
            local job = Job:new({
                cmd = "echo",
                args = { "hello" },
                on_stdout = function(data)
                    table.insert(normal, data)
                end,
            })
            job:watch_stdout(function(data)
                table.insert(watched, data)
            end)
            assert(job:start())
            job:wait()
            assert.are.same(normal, watched)
        end)
    end)
end)

describe("pty", function()
    --TODO:wait for https://github.com/neovim/neovim/pull/23747
end)
