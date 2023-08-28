local M = {}

--- scrub ANSI color codes
---@param str any
---@return unknown
function M.scrub_ansi(str)
    str = str:gsub("\27%[[0-9;mK]+", "")
    return str
end

return M
