local map = require("map")
local room = require("room")
local util = require("util")
local Map = map.Map

alias_group = alias.add_group()

local curmap = Map.new()

MAPPER = {
    map = map,
    room = room,
    alias_group = alias_group,
    curmap = curmap,
    on_print = nil,
    colours = {
        [0] = C_RESET,
    }
}

local function printMap()
    local output = curmap:ascii_string(MAPPER.colours)
    if MAPPER.on_print then
        MAPPER.on_print(output)
    else
        for _, line in ipairs(output) do
            print(line)
        end
    end
end

alias_group:add("^#dig (.+)", function(matches, line)
    curmap:checkpoint()
    curmap:dig(matches[2])
    printMap()
end)

alias_group:add("^#move (.+)", function(matches, _)
    curmap:checkpoint()
    curmap:dig(matches[2])
    curmap:move(matches[2])
    printMap()
end)

alias_group:add("^#goto ([^ ]+)", function(matches, _)
    local vnum = tonumber(matches[2])
    if vnum == nil then
        return
    end
    curmap:checkpoint()
    curmap:go_to(vnum)
    printMap()
end)

alias_group:add("^#link ([^ ]+)(?: ([^ ]+))?(?: (both))?$", function(matches, _)
    local dir = matches[2]
    local vnum = tonumber(matches[3])
    local both = matches[4] == "both" or vnum == nil and matches[3] == "both"

    curmap:checkpoint()
    curmap:link(dir, vnum, both)
    printMap()
end)

alias_group:add("^#unlink ([^ ]+)(?: ([^ ]+))?", function(matches, _)
    local dir = matches[2]
    local both = matches[3] == "both"
    curmap:checkpoint()
    curmap:unlink(dir, both)
    printMap()
end)

alias_group:add("^#prop(?: ([^ ]+)(?: ([^ ]+))?)?", function(matches, _)
    local prop = matches[2]
    local value = matches[3]

    if prop == "" then
        for k, v in pairs(curmap.props) do
            print(k .. " = " .. tostring(v))
        end
    end

    if curmap.props[prop] == nil then
        return
    end

    if value == "" then
        print(prop .. " = " .. tostring(curmap.props[prop]))
        return
    end

    if type(curmap.props[prop]) == "boolean" then
        curmap.props[prop] = util.parse_bool(value)
    else
        curmap.props[prop] = value
    end
end)

alias_group:add("^#insert ([^ ]+)(?: ([^ ]+))*", function(matches, _)
    local dir = matches[2]
    local void = matches[3] == "void" or matches[4] == "void"
    local hide = matches[3] == "hide" or matches[4] == "hide"

    curmap:checkpoint()
    local new_room = curmap:insert(dir)

    if new_room then
        new_room:setvoid(void)
        new_room.hide = hide
    end
    printMap()
end)

alias_group:add("^#uninsert ([^ ]+)", function(matches, _)
    local dir = matches[2]

    curmap:checkpoint()
    curmap:uninsert(dir)
    printMap()
end)

alias_group:add("^#merge ([^ ]+)", function(matches, _)
    local vnum = tonumber(matches[2])
    if vnum == nil then
        return
    end

    curmap:checkpoint()
    curmap:merge_room(vnum)
    printMap()
end)

alias_group:add("^#delete ([^ ]+)", function(matches, _)
    local dir = matches[2]

    curmap:checkpoint()
    curmap:delete(dir)
    printMap()
end)

alias_group:add("^#undo", function(_, _)
    curmap:undo()
    printMap()
end)

alias_group:add("^#info", function(_, _)
    local room = curmap:room()
    print("Current room: " .. room.vnum)
    print("Exits:")
    for dir, exit in pairs(room.exits) do
        print(dir, exit)
    end
end)

alias_group:add("^#map", function(_, _)
    printMap()
end)

alias_group:add("^#vnums", function(_, _)
    local setting = curmap.props.vnums
    curmap.props.vnums = true
    printMap()
    curmap.props.vnums = setting
end)

alias_group:add("^#save (.+)", function(matches, _)
    curmap:save(matches[2])
end)

alias_group:add("^#load (.+)", function(matches, _)
    curmap:load(matches[2])
    printMap()
end)

alias_group:add("^#room name (.+)", function(matches, _)
    local name = matches[2]

    curmap:room().name = name
end)

alias_group:add("^#room void ([^ ]+)", function(matches, _)
    local void = util.parse_bool(matches[2])

    curmap:room():setvoid(void)
    printMap()
end)

alias_group:add("^#room hide ([^ ]+)", function(matches, _)
    local hide = util.parse_bool(matches[2])

    curmap:room().hide = hide
    printMap()
end)

alias_group:add("^#room symbol (.)", function(matches, _)
    curmap:room().symbol = matches[2] ~= " " and matches[2] or nil
end)

alias_group:add("^#exit hide ([^ ]+) ([^ ]+)", function(matches, _)
    local dir = matches[2]
    local hide = util.parse_bool(matches[3])

    local room = curmap:room()
    room:set_exit_prop(dir, "hide", hide)
    printMap()
end)

alias_group:add("^#find (.+)", function(matches, _)
    local name = matches[2]

    local rooms = curmap:fuzzy_find_room(name)
    for k, v in pairs(rooms) do
        print(tostring(k) .. ": " .. v.name)
    end
end)

alias_group:add("^#clear", function(_, _)
    curmap = Map.new()
    MAPPER.curmap = curmap
end)
