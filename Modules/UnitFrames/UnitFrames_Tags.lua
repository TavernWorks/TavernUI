local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local oUF = TavernUI.oUF
if not oUF then return end

local floor = math.floor
local format = string.format
local sub = string.sub

local UnitName = UnitName
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitClass = UnitClass
local UnitRace = UnitRace
local UnitLevel = UnitLevel
local UnitEffectiveLevel = UnitEffectiveLevel
local UnitClassification = UnitClassification
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsGhost = UnitIsGhost
local UnitIsConnected = UnitIsConnected
local UnitIsAFK = UnitIsAFK
local IsResting = IsResting
local UnitReaction = UnitReaction
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local GetNumGroupMembers = GetNumGroupMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local GetCreatureDifficultyColor = GetCreatureDifficultyColor
local canaccessvalue = canaccessvalue
local issecretvalue = issecretvalue

local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local function ShortValue(val)
    return AbbreviateLargeNumbers(val)
end

-- ============================================================================
-- Identity Tags
-- ============================================================================

oUF.Tags.Methods["TUI:name"] = function(unit)
    return UnitName(unit)
end
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
    local class = UnitClass(unit)
    return class
end
oUF.Tags.Events["TUI:class"] = "UNIT_NAME_UPDATE"

oUF.Tags.Methods["TUI:level"] = function(unit)
    local level = UnitEffectiveLevel(unit)
    if not level or level <= 0 then
        return "??"
    end
    return tostring(level)
end
oUF.Tags.Events["TUI:level"] = "UNIT_LEVEL PLAYER_LEVEL_UP"

oUF.Tags.Methods["TUI:smartlevel"] = function(unit)
    local level = UnitEffectiveLevel(unit)
    if not level or level <= 0 then
        return "??"
    end
    local c = UnitClassification(unit)
    if c == "worldboss" or c == "boss" then
        return "Boss"
    elseif c == "rareelite" then
        return level .. "r+"
    elseif c == "elite" then
        return level .. "+"
    elseif c == "rare" then
        return level .. "r"
    end
    return tostring(level)
end
oUF.Tags.Events["TUI:smartlevel"] = "UNIT_LEVEL PLAYER_LEVEL_UP UNIT_CLASSIFICATION_CHANGED"

oUF.Tags.Methods["TUI:classification"] = function(unit)
    local c = UnitClassification(unit)
    if c == "worldboss" or c == "boss" then
        return "Boss"
    elseif c == "rareelite" then
        return "Rare Elite"
    elseif c == "elite" then
        return "Elite"
    elseif c == "rare" then
        return "Rare"
    end
    return nil
end
oUF.Tags.Events["TUI:classification"] = "UNIT_CLASSIFICATION_CHANGED"

oUF.Tags.Methods["TUI:group"] = function(unit)
    local name, realm = UnitName(unit)
    if not name then return nil end
    local nameRealm = realm and realm ~= "" and (name .. "-" .. realm) or name
    for i = 1, GetNumGroupMembers() do
        local raidName, _, subgroup = GetRaidRosterInfo(i)
        if raidName == nameRealm or raidName == name then
            return tostring(subgroup)
        end
    end
    return nil
end
oUF.Tags.Events["TUI:group"] = "GROUP_ROSTER_UPDATE"
oUF.Tags.SharedEvents.GROUP_ROSTER_UPDATE = true

-- ============================================================================
-- Health Tags
-- ============================================================================

oUF.Tags.Methods["TUI:curhp"] = function(unit)
    return UnitHealth(unit)
end
oUF.Tags.Events["TUI:curhp"] = "UNIT_HEALTH UNIT_MAXHEALTH"

oUF.Tags.Methods["TUI:maxhp"] = function(unit)
    return UnitHealthMax(unit)
end
oUF.Tags.Events["TUI:maxhp"] = "UNIT_HEALTH UNIT_MAXHEALTH"

oUF.Tags.Methods["TUI:perhp"] = function(unit)
    local cur = UnitHealth(unit)
    local max = UnitHealthMax(unit)
    if not canaccessvalue(cur) or not canaccessvalue(max) then
        return nil
    end
    if max == 0 then return "0" end
    return format("%d", (cur / max) * 100)
end
oUF.Tags.Events["TUI:perhp"] = "UNIT_HEALTH UNIT_MAXHEALTH"

oUF.Tags.Methods["TUI:deficit:hp"] = function(unit)
    local cur = UnitHealth(unit)
    local max = UnitHealthMax(unit)
    if not canaccessvalue(cur) or not canaccessvalue(max) then return nil end
    local deficit = max - cur
    if deficit > 0 then
        return "-" .. ShortValue(deficit)
    end
    return nil
