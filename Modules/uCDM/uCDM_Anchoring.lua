local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local Anchor = LibStub("LibAnchorRegistry-1.0", true)

if not Anchor then
    module:LogError("LibAnchorRegistry-1.0 not found")
    return
end

--[[
    Anchoring - Viewer positioning via LibAnchorRegistry
    
    Handles anchoring viewers to other UI elements and respects Edit Mode.
]]

local Anchoring = {}

local CONSTANTS = {
    POSITION_CHANGE_THRESHOLD = 1,
}

local anchorHandles = {}
local anchorTimers = {}
local editModeStartPositions = {}
local editModeHooked = false

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function GetViewerPosition(viewer)
    if not viewer or not viewer.GetPoint then return nil end
    
    local point, relativeTo, relativePoint, x, y = viewer:GetPoint(1)
    if not point then return nil end
    
    local relativeToName = nil
    if relativeTo then
        if relativeTo.GetName then
            relativeToName = relativeTo:GetName()
        elseif relativeTo == UIParent then
            relativeToName = "UIParent"
        end
    end
    
    return {
        point = point,
        relativeToName = relativeToName,
        relativePoint = relativePoint,
        x = x or 0,
        y = y or 0,
    }
end

local function HasPositionChanged(viewerKey, startPos)
    if not startPos then return false end
    
    local viewer = module:GetViewerFrame(viewerKey)
    if not viewer then return false end
    
    local currentPos = GetViewerPosition(viewer)
    if not currentPos then return true end
    
    local xDiff = math.abs(currentPos.x - startPos.x)
    local yDiff = math.abs(currentPos.y - startPos.y)
    
    if xDiff > CONSTANTS.POSITION_CHANGE_THRESHOLD or yDiff > CONSTANTS.POSITION_CHANGE_THRESHOLD then
        return true
    end
    
    return currentPos.point ~= startPos.point
        or currentPos.relativePoint ~= startPos.relativePoint
        or currentPos.relativeToName ~= startPos.relativeToName
end

local function ShouldApplyAnchor(viewerKey)
    local settings = module:GetViewerSettings(viewerKey)
    if not settings or not settings.anchorConfig then return false end
    
    local target = settings.anchorConfig.target
    return target and target ~= "" and target ~= "UIParent"
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
    
    Anchoring.RegisterAnchors()
    ReleaseAnchor(viewerKey)
    
    local handle = Anchor:AnchorTo(viewer, {
        target = config.target,
        point = config.point or "CENTER",
        relativePoint = config.relativePoint or "CENTER",
        offsetX = config.offsetX or 0,
        offsetY = config.offsetY or 0,
        deferred = false,
    })
    
    if handle then
        anchorHandles[viewerKey] = handle
        module:LogInfo("Applied anchor for " .. viewerKey)
    else
        module:LogError("Failed to create anchor for " .. viewerKey)
    end
end

local function ApplyAnchorWithSizeHook(viewerKey)
    local timer = anchorTimers[viewerKey]
    if timer then timer:Cancel() end
    
    local viewer = module:GetViewerFrame(viewerKey)
    if not viewer then return end
    
    -- Hook OnSizeChanged to re-apply anchor
    if not viewer.__ucdmAnchorSizeHooked then
        viewer:HookScript("OnSizeChanged", function()
            if anchorTimers[viewerKey] then
                anchorTimers[viewerKey]:Cancel()
                anchorTimers[viewerKey] = nil
            end
            ApplyAnchor(viewerKey)
        end)
        viewer.__ucdmAnchorSizeHooked = true
    end
    
    ApplyAnchor(viewerKey)
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

function Anchoring.RegisterViewer(viewerKey, viewerFrame)
    if not viewerFrame then return end
    
    local displayNames = {
        essential = "Essential Cooldowns",
        utility = "Utility Cooldowns",
        buff = "Buff Cooldowns",
    }
    
    Anchor:Register("TavernUI.uCDM." .. viewerKey, viewerFrame, {
        displayName = displayNames[viewerKey] or viewerKey,
        category = "ucdm",
    })
end

function Anchoring.RegisterAnchors()
    for viewerKey, viewerName in pairs(module.CONSTANTS.VIEWER_NAMES) do
        local viewer = _G[viewerName]
        if viewer then
            Anchoring.RegisterViewer(viewerKey, viewer)
        end
    end
end

--------------------------------------------------------------------------------
-- Edit Mode Integration
--------------------------------------------------------------------------------

local function OnEditModeEnter()
    if not module:IsEnabled() then return end
    
    editModeStartPositions = {}
    
    for viewerKey in pairs(module.CONSTANTS.VIEWER_NAMES) do
        if ShouldApplyAnchor(viewerKey) then
            local viewer = module:GetViewerFrame(viewerKey)
            if viewer then
                editModeStartPositions[viewerKey] = GetViewerPosition(viewer)
            end
        end
    end
end

local function OnEditModeSave()
    if not module:IsEnabled() then return end
    
    for viewerKey in pairs(module.CONSTANTS.VIEWER_NAMES) do
        local startPos = editModeStartPositions[viewerKey]
        
        if startPos then
            if HasPositionChanged(viewerKey, startPos) then
                ReleaseAnchor(viewerKey)
                ClearAnchorConfig(viewerKey)
                module:LogInfo(viewerKey .. " anchoring disabled (frame moved in Edit Mode)")
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
    module:LogInfo("Anchoring initialized")
end

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------

module.Anchoring = Anchoring
