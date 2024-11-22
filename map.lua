local util = require("util")
local Matrix = require("matrix").Matrix
local Room = require("room").Room

local mod = {}

---@class Props
---@field vnums boolean
---@field width integer
---@field height integer
---@field automerge boolean
local Props = {}
Props.__index = Props
mod.Props = Props

---@return Props
function Props.default()
    return {
        vnums = false,
        width = 80,
        height = 24,
        automerge = false,
    }
end

---@class Map
---@field rooms {[integer]: Room}
---@field cur_room integer
---@field max_vnum integer
---@field previous table?
---@field props Props
local Map = {}
Map.__index = Map
mod.Map = Map

mod.DIR_REVERSE = {
    e = "w",
    w = "e",
    n = "s",
    s = "n",
    ne = "sw",
    se = "nw",
    nw = "se",
    sw = "ne",
    u = "d",
    d = "u",
}

mod.DIR_VEC = {
    n = {0, -1, 0},
    s = {0, 1, 0},
    e = {1, 0, 0},
    w = {-1, 0, 0},
    ne = {1, -1, 0},
    se = {1, 1, 0},
    nw = {-1, -1, 0},
    sw = {-1, 1, 0},
    u = {0, 0, 1},
    d = {0, 0, -1},
}

---@return Map
function Map.new()
    local ret = setmetatable({}, Map)
    ret.rooms = {Room.new(1)}
    ret.cur_room = 1
    ret.max_vnum = 1
    ret.props = {
        vnums = false,
        width = 80,
        height = 16,
        automerge = false,
    }
    return ret
end

function Map:undo()
    if self.previous then
        self.rooms = self.previous.rooms
        self.cur_room = self.previous.cur_room
        self.max_vnum = self.previous.max_vnum
        self.previous = self.previous.previous
    end
end

function Map:checkpoint()
    local cp = {}
    cp.rooms = util.deep_copy(self.rooms)
    cp.cur_room = self.cur_room
    cp.max_vnum = self.max_vnum
    cp.previous = self.previous
    self.previous = cp
end

---@return Room
function Map:room()
    return self.rooms[self.cur_room]
end

---@return Room
function Map:create_room()
    local new_vnum = nil
    for i=1, self.max_vnum do
        if self.rooms[i] == nil then
            new_vnum = i
            break
        end
    end
    if new_vnum == nil then
        new_vnum = self.max_vnum + 1
    end

    if new_vnum > self.max_vnum then
        self.max_vnum = new_vnum
    end

    local new_room = Room.new(new_vnum)
    self.rooms[new_vnum] = new_room

    return new_room
end

---@param dir string
---@return boolean
function Map:dig(dir)
    local room = self:room()

    if room.exits[dir] then
        return false
    end

    if self.props.automerge and self:link(dir, nil, true) then
        return true
    end

    local new_room = self:create_room()

    room.exits[dir] = new_room.vnum

    if mod.DIR_REVERSE[dir] then
        new_room.exits[mod.DIR_REVERSE[dir]] = self.cur_room
    end

    return true
end

---@param dir string
function Map:move(dir)
    local room = self:room()
    if room.exits[dir] then
        self.cur_room = room.exits[dir]

        if self:room().void then
            self:move(dir)
        end
    end
end

---@param vnum integer
function Map:go_to(vnum)
    if not self.rooms[vnum] then
        return
    end

    self.cur_room = vnum
end

---@param vnum integer
function Map:delete_room(vnum)
    if not self.rooms[vnum] then
        return
    end

    for _, room in pairs(self.rooms) do
        local bad_exits = {}
        for dir, exit in pairs(room.exits) do
            if exit == vnum then
                bad_exits[dir] = true
            end
        end
        for exit in pairs(bad_exits) do
            room.exits[exit] = nil
        end
    end

    self.rooms[vnum] = nil
end

function Map:delete(dir)
    local room = self:room()

    if not room.exits[dir] then
        return
    end

    self:delete_room(room.exits[dir])
end

---@param dir string
---@return Room?
function Map:insert(dir)
    local room = self:room()
    local other_room = self.rooms[room.exits[dir]]

    if other_room == nil or not mod.DIR_REVERSE[dir] or other_room.exits[mod.DIR_REVERSE[dir]] ~= room.vnum then
        return nil
    end

    local new_room = self:create_room()
    room.exits[dir] = new_room.vnum
    other_room.exits[mod.DIR_REVERSE[dir]] = new_room.vnum

    new_room.exits[mod.DIR_REVERSE[dir]] = room.vnum
    new_room.exits[dir] = other_room.vnum

    return new_room
