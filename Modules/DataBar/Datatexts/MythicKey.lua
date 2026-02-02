local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local format = string.format

local function GetKeyColor(level)
    if not level or level == 0 then return 0.7, 0.7, 0.7 end
    if level >= 20 then return 1, 0.5, 0 end
    if level >= 15 then return 0.64, 0.21, 0.93 end
    if level >= 10 then return 0, 0.44, 0.87 end
    if level >= 5 then return 0.12, 1, 0 end
    return 1, 1, 1
end

local function GetShortDungeonName(mapID)
    local name = C_ChallengeMode.GetMapUIInfo(mapID)
    if name then
        return name:match("^(%S+)") or name
    end
    return "?"
end

DataBar:RegisterDatatext("Mythic Key", {
    labelShort = "Key",
    events = { "CHALLENGE_MODE_MAPS_UPDATE", "BAG_UPDATE" },
    update = function()
        local keystoneLevel = C_MythicPlus.GetOwnedKeystoneLevel()
        local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()

        if keystoneLevel and keystoneLevel > 0 and mapID then
            local shortName = GetShortDungeonName(mapID)
            local r, g, b = GetKeyColor(keystoneLevel)
            return format("|cff%02x%02x%02x+%d|r %s", r * 255, g * 255, b * 255, keystoneLevel, shortName)
        end
        return "No Key"
    end,
    tooltip = function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Mythic+ Keystone", 1, 1, 1)
        GameTooltip:AddLine(" ")

        local keystoneLevel = C_MythicPlus.GetOwnedKeystoneLevel()
        local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()

        if keystoneLevel and keystoneLevel > 0 and mapID then
            local name = C_ChallengeMode.GetMapUIInfo(mapID)
            local r, g, b = GetKeyColor(keystoneLevel)
            GameTooltip:AddDoubleLine("Current Key:",
                format("|cff%02x%02x%02x+%d %s|r", r * 255, g * 255, b * 255, keystoneLevel, name or "Unknown"),
                1, 1, 1)
        else
            GameTooltip:AddLine("No keystone in bags", 0.7, 0.7, 0.7)
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-Click: Open Group Finder", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end,
    onClick = function(_, button)
        if button == "LeftButton" then
            if InCombatLockdown() then return end
            PVEFrame_ToggleFrame("GroupFinderFrame", LFDParentFrame)
        end
    end,
})
