local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:NewModule("uCDM", "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")

local defaults = {
    enabled = true,
    general = {
        debug = false,
        updateRates = {
            normal = 0.1,
            combat = 0.3,
            initial = 0.05,
        },
    },
    viewers = {
            essential = {
                enabled = true,
                anchorConfig = nil,
                rowGrowDirection = "down",
                showKeybinds = false,
                keybindSize = 10,
                keybindPoint = "TOPLEFT",
                keybindOffsetX = 2,
                keybindOffsetY = -2,
                keybindColor = {r = 1, g = 1, b = 1, a = 1},
                disableTooltips = false,
                rows = {
                    {
                        name = "Default",
                        iconCount = 4,
                        iconSize = 50,
                        padding = -8,
                        yOffset = 0,
                        aspectRatioCrop = 1.0,
                        zoom = 0,
                        iconBorderSize = 0,
                        iconBorderColor = {r = 0, g = 0, b = 0, a = 1},
                        rowBorderSize = 0,
                        rowBorderColor = {r = 0, g = 0, b = 0, a = 1},
                        durationSize = 18,
                        durationPoint = "CENTER",
                        durationOffsetX = 0,
                        durationOffsetY = 0,
                        stackSize = 16,
                        stackPoint = "BOTTOMRIGHT",
                        stackOffsetX = 0,
                        stackOffsetY = 0,
                    },
                },
            },
            utility = {
                enabled = true,
                anchorBelowEssential = true,
                anchorPoint = "TOP",
                anchorRelativePoint = "BOTTOM",
                anchorOffsetX = 0,
                anchorGap = 5,
                anchorConfig = nil,
                rowGrowDirection = "down",
                showKeybinds = false,
                keybindSize = 10,
                keybindPoint = "TOPLEFT",
                keybindOffsetX = 2,
                keybindOffsetY = -2,
                keybindColor = {r = 1, g = 1, b = 1, a = 1},
                disableTooltips = false,
                rows = {
                    {
                        name = "Default",
                        iconCount = 6,
                        iconSize = 42,
                        padding = -8,
                        yOffset = 0,
                        aspectRatioCrop = 1.0,
                        zoom = 0,
                        iconBorderSize = 0,
                        iconBorderColor = {r = 0, g = 0, b = 0, a = 1},
                        rowBorderSize = 0,
                        rowBorderColor = {r = 0, g = 0, b = 0, a = 1},
                        durationSize = 18,
                        durationPoint = "CENTER",
                        durationOffsetX = 0,
                        durationOffsetY = 0,
                        stackSize = 16,
                        stackPoint = "BOTTOMRIGHT",
                        stackOffsetX = 0,
                        stackOffsetY = 0,
                    },
                },
            },
            buff = {
                enabled = true,
                anchorConfig = nil,
                rowGrowDirection = "down",
                showKeybinds = false,
                keybindSize = 10,
                keybindPoint = "TOPLEFT",
                keybindOffsetX = 2,
                keybindOffsetY = -2,
                keybindColor = {r = 1, g = 1, b = 1, a = 1},
                disableTooltips = false,
                rows = {
                    {
                        name = "Default",
                        iconCount = 6,
                        iconSize = 42,
                        padding = -8,
                        yOffset = 0,
                        aspectRatioCrop = 1.0,
                        zoom = 0,
                        iconBorderSize = 0,
                        iconBorderColor = {r = 0, g = 0, b = 0, a = 1},
                        rowBorderSize = 0,
                        rowBorderColor = {r = 0, g = 0, b = 0, a = 1},
                        durationSize = 18,
                        durationPoint = "CENTER",
                        durationOffsetX = 0,
                        durationOffsetY = 0,
                        stackSize = 16,
                        stackPoint = "BOTTOMRIGHT",
                        stackOffsetX = 0,
                        stackOffsetY = 0,
                    },
                },
            },
            custom = {
                enabled = true,
                anchorConfig = nil,
                rowGrowDirection = "down",
                showKeybinds = false,
                keybindSize = 10,
                keybindPoint = "TOPLEFT",
                keybindOffsetX = 2,
                keybindOffsetY = -2,
                keybindColor = {r = 1, g = 1, b = 1, a = 1},
                disableTooltips = false,
                rows = {
                    {
                        name = "Default",
                        iconCount = 4,
                        iconSize = 40,
                        padding = -8,
                        yOffset = 0,
                        aspectRatioCrop = 1.0,
                        zoom = 0,
                        iconBorderSize = 0,
                        iconBorderColor = {r = 0, g = 0, b = 0, a = 1},
                        rowBorderSize = 0,
                        rowBorderColor = {r = 0, g = 0, b = 0, a = 1},
                        durationSize = 18,
                        durationPoint = "CENTER",
                        durationOffsetX = 0,
                        durationOffsetY = 0,
                        stackSize = 16,
                        stackPoint = "BOTTOMRIGHT",
                        stackOffsetX = 0,
                        stackOffsetY = 0,
                    },
                },
            },
        },
    customEntries = {},
    positions = {},
}

