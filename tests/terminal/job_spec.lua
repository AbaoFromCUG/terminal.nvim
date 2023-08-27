local spy = require("luassert.spy")
local Job = require("terminal.job")
local Path = require("plenary.path")

local function scrub_ansi(str)
    -- scrub ANSI color codes
    str = str:gsub("\27%[[0-9;mK]+", "")
    return str
end

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
            local ansi_hello = "\x1b[31;40;9mhello\x1b[0m"
            local raw = spy.new(function() end)
            local scrubed = spy.new(function() end)
            local job = Job:new({
                cmd = "echo",
                args = { ansi_hello },
                on_stdout = function(data)
                    if data then
                        raw(data)
                        scrubed(scrub_ansi(data))
                    else
                        --stdout end
                    end
                end,
            })
            assert(job:start())
            job:wait()
            assert.spy(raw).was.called_with(string.format("%s\n", ansi_hello))
            assert.spy(scrubed).was.called_with("hello\n")
        end)

        -- cat tests/ansi.txt
        it("cat ANSI file", function()
            local ansi_file = Path:new(vim.loop.cwd()) / "tests/ansi.txt"
            local s = spy.new(function() end)
            local job = Job:new({
                cmd = "cat",
                args = { ansi_file.filename },
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
            local contents = vim.fn.readfile(ansi_file.filename)
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
            local ansi_hello = "\x1b[31;40;9mhello\x1b[0m"
            local raw = spy.new(function() end)
            local scrubed = spy.new(function() end)
            local job = Job:new({
                cmd = "cat",
                on_stdout = function(data)
                    if data then
                        raw(data)
                        scrubed(scrub_ansi(data))
                    else
                        --stdout end
                    end
                end,
            })
            assert(job:start())
            job:write(ansi_hello)
            job:wait(1000)
            job:shutdown()
            assert.spy(raw).was.called_with(string.format("%s", ansi_hello))
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
