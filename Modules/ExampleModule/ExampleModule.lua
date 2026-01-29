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
    -- Access settings via self:GetSetting() - uses new config system
    local setting1 = self:GetSetting("setting1", true)
    self:Debug("ExampleModule enabled, setting1 =", tostring(setting1))
    
    -- Example: Watch for setting changes
    -- self:WatchSetting("setting1", function(newValue, oldValue)
    --     self:Debug("setting1 changed from", oldValue, "to", newValue)
    -- end)
    
    -- Example: register for game events here
    -- self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function module:OnDisable()
    self:Debug("ExampleModule disabled")
    -- Cleanup: unregister events, hide frames, etc.
end

function module:OnProfileChanged()
    -- Profile changed - refresh any cached state
    -- Note: Config system automatically clears callbacks on profile change
    self:Debug("Profile changed, refreshing ExampleModule state")
    
    if self:IsEnabled() then
        -- Refresh your module's state with new profile data
        -- Use GetSetting to access new profile values
        local setting1 = self:GetSetting("setting1", true)
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
                get = function() return self:GetSetting("setting1", true) end,
                set = function(_, value)
                    self:SetSetting("setting1", value, {
                        callback = function()
                            self:Debug("setting1 changed to", tostring(value))
                            -- Add any refresh logic here
                        end
                    })
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
                get = function() return self:GetSetting("setting2", 50) end,
                set = function(_, value)
                    self:SetSetting("setting2", value, {
                        type = "number",
                        min = 0,
                        max = 100,
                        callback = function()
                            self:Debug("setting2 changed to", value)
                            -- Add any refresh logic here
                        end
                    })
                end,
            },
            someText = {
                type = "input",
                name = "Some Text",
                desc = "A text setting",
                order = 30,
                width = "full",
                get = function() return self:GetSetting("someText", "default value") end,
                set = function(_, value)
                    self:SetSetting("someText", value, {
                        type = "string",
                        callback = function()
                            -- Add any refresh logic here
                        end
                    })
                end,
            },
        },
    }
    
    TavernUI:RegisterModuleOptions("ExampleModule", options, "Example Module")
end
