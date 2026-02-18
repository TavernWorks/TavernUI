local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local oUF = TavernUI.oUF
if not oUF then return end

local format = string.format
local sub = string.sub

local UnitName = UnitName
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitPower = UnitPower
local UnitClass = UnitClass
local UnitRace = UnitRace
local UnitEffectiveLevel = UnitEffectiveLevel
local UnitIsAFK = UnitIsAFK
local GetCreatureDifficultyColor = GetCreatureDifficultyColor
local canaccessvalue = canaccessvalue

local function ShortValue(val)
    return AbbreviateLargeNumbers(val)
end

-- Delegate a TUI:tag to an oUF built-in tag, preserving user-facing tag names.
-- oUF.Tags.Methods lazily compiles built-in tag strings on first access.
local function delegate(tag)
    return function(unit, realUnit)
        return oUF.Tags.Methods[tag](unit, realUnit)
    end
end

-- ============================================================================
-- Identity Tags
-- ============================================================================

oUF.Tags.Methods["TUI:name"] = delegate("name")
oUF.Tags.Events["TUI:name"] = "UNIT_NAME_UPDATE"

oUF.Tags.Methods["TUI:name:short"] = function(unit)
    local name = UnitName(unit)
    if name and #name > 10 then
        return sub(name, 1, 10) .. ".."
    end
    return name
end
oUF.Tags.Events["TUI:name:short"] = "UNIT_NAME_UPDATE"

oUF.Tags.Methods["TUI:name:vshort"] = function(unit)
    local name = UnitName(unit)
    if name and #name > 5 then
        return sub(name, 1, 5) .. ".."
    end
    return name
end
oUF.Tags.Events["TUI:name:vshort"] = "UNIT_NAME_UPDATE"

oUF.Tags.Methods["TUI:race"] = function(unit)
    return UnitRace(unit)
end
oUF.Tags.Events["TUI:race"] = "UNIT_NAME_UPDATE"

oUF.Tags.Methods["TUI:class"] = function(unit)
    return UnitClass(unit)
end
oUF.Tags.Events["TUI:class"] = "UNIT_NAME_UPDATE"

oUF.Tags.Methods["TUI:level"] = delegate("level")
oUF.Tags.Events["TUI:level"] = "UNIT_LEVEL PLAYER_LEVEL_UP"

oUF.Tags.Methods["TUI:smartlevel"] = delegate("smartlevel")
oUF.Tags.Events["TUI:smartlevel"] = "UNIT_LEVEL PLAYER_LEVEL_UP UNIT_CLASSIFICATION_CHANGED"

oUF.Tags.Methods["TUI:classification"] = delegate("classification")
oUF.Tags.Events["TUI:classification"] = "UNIT_CLASSIFICATION_CHANGED"

oUF.Tags.Methods["TUI:group"] = delegate("group")
oUF.Tags.Events["TUI:group"] = "GROUP_ROSTER_UPDATE"
oUF.Tags.SharedEvents.GROUP_ROSTER_UPDATE = true

-- ============================================================================
-- Health Tags
-- ============================================================================

oUF.Tags.Methods["TUI:curhp"] = delegate("curhp")
oUF.Tags.Events["TUI:curhp"] = "UNIT_HEALTH UNIT_MAXHEALTH"

oUF.Tags.Methods["TUI:maxhp"] = delegate("maxhp")
oUF.Tags.Events["TUI:maxhp"] = "UNIT_HEALTH UNIT_MAXHEALTH"

-- oUF's perhp uses UnitHealthPercent which is secret-value safe
oUF.Tags.Methods["TUI:perhp"] = delegate("perhp")
oUF.Tags.Events["TUI:perhp"] = "UNIT_HEALTH UNIT_MAXHEALTH"

oUF.Tags.Methods["TUI:deficit:hp"] = delegate("missinghp")
oUF.Tags.Events["TUI:deficit:hp"] = "UNIT_HEALTH UNIT_MAXHEALTH"

