local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local Anchor = LibStub("LibAnchorRegistry-1.0", true)
local LibEditMode = LibStub("LibEditMode", true)
local useLibEditMode = LibEditMode and LibEditMode.AddFrame

if not Anchor then
    module:LogError("LibAnchorRegistry-1.0 not found")
    return
end

local Anchoring = {}
local libEditModeRegisteredViewers = {}

local CONSTANTS = {
    POSITION_CHANGE_THRESHOLD = 1,
}

local anchorHandles = {}
local lastAppliedConfig = {}
local anchorTimers = {}
local editModeStartPositions = {}
local editModeHooked = false

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function GetViewerPosition(viewer)
    if not viewer then return nil end
    return Anchor:GetFramePosition(viewer)
end

local function HasPositionChanged(viewerKey, startPos)
    if not startPos then return false end
    local viewer = module:GetViewerFrame(viewerKey)
    if not viewer then return false end
    return Anchor:HasPositionChanged(viewer, startPos, CONSTANTS.POSITION_CHANGE_THRESHOLD)
end

local function ShouldApplyAnchor(viewerKey)
    local settings = module:GetViewerSettings(viewerKey)
    if not settings or not settings.anchorConfig then return false end
    
    local target = settings.anchorConfig.target
    return target and target ~= ""
end

--------------------------------------------------------------------------------
-- Anchor Management
--------------------------------------------------------------------------------

local function ReleaseAnchor(viewerKey)
    local handle = anchorHandles[viewerKey]
    if handle then
        if handle.Release then
            handle:Release()
        end
        anchorHandles[viewerKey] = nil
    end
    lastAppliedConfig[viewerKey] = nil
end

local function ConfigMatches(viewerKey, config)
    local last = lastAppliedConfig[viewerKey]
    if not last then return false end
    return Anchor:ConfigEquals(last, config)
end

local function ClearAnchorConfig(viewerKey)
    local settings = module:GetViewerSettings(viewerKey)
    if settings and settings.anchorConfig then
        settings.anchorConfig.target = nil
    end
end

local function ApplyAnchor(viewerKey)
    local viewer = module:GetViewerFrame(viewerKey)
    if not viewer then return end
    
    if not ShouldApplyAnchor(viewerKey) then
        ReleaseAnchor(viewerKey)
        return
    end
    
    local settings = module:GetViewerSettings(viewerKey)
    local config = settings.anchorConfig
    local handle = anchorHandles[viewerKey]
    
    if ConfigMatches(viewerKey, config) and (not handle or not handle.released) then return end

    Anchoring.RegisterAnchors()
    ReleaseAnchor(viewerKey)

    handle = Anchor:AnchorTo(viewer, {
        target = config.target,
        point = config.point or "CENTER",
        relativePoint = config.relativePoint or "CENTER",
        offsetX = config.offsetX or 0,
        offsetY = config.offsetY or 0,
        deferred = false,
    })
    
    if handle then
        anchorHandles[viewerKey] = handle
        lastAppliedConfig[viewerKey] = {
            target = config.target,
            point = config.point or "CENTER",
            relativePoint = config.relativePoint or "CENTER",
            offsetX = config.offsetX or 0,
            offsetY = config.offsetY or 0,
        }
    else
        module:LogError("Failed to create anchor for " .. viewerKey)
    end
end

local function ApplyAnchorWithSizeHook(viewerKey)
    local timer = anchorTimers[viewerKey]
    if timer then timer:Cancel() end
    
    local viewer = module:GetViewerFrame(viewerKey)
    if not viewer then return end
    
    ApplyAnchor(viewerKey)
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

local function GetViewerDisplayName(viewerKey)
    local displayNames = {
        essential = "Essential Cooldowns",
        utility = "Utility Cooldowns",
        buff = "Buff Cooldowns",
    }
    if displayNames[viewerKey] then
        return displayNames[viewerKey]
    end
    if module.GetCustomViewerDisplayName and module:IsCustomViewerId(viewerKey) then
        return module:GetCustomViewerDisplayName(viewerKey)
    end
    return viewerKey
end

function Anchoring.RegisterViewer(viewerKey, viewerFrame)
    if not viewerFrame then return end
    Anchor:Register("TavernUI.uCDM." .. viewerKey, viewerFrame, {
        displayName = GetViewerDisplayName(viewerKey),
        category = "ucdm",
    })
    if useLibEditMode and not libEditModeRegisteredViewers[viewerKey] then
        local settings = module:GetViewerSettings(viewerKey)
        local ac = (settings and settings.anchorConfig and type(settings.anchorConfig) == "table") and settings.anchorConfig or {}
        local default = (ac.point and ac.offsetX and ac.offsetY) and { point = ac.point, x = ac.offsetX or 0, y = ac.offsetY or 0 } or { point = "CENTER", x = 0, y = -150 }
        LibEditMode:AddFrame(viewerFrame, function(f, layoutName, point, x, y)
            local key = f.viewerKey
            if not key then return end
            module:SetSetting("viewers." .. key .. ".anchorConfig", {
                target = "UIParent",
                point = point or "CENTER",
                relativePoint = point or "CENTER",
                offsetX = x or 0,
                offsetY = y or 0,
            })
            if ShouldApplyAnchor(key) then
                ApplyAnchor(key)
            end
        end, default, GetViewerDisplayName(viewerKey))
        viewerFrame.viewerKey = viewerKey
        libEditModeRegisteredViewers[viewerKey] = true
    end
