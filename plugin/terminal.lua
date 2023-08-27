local session = require("session")

local group = vim.api.nvim_create_augroup("Session", {})
vim.api.nvim_create_autocmd("StdinReadPre", {
    group = group,
    callback = function()
        print("StdinReadPre")
        session._state.started_with_stdin = true
    end,
})

vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    nested = true,
    callback = function()
        if session.enable() then
            session.restore_session()
        end
    end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
        if session.enable() then
            session.save_session()
        end
    end,
})
