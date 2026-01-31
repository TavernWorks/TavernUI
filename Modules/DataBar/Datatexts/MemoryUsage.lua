local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local min = math.min

DataBar:RegisterDatatext("Memory Usage", {
    label = "Memory",
    labelShort = "",
    pollInterval = 10,
    update = function()
        return DataBar:FormatMemory(collectgarbage("count"))
    end,
    tooltip = function(frame)
        UpdateAddOnMemoryUsage()
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Addon Memory", 1, 1, 1)
        GameTooltip:AddLine(" ")
        local addons = {}
        for i = 1, C_AddOns.GetNumAddOns() do
            local mem = GetAddOnMemoryUsage(i)
            if mem > 0 then
                addons[#addons + 1] = { name = C_AddOns.GetAddOnInfo(i), mem = mem }
            end
        end
        table.sort(addons, function(a, b) return a.mem > b.mem end)
        for i = 1, min(#addons, 15) do
            local a = addons[i]
            GameTooltip:AddDoubleLine(a.name, DataBar:FormatMemory(a.mem), 1, 1, 1, 1, 1, 0)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Total", DataBar:FormatMemory(collectgarbage("count")), 1, 1, 1, 0, 1, 0)
        GameTooltip:Show()
    end,
})
