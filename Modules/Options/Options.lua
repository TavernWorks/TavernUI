-- TavernUI Options Module

local TavernUI = _G.TavernUI
if not TavernUI then return end

local L = LibStub("AceLocale-3.0"):GetLocale("TavernUI", true)
local module = TavernUI:NewModule("Options")

local function getOptions()
    return {
        type = "group",
        name = L["TAVERN_UI"],
        args = {
            general = {
                type = "group",
                name = L["GENERAL"],
                order = 10,
                args = {
                    debug = {
                        type = "toggle",
                        name = L["DEBUG_MODE"],
                        desc = L["ENABLE_DEBUG_MESSAGES"],
                        get = function() return TavernUI.db.profile.general.debug end,
                        set = function(_, value) TavernUI.db.profile.general.debug = value end,
                        order = 10,
                    },
                    font = {
                        type = "group",
                        name = L["FONT"],
                        desc = L["FONT_RELOAD_WARNING"],
                        order = 20,
                        args = {
                            fontReloadWarning = {
                                type = "description",
                                name = "|cffffcc00" .. L["FONT_RELOAD_WARNING"] .. "|r",
                                order = 0,
                            },
                            face = {
                                type = "select",
                                name = L["FONT_FACE"],
                                desc = L["FONT_FACE_DESC"],
                                values = function()
                                    return TavernUI:GetLSMMediaDropdownValues("font", "", L["FONT_DEFAULT_LABEL"])
                                end,
                                get = function()
                                    local v = TavernUI.db.profile.general.font and TavernUI.db.profile.general.font.face
                                    return (v ~= nil and v ~= "") and v or ""
                                end,
                                set = function(_, value)
                                    if not TavernUI.db.profile.general.font then
                                        TavernUI.db.profile.general.font = { face = "", size = 12, flags = "OUTLINE", pixelPerfect = true, shadow = false }
                                    end
                                    TavernUI.db.profile.general.font.face = (value ~= nil and value ~= "") and value or ""
                                    TavernUI:RefreshAllFonts()
                                end,
                                order = 10,
                            },
                            size = {
                                type = "range",
                                name = L["FONT_SIZE"],
                                desc = L["FONT_SIZE_DESC"],
                                min = 6,
                                max = 24,
                                step = 1,
                                get = function()
                                    local v = TavernUI.db.profile.general.font and TavernUI.db.profile.general.font.size
                                    return (type(v) == "number" and v >= 6 and v <= 24) and v or 12
                                end,
                                set = function(_, value)
                                    if not TavernUI.db.profile.general.font then
                                        TavernUI.db.profile.general.font = { face = "", size = 12, flags = "OUTLINE", pixelPerfect = true, shadow = false }
                                    end
                                    TavernUI.db.profile.general.font.size = (type(value) == "number" and value >= 6 and value <= 24) and value or 12
                                    TavernUI:RefreshAllFonts()
                                end,
                                order = 20,
                            },
                            flags = {
                                type = "select",
                                name = L["FONT_OUTLINE"],
                                desc = L["FONT_OUTLINE_DESC"],
                                values = {
                                    [""] = L["FONT_OUTLINE_NONE"],
                                    ["OUTLINE"] = L["FONT_OUTLINE_NORMAL"],
                                    ["THICKOUTLINE"] = L["FONT_OUTLINE_THICK"],
                                    ["MONOCHROME"] = L["FONT_OUTLINE_MONOCHROME"],
                                    ["OUTLINE,MONOCHROME"] = L["FONT_OUTLINE_MONOCHROME_OUTLINE"],
                                },
                                get = function()
                                    local v = TavernUI.db.profile.general.font and TavernUI.db.profile.general.font.flags
                                    return (type(v) == "string") and v or "OUTLINE"
                                end,
                                set = function(_, value)
                                    if not TavernUI.db.profile.general.font then
                                        TavernUI.db.profile.general.font = { face = "", size = 12, flags = "OUTLINE", pixelPerfect = true, shadow = false }
                                    end
                                    TavernUI.db.profile.general.font.flags = (type(value) == "string") and value or "OUTLINE"
                                    TavernUI:RefreshAllFonts()
                                end,
                                order = 30,
                            },
                            shadow = {
                                type = "toggle",
                                name = L["FONT_SHADOW"],
                                desc = L["FONT_SHADOW_DESC"],
                                get = function()
                                    return TavernUI.db.profile.general.font and TavernUI.db.profile.general.font.shadow == true
                                end,
                                set = function(_, value)
                                    if not TavernUI.db.profile.general.font then
                                        TavernUI.db.profile.general.font = { face = "", size = 12, flags = "OUTLINE", pixelPerfect = true, shadow = false }
                                    end
                                    TavernUI.db.profile.general.font.shadow = value == true
                                    TavernUI:RefreshAllFonts()
                                end,
                                order = 35,
                            },
                            pixelPerfect = {
                                type = "toggle",
                                name = L["FONT_PIXEL_PERFECT"],
                                desc = L["FONT_PIXEL_PERFECT_DESC"],
                                get = function()
                                    local v = TavernUI.db.profile.general.font and TavernUI.db.profile.general.font.pixelPerfect
                                    return v == nil or v == true
                                end,
                                set = function(_, value)
                                    if not TavernUI.db.profile.general.font then
                                        TavernUI.db.profile.general.font = { face = "", size = 12, flags = "OUTLINE", pixelPerfect = true, shadow = false }
                                    end
                                    TavernUI.db.profile.general.font.pixelPerfect = value
                                    TavernUI:RefreshAllFonts()
                                end,
                                order = 40,
                            },
                        },
                    },
                },
            },
            modules = {
                type = "group",
                name = L["MODULES"],
                order = 20,
                args = {},
            },
        },
    }
end

function module:OnInitialize()
    self.GetOptions = getOptions
end

function module:OnEnable()
end

function module:OnDisable()
end
