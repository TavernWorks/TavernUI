local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local floor = math.floor
local format = string.format
local min = math.min

local cachedFps, cachedMs = 0, 0
local cachedAddons = {}
local cachedTotal = 0
local lastMemUpdate = 0
local MEM_UPDATE_INTERVAL = 30

DataBar:RegisterDatatext("System", {
    label = "System",
    labelShort = "Sys",
    pollInterval = 1,
    separator = " | ",
    update = function()
        cachedFps = floor(GetFramerate() + 0.5)
        local _, _, homePing = GetNetStats()
        cachedMs = floor(homePing or 0)

        local now = GetTime()
        if now - lastMemUpdate >= MEM_UPDATE_INTERVAL then
            lastMemUpdate = now
            UpdateAddOnMemoryUsage()
            for k in pairs(cachedAddons) do cachedAddons[k] = nil end
            for i = 1, C_AddOns.GetNumAddOns() do
                local mem = GetAddOnMemoryUsage(i)
                if mem > 0 then
                    cachedAddons[#cachedAddons + 1] = { name = C_AddOns.GetAddOnInfo(i), mem = mem }
                end
            end
            table.sort(cachedAddons, function(a, b) return a.mem > b.mem end)
            cachedTotal = collectgarbage("count")
        end

        return { tostring(cachedFps), tostring(cachedMs) }
    end,
    getColor = function()
        local fpsColor
        if cachedFps < 30 then
            fpsColor = { 1, 0.2, 0.2 }
        end

        local msColor
        if cachedMs > 100 then
            msColor = { 1, 0.2, 0.2 }
        elseif cachedMs > 50 then
            msColor = { 1, 1, 0 }
        else
            msColor = { 0, 1, 0 }
        end

        return { fpsColor, msColor }
    end,
    tooltip = function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("System", 1, 1, 1)
        GameTooltip:AddLine(" ")

        local _, _, _, worldPing = GetNetStats()

        GameTooltip:AddDoubleLine("Framerate:", format("%d fps", cachedFps), 0.7, 0.7, 0.7, 1, 1, 1)
        GameTooltip:AddDoubleLine("Home Latency:", format("%d ms", cachedMs), 0.7, 0.7, 0.7, 1, 1, 1)
        GameTooltip:AddDoubleLine("World Latency:", format("%d ms", floor(worldPing or 0)), 0.7, 0.7, 0.7, 1, 1, 1)

        if #cachedAddons > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Top Addons (Memory)", 1, 1, 1)
            for i = 1, min(#cachedAddons, 10) do
                local a = cachedAddons[i]
                GameTooltip:AddDoubleLine(a.name, DataBar:FormatMemory(a.mem), 0.7, 0.7, 0.7, 1, 1, 0)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Total:", DataBar:FormatMemory(cachedTotal), 1, 1, 1, 0, 1, 0)
        end

        GameTooltip:Show()
    end,
})
