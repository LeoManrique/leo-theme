-- 04-mod.lua — sm64coopdx-flavoured, matching GameDev/sm64coopdx-ios.
--
-- Lua is the sparse-grammar case: few keywords, no type annotations, and most
-- of the file is bare identifiers. If unmatched text is too dim in Leo Dark,
-- this is the sample where it becomes obvious — the majority of these lines
-- have nothing to fall back on but editor.foreground.

--[[
    Long-bracket block comment.
    Spans multiple lines and should read as one continuous comment,
    including this ]==] which is not a terminator at this level.
]]

local MOD_NAME    = "preview-hud"
local MOD_VERSION = "0.3.1"
local MAX_PLAYERS = 16
local HUD_MARGIN  = 8
local COLOR_MASK  = 0xFF00FF
local GOLDEN      = 1.618033988749
local ENABLED     = true
local UNSET       = nil

-- Table constructor with mixed array and hash parts.
local PALETTE = {
    background = { r = 0x16, g = 0x16, b = 0x16, a = 0xFF },
    accent     = { r = 0x59, g = 0x96, b = 0xDB, a = 0xFF },
    warning    = { r = 0xDE, g = 0xC0, b = 0x78, a = 0xFF },
    "first",
    "second",
    [10] = "sparse",
}

local LEVEL_NAMES = {
    [LEVEL_CASTLE_GROUNDS] = "Castle Grounds",
    [LEVEL_BOB]            = "Bob-omb Battlefield",
    [LEVEL_WF]             = "Whomp's Fortress",
}

local state = {
    frame     = 0,
    visible   = ENABLED,
    lastActor = UNSET,
    history   = {},
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

--- Clamps `value` into the inclusive range [lo, hi].
local function clamp(value, lo, hi)
    if value < lo then
        return lo
    elseif value > hi then
        return hi
    end
    return value
end

-- Multiple return values, a very Lua thing.
local function split(str, sep)
    sep = sep or "%s"
    local parts, count = {}, 0
    for field in string.gmatch(str, "([^" .. sep .. "]+)") do
        count = count + 1
        parts[count] = field
    end
    return parts, count
end

-- Varargs, select(), and string.format.
local function log(level, fmt, ...)
    if not state.visible then return end
    local prefix = string.format("[%s/%s] %-5s ", MOD_NAME, MOD_VERSION, level)
    local n = select("#", ...)
    if n == 0 then
        print(prefix .. fmt)
    else
        print(prefix .. string.format(fmt, ...))
    end
end

local function isLoud(level)
    return level == "warn" or level == "fatal"
end

---------------------------------------------------------------------------
-- Metatables and method syntax
---------------------------------------------------------------------------

local Ring = {}
Ring.__index = Ring

function Ring.new(capacity)
    return setmetatable({ items = {}, capacity = capacity or 8, head = 0 }, Ring)
end

function Ring:push(value)
    self.head = (self.head % self.capacity) + 1
    self.items[self.head] = value
    return self
end

function Ring:len()
    return #self.items
end

function Ring:each(fn)
    for i, value in ipairs(self.items) do
        fn(value, i)
    end
end

Ring.__tostring = function(self)
    return ("Ring(%d/%d)"):format(self:len(), self.capacity)
end

Ring.__len = function(self) return self:len() end

---------------------------------------------------------------------------
-- Loops
---------------------------------------------------------------------------

local function scanPlayers()
    local active = Ring.new(MAX_PLAYERS)

    -- Numeric for, with an explicit step.
    for i = 0, MAX_PLAYERS - 1, 1 do
        local np = gNetworkPlayers[i]
        if np ~= nil and np.connected then
            active:push(np.globalIndex)
        end
    end

    -- Generic for over a hash table.
    for name, color in pairs(PALETTE) do
        if type(color) == "table" then
            log("debug", "palette %s -> #%02X%02X%02X", name, color.r, color.g, color.b)
        end
    end

    -- while / repeat-until, the two loop forms people forget.
    local tries = 0
    while tries < 3 and active:len() == 0 do
        tries = tries + 1
    end

    repeat
        tries = tries - 1
    until tries <= 0

    return active
end

---------------------------------------------------------------------------
-- Hooks
---------------------------------------------------------------------------

local function onUpdate()
    state.frame = state.frame + 1
    if state.frame % 30 ~= 0 then return end

    local m = gMarioStates[0]
    if m == nil then goto skip end

    do
        local speed  = clamp(m.forwardVel, -64.0, 64.0)
        local height = m.pos[1]
        local level  = LEVEL_NAMES[gNetworkPlayers[0].currLevelNum] or "Unknown"

        state.history[#state.history + 1] = {
            frame = state.frame,
            speed = speed,
            level = level,
        }

        log(isLoud("info") and "warn" or "info",
            "%s | vel %.2f | y %.1f | %d entries",
            level, speed, height, #state.history)
    end

    ::skip::
end

local function onHudRender()
    if not state.visible then return end

    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_TINY)
    djui_hud_set_color(PALETTE.accent.r, PALETTE.accent.g, PALETTE.accent.b, 0xC0)

    local text = ("frame %d  ·  %s"):format(state.frame, tostring(Ring.new(4)))
    djui_hud_print_text(text, HUD_MARGIN, HUD_MARGIN, 1.0)
end

local function onChatCommand(msg)
    local args, count = split(msg, " ")
    if count == 0 then return false end

    local verb = args[1]:lower()
    if verb == "toggle" then
        state.visible = not state.visible
        djui_chat_message_create("preview hud: " .. (state.visible and "on" or "off"))
        return true
    elseif verb == "reset" then
        state.history = {}
        return true
    end

    return false
end

hook_event(HOOK_UPDATE, onUpdate)
hook_event(HOOK_ON_HUD_RENDER, onHudRender)
hook_chat_command("preview", "[toggle|reset]", onChatCommand)

log("info", "loaded %s v%s (mask 0x%06X, phi %.6f)", MOD_NAME, MOD_VERSION, COLOR_MASK, GOLDEN)

return {
    name    = MOD_NAME,
    version = MOD_VERSION,
    Ring    = Ring,
    clamp   = clamp,
    scan    = scanPlayers,
}
