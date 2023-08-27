# terminal.nvim [WIP]

> Next generation terminal for neovim


# Useages

Terminal will be reused by tasks

```lua

local terminal = Terminal:new({
    cmd = "zsh"
})

terminal:add_job(Job:new({
    cmd = "cmake"
    on_exit = function(code)
        -- job complete
    end
}))

local yarn = Job:new({
    cmd = "yarn"
})
terminal:add_job(yarn)
yarn:wait()
-- job completed

```