oUF.Tags.Methods["TUI:curhp:short"] = function(unit)
    return ShortValue(UnitHealth(unit))
end
oUF.Tags.Events["TUI:curhp:short"] = "UNIT_HEALTH UNIT_MAXHEALTH"

oUF.Tags.Methods["TUI:maxhp:short"] = function(unit)
    return ShortValue(UnitHealthMax(unit))
end
oUF.Tags.Events["TUI:maxhp:short"] = "UNIT_HEALTH UNIT_MAXHEALTH"

-- ============================================================================
-- Power Tags
-- ============================================================================

oUF.Tags.Methods["TUI:curpp"] = delegate("curpp")
oUF.Tags.Events["TUI:curpp"] = "UNIT_POWER_UPDATE UNIT_MAXPOWER"

oUF.Tags.Methods["TUI:maxpp"] = delegate("maxpp")
oUF.Tags.Events["TUI:maxpp"] = "UNIT_POWER_UPDATE UNIT_MAXPOWER"

-- oUF's perpp uses UnitPowerPercent which is secret-value safe
oUF.Tags.Methods["TUI:perpp"] = delegate("perpp")
oUF.Tags.Events["TUI:perpp"] = "UNIT_POWER_UPDATE UNIT_MAXPOWER"

oUF.Tags.Methods["TUI:curpp:short"] = function(unit)
    return ShortValue(UnitPower(unit))
end
oUF.Tags.Events["TUI:curpp:short"] = "UNIT_POWER_UPDATE UNIT_MAXPOWER"

oUF.Tags.Methods["TUI:curmana"] = function(unit)
    return ShortValue(UnitPower(unit, Enum.PowerType.Mana))
end
oUF.Tags.Events["TUI:curmana"] = "UNIT_POWER_UPDATE UNIT_MAXPOWER"

-- ============================================================================
-- Status Tags
-- ============================================================================

oUF.Tags.Methods["TUI:dead"] = delegate("dead")
oUF.Tags.Events["TUI:dead"] = "UNIT_HEALTH"

oUF.Tags.Methods["TUI:offline"] = delegate("offline")
oUF.Tags.Events["TUI:offline"] = "UNIT_CONNECTION"

oUF.Tags.Methods["TUI:status"] = delegate("status")
oUF.Tags.Events["TUI:status"] = "UNIT_HEALTH UNIT_CONNECTION PLAYER_UPDATE_RESTING"

oUF.Tags.Methods["TUI:afk"] = function(unit)
    if UnitIsAFK(unit) then return "AFK" end
    return nil
end
oUF.Tags.Events["TUI:afk"] = "PLAYER_FLAGS_CHANGED"

oUF.Tags.Methods["TUI:resting"] = delegate("resting")
oUF.Tags.Events["TUI:resting"] = "PLAYER_UPDATE_RESTING"

-- ============================================================================
-- Color Tags (return |cff hex codes)
-- ============================================================================

oUF.Tags.Methods["TUI:classcolor"] = delegate("raidcolor")
oUF.Tags.Events["TUI:classcolor"] = "UNIT_NAME_UPDATE"

oUF.Tags.Methods["TUI:diffcolor"] = function(unit)
    local level = UnitEffectiveLevel(unit)
    if not level or level <= 0 then
        return "|cffff0000"
    end
    local color = GetCreatureDifficultyColor(level)
    if color then
        return format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
    end
    return "|cffffffff"
end
oUF.Tags.Events["TUI:diffcolor"] = "UNIT_LEVEL PLAYER_LEVEL_UP"

-- ============================================================================
-- Class Resource Tags
-- ============================================================================

oUF.Tags.Methods["TUI:cpoints"] = function(unit)
    local cp = UnitPower("player", Enum.PowerType.ComboPoints)
    if canaccessvalue(cp) and cp > 0 then
        return tostring(cp)
    end
    return nil
end
oUF.Tags.Events["TUI:cpoints"] = "UNIT_POWER_UPDATE"
