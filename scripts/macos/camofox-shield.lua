-- camofox-shield.lua
--
-- macOS-native replacement for the fork's scripts/camofox-input-shield.sh.
-- Uses hs.eventtap to drop physical mouse/scroll events whose location is
-- (a) inside the page area of a Camoufox window (below the chrome) AND
-- (b) the Camoufox window is the *topmost* window under that point.
-- That keeps clicks on any other window placed visually on top of Camoufox
-- working normally. Playwright/CDP automation does not go through NSEvent,
-- so MCP-driven clicks are unaffected.
--
-- Toggle: Ctrl+Alt+I
-- Enable: Ctrl+Alt+Cmd+I
-- Disable: Ctrl+Alt+Shift+I

local M = {}

local APP_NAME_LOWER = "camoufox"
local LOG = hs.logger.new("camofox-shield", "info")

-- Pixels at the top of each Camoufox window that should remain interactive
-- (title bar + tab strip + URL/nav bar).
local CHROME_HEIGHT = 90

-- Cache of front-to-back ordered visible windows, refreshed at ~30 Hz so
-- the eventtap callback doesn't have to do an Accessibility round-trip on
-- every mouse-move event.
local orderedCache = {}
local refreshTimer = nil
local tap = nil
local enabled = true

local function isCamoufoxAppName(name)
    if not name then return false end
    return name:lower() == APP_NAME_LOWER
end

local function refreshOrderedCache()
    local out = {}
    for _, w in ipairs(hs.window.orderedWindows()) do
        local app = w:application()
        local f = w:frame()
        if f and app then
            out[#out + 1] = {
                app = app:name(),
                frame = f,
                isCamoufox = isCamoufoxAppName(app:name()),
            }
        end
    end
    orderedCache = out
end

-- Return the topmost window entry containing the point, or nil.
local function topmostAt(p, cache)
    for _, w in ipairs(cache) do
        local f = w.frame
        if p.x >= f.x and p.x < f.x + f.w and p.y >= f.y and p.y < f.y + f.h then
            return w
        end
    end
    return nil
end

local function shouldDrop(event)
    if not enabled then return false end
    local loc = event:location()
    if not loc then return false end
    local top = topmostAt(loc, orderedCache)
    if not top then return false end
    if not top.isCamoufox then return false end
    -- Inside a Camoufox window AND no other window is visually above it
    -- here. Drop only if we're below the chrome (page area).
    return loc.y >= top.frame.y + CHROME_HEIGHT
end

local function tapCallback(event)
    if shouldDrop(event) then
        return true  -- consume the event; do not propagate to any window.
    end
    return false  -- let it through.
end

-- For mouseDown events the 33 ms cache latency can cause wrong decisions if
-- the user just brought a window above Camoufox. Do a synchronous refresh
-- right before deciding so a click that should reach the front window
-- isn't accidentally dropped.
local function tapCallbackForClicks(event)
    if not enabled then return false end
    refreshOrderedCache()
    return tapCallback(event)
end

function M.enable()
    enabled = true
    refreshOrderedCache()
    if tap then tap:start() end
    if refreshTimer then refreshTimer:start() end
    hs.alert.show("Camofox shield: ON")
    LOG.i("shield enabled")
end

function M.disable()
    enabled = false
    if tap then tap:stop() end
    if refreshTimer then refreshTimer:stop() end
    orderedCache = {}
    hs.alert.show("Camofox shield: OFF")
    LOG.i("shield disabled")
end

function M.toggle()
    if enabled then M.disable() else M.enable() end
end

function M.status()
    return {
        enabled = enabled,
        cacheSize = #orderedCache,
        tapEnabled = tap and tap:isEnabled() or false,
    }
end

function M.debugDump()
    local lines = {}
    table.insert(lines, string.format("enabled=%s cache=%d tap=%s",
        tostring(enabled), #orderedCache, tostring(tap and tap:isEnabled())))
    for i, w in ipairs(orderedCache) do
        if i <= 8 then
            local f = w.frame
            table.insert(lines, string.format("%d %s %dx%d@%d,%d%s",
                i, w.app, f.w, f.h, f.x, f.y, w.isCamoufox and " [SHIELD]" or ""))
        end
    end
    return table.concat(lines, " | ")
end

function M.start()
    refreshTimer = hs.timer.new(1 / 30, refreshOrderedCache)

    local et = hs.eventtap.event.types
    -- Single tap for high-frequency hover/scroll events (uses cached order).
    tap = hs.eventtap.new({
        et.mouseMoved,
        et.leftMouseDragged,
        et.rightMouseDragged,
        et.otherMouseDragged,
        et.scrollWheel,
        -- Click events: also handled here but we redo the lookup fresh
        -- in tapCallbackForClicks-equivalent inline (via fresh refresh).
        et.leftMouseDown, et.leftMouseUp,
        et.rightMouseDown, et.rightMouseUp,
        et.otherMouseDown, et.otherMouseUp,
    }, function(event)
        local t = event:getType()
        if t == et.leftMouseDown or t == et.rightMouseDown or t == et.otherMouseDown then
            refreshOrderedCache()
        end
        return tapCallback(event)
    end)

    if enabled then
        refreshOrderedCache()
        refreshTimer:start()
        tap:start()
    end

    hs.hotkey.bind({"ctrl", "alt"}, "i", function() M.toggle() end)
    hs.hotkey.bind({"ctrl", "alt", "shift"}, "i", function() M.disable() end)
    hs.hotkey.bind({"ctrl", "alt", "cmd"}, "i", function() M.enable() end)

    LOG.i("camofox-shield started (eventtap mode)")
end

return M
