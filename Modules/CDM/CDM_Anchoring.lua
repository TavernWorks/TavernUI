-- CDM Anchoring Module
-- Handles all anchoring, positioning, and Edit Mode integration

local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("CDM")
local Anchor = LibStub("LibAnchorRegistry-1.0", true)

if not module then return end

local VIEWER_ESSENTIAL = module.VIEWER_ESSENTIAL or "EssentialCooldownViewer"
local VIEWER_UTILITY = module.VIEWER_UTILITY or "UtilityCooldownViewer"
local VIEWER_BUFF = module.VIEWER_BUFF or "BuffCooldownViewer"

local CDM = module.CDM
if not CDM then
    module.CDM = {}
    CDM = module.CDM
end

CDM.anchorHandles = CDM.anchorHandles or {}
CDM.anchorTimers = CDM.anchorTimers or {}
-- Stores position when edit mode opens, to compare on save
CDM.editModeStartPositions = CDM.editModeStartPositions or {}

local function GetSettings(key)
    return module.GetSettings and module.GetSettings(key)
end

local function ReleaseAnchor(key)
    local handle = CDM.anchorHandles[key]
    if handle then
        pcall(function() handle:Release() end)
        CDM.anchorHandles[key] = nil
    end
end

local function ClearAnchorConfig(key)
    local settings = GetSettings(key)
    if settings and settings.anchorConfig then
        settings.anchorConfig.target = nil
    end
    -- Also clear the category selection so the UI resets properly
    local db = module:GetDB()
    if db and db[key] then
        db[key].anchorCategory = nil
    end
end

local function ShouldApplyAnchor(key)
    local settings = GetSettings(key)
    return settings and settings.anchorConfig and settings.anchorConfig.target and settings.anchorConfig.target ~= "" and settings.anchorConfig.target ~= "UIParent"
end

local function ApplyAnchor(viewerName, key)
    if not Anchor then return end
    
    local viewer = _G[viewerName]
    if not viewer then return end
    
    if not ShouldApplyAnchor(key) then
        ReleaseAnchor(key)
        return
    end
    
    local settings = GetSettings(key)
    local config = settings.anchorConfig
    if not config or not config.target then
        ReleaseAnchor(key)
        return
    end
    
    if module.RegisterAnchors then
        module.RegisterAnchors()
    end
    
    ReleaseAnchor(key)
    
    local handle = Anchor:AnchorTo(viewer, {
        target = config.target,
        point = config.point or "CENTER",
        relativePoint = config.relativePoint or "CENTER",
        offsetX = config.offsetX or 0,
        offsetY = config.offsetY or 0,
        deferred = false,
    })
    
    if handle then
        CDM.anchorHandles[key] = handle
    end
end

local function ApplyAnchorWithTimer(key, viewerName)
    local timer = CDM.anchorTimers[key]
    if timer then timer:Cancel() end
    
    CDM.anchorTimers[key] = C_Timer.NewTimer(0.05, function()
        CDM.anchorTimers[key] = nil
        ApplyAnchor(viewerName, key)
    end)
end

local function RegisterAnchors()
    if not Anchor then return end
    
    local essentialViewer = _G[VIEWER_ESSENTIAL]
    local utilityViewer = _G[VIEWER_UTILITY]
    local buffViewer = _G[VIEWER_BUFF]
    
    if essentialViewer then
        Anchor:Register("TavernUI.CDM.Essential", essentialViewer, {
            displayName = "Essential Cooldowns",
            category = "cdm",
        })
    end
    
    if utilityViewer then
        Anchor:Register("TavernUI.CDM.Utility", utilityViewer, {
            displayName = "Utility Cooldowns",
            category = "cdm",
        })
    end
    
    if buffViewer then
        Anchor:Register("TavernUI.CDM.Buff", buffViewer, {
            displayName = "Buff Cooldowns",
            category = "cdm",
        })
    end
end

-- Store current position of a viewer frame
local function GetViewerPosition(viewer)
    if not viewer or not viewer.GetPoint then return nil end
    
    local point, relativeTo, relativePoint, x, y = viewer:GetPoint(1)
    if not point then return nil end
    
    -- Store relativeTo as a name if it's a frame, to avoid stale references
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

-- Check if position has changed significantly
local function HasPositionChanged(key, startPos)
    if not startPos then return false end
    
    local viewerName = (key == "essential" and VIEWER_ESSENTIAL) or (key == "utility" and VIEWER_UTILITY) or (key == "buff" and VIEWER_BUFF)
    local viewer = _G[viewerName]
    if not viewer then return false end
    
    local currentPos = GetViewerPosition(viewer)
    if not currentPos then return true end -- Can't get position, assume changed
    
    -- Check if offsets changed significantly (more than 1 pixel)
    local xDiff = math.abs(currentPos.x - startPos.x)
    local yDiff = math.abs(currentPos.y - startPos.y)
    
    if xDiff > 1 or yDiff > 1 then
        return true
    end
    
    -- Check if anchor points changed
    if currentPos.point ~= startPos.point then
        return true
    end
    
    if currentPos.relativePoint ~= startPos.relativePoint then
        return true
    end
    
    -- Check if relative frame changed
    if currentPos.relativeToName ~= startPos.relativeToName then
        return true
    end
    
    return false
end

