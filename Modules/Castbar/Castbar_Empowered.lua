local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("Castbar")

-- Empowered visuals are now handled by CastbarShared via oUF Pips callbacks
-- (CreatePip, PostUpdatePips, CustomOnUpdate empowered fill color).
-- This file is kept as a stub so module.Empowered exists for any references.

local Empowered = {}
module.Empowered = Empowered
