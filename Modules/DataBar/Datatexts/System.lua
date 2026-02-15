local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local floor = math.floor
local format = string.format
local min = math.min

local cachedFps, cachedMs = 0, 0
local cache = DataBar.memoryCache

DataBar:RegisterDatatext("System", {
    label = "System",
    labelShort = "Sys",
    pollInterval = 1,
    separator = " | ",
    options = {
        memoryPollInterval = {
            type = "select",
            name = "Memory Refresh",
            desc = "How often to refresh addon memory data. Disabled = tooltip hover only. Higher values reduce stuttering with many addons.",
            values = {
                ["0"] = "Disabled (tooltip only)",
                ["30"] = "30 seconds",
                ["60"] = "60 seconds",
                ["120"] = "120 seconds",
            },
            default = "0",
        },
    },
    update = function(slot)
        cachedFps = floor(GetFramerate() + 0.5)
        local _, _, homePing = GetNetStats()
        cachedMs = floor(homePing or 0)

        DataBar:CheckMemoryPoll(slot)

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

        if #cache.addons > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Top Addons (Memory)", 1, 1, 1)
            for i = 1, min(#cache.addons, 10) do
                local a = cache.addons[i]
                GameTooltip:AddDoubleLine(a.name, DataBar:FormatMemory(a.mem), 0.7, 0.7, 0.7, 1, 1, 0)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Total:", DataBar:FormatMemory(cache.total), 1, 1, 1, 0, 1, 0)
        end

        GameTooltip:Show()

        DataBar:RefreshMemoryCacheOnHover()
    end,
})
