local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local Anchor = LibStub("LibAnchorRegistry-1.0", true)

if not Anchor then
    module:LogError("LibAnchorRegistry-1.0 not found")
    return
end

local Anchoring = {}

local VIEWER_NAMES = {
    essential = "EssentialCooldownViewer",
    utility = "UtilityCooldownViewer",
    buff = "BuffIconCooldownViewer",
}

local anchorHandles = {}
local anchorTimers = {}
local editModeStartPositions = {}
local editModeHooked = false

local function GetViewerFrame(viewerKey)
    return _G[VIEWER_NAMES[viewerKey]]
end

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
    
    local viewer = GetViewerFrame(viewerKey)
    if not viewer then return false end
    
    local currentPos = GetViewerPosition(viewer)
    if not currentPos then return true end
    
    local xDiff = math.abs(currentPos.x - startPos.x)
    local yDiff = math.abs(currentPos.y - startPos.y)
    
    if xDiff > 1 or yDiff > 1 then
        return true
    end
    
    if currentPos.point ~= startPos.point then
        return true
    end
    
    if currentPos.relativePoint ~= startPos.relativePoint then
        return true
    end
    
    if currentPos.relativeToName ~= startPos.relativeToName then
        return true
    end
    
    return false
end

local function ReleaseAnchor(viewerKey)
    local handle = anchorHandles[viewerKey]
    if handle then
        pcall(function() handle:Release() end)
        anchorHandles[viewerKey] = nil
    end
end

local function ClearAnchorConfig(viewerKey)
    local settings = module:GetViewerSettings(viewerKey)
    if settings and settings.anchorConfig then
        settings.anchorConfig.target = nil
    end
end

local function ShouldApplyAnchor(viewerKey)
    local settings = module:GetViewerSettings(viewerKey)
    return settings and settings.anchorConfig and settings.anchorConfig.target and settings.anchorConfig.target ~= "" and settings.anchorConfig.target ~= "UIParent"
end

local function ApplyAnchor(viewerKey)
    if not Anchor then return end
    
    local viewer = GetViewerFrame(viewerKey)
    if not viewer then return end
    
    if not ShouldApplyAnchor(viewerKey) then
        ReleaseAnchor(viewerKey)
        return
    end
    
    local settings = module:GetViewerSettings(viewerKey)
    local config = settings.anchorConfig
    if not config or not config.target then
        ReleaseAnchor(viewerKey)
        return
    end
    
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
    end
end

local function ApplyAnchorWithTimer(viewerKey)
    local timer = anchorTimers[viewerKey]
    if timer then timer:Cancel() end
    
    anchorTimers[viewerKey] = C_Timer.NewTimer(0.05, function()
        anchorTimers[viewerKey] = nil
        ApplyAnchor(viewerKey)
    end)
end

function Anchoring.RegisterViewer(viewerKey, viewerFrame)
    if not Anchor then return end
    
    local displayNames = {
        essential = "Essential Cooldowns",
        utility = "Utility Cooldowns",
        buff = "Buff Cooldowns",
    }
    
    if viewerFrame then
        Anchor:Register("TavernUI.uCDM." .. viewerKey, viewerFrame, {
            displayName = displayNames[viewerKey] or viewerKey,
            category = "ucdm",
        })
    end
end

function Anchoring.RegisterAnchors()
    if not Anchor then return end
    
    for viewerKey, viewerName in pairs(VIEWER_NAMES) do
        local viewer = GetViewerFrame(viewerKey)
        if viewer then
            Anchoring.RegisterViewer(viewerKey, viewer)
        end
    end
    
end

local function OnEditModeEnter()
    if not module:IsEnabled() then return end
    
    editModeStartPositions = {}
    
    for _, viewerKey in ipairs({"essential", "utility", "buff"}) do
        if ShouldApplyAnchor(viewerKey) then
            local viewer = GetViewerFrame(viewerKey)
            if viewer then
                editModeStartPositions[viewerKey] = GetViewerPosition(viewer)
            end
        end
    end
end

local function OnEditModeSave()
    if not module:IsEnabled() then return end
    
    for _, viewerKey in ipairs({"essential", "utility", "buff"}) do
        local startPos = editModeStartPositions[viewerKey]
        
        if startPos then
            if HasPositionChanged(viewerKey, startPos) then
                ReleaseAnchor(viewerKey)
                ClearAnchorConfig(viewerKey)
                
                module:LogInfo(viewerKey .. " anchoring disabled (frame moved in Edit Mode)")
            else
                ApplyAnchorWithTimer(viewerKey)
            end
        end
    end
    
    editModeStartPositions = {}
end

local function HookEditMode()
    if editModeHooked then return end
    
    local EditModeManagerFrame = _G.EditModeManagerFrame
    if EditModeManagerFrame then
        EditModeManagerFrame:HookScript("OnShow", function()
            C_Timer.After(0.1, OnEditModeEnter)
        end)
        
        EditModeManagerFrame:HookScript("OnHide", function()
            C_Timer.After(0.1, OnEditModeSave)
        end)
    end
    
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "EDIT_MODE_LAYOUTS_UPDATED" then
            C_Timer.After(0.1, OnEditModeSave)
        end
    end)
    
    local C_EditMode = _G.C_EditMode
    if C_EditMode and C_EditMode.SaveLayouts then
        hooksecurefunc(C_EditMode, "SaveLayouts", function()
            C_Timer.After(0.1, OnEditModeSave)
        end)
    end
    
    editModeHooked = true
end

function Anchoring.InitializeEditMode()
    if not module:IsEnabled() then return end
    HookEditMode()
end

function Anchoring.ApplyAnchorsAfterLayout(viewerKey)
    if InCombatLockdown() then return end
    
    local EditModeManagerFrame = _G.EditModeManagerFrame
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        return
    end
    
    if ShouldApplyAnchor(viewerKey) then
        ApplyAnchorWithTimer(viewerKey)
    end
end

function Anchoring.Initialize()
    Anchoring.RegisterAnchors()
    Anchoring.InitializeEditMode()
    module:LogInfo("Anchoring initialized")
end

module.Anchoring = Anchoring
