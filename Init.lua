-- TavernUI Init.lua
-- Initialization file for TavernUI addon

---@type AbstractFramework
local AF = select(2, ...)

-- Create addon namespace
local TavernUI = {}
_G.TavernUI = TavernUI

-- Addon metadata
TavernUI.name = "TavernUI"
TavernUI.version = "0.0.1"
TavernUI.author = "Mondo, LiQiuDgg"

-- Store AbstractFramework reference
TavernUI.AF = AF

-- Initialize addon when AbstractFramework is loaded
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")

initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == TavernUI.name then
        self:UnregisterEvent("ADDON_LOADED")
        TavernUI:Initialize()
    end
end)
