local terminal = require("terminal")
vim.api.nvim_create_user_command("TermToggle", function(command) end, {
    complete = function()
        return {}
    end,
    nargs = "*",
    bang = true,
    desc = "Toggle terminal",
})
