local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("CursorCrosshair")
local L = LibStub("AceLocale-3.0"):GetLocale("TavernUI")

local function RefreshReticle()
    if module.Reticle then
        module.Reticle:Refresh()
    end
end

local function RefreshCrosshair()
    if module.Crosshair then
        module.Crosshair:Refresh()
    end
end

function module:RegisterOptions()
    local options = {
        type = "group",
        name = L["CURSOR_CROSSHAIR"],
        childGroups = "tab",
        args = {
            enabled = {
                type = "toggle",
                name = L["ENABLED"],
                desc = L["ENABLE_CURSOR_CROSSHAIR_MODULE_DESC"],
                order = 1,
                width = "full",
                get = function() return self:GetSetting("enabled", false) end,
                set = function(_, val)
                    self:SetSetting("enabled", val)
                    if val then
                        self:Enable()
                    else
                        self:Disable()
                    end
                end,
            },
            reticleTab = {
                type = "group",
                name = L["CURSOR_RING"],
                order = 10,
                args = {
                    reticleEnabled = {
                        type = "toggle",
                        name = L["ENABLED"],
                        desc = L["ENABLE_CURSOR_RING_DESC"],
                        order = 1,
                        width = "full",
                        get = function() return self:GetSetting("reticle.enabled", false) end,
                        set = function(_, val)
                            self:SetSetting("reticle.enabled", val)
                            RefreshReticle()
                        end,
                    },
                    ringStyle = {
                        type = "select",
                        name = L["RING_STYLE"],
                        desc = L["RING_STYLE_DESC"],
                        order = 2,
                        values = {
                            standard = L["STANDARD"],
                            thin = L["THIN"],
                        },
                        get = function() return self:GetSetting("reticle.ringStyle", "standard") end,
                        set = function(_, val)
                            self:SetSetting("reticle.ringStyle", val)
                            RefreshReticle()
                        end,
                    },
                    ringSize = {
                        type = "range",
                        name = L["RING_SIZE"],
                        desc = L["RING_SIZE_DESC"],
                        order = 3,
                        min = 20, max = 80, step = 1,
                        get = function() return self:GetSetting("reticle.ringSize", 40) end,
                        set = function(_, val)
                            self:SetSetting("reticle.ringSize", val)
                            RefreshReticle()
                        end,
                    },
                    reticleStyle = {
                        type = "select",
                        name = L["RETICLE_STYLE"],
                        desc = L["RETICLE_STYLE_DESC"],
                        order = 4,
                        values = {
                            cross = L["CROSS"],
                            chevron = L["CHEVRON"],
                            diamond = L["DIAMOND"],
                        },
                        get = function() return self:GetSetting("reticle.reticleStyle", "cross") end,
                        set = function(_, val)
                            self:SetSetting("reticle.reticleStyle", val)
                            RefreshReticle()
                        end,
                    },
                    reticleSize = {
                        type = "range",
                        name = L["RETICLE_SIZE"],
                        desc = L["RETICLE_SIZE_DESC"],
                        order = 5,
                        min = 4, max = 40, step = 1,
                        get = function() return self:GetSetting("reticle.reticleSize", 10) end,
                        set = function(_, val)
                            self:SetSetting("reticle.reticleSize", val)
                            RefreshReticle()
                        end,
                    },
                    colorHeader = {
                        type = "header",
                        name = L["COLOR"],
                        order = 10,
                    },
                    useClassColor = {
                        type = "toggle",
                        name = L["USE_CLASS_COLOUR"],
                        desc = L["USE_CLASS_COLOUR_DESC"],
                        order = 11,
                        get = function() return self:GetSetting("reticle.useClassColor", false) end,
                        set = function(_, val)
                            self:SetSetting("reticle.useClassColor", val)
                            RefreshReticle()
                        end,
                    },
                    customColor = {
                        type = "color",
                        name = L["COLOR"],
                        desc = L["CURSOR_RING_COLOR_DESC"],
                        order = 12,
                        hasAlpha = true,
                        get = function()
                            local c = self:GetSetting("reticle.customColor", { 0.82, 0.82, 0.82, 1 })
                            return c[1], c[2], c[3], c[4]
                        end,
                        set = function(_, r, g, b, a)
                            self:SetSetting("reticle.customColor", { r, g, b, a })
                            RefreshReticle()
                        end,
                    },
                    hideOutOfCombat = {
                        type = "toggle",
                        name = L["HIDE_OUT_OF_COMBAT"],
                        desc = L["HIDE_OUT_OF_COMBAT_DESC"],
                        order = 23,
                        get = function() return self:GetSetting("reticle.hideOutOfCombat", false) end,
                        set = function(_, val)
                            self:SetSetting("reticle.hideOutOfCombat", val)
                            RefreshReticle()
                        end,
                    },
                    gcdHeader = {
                        type = "header",
                        name = L["GCD_SETTINGS"],
                        order = 30,
                    },
                    gcdEnabled = {
                        type = "toggle",
                        name = L["ENABLE_GCD_SWIPE"],
                        desc = L["ENABLE_GCD_SWIPE_DESC"],
                        order = 31,
                        get = function() return self:GetSetting("reticle.gcdEnabled", true) end,
                        set = function(_, val)
                            self:SetSetting("reticle.gcdEnabled", val)
                            RefreshReticle()
                        end,
                    },
                    gcdFadeRing = {
                        type = "range",
                        name = L["RING_FADE_DURING_GCD"],
                        desc = L["RING_FADE_DURING_GCD_DESC"],
                        order = 32,
                        min = 0, max = 1, step = 0.05,
                        isPercent = true,
                        get = function() return self:GetSetting("reticle.gcdFadeRing", 0.35) end,
                        set = function(_, val)
                            self:SetSetting("reticle.gcdFadeRing", val)
                            RefreshReticle()
                        end,
                    },
                    gcdReverse = {
                        type = "toggle",
                        name = L["REVERSE_SWIPE"],
                        desc = L["REVERSE_SWIPE_DESC"],
                        order = 33,
                        get = function() return self:GetSetting("reticle.gcdReverse", false) end,
                        set = function(_, val)
                            self:SetSetting("reticle.gcdReverse", val)
                            RefreshReticle()
                        end,
                    },
                    miscHeader = {
                        type = "header",
                        name = L["MISC"],
                        order = 40,
                    },
                    hideOnRightClick = {
                        type = "toggle",
                        name = L["HIDE_ON_RIGHT_CLICK"],
                        desc = L["HIDE_ON_RIGHT_CLICK_DESC"],
                        order = 41,
                        get = function() return self:GetSetting("reticle.hideOnRightClick", false) end,
                        set = function(_, val)
                            self:SetSetting("reticle.hideOnRightClick", val)
                            RefreshReticle()
                        end,
                    },
                },
            },
            crosshairTab = {
                type = "group",
                name = L["CROSSHAIR"],
                order = 20,
                args = {
                    crosshairEnabled = {
                        type = "toggle",
                        name = L["ENABLED"],
                        desc = L["ENABLE_CROSSHAIR_DESC"],
                        order = 1,
                        width = "full",
                        get = function() return self:GetSetting("crosshair.enabled", false) end,
                        set = function(_, val)
                            self:SetSetting("crosshair.enabled", val)
                            RefreshCrosshair()
                        end,
                    },
                    onlyInCombat = {
                        type = "toggle",
                        name = L["COMBAT_ONLY"],
                        desc = L["COMBAT_ONLY_DESC"],
                        order = 2,
                        get = function() return self:GetSetting("crosshair.onlyInCombat", false) end,
                        set = function(_, val)
                            self:SetSetting("crosshair.onlyInCombat", val)
                            RefreshCrosshair()
                        end,
                    },
                    rangeHeader = {
                        type = "header",
                        name = L["RANGE_CHECK"],
                        order = 10,
                    },
                    changeColorOnRange = {
                        type = "toggle",
                        name = L["OUT_OF_MELEE_RANGE_CHECK"],
                        desc = L["OUT_OF_MELEE_RANGE_CHECK_DESC"],
                        order = 11,
                        get = function() return self:GetSetting("crosshair.changeColorOnRange", false) end,
                        set = function(_, val)
                            self:SetSetting("crosshair.changeColorOnRange", val)
                            RefreshCrosshair()
                        end,
                    },
                    rangeColorInCombatOnly = {
                        type = "toggle",
                        name = L["CHECK_ONLY_IN_COMBAT"],
                        desc = L["CHECK_ONLY_IN_COMBAT_DESC"],
                        order = 12,
                        disabled = function() return not self:GetSetting("crosshair.changeColorOnRange", false) end,
                        get = function() return self:GetSetting("crosshair.rangeColorInCombatOnly", false) end,
                        set = function(_, val)
                            self:SetSetting("crosshair.rangeColorInCombatOnly", val)
                            RefreshCrosshair()
                        end,
                    },
                    hideUntilOutOfRange = {
                        type = "toggle",
                        name = L["ONLY_SHOW_WHEN_OUT_OF_RANGE"],
                        desc = L["ONLY_SHOW_WHEN_OUT_OF_RANGE_DESC"],
                        order = 13,
                        disabled = function() return not self:GetSetting("crosshair.changeColorOnRange", false) end,
                        get = function() return self:GetSetting("crosshair.hideUntilOutOfRange", false) end,
                        set = function(_, val)
                            self:SetSetting("crosshair.hideUntilOutOfRange", val)
                            RefreshCrosshair()
                        end,
                    },
                    outOfRangeColor = {
                        type = "color",
                        name = L["OUT_OF_RANGE_COLOR"],
                        desc = L["OUT_OF_RANGE_COLOR_DESC"],
                        order = 14,
                        hasAlpha = true,
                        disabled = function() return not self:GetSetting("crosshair.changeColorOnRange", false) end,
                        get = function()
                            local c = self:GetSetting("crosshair.outOfRangeColor", { 0.65, 0.25, 0.25, 1 })
                            return c[1], c[2], c[3], c[4]
                        end,
                        set = function(_, r, g, b, a)
                            self:SetSetting("crosshair.outOfRangeColor", { r, g, b, a })
                            RefreshCrosshair()
                        end,
                    },
                    appearanceHeader = {
                        type = "header",
                        name = L["CROSSHAIR_APPEARANCE"],
                        order = 20,
                    },
                    crosshairColor = {
                        type = "color",
                        name = L["CROSSHAIR_COLOR"],
                        desc = L["CROSSHAIR_COLOR_DESC"],
                        order = 21,
                        hasAlpha = true,
                        get = function()
                            local c = self:GetSetting("crosshair.color", { 0.82, 0.82, 0.82, 1 })
                            return c[1], c[2], c[3], c[4]
                        end,
                        set = function(_, r, g, b, a)
                            self:SetSetting("crosshair.color", { r, g, b, a })
                            RefreshCrosshair()
                        end,
                    },
                    borderColor = {
                        type = "color",
                        name = L["OUTLINE_COLOR"],
                        desc = L["OUTLINE_COLOR_DESC"],
                        order = 22,
                        hasAlpha = true,
                        get = function()
                            local c = self:GetSetting("crosshair.borderColor", { 0, 0, 0, 1 })
                            return c[1], c[2], c[3], c[4]
                        end,
                        set = function(_, r, g, b, a)
                            self:SetSetting("crosshair.borderColor", { r, g, b, a })
                            RefreshCrosshair()
                        end,
                    },
                    size = {
                        type = "range",
                        name = L["LENGTH"],
                        desc = L["CROSSHAIR_LENGTH_DESC"],
                        order = 23,
                        min = 5, max = 50, step = 1,
                        get = function() return self:GetSetting("crosshair.size", 12) end,
                        set = function(_, val)
                            self:SetSetting("crosshair.size", val)
                            RefreshCrosshair()
                        end,
                    },
                    thickness = {
                        type = "range",
                        name = L["THICKNESS"],
                        desc = L["CROSSHAIR_THICKNESS_DESC"],
                        order = 24,
                        min = 1, max = 10, step = 1,
                        get = function() return self:GetSetting("crosshair.thickness", 3) end,
                        set = function(_, val)
                            self:SetSetting("crosshair.thickness", val)
                            RefreshCrosshair()
                        end,
                    },
                    borderSizeSlider = {
                        type = "range",
                        name = L["OUTLINE_SIZE"],
                        desc = L["OUTLINE_SIZE_DESC"],
                        order = 25,
                        min = 0, max = 5, step = 1,
                        get = function() return self:GetSetting("crosshair.borderSize", 2) end,
                        set = function(_, val)
                            self:SetSetting("crosshair.borderSize", val)
                            RefreshCrosshair()
                        end,
                    },
                    positionHeader = {
                        type = "header",
                        name = L["POSITION"],
                        order = 30,
                    },
                    strata = {
                        type = "select",
                        name = L["FRAME_STRATA"],
                        desc = L["FRAME_STRATA_DESC"],
                        order = 31,
                        values = {
                            BACKGROUND = L["STRATA_BACKGROUND"],
                            LOW = L["STRATA_LOW"],
                            MEDIUM = L["STRATA_MEDIUM"],
                            HIGH = L["STRATA_HIGH"],
                            DIALOG = L["STRATA_DIALOG"],
                        },
                        get = function() return self:GetSetting("crosshair.strata", "HIGH") end,
                        set = function(_, val)
                            self:SetSetting("crosshair.strata", val)
                            RefreshCrosshair()
                        end,
                    },
                    offsetX = {
                        type = "range",
                        name = L["OFFSET_X"],
                        desc = L["HORIZONTAL_OFFSET"],
                        order = 32,
                        min = -500, max = 500, step = 1,
                        get = function() return self:GetSetting("crosshair.offsetX", 0) end,
                        set = function(_, val)
                            self:SetSetting("crosshair.offsetX", val)
                            RefreshCrosshair()
                        end,
                    },
                    offsetY = {
                        type = "range",
                        name = L["OFFSET_Y"],
                        desc = L["VERTICAL_OFFSET"],
                        order = 33,
                        min = -500, max = 500, step = 1,
                        get = function() return self:GetSetting("crosshair.offsetY", 0) end,
                        set = function(_, val)
                            self:SetSetting("crosshair.offsetY", val)
                            RefreshCrosshair()
                        end,
                    },
                },
            },
        },
    }

    TavernUI:RegisterModuleOptions("CursorCrosshair", options, L["CURSOR_CROSSHAIR"])
end