TavernUI:RegisterModuleDefaults("uCDM", defaults, true)

function module:OnInitialize()
    pcall(function() SetCVar("cooldownViewerEnabled", 1) end)
    self:RegisterMessage("TavernUI_ProfileChanged", "OnProfileChanged")
end

function module:GetUpdateInterval()
    local db = self:GetDB()
    if not db or not db.general or not db.general.updateRates then
        return 0.1
    end
    
    local rates = db.general.updateRates
    
    if self.initialPhaseStartTime then
        local elapsed = GetTime() - self.initialPhaseStartTime
        if elapsed < 5.0 then
            return rates.initial or 0.05
        end
    end
    
    if InCombatLockdown() then
        return rates.combat or 0.3
    end
    
    return rates.normal or 0.1
end

function module:IsInInitialPhase()
    if not self.initialPhaseStartTime then return false end
    local elapsed = GetTime() - self.initialPhaseStartTime
    return elapsed < 5.0
end

function module:UnifiedUpdate()
    if not self:IsEnabled() then return end
    
    if self.CooldownTracker then
        for _, viewerKey in ipairs({"essential", "utility", "buff", "custom"}) do
            local entries = self.EntrySystem.GetMergedEntriesForViewer(viewerKey)
            for _, entry in ipairs(entries) do
                if entry.enabled ~= false and entry.frame then
                    if not entry.frame.Cooldown or not entry.frame.Cooldown:IsShown() then
                        self.CooldownTracker.UpdateEntry(entry)
                    end
                end
            end
        end
    end
    
    if self.Styler then
        self.Styler.ProcessPendingStyling()
    end
    
    if self.Conditions then
        for _, viewerKey in ipairs({"essential", "utility", "buff", "custom"}) do
            local entries = self.EntrySystem.GetMergedEntriesForViewer(viewerKey)
            for _, entry in ipairs(entries) do
                if entry.frame then
                    self.Conditions.UpdateEntry(entry)
                end
            end
        end
    end
end

function module:StartUpdateLoop()
    if self.updateTicker then
        self.updateTicker:Cancel()
        self.updateTicker = nil
    end
    
    self.updateLoopActive = true
    self.initialPhaseStartTime = GetTime()
    
    local function UpdateLoop()
        if not self.updateLoopActive or not self:IsEnabled() then return end
        
        self:UnifiedUpdate()
        
        local interval = self:GetUpdateInterval()
        C_Timer.After(interval, UpdateLoop)
    end
    
    UpdateLoop()
end

function module:StopUpdateLoop()
    self.updateLoopActive = false
    if self.updateTicker then
        self.updateTicker:Cancel()
        self.updateTicker = nil
    end
end

module.entries = {}
module.viewerEntries = {}
module.nextIndex = {}
module.updateTicker = nil
module.customViewerFrame = nil
module.initialPhaseStartTime = nil
module.updateLoopActive = false

