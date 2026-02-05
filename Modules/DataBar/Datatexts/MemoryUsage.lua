local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local min = math.min

local cachedAddons = {}
local cachedTotal = 0

DataBar:RegisterDatatext("Memory Usage", {
    label = "Memory",
    labelShort = "Mem",
    pollInterval = 10,
    update = function()
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
        return DataBar:FormatMemory(cachedTotal)
    end,
    tooltip = function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Addon Memory", 1, 1, 1)
        GameTooltip:AddLine(" ")
        for i = 1, min(#cachedAddons, 15) do
            local a = cachedAddons[i]
            GameTooltip:AddDoubleLine(a.name, DataBar:FormatMemory(a.mem), 1, 1, 1, 1, 1, 0)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Total", DataBar:FormatMemory(cachedTotal), 1, 1, 1, 0, 1, 0)
        GameTooltip:Show()
    end,
})
