local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local floor = math.floor

DataBar:RegisterDatatext("Coordinates", {
    label = "Coords",
    labelShort = "",
    pollInterval = 0.5,
    update = function()
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            local pos = C_Map.GetPlayerMapPosition(mapID, "player")
            if pos then
                local x, y = pos:GetXY()
                if x and y then
                    return string.format("%d, %d", x * 100, y * 100)
                end
            end
        end
        return "--"
    end,
    tooltip = function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Coordinates", 1, 1, 1)
        GameTooltip:AddLine(" ")

        local zone = GetZoneText()
        if zone and zone ~= "" then
            GameTooltip:AddLine(zone, 1, 1, 1)
        end

        local subzone = GetSubZoneText()
        if subzone and subzone ~= "" then
            GameTooltip:AddLine(subzone, 0.7, 0.7, 0.7)
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-Click: Open Map", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end,
    onClick = function(_, button)
        if button == "LeftButton" then
            ToggleWorldMap()
        end
    end,
})
