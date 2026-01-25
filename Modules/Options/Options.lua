-- TavernUI Options Module

local TavernUI = _G.TavernUI
if not TavernUI then return end

local module = TavernUI:NewModule("Options")

local function getOptions()
    return {
        type = "group",
        name = "TavernUI",
        args = {
            general = {
                type = "group",
                name = "General",
                order = 10,
                args = {
                    debug = {
                        type = "toggle",
                        name = "Debug Mode",
                        desc = "Enable debug messages",
                        get = function() return TavernUI.db.profile.general.debug end,
                        set = function(_, value) TavernUI.db.profile.general.debug = value end,
                        order = 10,
                    },
                },
            },
            modules = {
                type = "group",
                name = "Modules",
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