end

function Map:uninsert(dir)
    if not mod.DIR_REVERSE[dir] then
        return
    end

    local room = self:room()
    local todelete = self.rooms[room.exits[dir]]
    if todelete == nil then
        return
    end
    local backlink = self.rooms[todelete.exits[dir]]
    if backlink == nil then
        return
    end

    room.exits[dir] = backlink.vnum
    backlink.exits[mod.DIR_REVERSE[dir]] = room.vnum

    self:delete_room(todelete.vnum)
end

---@param dir string
---@param vnum integer?
---@param both boolean
---@return boolean
function Map:link(dir, vnum, both)
    if vnum == nil then
        local matrix = self:displayMatrix(0, 0)
        local offset = mod.DIR_VEC[dir]
        if not offset then
            return false
        end

        vnum = matrix:get(offset[1], offset[2], offset[3])
    end
    if not self.rooms[vnum] then
        return false
    end

    local room = self:room()
    room.exits[dir] = vnum

    if both and mod.DIR_REVERSE[dir] then
        self.rooms[vnum].exits[mod.DIR_REVERSE[dir]] = room.vnum
    end

    return true
end

---@param dir string
---@param both boolean
function Map:unlink(dir, both)
    local room = self:room()
    if both and room.exits[dir] and mod.DIR_REVERSE[dir] then
        self.rooms[room.exits[dir]].exits[mod.DIR_REVERSE[dir]] = nil
    end
    room.exits[dir] = nil
end

---@param vnum integer
function Map:merge_room(vnum)
    local room = self:room()
    local other_room = self.rooms[vnum]
    if other_room == nil then
        return
    end

    -- Same exit pointing to different rooms - can't merge
    for dir, exit in pairs(room.exits) do
        if other_room.exits[dir] ~= nil and other_room.exits[dir] ~= exit then
            return
        end
    end

    -- Move exits
    for dir, exit in pairs(room.exits) do
        other_room.exits[dir] = exit
    end

    -- Update incoming exits
    for _, itroom in pairs(self.rooms) do
        for dir, exit in pairs(itroom.exits) do
            if exit == room.vnum then
                itroom.exits[dir] = other_room.vnum
            end
        end
    end

    self.cur_room = other_room.vnum

    self.rooms[room.vnum] = nil
end

---@param name string
---@return {integer: Room}
function Map:fuzzy_find_room(name)
    local results = {}
    for _, room in pairs(self.rooms) do
        if room.name and util.fuzzy_match(name, room.name) then
            results[room.vnum] = room
        end
    end
    return results
end

