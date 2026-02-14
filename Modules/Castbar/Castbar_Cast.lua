local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("Castbar")

-- Cast event handling is now managed by oUF's castbar element.
-- This file provides preview mode control for the Castbar Options panel.

local Cast = {}
module.Cast = Cast

function Cast:EnablePreview(castbar)
    if not castbar then return end
    local ufModule = TavernUI:GetModule("UnitFrames", true)
    if ufModule and ufModule.CastbarShared then
        ufModule.CastbarShared:EnablePreview(castbar, castbar.TUI_unit)
    end
end

function Cast:DisablePreview(castbar)
    if not castbar then return end
    local ufModule = TavernUI:GetModule("UnitFrames", true)
    if ufModule and ufModule.CastbarShared then
        ufModule.CastbarShared:DisablePreview(castbar)
    end
end