function module:OnEnable()
    self.__onEnableCalled = true
    self:LogInfo("uCDM enabled")
    
    if self.EntrySystem then
        self.EntrySystem.Initialize()
    end
    
    if self.LayoutEngine then
        self.LayoutEngine.Initialize()
    end
    
    if self.FrameManager then
        self.FrameManager.Initialize()
    end
    
    if self.CooldownTracker then
        self.CooldownTracker.Initialize()
    end
    
    if self.Styler then
        self.Styler.Initialize()
    end
    
    if self.Keybinds then
        self.Keybinds.Initialize()
    end
    
    if self.Conditions then
        self.Conditions.Initialize()
    end
    
    if self.RefreshManager then
        self.RefreshManager.Initialize()
    end
    
    if self.Anchoring then
        self.Anchoring.Initialize()
    end
    
    
    if self.BlizzProvider then
        self.BlizzProvider.Initialize()
    end
    
    if self.CustomProvider then
        self.CustomProvider.Initialize()
    end
    
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "OnEquipmentChanged")
    self:RegisterEvent("UPDATE_BINDINGS", "OnBindingsUpdate")
    
    self:StartUpdateLoop()
    
    C_Timer.After(0, function()
        if self:IsEnabled() then
            local hasViewer = false
            if self.BlizzProvider then
                for viewerKey, viewerName in pairs(self.BlizzProvider.VIEWER_NAMES) do
                    if _G[viewerName] then
                        hasViewer = true
                        break
                    end
                end
            end
            if hasViewer then
                if self.BlizzProvider then
                    self.BlizzProvider.Initialize()
                end
            end
        end
    end)
    
    C_Timer.After(1.0, function()
        if self:IsEnabled() then
            self:RefreshAllViewers()
        end
    end)
end

function module:OnDisable()
    self.__onEnableCalled = nil
    if self.BlizzProvider then
        self.BlizzProvider.Reset()
    end
    self:StopUpdateLoop()
end

function module:RefreshAllViewers()
    if self.BlizzProvider then
        for viewerKey, viewerName in pairs(self.BlizzProvider.VIEWER_NAMES) do
            local viewer = _G[viewerName]
            if viewer then
                self.BlizzProvider.RefreshEntries(viewerKey)
                if self.LayoutEngine then
                    self.LayoutEngine.LayoutViewer(viewerKey)
                end
            end
        end
    end
    
    if self.RefreshManager then
        for _, viewerKey in ipairs({"essential", "utility", "buff", "custom"}) do
            self.RefreshManager.RefreshViewer(viewerKey)
        end
    end
end


function module:OnEquipmentChanged()
    if self.RefreshManager then
        self.RefreshManager.RefreshViewer("custom")
    end
end

function module:OnBindingsUpdate()
    if self.Keybinds then
        for _, viewerKey in ipairs({"essential", "utility", "buff", "custom"}) do
            self.Keybinds.UpdateViewer(viewerKey, self.EntrySystem.GetMergedEntriesForViewer(viewerKey))
        end
    end
end


function module:OnDisable()
    self:UnregisterAllEvents()
    
    if self.updateTicker then
        self.updateTicker:Cancel()
        self.updateTicker = nil
    end
    
    if self.RefreshManager then
        self.RefreshManager.Cleanup()
    end
end

function module:OnProfileChanged()
    if not self:IsEnabled() then return end
    
    self:LogInfo("Profile changed, refreshing uCDM")
    
    if self.CustomProvider then
        self.CustomProvider.LoadFromDB()
    end
    
    if self.RefreshManager then
        for _, viewerKey in ipairs({"essential", "utility", "buff", "custom"}) do
            self.RefreshManager.RefreshViewer(viewerKey)
        end
    end
end

function module:GetViewerSettings(viewerKey)
    local db = self:GetDB()
    if not db or not db.viewers then
        return nil
    end
    return db.viewers[viewerKey]
end

function module:LogError(msg)
    local db = self:GetDB()
    if db and db.general and db.general.debug then
        print("|cFFFF0000uCDM Error:|r " .. tostring(msg))
    end
end

function module:LogInfo(msg)
    local db = self:GetDB()
    if db and db.general and db.general.debug then
        print("|cFF00FF00uCDM:|r " .. tostring(msg))
        self:Debug(tostring(msg))
    end
end


function module:IsEnabled()
    local db = self:GetDB()
    return db and db.enabled ~= false
end
