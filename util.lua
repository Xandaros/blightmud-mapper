local mod = {}

---@param tbl table
function mod.deep_copy(tbl)
    local ret = setmetatable({}, getmetatable(tbl))
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            ret[k] = mod.deep_copy(v)
        else
            ret[k] = v
        end
    end
    return ret
end

---@param needle string
---@param str string
function mod.fuzzy_match(needle, str)
    needle = string.lower(needle)
    str = string.lower(str)
    local idx = 1
    for i=1, #needle do
        while str:sub(idx, idx) ~= needle:sub(i, i) do
            if idx > #str then
                return false
            end
            idx = idx + 1
        end
    end
    return true
end

---@param str string
---@return boolean
function mod.parse_bool(str)
    return str == "true" or str == "on" or str == "y" or str == "yes" or str == "1"
end

return mod
