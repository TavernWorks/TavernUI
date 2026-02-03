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
        ACTION = 4,
    },
    DEFAULT_ICON_BORDER_COLOR = {r = 0, g = 0, b = 0, a = 1},
    DEFAULT_ROW_BORDER_COLOR = {r = 0, g = 0, b = 0, a = 1},
}

module.CONSTANTS = CONSTANTS

local defaults = {
    enabled = true,
    general = {
        debug = false,
        updateRates = {
            normal = 0.1,
            combat = 0.3,
            initial = 0.05,
        },
        visibility = {
            combat = { showInCombat = true, showOutOfCombat = true },
            target = { showWhenTargetExists = false },
            group = { showSolo = true, showParty = true, showRaid = true },
            hideWhenInVehicle = false,
            hideWhenMounted = false,
            hideWhenMountedWhen = "both",
        },
    },
    viewers = {
        essential = {
            enabled = true,
            scale = 1.0,
            anchorConfig = {
                target = "UIParent",
                point = "CENTER",
                relativePoint = "CENTER",
                offsetX = 0,
                offsetY = -150,
            },
            rowGrowDirection = "down",
            rowSpacing = 5,
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
                    iconSize = 38,
                    padding = 4,
                    yOffset = 0,
                    aspectRatioCrop = 1.0,
                    zoom = 0.08,
                    iconBorderSize = 1,
                    iconBorderColor = CONSTANTS.DEFAULT_ICON_BORDER_COLOR,
                    rowBorderSize = 0,
                    rowBorderColor = CONSTANTS.DEFAULT_ROW_BORDER_COLOR,
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
            scale = 1.0,
            anchorBelowEssential = true,
            anchorPoint = "TOP",
            anchorRelativePoint = "BOTTOM",
            anchorOffsetX = 0,
            anchorGap = 5,
            anchorConfig = {
                target = "TavernUI.uCDM.essential",
                point = "TOP",
                relativePoint = "BOTTOM",
                offsetX = 0,
                offsetY = -5,
            },
            rowGrowDirection = "down",
            rowSpacing = 5,
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
                    iconSize = 30,
                    padding = 4,
                    yOffset = 0,
                    aspectRatioCrop = 1.0,
                    zoom = 0.08,
                    iconBorderSize = 1,
                    iconBorderColor = CONSTANTS.DEFAULT_ICON_BORDER_COLOR,
                    rowBorderSize = 0,
                    rowBorderColor = CONSTANTS.DEFAULT_ROW_BORDER_COLOR,
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
            scale = 1.0,
            showPreview = false,
            previewIconCount = 6,
            anchorConfig = {
                target = "TavernUI.uCDM.essential",
                point = "BOTTOM",
                relativePoint = "TOP",
                offsetX = 0,
                offsetY = 5,
            },
            rowGrowDirection = "down",
            rowSpacing = 5,
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
                    iconSize = 40,
                    padding = 4,
                    yOffset = 0,
                    aspectRatioCrop = 1.0,
                    zoom = 0.08,
                    iconBorderSize = 1,
                    iconBorderColor = CONSTANTS.DEFAULT_ICON_BORDER_COLOR,
                    rowBorderSize = 0,
                    rowBorderColor = CONSTANTS.DEFAULT_ROW_BORDER_COLOR,
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
            scale = 1.0,
            anchorConfig = nil,
            rowGrowDirection = "down",
            rowSpacing = 5,
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
                    iconSize = 38,
                    padding = 4,
                    yOffset = 0,
                    aspectRatioCrop = 1.0,
                    zoom = 0.08,
                    iconBorderSize = 1,
                    iconBorderColor = CONSTANTS.DEFAULT_ICON_BORDER_COLOR,
                    rowBorderSize = 0,
                    rowBorderColor = CONSTANTS.DEFAULT_ROW_BORDER_COLOR,
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
    customViewers = {},
    positions = {},
}

TavernUI:RegisterModuleDefaults("uCDM", defaults, true)

local function CopyTableShallow(src)
    if type(src) ~= "table" then return src end
    local t = {}
    for k, v in pairs(src) do
        t[k] = (type(v) == "table" and v ~= src) and CopyTableShallow(v) or v
    end
    return t
end

local DEFAULT_CUSTOM_VIEWER_SETTINGS = {
    enabled = true,
    scale = 1.0,
    anchorConfig = nil,
    rowGrowDirection = "down",
    rowSpacing = 5,
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
            iconSize = 38,
            padding = 4,
            yOffset = 0,
            aspectRatioCrop = 1.0,
            zoom = 0.08,
            iconBorderSize = 1,
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
}

function module:GetDefaultCustomViewerSettings()
    return CopyTableShallow(DEFAULT_CUSTOM_VIEWER_SETTINGS)
end

function module:OnInitialize()
    pcall(function() SetCVar("cooldownViewerEnabled", 1) end)
    self:RegisterMessage("TavernUI_ProfileChanged", "OnProfileChanged")
    self.CustomViewerFrames = {}

    -- Initialize subsystems in order
    if self.ItemRegistry then self.ItemRegistry.Initialize() end
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

    _G.cdm = function(viewer, slot, duration)
        local m = TavernUI:GetModule("uCDM")
        if m and m.SetSlotCooldown then
            m:SetSlotCooldown(viewer, tonumber(slot) or 1, tonumber(duration) or 30)
        end
    end

    -- Listen for UI scale changes to refresh pixel-perfect elements
    self:RegisterMessage("TavernUI_UIScaleChanged", "OnUIScaleChanged")
end

function module:OnUIScaleChanged()
    if self.LayoutEngine then
        self:RefreshAllViewers()
    end
end

function module:OnDisable()
    self.__onEnableCalled = nil
    if self._visibilityCallbackId and TavernUI.Visibility and TavernUI.Visibility.UnregisterCallback then
        TavernUI.Visibility.UnregisterCallback(self._visibilityCallbackId)
        self._visibilityCallbackId = nil
    end
    self:UnregisterAllEvents()
    self:StopUpdateLoop()

    if self.ItemRegistry then
        self.ItemRegistry.Reset()
    end
end

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

    if self.ItemRegistry then
        for _, viewerKey in ipairs(CONSTANTS.VIEWER_KEYS) do
            if viewerKey ~= "custom" then
                local items = self.ItemRegistry.GetItemsForViewer(viewerKey)
                for _, item in ipairs(items) do
                    item:update()
                end
            end
        end
        for _, id in ipairs(self:GetCustomViewerIds()) do
            local items = self.ItemRegistry.GetItemsForViewer(id)
            for _, item in ipairs(items) do
                item:update()
            end
        end
    end
end

function module:OnPlayerEnteringWorld()
    if not self:IsEnabled() then return end
    self:StartUpdateLoop()
    if TavernUI.Visibility and TavernUI.Visibility.RegisterCallback and not self._visibilityCallbackId then
        self._visibilityCallbackId = TavernUI.Visibility.RegisterCallback(function()
            if self:IsEnabled() then self:RefreshAllViewers() end
        end)
    end

    C_Timer.After(0, function()
        if not self:IsEnabled() then return end
        for _, entry in ipairs(self:GetSetting("customViewers", {})) do
            if entry and entry.id and not self.CustomViewerFrames[entry.id] then
                self:CreateCustomViewerFrame(entry.id, entry.name)
            end
        end
        if self.Anchoring and self.Anchoring.RegisterAnchors then
            self.Anchoring.RegisterAnchors()
        end
        local reg = self.ItemRegistry
        if reg then
            reg.HookBlizzardViewers()
            reg.LoadCustomEntries()
            for _, viewerKey in ipairs({"essential", "utility", "buff"}) do
                reg.CollectBlizzardItems(viewerKey)
            end
        end
        self:RefreshAllViewers()
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
            if TavernUI.Visibility and TavernUI.Visibility.RegisterCallback and not self._visibilityCallbackId then
                self._visibilityCallbackId = TavernUI.Visibility.RegisterCallback(function()
                    if self:IsEnabled() then self:RefreshAllViewers() end
                end)
            end
            self:RefreshAllViewers()
        end
    else
        if self._visibilityCallbackId and TavernUI.Visibility and TavernUI.Visibility.UnregisterCallback then
            TavernUI.Visibility.UnregisterCallback(self._visibilityCallbackId)
            self._visibilityCallbackId = nil
        end
        self:StopUpdateLoop()
        for _, viewerKey in ipairs(CONSTANTS.VIEWER_KEYS) do
            local viewer = self:GetViewerFrame(viewerKey)
            if viewer then
                viewer:Hide()
            end
        end
        for _, id in ipairs(self:GetCustomViewerIds()) do
            local viewer = self:GetViewerFrame(id)
            if viewer then
                viewer:Hide()
            end
        end
    end
end

local refreshTimers = {}
local contentRefreshTimers = {}
local REFRESH_DEBOUNCE_SEC = 0.15

function module:RefreshAllViewers()
    for _, viewerKey in ipairs(CONSTANTS.VIEWER_KEYS) do
        if viewerKey ~= "custom" then
            self:RefreshViewer(viewerKey)
        end
    end
    for _, id in ipairs(self:GetCustomViewerIds()) do
        self:RefreshViewer(id)
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

        local skipBlizzard = (viewerKey == "custom") or self:IsCustomViewerId(viewerKey)
        if not skipBlizzard and self.ItemRegistry then
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

function module:GetViewerSettings(viewerKey)
    return self:GetSetting(string.format("viewers.%s", viewerKey))
end

function module:GetViewerFrame(viewerKey)
    if CONSTANTS.VIEWER_NAMES[viewerKey] then
        return _G[CONSTANTS.VIEWER_NAMES[viewerKey]]
    end
    if self:IsCustomViewerId(viewerKey) and self.CustomViewerFrames then
        return self.CustomViewerFrames[viewerKey]
    end
    return nil
end

function module:CreateCustomViewerFrame(id, name)
    if self.CustomViewerManager and self.CustomViewerManager.CreateCustomViewerFrame then
        return self.CustomViewerManager.CreateCustomViewerFrame(self, id, name)
    end
end

function module:RemoveCustomViewer(id)
    if self.CustomViewerManager and self.CustomViewerManager.RemoveCustomViewer then
        self.CustomViewerManager.RemoveCustomViewer(self, id)
    end
end

function module:SetCustomViewerName(id, name)
    if self.CustomViewerManager and self.CustomViewerManager.SetCustomViewerName then
        self.CustomViewerManager.SetCustomViewerName(self, id, name)
    end
end

function module:GetCustomViewerIds()
    if self.CustomViewerManager and self.CustomViewerManager.GetCustomViewerIds then
        return self.CustomViewerManager.GetCustomViewerIds(self)
    end
    return {}
end

function module:IsCustomViewerId(viewerKey)
    if self.CustomViewerManager and self.CustomViewerManager.IsCustomViewerId then
        return self.CustomViewerManager.IsCustomViewerId(self, viewerKey)
    end
    return false
end

function module:GetCustomViewerDisplayName(viewerKey)
    if self.CustomViewerManager and self.CustomViewerManager.GetCustomViewerDisplayName then
        return self.CustomViewerManager.GetCustomViewerDisplayName(self, viewerKey)
    end
    return viewerKey
end

function module:IsEnabled()
    return self:GetSetting("enabled", true) ~= false
end

function module:LogError(msg, ...)
    -- Errors always print regardless of debug setting
    print("|cFFFF0000uCDM Error:|r " .. tostring(msg), ...)
end

function module:LogInfo(msg, ...)
    if self:GetSetting("general.debug", false) then
        print("|cFF00FF00uCDM:|r " .. tostring(msg), ...)
        self:Debug(tostring(msg))
    end
end

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

module._slotCooldownOverrides = module._slotCooldownOverrides or {}

function module:SetSlotCooldown(viewerKey, layoutIndex, durationSeconds)
    if not viewerKey or not layoutIndex or not durationSeconds or durationSeconds <= 0 then return end
    layoutIndex = math.floor(layoutIndex)
    if layoutIndex < 1 then return end
    if not self._slotCooldownOverrides[viewerKey] then
        self._slotCooldownOverrides[viewerKey] = {}
    end
    self._slotCooldownOverrides[viewerKey][layoutIndex] = {
        startTime = GetTime(),
        duration = durationSeconds,
    }
    local found = false
    if self.ItemRegistry then
        local items = self.ItemRegistry.GetItemsForViewer(viewerKey)
        for _, item in ipairs(items) do
            if item.layoutIndex == layoutIndex and item.update then
                item:update()
                found = true
                break
            end
        end
    end
    print("[TavernUI CDM] " .. (found and ("Slot " .. layoutIndex .. " override set, duration " .. durationSeconds .. "s") or ("Override set but no item at " .. viewerKey .. " slot " .. layoutIndex .. " (layoutIndex?)")))
end

function module:GetSlotCooldownOverride(viewerKey, layoutIndex)
    local overrides = self._slotCooldownOverrides and self._slotCooldownOverrides[viewerKey]
    if not overrides then return nil end
    local o = overrides[layoutIndex]
    if not o or not o.startTime or not o.duration then return nil end
    local now = GetTime()
    if now >= o.startTime + o.duration then
        overrides[layoutIndex] = nil
        return nil
    end
    return o.startTime, o.duration
end

SLASH_TAVERNUI_CDM1 = "/cdm"
SlashCmdList["TAVERNUI_CDM"] = function(msg)
    local m = TavernUI:GetModule("uCDM", true)
    if not m or not m.SetSlotCooldown then
        return
    end
    local viewer, slot, duration = msg:match("^%s*(%S+)%s+(%d+)%s+(%d+)%s*$")
    if not viewer then
        viewer, slot, duration = msg:match("^%s*(%S+)%s+(%d+)%s+%S+%s+(%d+)%s*$")
    end
    if viewer and slot and duration then
        m:SetSlotCooldown(viewer, tonumber(slot), tonumber(duration))
    else
        print("[TavernUI CDM] Parse failed. Use: /cdm <viewer> <slot> [timer] <duration> e.g. /cdm essential 3 30")
    end
end
