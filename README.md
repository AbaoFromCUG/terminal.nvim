# terminal.nvim [WIP]

> Next generation terminal for neovim


# Useages

Terminal will be reused by tasks

```lua

local terminal = Terminal:new()

local cmake = Job:new({
    cmd = "cmake",
    on_exit = function(code)
        -- job complete
    end
})
cmake:watch_stdout(function(data)
    terminal:write(data)
end)
cmake:wait()
-- terminal can be reused

```


