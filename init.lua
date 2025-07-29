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
local leftMargin = 110

-- Centralized frame definitions
local frames = {
    stageManager = function(screenFrame)
        return {
            x = screenFrame.x + leftMargin,
            y = screenFrame.y,
            w = screenFrame.w - leftMargin,
            h = screenFrame.h
        }
    end,
    leftHalf = function(screenFrame)
        return {
            x = screenFrame.x,
            y = screenFrame.y,
            w = screenFrame.w / 2,
            h = screenFrame.h
        }
    end,
    rightHalf = function(screenFrame)
        return {
            x = screenFrame.x + screenFrame.w / 2,
            y = screenFrame.y,
            w = screenFrame.w / 2,
            h = screenFrame.h
        }
    end
}

-- Helper function to check if two frames are approximately equal
function framesAreEqual(frame1, frame2)
    return math.abs(frame1.x - frame2.x) < 5 and
           math.abs(frame1.y - frame2.y) < 5 and
           math.abs(frame1.w - frame2.w) < 5 and
           math.abs(frame1.h - frame2.h) < 5
end

-- Helper function to check if a window is in a predefined resized state
function isResized(win)
    if not win then return false end

    local currentFrame = win:frame()
    local screenFrame = win:screen():frame()

    for _, frameBuilder in pairs(frames) do
        if framesAreEqual(currentFrame, frameBuilder(screenFrame)) then
            return true
        end
    end

    return false
end

-- Helper function to save window frame if not in a resized state
function saveFrame(win)
    if not isResized(win) then
        local winId = win:id()
        windowFrameCache[winId] = win:frame()
    end
end

-- Generic function to apply a frame to a window
function applyFrame(frameName)
    return function()
        local win = hs.window.focusedWindow()
        if not win then return end

        saveFrame(win)

        local screenFrame = win:screen():frame()
        win:setFrame(frames[frameName](screenFrame))
    end
end

-- Hotkey bindings
hs.hotkey.bind({"cmd", "shift"}, "f", applyFrame("stageManager"))
hs.hotkey.bind({"cmd", "shift"}, "Left", applyFrame("leftHalf"))
hs.hotkey.bind({"cmd", "shift"}, "Right", applyFrame("rightHalf"))

-- Restore window to previous dimensions
hs.hotkey.bind({"cmd", "shift"}, "delete", function()
    local win = hs.window.focusedWindow()
    if not win then return end

    local winId = win:id()
    if windowFrameCache[winId] then
        win:setFrame(windowFrameCache[winId])
        windowFrameCache[winId] = nil
    end
end)
