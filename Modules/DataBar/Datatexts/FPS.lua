local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local floor = math.floor

DataBar:RegisterDatatext("FPS", {
    label = "FPS",
    labelShort = "F",
    pollInterval = 1,
    update = function()
        return tostring(floor(GetFramerate()))
    end,
    getColor = function()
        local fps = GetFramerate()
        if fps < 30 then
            return 1, 0.2, 0.2
        end
        return nil
    end,
})
