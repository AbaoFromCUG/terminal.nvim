local M = {}

function M.get_buf_content(bufnr)
    local content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    return table.concat(content, "\n")
end

return M
