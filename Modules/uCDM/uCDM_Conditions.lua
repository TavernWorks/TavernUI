local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local Conditions = {}

function Conditions.ShouldDisplayEntry(entry)
    if not entry or not entry.config then
        return true
    end
    
    local conditions = entry.config.conditionalDisplay
    if not conditions or not conditions.enabled then
        return true
    end
    
    local inCombat = UnitAffectingCombat("player")
    if inCombat and not conditions.showInCombat then
        return false
    end
    if not inCombat and not conditions.showOutOfCombat then
        return false
    end
    
    local inGroup = IsInGroup() or IsInRaid()
    if inGroup and not conditions.showInGroup then
        return false
    end
    if not inGroup and not conditions.showSolo then
        return false
    end
    
    local inInstance, instanceType = IsInInstance()
    if inInstance and not conditions.showInInstance then
        return false
    end
    if not inInstance and not conditions.showInOpenWorld then
        return false
    end
    
    if conditions.healthThreshold > 0 then
        local healthPercent = (UnitHealth("player") / UnitHealthMax("player")) * 100
        if healthPercent >= conditions.healthThreshold then
            return false
        end
    end
    
    return true
end

function Conditions.UpdateEntry(entry)
    if not entry or not entry.frame then return end
    if entry.type ~= "custom" then return end
    
    local shouldShow = Conditions.ShouldDisplayEntry(entry)
    
    if shouldShow then
        entry.frame:Show()
    else
        entry.frame:Hide()
    end
end

function Conditions.Initialize()
    module:LogInfo("Conditions initialized")
end

module.Conditions = Conditions
