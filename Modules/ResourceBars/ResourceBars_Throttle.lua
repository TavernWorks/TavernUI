local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("ResourceBars")

local Throttle = {}

local throttleTimers = {}

function Throttle:ThrottleUpdate(barId, interval, updateFunc)
    if throttleTimers[barId] then
        return
    end
    
    throttleTimers[barId] = true
    
    C_Timer.After(interval, function()
        throttleTimers[barId] = nil
        updateFunc()
    end)
end

function Throttle:ClearThrottle(barId)
    throttleTimers[barId] = nil
end

function Throttle:ClearAllThrottles()
    throttleTimers = {}
end

module.Throttle = Throttle