end
oUF.Tags.Events["TUI:deficit:hp"] = "UNIT_HEALTH UNIT_MAXHEALTH"

oUF.Tags.Methods["TUI:curhp:short"] = function(unit)
    local cur = UnitHealth(unit)
    return ShortValue(cur)
end
oUF.Tags.Events["TUI:curhp:short"] = "UNIT_HEALTH UNIT_MAXHEALTH"

oUF.Tags.Methods["TUI:maxhp:short"] = function(unit)
    local max = UnitHealthMax(unit)
    return ShortValue(max)
end
oUF.Tags.Events["TUI:maxhp:short"] = "UNIT_HEALTH UNIT_MAXHEALTH"

-- ============================================================================
-- Power Tags
-- ============================================================================

oUF.Tags.Methods["TUI:curpp"] = function(unit)
    return UnitPower(unit)
end
oUF.Tags.Events["TUI:curpp"] = "UNIT_POWER_UPDATE UNIT_MAXPOWER"

oUF.Tags.Methods["TUI:maxpp"] = function(unit)
    return UnitPowerMax(unit)
end
oUF.Tags.Events["TUI:maxpp"] = "UNIT_POWER_UPDATE UNIT_MAXPOWER"

oUF.Tags.Methods["TUI:perpp"] = function(unit)
    local max = UnitPowerMax(unit)
    local cur = UnitPower(unit)
    if not canaccessvalue(cur) or not canaccessvalue(max) then
        return cur
    end
    if max == 0 then return "0" end
    return format("%d", (cur / max) * 100)
end
oUF.Tags.Events["TUI:perpp"] = "UNIT_POWER_UPDATE UNIT_MAXPOWER"

oUF.Tags.Methods["TUI:curpp:short"] = function(unit)
    local cur = UnitPower(unit)
    return ShortValue(cur)
end
oUF.Tags.Events["TUI:curpp:short"] = "UNIT_POWER_UPDATE UNIT_MAXPOWER"

oUF.Tags.Methods["TUI:curmana"] = function(unit)
    local mana = UnitPower(unit, Enum.PowerType.Mana)
    return ShortValue(mana)
end
oUF.Tags.Events["TUI:curmana"] = "UNIT_POWER_UPDATE UNIT_MAXPOWER"

-- ============================================================================
-- Status Tags
-- ============================================================================

oUF.Tags.Methods["TUI:dead"] = function(unit)
    if UnitIsGhost(unit) then return "Ghost" end
    if UnitIsDeadOrGhost(unit) then return "Dead" end
    return nil
end
oUF.Tags.Events["TUI:dead"] = "UNIT_HEALTH"

oUF.Tags.Methods["TUI:offline"] = function(unit)
    if not UnitIsConnected(unit) then return "Offline" end
    return nil
end
oUF.Tags.Events["TUI:offline"] = "UNIT_CONNECTION"

oUF.Tags.Methods["TUI:status"] = function(unit)
    if not UnitIsConnected(unit) then return "Offline" end
    if UnitIsGhost(unit) then return "Ghost" end
    if UnitIsDeadOrGhost(unit) then return "Dead" end
    if unit == "player" and IsResting() then return "zzz" end
    return nil
end
oUF.Tags.Events["TUI:status"] = "UNIT_HEALTH UNIT_CONNECTION PLAYER_UPDATE_RESTING"
oUF.Tags.SharedEvents.PLAYER_UPDATE_RESTING = true

oUF.Tags.Methods["TUI:afk"] = function(unit)
    if UnitIsAFK(unit) then return "AFK" end
    return nil
end
oUF.Tags.Events["TUI:afk"] = "PLAYER_FLAGS_CHANGED"

oUF.Tags.Methods["TUI:resting"] = function(unit)
    if unit == "player" and IsResting() then return "zzz" end
    return nil
end
oUF.Tags.Events["TUI:resting"] = "PLAYER_UPDATE_RESTING"

-- ============================================================================
-- Color Tags (return |cff hex codes)
-- ============================================================================

oUF.Tags.Methods["TUI:classcolor"] = function(unit)
    local _, class = UnitClass(unit)
    if class then
        local color = RAID_CLASS_COLORS[class]
        if color then
            return format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
        end
    end
    return "|cffffffff"
end
oUF.Tags.Events["TUI:classcolor"] = "UNIT_NAME_UPDATE"

oUF.Tags.Methods["TUI:reactioncolor"] = function(unit)
    local reaction = UnitReaction(unit, "player")
    if reaction then
        local colors = oUF.colors.reaction
        if colors and colors[reaction] then
            local c = colors[reaction]
            return format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
        end
    end
    return "|cffffffff"
end
oUF.Tags.Events["TUI:reactioncolor"] = "UNIT_FACTION"

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
