local mod = {}


---@class Matrix
local Matrix = {}
Matrix.__index = Matrix
mod.Matrix = Matrix

---@return Matrix
function Matrix.new()
    return setmetatable({}, Matrix)
end

---@param x integer
---@param y integer
---@param z integer
---@param val integer
function Matrix:set(x, y, z, val)
    if self[x] == nil then
        self[x] = {}
    end
    if self[x][y] == nil then
        self[x][y] = {}
    end

    self[x][y][z] = val
end

---@param x integer
---@param y integer
---@param z integer
---@return integer?
function Matrix:get(x, y, z)
    if self[x] == nil then
        return nil
    end
    if self[x][y] == nil then
        return nil
    end
    return self[x][y][z]
end

return mod
