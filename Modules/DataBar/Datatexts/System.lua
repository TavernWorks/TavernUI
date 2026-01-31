local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local floor = math.floor
local format = string.format

local function GetFPSColor(fps)
    if fps < 30 then return "ff3333" end
    return nil
end

local function GetMSColor(ms)
    if ms > 100 then return "ff3333" end
    if ms > 50 then return "ffff00" end
    return "00ff00"
end

DataBar:RegisterDatatext("System", {
    label = "System",
    labelShort = "",
    pollInterval = 1,
    update = function()
        local fps = floor(GetFramerate() + 0.5)
        local _, _, homePing = GetNetStats()
        local ms = floor(homePing or 0)

        local fpsColor = GetFPSColor(fps)
        local msColor = GetMSColor(ms)

        local fpsStr = fpsColor and format("|cff%s%d|r", fpsColor, fps) or tostring(fps)
        local msStr = format("|cff%s%d|r", msColor, ms)

        return fpsStr .. " | " .. msStr
    end,
    tooltip = function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("System", 1, 1, 1)
        GameTooltip:AddLine(" ")

        local fps = floor(GetFramerate() + 0.5)
        local _, _, homePing, worldPing = GetNetStats()

        GameTooltip:AddDoubleLine("Framerate:", format("%d fps", fps), 0.7, 0.7, 0.7, 1, 1, 1)
        GameTooltip:AddDoubleLine("Home Latency:", format("%d ms", floor(homePing or 0)), 0.7, 0.7, 0.7, 1, 1, 1)
        GameTooltip:AddDoubleLine("World Latency:", format("%d ms", floor(worldPing or 0)), 0.7, 0.7, 0.7, 1, 1, 1)

        GameTooltip:Show()
    end,
})
