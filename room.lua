local mod = {}

---@class Room
---@field vnum number
---@field exits table<string, number>
---@field exit_props table<string, any>
---@field name string?
---@field void boolean
---@field hide boolean
---@field terrain integer?
---@field symbol string?
local Room = {}
Room.__index = Room
mod.Room = Room

function Room.new(vnum)
    local ret = {}
    ret.vnum = vnum
    ret.exits = {}
    ret.exit_props = {}
    ret.name = nil
    ret.void = false
    ret.hide = false
    ret.terrain = nil
    ret.symbol = nil
    return setmetatable(ret, Room)
end

---@param room Room
local function exit_count(room)
    local count = 0
    for _, _ in pairs(room.exits) do
        count = count + 1
    end
    return count
end

---@param void boolean
---@return boolean
function Room:setvoid(void)
    local exits = exit_count(self)
    if void and exits ~= 2 then
        return false
    end
    self.void = void
    return true
end

---@param exit string
---@param prop string
---@param value any
function Room:set_exit_prop(exit, prop, value)
    if not self.exit_props[exit] then
        self.exit_props[exit] = {}
    end
    self.exit_props[exit][prop] = value
end

---@param exit string
---@param prop string
---@return any
function Room:get_exit_prop(exit, prop)
    if not self.exit_props[exit] then
        return nil
    end
    return self.exit_props[exit][prop]
end

return mod