-- Called when Edit Mode opens
local function OnEditModeEnter()
    if not module:IsEnabled() then return end
    
    CDM.editModeStartPositions = {}
    
    -- Store positions for frames that have anchoring enabled
    for _, key in ipairs({"essential", "utility", "buff"}) do
        if ShouldApplyAnchor(key) then
            local viewerName = (key == "essential" and VIEWER_ESSENTIAL) or (key == "utility" and VIEWER_UTILITY) or (key == "buff" and VIEWER_BUFF)
            local viewer = _G[viewerName]
            if viewer then
                CDM.editModeStartPositions[key] = GetViewerPosition(viewer)
            end
        end
    end
end

-- Called when Edit Mode saves/closes
local function OnEditModeSave()
    if not module:IsEnabled() then return end
    
    -- Check each viewer that had anchoring
    for _, key in ipairs({"essential", "utility", "buff"}) do
        local startPos = CDM.editModeStartPositions[key]
        
        -- Only check if we had a start position (meaning anchoring was enabled)
        if startPos then
            if HasPositionChanged(key, startPos) then
                -- User moved the frame in edit mode - disconnect anchoring
                ReleaseAnchor(key)
                ClearAnchorConfig(key)
                
                -- Notify about the change
                local viewerName = (key == "essential" and "Essential") or (key == "utility" and "Utility") or (key == "buff" and "Buff")
                if DEFAULT_CHAT_FRAME then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00CDM:|r " .. viewerName .. " anchoring disabled (frame moved in Edit Mode)")
                end
                
                -- Refresh the options UI if it's open
                if module.RefreshOptions then
                    C_Timer.After(0.1, function()
                        module:RefreshOptions(false)
                    end)
                end
            else
                -- Position didn't change, re-apply anchor to maintain the connection
                local viewerName = (key == "essential" and VIEWER_ESSENTIAL) or (key == "utility" and VIEWER_UTILITY) or (key == "buff" and VIEWER_BUFF)
                ApplyAnchorWithTimer(key, viewerName)
            end
        end
    end
    
    -- Clear stored positions
    CDM.editModeStartPositions = {}
end

local function HookEditMode()
    if CDM.editModeHooked then return end
    
    local EditModeManagerFrame = _G.EditModeManagerFrame
    if EditModeManagerFrame then
        -- When edit mode opens, store positions
        EditModeManagerFrame:HookScript("OnShow", function()
            C_Timer.After(0.1, OnEditModeEnter)
        end)
        
        -- When edit mode closes, check for changes
        EditModeManagerFrame:HookScript("OnHide", function()
            C_Timer.After(0.1, OnEditModeSave)
        end)
    end
    
    -- Also hook the save event
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "EDIT_MODE_LAYOUTS_UPDATED" then
            C_Timer.After(0.1, OnEditModeSave)
        end
    end)
    
    -- Hook C_EditMode.SaveLayouts if available
    local C_EditMode = _G.C_EditMode
    if C_EditMode and C_EditMode.SaveLayouts then
        hooksecurefunc(C_EditMode, "SaveLayouts", function()
            C_Timer.After(0.1, OnEditModeSave)
        end)
    end
    
    CDM.editModeHooked = true
end

local function InitializeEditMode()
    if not module:IsEnabled() then return end
    HookEditMode()
end

local function ApplyAnchorsAfterLayout(trackerKey)
    if InCombatLockdown() then return end
    
    -- Don't apply anchors if we're in edit mode
    local EditModeManagerFrame = _G.EditModeManagerFrame
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        return
    end
    
    if trackerKey == "essential" then
        if ShouldApplyAnchor("essential") then
            ApplyAnchorWithTimer("essential", VIEWER_ESSENTIAL)
        end
        if ShouldApplyAnchor("utility") then
            ApplyAnchorWithTimer("utility", VIEWER_UTILITY)
        end
    elseif trackerKey == "utility" then
        if ShouldApplyAnchor("utility") then
            ApplyAnchorWithTimer("utility", VIEWER_UTILITY)
        end
    elseif trackerKey == "buff" then
        if ShouldApplyAnchor("buff") then
            ApplyAnchorWithTimer("buff", VIEWER_BUFF)
        end
    end
end

module.ApplyEssentialAnchor = function()
    ApplyAnchorWithTimer("essential", VIEWER_ESSENTIAL)
end

module.ApplyUtilityAnchor = function()
    ApplyAnchorWithTimer("utility", VIEWER_UTILITY)
end

module.ApplyBuffAnchor = function()
    ApplyAnchorWithTimer("buff", VIEWER_BUFF)
end

module.RegisterAnchors = RegisterAnchors
module.InitializeEditMode = InitializeEditMode
module.ShouldApplyAnchors = ShouldApplyAnchor
module.ApplyAnchorsAfterLayout = ApplyAnchorsAfterLayout

local function CleanupAnchors()
    local Anchor = LibStub("LibAnchorRegistry-1.0", true)
    
    if Anchor then
        Anchor:Unregister("TavernUI.CDM.Essential")
        Anchor:Unregister("TavernUI.CDM.Utility")
        Anchor:Unregister("TavernUI.CDM.Buff")
    end
    
    for key, handle in pairs(CDM.anchorHandles) do
        if handle then
            pcall(function() handle:Release() end)
        end
        CDM.anchorHandles[key] = nil
    end
    
    for key, timer in pairs(CDM.anchorTimers) do
        if timer then
            timer:Cancel()
        end
        CDM.anchorTimers[key] = nil
    end
    
    CDM.editModeStartPositions = {}
end

module.CleanupAnchors = CleanupAnchors

if module:IsEnabled() then
    InitializeEditMode()
end