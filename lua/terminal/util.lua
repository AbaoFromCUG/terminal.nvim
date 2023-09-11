local M = {}

---get index of element
---@generic T
---@param array Array<T>
---@param value T
---@return integer|nil
function M.indexOf(array, value)
    for i, v in ipairs(array) do
        if v == value then
            return i
        end
    end
    return nil
end

return M
