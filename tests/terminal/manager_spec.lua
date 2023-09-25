describe("insulate", function()
    ---@type terminal.SimpleManager
    local SimpleManager
    before_each(function()
        SimpleManager = require("terminal.manager").SimpleManager
    end)
    after_each(function()
        package.loaded["terminal.manager"] = nil
    end)
    it("open-close", function()
        for i = 1, 2, 1 do
            local manager = SimpleManager:new()
            assert.are.equal(1, #vim.api.nvim_list_bufs())
            assert.are.equal(1, #vim.api.nvim_list_wins())
            manager:open()
            assert.are.equal(3, #vim.api.nvim_list_bufs())
            assert.are.equal(2, #vim.api.nvim_list_wins())
            manager:close()
            manager = nil
            assert.are.equal(1, #vim.api.nvim_list_bufs())
            assert.are.equal(1, #vim.api.nvim_list_wins())
            break
        end
    end)
    it("open-split-close", function()
        for i = 1, 2, 1 do
            local manager = SimpleManager:new()
            assert.are.equal(1, #vim.api.nvim_list_bufs())
            assert.are.equal(1, #vim.api.nvim_list_wins())
            manager:open()
            assert.are.equal(3, #vim.api.nvim_list_bufs())
            assert.are.equal(2, #vim.api.nvim_list_wins())
            manager:close()
            manager = nil
            assert.are.equal(1, #vim.api.nvim_list_bufs())
            assert.are.equal(1, #vim.api.nvim_list_wins())
            break
        end
    end)
end)
