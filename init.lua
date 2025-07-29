-- Use hidutil to remap right option to right control
-- Right Option: 0x7000000e6, Right Control: 0x7000000e4
hs.execute('hidutil property --set \'{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x7000000e6,"HIDKeyboardModifierMappingDst":0x7000000e4}]}\'')

-- Show notification when loaded
hs.notify.new({title="Hammerspoon", informativeText="Right Option → Right Control remapped"}):send()

-- Reload config when files change
hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", function()
    hs.reload()
end):start()

local windowFrameCache = {}
local windowState = {}
local leftMargin = 110

-- Centralized frame definitions
local frames = {
    stageManager = function(sf) return {x = sf.x + leftMargin, y = sf.y, w = sf.w - leftMargin, h = sf.h} end,
    stageManagerTop = function(sf) return {x = sf.x + leftMargin, y = sf.y, w = sf.w - leftMargin, h = sf.h / 2} end,
    stageManagerBottom = function(sf) return {x = sf.x + leftMargin, y = sf.y + sf.h / 2, w = sf.w - leftMargin, h = sf.h / 2} end,
    leftHalf = function(sf) return {x = sf.x, y = sf.y, w = sf.w / 2, h = sf.h} end,
    rightHalf = function(sf) return {x = sf.x + sf.w / 2, y = sf.y, w = sf.w / 2, h = sf.h} end,
    upperLeft = function(sf) return {x = sf.x, y = sf.y, w = sf.w / 2, h = sf.h / 2} end,
    upperRight = function(sf) return {x = sf.x + sf.w / 2, y = sf.y, w = sf.w / 2, h = sf.h / 2} end,
    lowerLeft = function(sf) return {x = sf.x, y = sf.y + sf.h / 2, w = sf.w / 2, h = sf.h / 2} end,
    lowerRight = function(sf) return {x = sf.x + sf.w / 2, y = sf.y + sf.h / 2, w = sf.w / 2, h = sf.h / 2} end
}

-- State transitions
local transitions = {
    stageManager = {Left = "leftHalf", Right = "rightHalf", Up = "stageManagerTop", Down = "stageManagerBottom"},
    stageManagerTop = {Left = "upperLeft", Right = "upperRight", Down = "stageManagerBottom"},
    stageManagerBottom = {Left = "lowerLeft", Right = "lowerRight", Up = "stageManagerTop"},
    leftHalf = {Right = "rightHalf", Up = "upperLeft", Down = "lowerLeft"},
    rightHalf = {Left = "leftHalf", Up = "upperRight", Down = "lowerRight"},
    upperLeft = {Left = "leftHalf", Right = "upperRight", Up = "stageManagerTop", Down = "leftHalf"},
    upperRight = {Left = "upperLeft", Right = "rightHalf", Up = "stageManagerTop", Down = "rightHalf"},
    lowerLeft = {Left = "leftHalf", Right = "lowerRight", Up = "leftHalf", Down = "stageManagerBottom"},
    lowerRight = {Left = "lowerLeft", Right = "rightHalf", Up = "rightHalf", Down = "stageManagerBottom"}
}

-- Helper function to check if two frames are approximately equal
function framesAreEqual(frame1, frame2)
    return math.abs(frame1.x - frame2.x) < 5 and
           math.abs(frame1.y - frame2.y) < 5 and
           math.abs(frame1.w - frame2.w) < 5 and
           math.abs(frame1.h - frame2.h) < 5
end

-- Helper function to check if a window is in a predefined resized state
function getWindowState(win)
    if not win then return nil end
    local currentFrame = win:frame()
    local screenFrame = win:screen():frame()
    for name, frameBuilder in pairs(frames) do
        if framesAreEqual(currentFrame, frameBuilder(screenFrame)) then
            return name
        end
    end
    return nil
end

-- Helper function to save window frame if not in a resized state
function saveFrame(win)
    local winId = win:id()
    if not windowState[winId] and not getWindowState(win) then
        windowFrameCache[winId] = win:frame()
    end
end

-- Generic function to apply a frame and update state
function applyFrame(win, frameName)
    local screenFrame = win:screen():frame()
    win:setFrame(frames[frameName](screenFrame))
    windowState[win:id()] = frameName
end

-- Hotkey handler for directional keys
function handleKey(direction)
    return function()
        local win = hs.window.focusedWindow()
        if not win then return end

        saveFrame(win)

        local winId = win:id()
        local currentState = windowState[winId] or getWindowState(win)
        local nextState

        if currentState then
            -- If we are in a state, only move if there is a valid transition
            nextState = transitions[currentState] and transitions[currentState][direction]
        else
            -- If we are not in a state, this is an initial move
            if direction == "Left" then
                nextState = "leftHalf"
            elseif direction == "Right" then
                nextState = "rightHalf"
            end
        end

        if nextState then
            applyFrame(win, nextState)
        end
    end
end

-- Hotkey bindings
hs.hotkey.bind({"cmd", "shift"}, "f", function()
    local win = hs.window.focusedWindow()
    if not win then return end
    saveFrame(win)
    applyFrame(win, "stageManager")
end)

hs.hotkey.bind({"cmd", "shift"}, "Left", handleKey("Left"))
hs.hotkey.bind({"cmd", "shift"}, "Right", handleKey("Right"))
hs.hotkey.bind({"cmd", "shift"}, "Up", handleKey("Up"))
hs.hotkey.bind({"cmd", "shift"}, "Down", handleKey("Down"))

-- Restore window to previous dimensions
hs.hotkey.bind({"cmd", "shift"}, "delete", function()
    local win = hs.window.focusedWindow()
    if not win then return end

    local winId = win:id()
    if windowFrameCache[winId] then
        win:setFrame(windowFrameCache[winId])
        windowFrameCache[winId] = nil
        windowState[winId] = nil
    end
end)
