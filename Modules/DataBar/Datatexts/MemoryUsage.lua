local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local min = math.min

local cache = DataBar.memoryCache

DataBar:RegisterDatatext("Memory Usage", {
    label = "Memory",
    labelShort = "Mem",
    pollInterval = 1,
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
        DataBar:CheckMemoryPoll(slot)

        return DataBar:FormatMemory(cache.total)
    end,
    tooltip = function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Addon Memory", 1, 1, 1)
        GameTooltip:AddLine(" ")
        for i = 1, min(#cache.addons, 15) do
            local a = cache.addons[i]
            GameTooltip:AddDoubleLine(a.name, DataBar:FormatMemory(a.mem), 1, 1, 1, 1, 1, 0)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Total", DataBar:FormatMemory(cache.total), 1, 1, 1, 0, 1, 0)
        GameTooltip:Show()

        DataBar:RefreshMemoryCacheOnHover()
    end,
})
