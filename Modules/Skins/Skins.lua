local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:NewModule("Skins")

-- Qui-style greys: Armor Wash #030303, Sooty #141414, Shoe Wax #2B2B2B,
-- Black Suede #434343, Greasy Grey #828383, Clouded Vision #D1D1D1
module.Theme = {
    fontFace = "Fonts\\FRIZQT__.TTF",
    fontSize = 12,
    frameBg = { r = 0.078, g = 0.078, b = 0.078, a = 0.98 },
    borderColor = { r = 0.169, g = 0.169, b = 0.169, a = 1 },
    accentColor = { r = 0.82, g = 0.82, b = 0.82, a = 1 },
    accentBg = { r = 0.169, g = 0.169, b = 0.169, a = 0.6 },
    textColor = { r = 0.82, g = 0.82, b = 0.82, a = 1 },
    sliderTrack = { r = 0.169, g = 0.169, b = 0.169, a = 1 },
    borderWidth = 1,
    inset = 4,
}

local defaults = {}
TavernUI:RegisterModuleDefaults("Skins", defaults, true)

function module:OnInitialize()
    if TavernUI.RegisterModuleOptions then
        TavernUI:RegisterModuleOptions("Skins", nil, "Skins")
    end
end

function module:OnEnable()
    if self.AceSkin then
        self.AceSkin.Enable(self)
    end
    if self.EnableEditModeSkin then
        self:EnableEditModeSkin()
    end
end

function module:OnDisable()
    if self.AceSkin then
        self.AceSkin.Disable(self)
    end
end