end

function Anchoring.UnregisterViewer(viewerKey)
    if not viewerKey then return end
    libEditModeRegisteredViewers[viewerKey] = nil
    local frame = module:GetViewerFrame(viewerKey)
    if useLibEditMode and frame and LibEditMode then
        if LibEditMode.frameSelections then LibEditMode.frameSelections[frame] = nil end
        if LibEditMode.frameCallbacks then LibEditMode.frameCallbacks[frame] = nil end
        if LibEditMode.frameDefaults then LibEditMode.frameDefaults[frame] = nil end
        if LibEditMode.frameSettings then LibEditMode.frameSettings[frame] = nil end
        if LibEditMode.frameButtons then LibEditMode.frameButtons[frame] = nil end
    end
    Anchor:Unregister("TavernUI.uCDM." .. viewerKey)
end

function Anchoring.RegisterAnchors()
    for viewerKey, viewerName in pairs(module.CONSTANTS.VIEWER_NAMES) do
        local viewer = _G[viewerName]
        if viewer then
            Anchoring.RegisterViewer(viewerKey, viewer)
        end
    end
    for _, id in ipairs(module:GetCustomViewerIds()) do
        local viewer = module:GetViewerFrame(id)
        if viewer then
            Anchoring.RegisterViewer(id, viewer)
        end
    end
end

--------------------------------------------------------------------------------
-- Edit Mode Integration
--------------------------------------------------------------------------------

local function GetAllViewerKeys()
    local keys = {}
    for viewerKey in pairs(module.CONSTANTS.VIEWER_NAMES) do
        keys[#keys + 1] = viewerKey
    end
    for _, id in ipairs(module:GetCustomViewerIds()) do
        keys[#keys + 1] = id
    end
    return keys
end

local function OnEditModeEnter()
    if not module:IsEnabled() then return end

    for _, entry in ipairs(module:GetSetting("customViewers", {})) do
        if entry and entry.id and not module:GetViewerFrame(entry.id) then
            module:CreateCustomViewerFrame(entry.id, entry.name or "Custom")
        end
    end
    Anchoring.RegisterAnchors()

    editModeStartPositions = {}

    for _, viewerKey in ipairs(GetAllViewerKeys()) do
        local viewer = module:GetViewerFrame(viewerKey)
        if viewer then
            viewer:Show()
            if ShouldApplyAnchor(viewerKey) then
                editModeStartPositions[viewerKey] = GetViewerPosition(viewer)
            end
        end
    end
end

local function OnEditModeSave()
    if not module:IsEnabled() then return end

    for _, viewerKey in ipairs(GetAllViewerKeys()) do
        local startPos = editModeStartPositions[viewerKey]

        if startPos then
            if HasPositionChanged(viewerKey, startPos) then
                ReleaseAnchor(viewerKey)
            else
                ApplyAnchorWithSizeHook(viewerKey)
            end
        end
    end

    editModeStartPositions = {}
end

local function HookEditMode()
    if editModeHooked then return end
    
    local EditModeManagerFrame = _G.EditModeManagerFrame
    if EditModeManagerFrame then
        EditModeManagerFrame:HookScript("OnShow", OnEditModeEnter)
        EditModeManagerFrame:HookScript("OnHide", OnEditModeSave)
    end
    
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "EDIT_MODE_LAYOUTS_UPDATED" then
            OnEditModeSave()
        end
    end)
    
    local C_EditMode = _G.C_EditMode
    if C_EditMode and C_EditMode.SaveLayouts then
        hooksecurefunc(C_EditMode, "SaveLayouts", OnEditModeSave)
    end
    
    editModeHooked = true
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function Anchoring.RefreshViewer(viewerKey)
    if not module:IsEnabled() then return end
    
    -- Skip if Edit Mode is active
    local EditModeManagerFrame = _G.EditModeManagerFrame
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        return
    end
    
    if ShouldApplyAnchor(viewerKey) then
        ApplyAnchorWithSizeHook(viewerKey)
    else
        ReleaseAnchor(viewerKey)
    end
end

function Anchoring.Initialize()
    Anchoring.RegisterAnchors()
    HookEditMode()
end

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------

module.Anchoring = Anchoring
