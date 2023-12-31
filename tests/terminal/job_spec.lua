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
    it("env1", function()
        local s = spy.new(function() end)
        local job = Job:new({
            cmd = "bash",
            args = { "-c", "echo $JOB_SPEC" },
            env = { JOB_SPEC = "SPEC_VALUE" },
            on_stdout = function(data)
                if data then
                    s(data)
                end
            end,
        })
        assert(job:start())
        assert(job:wait())
        assert.spy(s).was.called_with("SPEC_VALUE\n")
    end)
    it("env2", function()
        local s = spy.new(function() end)
        local job = Job:new({
            cmd = "printenv",
            args = { "JOB_SPEC" },
            env = { JOB_SPEC = "SPEC_VALUE" },
            on_stdout = function(data)
                if data then
                    s(data)
                end
            end,
        })
        assert(job:start())
        assert(job:wait())
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

    describe("stderr", function()
        -- errecho hello
        it("errecho", function()
            local s = spy.new(function() end)
            local job = Job:new({
                cmd = "bash",
                args = { "-c", "echo error message >&2" },
                on_stderr = function(data)
                    if data then
                        s(data)
                    end
                end,
            })
            assert(job:start())
            assert(job:wait(1000))
            assert.spy(s).was.called_with("error message\n")
        end)
    end)
    describe("shared", function()
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
            assert(job:wait())
            assert.are.same(normal, watched)
        end)
        it("stderr", function()
            local normal = {}
            local watched = {}
            local job = Job:new({
                cmd = "bash",
                args = { "-c", "echo error message >&2" },
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

describe("backend same", function()
    local tasks = {
        ls = {
            cmd = "ls",
        },
        sleep = {
            cmd = "sleep",
            args = { 1 },
        },
        echo = {
            cmd = "echo",
            args = { "hello" },
        },
        echo_newline = {
            cmd = "echo",
            args = { "\n" },
        },
        echo_ansi = {
            cmd = "echo",
            args = { common.ansi_hello },
        },
        cat_ansi = {
            cmd = "cat",
            args = { common.ansi_file },
        },
        env = {
            cmd = "printenv",
            args = { "JOB_SPEC" },
            env = { JOB_SPEC = "SPEC_VALUE" },
        },
        stdin = {
            cmd = "cat",
            env = { JOB_SPEC = "SPEC_VALUE" },
            inputs = {
                "some text",
                function(job, backend)
                    job:shutdown()
                end,
            },
        },
    }
    local function get_task_output(task, backend)
        local output = {
            on_stdout = {},
            on_stderr = {},
            on_exit = {},
        }
        task = vim.deepcopy(task)
        task["backend"] = backend
        local job = Job:new(task)
        job:watch_stdout(function(data)
            table.insert(output.on_stdout, data)
        end)
        job:watch_stderr(function(data)
            table.insert(output.on_stderr, data)
        end)
        job:watch_exit(function(code, signal)
            table.insert(output.on_exit, code)
            table.insert(output.on_exit, signal)
        end)
        assert(job:start())
        assert.are.equals(job.backend, backend)
        if task.inputs then
            for _, handle in ipairs(task.inputs) do
                if type(handle) == "string" then
                    job:write(handle)
                elseif type(handle) == "function" then
                    handle(job, backend)
                end
            end
        end
        assert(job:wait())
        return vim.inspect(output)
    end
    for name, task in pairs(tasks) do
        it(name, function()
            local spawn_output = get_task_output(task, "spawn")
            local jobstart_output = get_task_output(task, "jobstart")
            assert.equals(spawn_output, jobstart_output)
        end)
    end
end)

describe("cleanup", function()
    it("shutdown bash", function()
        local j = Job:new({
            cmd = "bash",
            pty = true,
            backend = "jobstart",
        })
        j:start()
        common.sleep(1000)
        j:shutdown()
        -- vim.fn.chanclose(id, stream?)
        print(vim.inspect(vim.api.nvim_list_chans()))
    end)
end)
