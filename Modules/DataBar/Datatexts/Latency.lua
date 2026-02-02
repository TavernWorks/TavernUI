local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local floor = math.floor

DataBar:RegisterDatatext("Latency", {
    label = "Latency",
    labelShort = "M",
    pollInterval = 30,
    update = function()
        local _, _, _, world = GetNetStats()
        return tostring(floor(world or 0))
    end,
    getColor = function()
        local _, _, _, world = GetNetStats()
        world = world or 0
        if world > 100 then
            return 1, 0, 0
        elseif world > 50 then
            return 1, 1, 0
        end
        return 0, 1, 0
    end,
})
