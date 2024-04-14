--[[

    Licensed under GNU General Public License v2
    * (c) 2016, Luca CPZ
    * (c) 2015, unknown
    * (c) 2024, hyperimpose.org

--]]

local io           = io
local math         = math
local pairs        = pairs
local setmetatable = setmetatable

local awful        = require("awful")
local screen       = screen
local client       = client


-- Quake-like Dropdown application spawn
local quake = {}


-- NOTE: Unsure if this comment still applies:
--
-- If you have a rule like "awful.client.setslave" for your terminals,
-- ensure you use an exception for QuakeDD. Otherwise, you may
-- run into problems with focus.

function setup(c)
    c.floating = true
    c.size_hints_honor = false
    c.sticky = false
    c.ontop = true
    c.above = true
    c.skip_taskbar = true
end

function show(c, tag, geometry)
    local screen = awful.screen.focused()

    setup(c)
    c:geometry(geometry)
    c.hidden = false
    c:raise()
    c:tags({tag})
    client.focus = c
end

function hide(c)
    c.hidden = true

    local ctags = c:tags()
    for i, t in pairs(ctags) do
        ctags[i] = nil
    end
    c:tags(ctags)
end


function quake:compute_size(screen)
    -- Skip if we already have a geometry for this screen
    if not self.geometry[screen.index] then
        local geom
        if not self.overlap then
            geom = screen.workarea
        else
            geom = screen.geometry
        end
        local width, height = self.width, self.height
        if width  <= 1 then width = math.floor(geom.width * width) - 2 end
        if height <= 1 then height = math.floor(geom.height * height) end
        local x, y
        if     self.horiz == "left"  then x = geom.x
        elseif self.horiz == "right" then x = geom.width + geom.x - width
        else   x = geom.x + (geom.width - width)/2 end
        if     self.vert == "top"    then y = geom.y
        elseif self.vert == "bottom" then y = geom.height + geom.y - height
        else   y = geom.y + (geom.height - height)/2 end
        self.geometry[screen.index] = { x = x, y = y, width = width, height = height }
    end
    return self.geometry[screen.index]
end

function quake:new(config)
    local conf = config or {}

    conf.visible    = conf.visible   or true       -- initially visible
    conf.overlap    = conf.overlap   or false      -- overlap wibox

    -- If width or height <= 1 this is a proportion of the workspace
    conf.height     = conf.height    or 0.25       -- height
    conf.width      = conf.width     or 1          -- width
    conf.vert       = conf.vert      or "top"      -- top, bottom or center
    conf.horiz      = conf.horiz     or "left"     -- left, right or center

    -- Internal use
    conf.c          = nil  -- The attached client object
    conf.geometry   = {}
    -- Client defaults to use when dettaching. Set on client attachment.
    conf.c_geometry = nil
    conf.c_tags = nil

    local dropdown = setmetatable(conf, { __index = quake })

    -- Restore the window when awesome restarts/exits
    awesome.connect_signal("exit", function() dropdown:detach() end)

    return dropdown
end

function quake:attach(c)
    self.c = c

    -- Save current client state
    self.c_geometry = c:geometry()
    self.c_tags = c:tags()
end

function quake:detach()
    self.c.floating = false
    self.c.size_hints_honor = true
    self.c.sticky = false
    self.c.ontop = false
    self.c.above = false
    self.c.skip_taskbar = false
    self.c.hidden = false
    self.c.fullscreen = false
    self.c.maximized = false
    self.c.minimized = false
    self.c:geometry(self.c_geometry)
    self.c:tags(self.c_tags)
end

function quake:use_focused()
    local c = client.focus

    if not c then
        return
    end

    if self.c and self.c.valid then  -- Unselect
        self:detach()
        if self.c == c then  -- Do not reuse the same client
            self.c = nil
            return
        end
    end

    self:attach(c)
    self:toggle()
end

function quake:toggle()
    if not self.c or not self.c.valid then
        return
    end

    local screen = awful.screen.focused()
    local current_tag = screen.selected_tag

    if current_tag and self.last_tag ~= current_tag then
        self.last_tag = current_tag
        self.visible = false
    end

    if self.visible then
        hide(self.c)
        self.visible = false
    else
        show(self.c, screen.selected_tag, self:compute_size(screen))
        self.visible = true
    end
end


return setmetatable(quake, { __call = function(_, ...) return quake:new(...) end })
