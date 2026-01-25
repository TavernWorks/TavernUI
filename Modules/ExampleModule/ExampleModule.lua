-- TavernUI ExampleModule

local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:NewModule("ExampleModule", "AceEvent-3.0")

-- IMPORTANT: Register defaults at FILE LOAD TIME, not in OnInitialize
-- This ensures defaults are in place BEFORE AceDB:New() is called
local defaults = {
    setting1 = true,
    setting2 = 50,
    someText = "default value",
}
TavernUI:RegisterModuleDefaults("ExampleModule", defaults, true) -- true = enabled by default

function module:OnInitialize()
    -- Register for profile changes so we can refresh our cached state
    self:RegisterMessage("TavernUI_ProfileChanged", "OnProfileChanged")
    self:RegisterMessage("TavernUI_CoreEnabled", "OnCoreEnabled")
    self:RegisterMessage("TavernUI_SomeEvent", "OnSomeEvent")
    
    -- Register our options with the main options panel
    self:RegisterOptions()
    
    self:Debug("ExampleModule initialized")
end

function module:OnEnable()
    -- Access settings via self:GetDB() - always returns fresh reference
    local db = self:GetDB()
    self:Debug("ExampleModule enabled, setting1 =", tostring(db.setting1))
    
    -- Example: register for game events here
    -- self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function module:OnDisable()
    self:Debug("ExampleModule disabled")
    -- Cleanup: unregister events, hide frames, etc.
end

function module:OnProfileChanged()
    -- Profile changed - refresh any cached state
    self:Debug("Profile changed, refreshing ExampleModule state")
    
    if self:IsEnabled() then
        -- Refresh your module's state with new profile data
        local db = self:GetDB()
        -- Update frames, settings, etc. with new values
    end
end

function module:OnCoreEnabled()
    self:Debug("Core enabled notification received")
end

function module:OnSomeEvent(event, ...)
    self:Debug("Received SomeEvent", ...)
end

function module:RegisterOptions()
    local options = {
        type = "group",
        name = "Example Module",
        args = {
            setting1 = {
                type = "toggle",
                name = "Setting 1",
                desc = "Toggle this example setting",
                order = 10,
                get = function() return self:GetDB().setting1 end,
                set = function(_, value)
                    TavernUI.db.profile.ExampleModule.setting1 = value
                    self:Debug("setting1 changed to", tostring(value))
                end,
            },
            setting2 = {
                type = "range",
                name = "Setting 2",
                desc = "A numeric setting",
                order = 20,
                min = 0,
                max = 100,
                step = 1,
                get = function() return self:GetDB().setting2 end,
                set = function(_, value)
                    TavernUI.db.profile.ExampleModule.setting2 = value
                    self:Debug("setting2 changed to", value)
                end,
            },
            someText = {
                type = "input",
                name = "Some Text",
                desc = "A text setting",
                order = 30,
                width = "full",
                get = function() return self:GetDB().someText end,
                set = function(_, value)
                    TavernUI.db.profile.ExampleModule.someText = value
                end,
            },
        },
    }
    
    TavernUI:RegisterModuleOptions("ExampleModule", options, "Example Module")
end
