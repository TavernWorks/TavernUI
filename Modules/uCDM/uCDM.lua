local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:NewModule("uCDM", "AceEvent-3.0", "AceConsole-3.0")

--[[
    uCDM - Unified Cooldown Manager (Refactored)
    
    Architecture:
    - CooldownItem: Single class that handles all item types uniformly
    - ItemRegistry: Stores and manages all cooldown items
    - LayoutEngine: Positions items and applies per-row styling
    - Keybinds: Keybind lookup and display
    - Anchoring: Viewer positioning via LibAnchorRegistry
]]

local CONSTANTS = {
    INITIAL_PHASE_DURATION = 5.0,
    VIEWER_NAMES = {
        essential = "EssentialCooldownViewer",
        utility = "UtilityCooldownViewer",
        buff = "BuffIconCooldownViewer",
    },
    VIEWER_KEYS = {"essential", "utility", "buff", "custom"},
    TRACKING_TYPE = {
        TRINKET = 1,
        ITEM = 2,
        SPELL = 3,
    },
}

module.CONSTANTS = CONSTANTS

local defaults = {
    enabled = true,
    general = {
        debug = false,
        scaleFactor = 1,
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
                    iconCount = 8,
                    iconSize = 40,
                    padding = 0,
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

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function module:OnInitialize()
    pcall(function() SetCVar("cooldownViewerEnabled", 1) end)
    self:RegisterMessage("TavernUI_ProfileChanged", "OnProfileChanged")

    -- Initialize subsystems in order
    if self.ItemRegistry then self.ItemRegistry.Initialize() end
    if self.CooldownTracker and self.CooldownTracker.Initialize then self.CooldownTracker.Initialize() end
    if self.LayoutEngine then self.LayoutEngine.Initialize() end
    if self.Keybinds then self.Keybinds.Initialize() end
    if self.Anchoring then self.Anchoring.Initialize() end

    -- Register events
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "OnEquipmentChanged")
    self:RegisterEvent("UPDATE_BINDINGS", "OnBindingsUpdate")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")

    -- Watch for setting changes
    self:WatchSetting("enabled", function(newValue, oldValue)
        self:HandleEnabledChange(newValue, oldValue)
    end)

    for _, rate in ipairs({"initial", "normal", "combat"}) do
        self:WatchSetting("general.updateRates." .. rate, function()
            if self:IsEnabled() then
                self:RestartUpdateLoop()
            end
        end)
    end
end

function module:OnEnable()
    if self.__onEnableCalled then return end
    self.__onEnableCalled = true
end

function module:OnDisable()
    self.__onEnableCalled = nil
    self:UnregisterAllEvents()
    self:StopUpdateLoop()
    
    if self.ItemRegistry then
        self.ItemRegistry.Reset()
    end
end

--------------------------------------------------------------------------------
-- Update Loop
--------------------------------------------------------------------------------

function module:GetUpdateInterval()
    local rates = {
        initial = self:GetSetting("general.updateRates.initial", 0.05),
        combat = self:GetSetting("general.updateRates.combat", 0.3),
        normal = self:GetSetting("general.updateRates.normal", 0.1),
    }
    
    if self.initialPhaseStartTime then
        local elapsed = GetTime() - self.initialPhaseStartTime
        if elapsed < CONSTANTS.INITIAL_PHASE_DURATION then
            return rates.initial
        end
    end
    
    return InCombatLockdown() and rates.combat or rates.normal
end

function module:IsInInitialPhase()
    if not self.initialPhaseStartTime then return false end
    return (GetTime() - self.initialPhaseStartTime) < CONSTANTS.INITIAL_PHASE_DURATION
end

function module:StartUpdateLoop()
    self:StopUpdateLoop()
    self.updateLoopActive = true
    self.initialPhaseStartTime = GetTime()
    
    local function UpdateLoop()
        if not self.updateLoopActive or not self:IsEnabled() then return end
        
        self:Update()
        
        C_Timer.After(self:GetUpdateInterval(), UpdateLoop)
    end
    
    UpdateLoop()
end

function module:StopUpdateLoop()
    self.updateLoopActive = false
end

function module:RestartUpdateLoop()
    self:StopUpdateLoop()
    self:StartUpdateLoop()
end

function module:Update()
    if not self:IsEnabled() then return end
    
    -- Update ALL items (we now control all frames)
    if self.ItemRegistry then
        for _, viewerKey in ipairs(CONSTANTS.VIEWER_KEYS) do
            local items = self.ItemRegistry.GetItemsForViewer(viewerKey)
            for _, item in ipairs(items) do
                item:update()
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

function module:OnPlayerEnteringWorld()
    if not self:IsEnabled() then return end
    self:StartUpdateLoop()

    local function Stage1()
        if self.ItemRegistry then
            self.ItemRegistry.HookBlizzardViewers()
        end
    end
    
    local function Stage2()
        if self.ItemRegistry then
            self.ItemRegistry.LoadCustomEntries()
        end
    end
    
    local function Stage3()
        for _, viewerKey in ipairs({"essential", "utility", "buff"}) do
            if self.ItemRegistry then
                self.ItemRegistry.CollectBlizzardItems(viewerKey)
            end
        end
    end
    
    local function Stage4()
        self:RefreshAllViewers()
    end
    
    -- Stagger initialization
    C_Timer.After(0.1, Stage1)
    C_Timer.After(0.3, Stage2)
    C_Timer.After(0.5, Stage3)
    C_Timer.After(0.7, Stage4)
    
    C_Timer.After(1.5, function()
        if self:IsEnabled() then
            self:RefreshAllViewers()
        end
    end)
end

function module:OnEquipmentChanged()
    -- Refresh trinket icons
    if self.ItemRegistry then
        for _, viewerKey in ipairs({"essential", "utility"}) do
            local items = self.ItemRegistry.GetItemsForViewer(viewerKey)
            for _, item in ipairs(items) do
                if item.slotID then
                    item:refreshIcon()
                end
            end
        end
    end
    
    if self.LayoutEngine then
        self.LayoutEngine.RefreshViewer("essential")
        self.LayoutEngine.RefreshViewer("utility")
    end
end

function module:OnBindingsUpdate()
    if self.Keybinds then
        for _, viewerKey in ipairs(CONSTANTS.VIEWER_KEYS) do
            self.Keybinds.RefreshViewer(viewerKey)
        end
    end
end

function module:OnProfileChanged()
    if not self:IsEnabled() then return end

    -- Reset and reload
    if self.ItemRegistry then
        self.ItemRegistry.Reset()
        self.ItemRegistry.Initialize()
    end
    
    C_Timer.After(0.2, function()
        if self:IsEnabled() then
            self:RefreshAllViewers()
        end
    end)
end

function module:HandleEnabledChange(newValue, oldValue)
    if newValue then
        if self:IsEnabled() then
            self:StartUpdateLoop()
            self:RefreshAllViewers()
        end
    else
        self:StopUpdateLoop()
        for _, viewerKey in ipairs(CONSTANTS.VIEWER_KEYS) do
            local viewer = self:GetViewerFrame(viewerKey)
            if viewer then
                viewer:Hide()
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Refresh
--------------------------------------------------------------------------------

local refreshTimers = {}
local contentRefreshTimers = {}
local REFRESH_DEBOUNCE_SEC = 0.15

function module:RefreshAllViewers()
    for _, viewerKey in ipairs(CONSTANTS.VIEWER_KEYS) do
        self:RefreshViewer(viewerKey)
    end
end

function module:RefreshViewer(viewerKey)
    if not viewerKey then return end
    
    local timer = refreshTimers[viewerKey]
    if timer then
        timer:Cancel()
        refreshTimers[viewerKey] = nil
    end
    
    local function DoRefresh()
        refreshTimers[viewerKey] = nil
        if not self:IsEnabled() then return end

        if viewerKey ~= "custom" and self.ItemRegistry then
            self.ItemRegistry.CollectBlizzardItems(viewerKey)
        end
        
        if self.LayoutEngine then
            self.LayoutEngine.RefreshViewer(viewerKey)
        end
        
        if self.Keybinds then
            self.Keybinds.RefreshViewer(viewerKey)
        end
        
        if self.Anchoring then
            self.Anchoring.RefreshViewer(viewerKey)
        end
    end
    
    refreshTimers[viewerKey] = C_Timer.NewTimer(REFRESH_DEBOUNCE_SEC, DoRefresh)
end

function module:RefreshViewerContent(viewerKey)
    if not viewerKey or viewerKey == "custom" then return end
    
    local timer = contentRefreshTimers[viewerKey]
    if timer then
        timer:Cancel()
        contentRefreshTimers[viewerKey] = nil
    end
    
    local function DoContentRefresh()
        contentRefreshTimers[viewerKey] = nil
        if not self:IsEnabled() then return end
        
        if self.ItemRegistry then
            self.ItemRegistry.CollectBlizzardItems(viewerKey)
        end
        
        if self.Keybinds then
            self.Keybinds.RefreshViewer(viewerKey)
        end
    end
    
    contentRefreshTimers[viewerKey] = C_Timer.NewTimer(REFRESH_DEBOUNCE_SEC, DoContentRefresh)
end

--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------

function module:GetViewerSettings(viewerKey)
    return self:GetSetting(string.format("viewers.%s", viewerKey))
end

function module:GetViewerFrame(viewerKey)
    return _G[CONSTANTS.VIEWER_NAMES[viewerKey]]
end

function module:IsEnabled()
    return self:GetSetting("enabled", true) ~= false
end

function module:LogError(msg, ...)
    if self:GetSetting("general.debug", false) then
        print("|cFFFF0000uCDM Error:|r " .. tostring(msg), ...)
    end
end

function module:LogInfo(msg, ...)
    if self:GetSetting("general.debug", false) then
        print("|cFF00FF00uCDM:|r " .. tostring(msg), ...)
        self:Debug(tostring(msg))
    end
end

--------------------------------------------------------------------------------
-- ID Generation (for Options compatibility)
--------------------------------------------------------------------------------

function module:GenerateItemID(trackingType, id)
    if not trackingType or not id then
        return "custom_" .. GetTime() .. "_" .. math.random(1000, 9999)
    end
    local baseID = trackingType * 10000000 + id
    return baseID * 1000 + math.random(1, 999)
end

function module:GetNextIndex(viewerKey)
    if self.ItemRegistry then
        local items = self.ItemRegistry.GetItemsForViewer(viewerKey)
        return #items + 1
    end
    return 1
end
