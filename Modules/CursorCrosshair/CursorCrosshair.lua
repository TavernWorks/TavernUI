local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:NewModule("CursorCrosshair", "AceEvent-3.0")

local CONSTANTS = {
    RANGE_CHECK_INTERVAL = 0.1,
    CURSOR_MOVE_THRESHOLD = 0.5,
    GCD_SPELL_ID = 61304,
}
module.CONSTANTS = CONSTANTS

local MELEE_RANGE_ABILITIES = {
    96231, 6552, 1766, 116705, 183752,
    228478, 263642,
    49143, 55090, 206930,
    100780, 100784, 107428,
    5221, 3252, 1822, 22568, 22570,
    33917, 6807,
}
module.MELEE_RANGE_ABILITIES = MELEE_RANGE_ABILITIES

local defaults = {
    enabled = false,
    reticle = {
        enabled = false,
        ringStyle = "standard",
        ringSize = 40,
        useClassColor = false,
        customColor = { 0.82, 0.82, 0.82, 1 },
        hideOutOfCombat = false,
        hideOnRightClick = false,
        reticleStyle = "cross",
        reticleSize = 10,
        gcdEnabled = true,
        gcdFadeRing = 0.35,
        gcdReverse = false,
    },
    crosshair = {
        enabled = false,
        size = 12,
        thickness = 3,
        borderSize = 2,
        color = { 0.82, 0.82, 0.82, 1 },
        borderColor = { 0, 0, 0, 1 },
        outOfRangeColor = { 0.65, 0.25, 0.25, 1 },
        onlyInCombat = false,
        changeColorOnRange = false,
        rangeColorInCombatOnly = false,
        hideUntilOutOfRange = false,
        strata = "HIGH",
        offsetX = 0,
        offsetY = 0,
    },
}

TavernUI:RegisterModuleDefaults("CursorCrosshair", defaults, true)

function module:OnInitialize()
    self:WatchSetting("enabled", function(newValue)
        if newValue then
            self:Enable()
        else
            self:Disable()
        end
    end)
    self:RegisterMessage("TavernUI_ProfileChanged", "OnProfileChanged")
    if TavernUI.RegisterModuleOptions then
        self:RegisterOptions()
    end
end

function module:OnEnable()
    self:Debug("CursorCrosshair module enabled")
    if self.Reticle then
        self.Reticle:Enable()
    end
    if self.Crosshair then
        self.Crosshair:Enable()
    end
end

function module:OnDisable()
    self:Debug("CursorCrosshair module disabled")
    if self.Reticle then
        self.Reticle:Disable()
    end
    if self.Crosshair then
        self.Crosshair:Disable()
    end
end

function module:OnProfileChanged()
    if not self:IsEnabled() then return end
    if self.Reticle then
        self.Reticle:Refresh()
    end
    if self.Crosshair then
        self.Crosshair:Refresh()
    end
end