---@param path string
function Map:save(path)
    local rooms = {}
    for _, v in pairs(self.rooms) do
        rooms[#rooms+1] = v
    end

    local value = {
        cur_room = self.cur_room,
        max_vnum = self.max_vnum,
        rooms = rooms,
        props = self.props,
    }

    local file = io.open(path, "w")
    if file == nil then
        return
    end

    file:write(json.encode(value))
    file:close()
end

---@param path string
function Map:load(path)
    local file = io.open(path, "r")
    if file == nil then
        return
    end
    local value = json.decode(file:read("a"))
    file:close()

    local rooms = {}
    for _, room in pairs(value.rooms) do
        setmetatable(room, Room)
        rooms[room.vnum] = room
        if not room.exit_props then
            room.exit_props = {}
        end
    end
    self.rooms = rooms
    self.cur_room = value.cur_room
    self.max_vnum = value.max_vnum
    self.props = value.props or Props.default()
    self.previous = nil
end

---@param width integer
---@param height integer
function Map:displayMatrix(width, height)
    local matrix = Matrix.new()

    matrix:set(0, 0, 0, self.cur_room)

    local positions = {}
    positions[self.cur_room] = {0, 0, 0}

    local visited = {}
    local open = {self.cur_room}

    local idx = 1
    while open[idx] ~= nil do
        local vnum = open[idx]
        local room = self.rooms[vnum]
        local pos = positions[vnum]

        if not room.hide or idx == 1 then
            for dir, exit in pairs(room.exits) do
                local x = pos[1]
                local y = pos[2]
                local z = pos[3]
                local offset = mod.DIR_VEC[dir]
                if offset then
                    x = x + offset[1]
                    y = y + offset[2]
                    z = z + offset[3]

                    if not (self.rooms[exit].void and self.rooms[exit].hide or room:get_exit_prop(dir, "hide")) then
                        if width == 0 and height == 0 or x >= -math.floor(width / 2) and x <= math.ceil(width /2) and y >= -math.floor(height / 2) and y <= math.ceil(height / 2) then
                            if not visited[exit] then
                                if matrix:get(x, y, z) == nil then
                                    matrix:set(x, y, z, exit)
                                end
                                positions[exit] = {x, y, z}

                                open[#open+1] = exit
                                visited[exit] = true
                            end
                        end
                    end
                end
            end
        end

        idx = idx + 1
    end

    return matrix
end

---@param colours table<integer, string>?
---@return [string]
function Map:ascii_string(colours)
    local ret = {}
    local max_vnum_len = #tostring(self.max_vnum)

    local room_height = 3
    local room_width = 6
    if self.props.vnums then
        room_width = max_vnum_len + 5
    end

    local width = self.props.width
    local height = self.props.height
    if width == nil then
        width = 80
    end
    if height == nil then
        height = 16
    end

    local width_rooms = math.floor(width / room_width)
    local height_rooms = math.floor(height / room_height)

    local matrix = self:displayMatrix(width_rooms * 20, height_rooms * 20)
    if matrix == nil then
        return {}
    end

    for y = -math.floor(height_rooms / 2), math.ceil(height_rooms / 2) do
        local rows = {"", "", ""}
        for x = -math.floor(width_rooms / 2), math.ceil(width_rooms / 2) do
            local vnum = matrix:get(x,y,0)
            if not vnum then
                local width = 6
                if self.props.vnums then
                    width = max_vnum_len + 5
                end
                rows[1] = rows[1] .. string.rep(" ", width)
                rows[2] = rows[2] .. string.rep(" ", width)
                rows[3] = rows[3] .. string.rep(" ", width)
            else
                local room = self.rooms[vnum]
                local prefix = " "
                local suffix = "  "
                if room.exits.w then
                    prefix = "-"
                end
                if room.exits.e then
                    suffix = "--"
                end

                local middle_colour_len = 0

                if room.terrain and colours and colours[room.terrain] then
                    prefix = prefix .. colours[room.terrain]
                    suffix = C_RESET .. suffix
                    middle_colour_len = #colours[room.terrain] + #C_RESET
                end

                local top = ""
                local middle = ""
                local bottom = ""

                local centre = " "
                if self.props.vnums then
                    if vnum == self.cur_room then
                        centre = string.format("%" .. max_vnum_len .. "s", "-")
                    else
                        centre = string.format("%" .. max_vnum_len .. "s", vnum)
                    end
                else
                    if vnum == self.cur_room then
                        centre = "-"
                    elseif room.symbol then
                        centre = room.symbol
                    end
                end
                middle = prefix .. "[" .. centre .. "]" .. suffix

                if not self.props.vnums and room.void then
                    if room.exits.n then
                        centre = " | "
                    elseif room.exits.e then
                        centre = "---"
                    elseif room.exits.ne then
                        centre = " / "
                    elseif room.exits.se then
                        centre = " \\ "
                    else
                        centre = "   "
                    end
                    middle = prefix .. centre .. suffix
                end

                local middle_len = #middle - middle_colour_len

                if room.exits.nw then
                    top = "\\"
                else
                    top = " "
                end
                if room.exits.n then
                    top = top .. string.rep(" ", math.floor((middle_len - 3) / 2)) .. "|" .. string.rep(" ", math.ceil((middle_len - 3) / 2) - 2)
                else
                    top = top .. string.rep(" ", middle_len - 4)
                end
                if room.exits.u then
                    top = top .. "+"
                else
                    top = top .. " "
                end
                if room.exits.ne then
                    top = top .. "/ "
                else
                    top = top .. "  "
                end

                if room.exits.sw then
                    bottom = "/"
                else
                    bottom = " "
                end
                if room.exits.d then
                    bottom = bottom .. "-"
                else
                    bottom = bottom .. " "
                end
                if room.exits.s then
                    bottom = bottom .. string.rep(" ", math.floor((middle_len - 3) / 2) - 1) .. "|" .. string.rep(" ", math.ceil((middle_len - 3) / 2) - 1)
                else
                    bottom = bottom .. string.rep(" ", middle_len - 4)
                end
                if room.exits.se then
                    bottom = bottom .. "\\ "
                else
                    bottom = bottom .. "  "
                end

                rows[1] = rows[1] .. top
                rows[2] = rows[2] .. middle
                rows[3] = rows[3] .. bottom
            end
        end
        ret[#ret+1] = rows[1]
        ret[#ret+1] = rows[2]
        ret[#ret+1] = rows[3]
    end
    return ret
end

return mod
