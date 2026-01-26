-- CDM Anchoring Module
-- Handles all anchoring, positioning, and Edit Mode integration

local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("CDM")
local Anchor = LibStub("LibAnchorRegistry-1.0", true)

local VIEWER_ESSENTIAL = "EssentialCooldownViewer"
local VIEWER_UTILITY = "UtilityCooldownViewer"

local CDM = module and module.CDM or {}
if not module.CDM then
    module.CDM = CDM
end

local function GetSettings(key)
    if not module then return nil end
    local db = module:GetDB()
    if db and db[key] then
        return db[key]
    end
    return nil
end

local function IncrementSettingsVersion(trackerKey)
    if trackerKey then
        CDM.settingsVersion = CDM.settingsVersion or {}
        CDM.settingsVersion[trackerKey] = (CDM.settingsVersion[trackerKey] or 0) + 1
    else
        CDM.settingsVersion = CDM.settingsVersion or {}
        CDM.settingsVersion.essential = (CDM.settingsVersion.essential or 0) + 1
        CDM.settingsVersion.utility = (CDM.settingsVersion.utility or 0) + 1
    end
end

local function IsEditModeActive()
    return C_EditMode and C_EditMode.IsEditModeActive and C_EditMode.IsEditModeActive()
end

local function GetFramePositionRelativeToUIParent(frame, viewerName)
    if not frame then return nil end
    
    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(1)
    if not point then return nil end
    
    if relativeTo == UIParent then
        return point, relativePoint, xOfs, yOfs
    end
    
    local left, bottom, width, height = frame:GetRect()
    if not left or not bottom then return nil end
    
    local uiLeft, uiBottom, uiWidth, uiHeight = UIParent:GetRect()
    if not uiLeft or not uiBottom then return nil end
    
    local frameCenterX = left + width / 2
    local frameCenterY = bottom + height / 2
    local uiCenterX = uiLeft + uiWidth / 2
    local uiCenterY = uiBottom + uiHeight / 2
    local offsetX = frameCenterX - uiCenterX
    local offsetY = frameCenterY - uiCenterY
    
    return "CENTER", "CENTER", offsetX, offsetY
end

local function GetEditModePosition(frame)
    if not frame or not C_EditMode then return nil end
    
    local frameName = frame:GetName()
    if not frameName then return nil end
    
    local layoutInfo = C_EditMode.GetLayouts and C_EditMode.GetLayouts()
    if not layoutInfo then return nil end
    
    local activeLayout = layoutInfo.activeLayout
    if not activeLayout then return nil end
    
    local accountSettings = C_EditMode.GetAccountSettings and C_EditMode.GetAccountSettings()
    if accountSettings and accountSettings.layoutSettings then
        for layoutName, layoutData in pairs(accountSettings.layoutSettings) do
            if layoutName == activeLayout and layoutData.frames then
                for frameKey, frameData in pairs(layoutData.frames) do
                    if frameKey == frameName and frameData.anchorInfo then
                        local anchorInfo = frameData.anchorInfo
                        if anchorInfo.point and anchorInfo.relativeTo == "UIParent" then
                            return anchorInfo.point, anchorInfo.relativePoint or anchorInfo.point, 
                                   anchorInfo.offsetX or 0, anchorInfo.offsetY or 0
                        end
                    end
                end
            end
        end
    end
    
    return nil
end

local function SavePosition(viewerName, key)
    local viewer = _G[viewerName]
    if not viewer then return end
    
    local point, relativePoint, xOfs, yOfs
    
    local editModePos = GetEditModePosition(viewer)
    if editModePos then
        point, relativePoint, xOfs, yOfs = editModePos
    else
        local result = GetFramePositionRelativeToUIParent(viewer, viewerName)
        if not result then return end
        point, relativePoint, xOfs, yOfs = result
    end
    
    local settings = GetSettings(key)
    if not settings then return end
    
    if not settings.anchorConfig then
        settings.anchorConfig = {}
    end
    
    local handleKey = key == "essential" and "essential" or "utility"
    if CDM.anchorHandles and CDM.anchorHandles[handleKey] then
        pcall(function() CDM.anchorHandles[handleKey]:Release() end)
        CDM.anchorHandles[handleKey] = nil
    end
    
    if settings.anchorConfig.target and settings.anchorConfig.target ~= "UIParent" and settings.anchorConfig.target ~= "" then
        settings.anchorConfig.offsetX = xOfs
        settings.anchorConfig.offsetY = yOfs
        if not settings.anchorConfig.point or settings.anchorConfig.point == "CENTER" then
            settings.anchorConfig.point = point
            settings.anchorConfig.relativePoint = relativePoint
        end
    else
        settings.anchorConfig.target = "UIParent"
        settings.anchorConfig.point = point
        settings.anchorConfig.relativePoint = relativePoint
        settings.anchorConfig.offsetX = xOfs
        settings.anchorConfig.offsetY = yOfs
    end
    
    if key == "utility" then
        settings.anchorBelowEssential = false
    end
end

local function SaveEssentialPosition()
    SavePosition(VIEWER_ESSENTIAL, "essential")
end

local function SaveUtilityPosition()
    SavePosition(VIEWER_UTILITY, "utility")
end

local function ApplyAnchor(viewerName, key, anchorHandleKey)
    if InCombatLockdown() then
        return
    end
    
    if not CDM.applyingAnchors then
        CDM.applyingAnchors = {}
    end
    
    if CDM.applyingAnchors[anchorHandleKey] then
        return
    end
    
    CDM.applyingAnchors[anchorHandleKey] = true
    
    local viewer = _G[viewerName]
    if not viewer then 
        CDM.applyingAnchors[anchorHandleKey] = nil
        return 
    end
    
    if not Anchor then
        CDM.applyingAnchors[anchorHandleKey] = nil
        return
    end
    
    if module.RegisterAnchors then
        module.RegisterAnchors()
    end
    
    local settings = GetSettings(key)
    if not settings then 
        CDM.applyingAnchors[anchorHandleKey] = nil
        return 
    end
    
    if settings.anchorConfig and settings.anchorConfig.target and settings.anchorConfig.target ~= "" and settings.anchorConfig.target ~= "UIParent" then
        local target = settings.anchorConfig.target
        
        if Anchor:Exists(target) then
            local needsUpdate = true
            if CDM.anchorHandles and CDM.anchorHandles[anchorHandleKey] then
                local currentHandle = CDM.anchorHandles[anchorHandleKey]
                local ok, currentConfig = pcall(function() return currentHandle and currentHandle.config end)
                if ok and currentConfig and currentConfig.target then
                    local currentTarget = currentConfig.target
                    local currentPoint = currentConfig.point
                    local currentRelativePoint = currentConfig.relativePoint
                    local currentOffsetX = currentConfig.offsetX
                    local currentOffsetY = currentConfig.offsetY
                    
                    local newPoint = settings.anchorConfig.point or "CENTER"
                    local newRelativePoint = settings.anchorConfig.relativePoint or "CENTER"
                    local newOffsetX = settings.anchorConfig.offsetX or 0
                    local newOffsetY = settings.anchorConfig.offsetY or 0
                    
                    if currentTarget == target and 
                       currentPoint == newPoint and 
                       currentRelativePoint == newRelativePoint and
                       math.abs((currentOffsetX or 0) - newOffsetX) < 0.1 and
                       math.abs((currentOffsetY or 0) - newOffsetY) < 0.1 then
                        needsUpdate = false
                    else
                        pcall(function() currentHandle:Release() end)
                        CDM.anchorHandles[anchorHandleKey] = nil
                    end
                else
                    CDM.anchorHandles[anchorHandleKey] = nil
                end
            end
            
            if needsUpdate then
                if not CDM.anchorHandles then
                    CDM.anchorHandles = {}
                end
                local handle = Anchor:AnchorTo(viewer, {
                    target = target,
                    point = settings.anchorConfig.point or "CENTER",
                    relativePoint = settings.anchorConfig.relativePoint or "CENTER",
                    offsetX = settings.anchorConfig.offsetX or 0,
                    offsetY = settings.anchorConfig.offsetY or 0,
                    deferred = false,
                })
                
                if handle then
                    CDM.anchorHandles[anchorHandleKey] = handle
                end
            end
            CDM.applyingAnchors[anchorHandleKey] = nil
            return
        end
    end
    
    if key == "utility" and (not settings.anchorConfig or not settings.anchorConfig.target or settings.anchorConfig.target == "" or settings.anchorConfig.target == "UIParent") and settings.anchorBelowEssential ~= false then
        local target = "TavernUI.CDM.Essential"
        local essentialViewer = _G[VIEWER_ESSENTIAL]
        
        if not essentialViewer then
            CDM.applyingAnchors[anchorHandleKey] = nil
            return
        end
        
        if not Anchor:Exists(target) then
            CDM.applyingAnchors[anchorHandleKey] = nil
            return
        end
        
        if module.UpdateCDMAnchorMetadata then
            module.UpdateCDMAnchorMetadata(VIEWER_ESSENTIAL, essentialViewer)
        end
        
        do
            local needsUpdate = true
            if CDM.anchorHandles and CDM.anchorHandles[anchorHandleKey] then
                local currentHandle = CDM.anchorHandles[anchorHandleKey]
                local ok, currentConfig = pcall(function() return currentHandle and currentHandle.config end)
                if ok and currentConfig and currentConfig.target then
                    local currentTarget = currentConfig.target
                    local currentPoint = currentConfig.point
                    local currentRelativePoint = currentConfig.relativePoint
                    local currentOffsetX = currentConfig.offsetX
                    local currentOffsetY = currentConfig.offsetY
                    
                    local newPoint = settings.anchorPoint or "TOP"
                    local newRelativePoint = settings.anchorRelativePoint or "BOTTOM"
                    local newOffsetX = settings.anchorOffsetX or 0
                    local newOffsetY = -(settings.anchorGap or 5)
                    
                    if currentTarget == target and 
                       currentPoint == newPoint and 
                       currentRelativePoint == newRelativePoint and
                       math.abs((currentOffsetX or 0) - newOffsetX) < 0.1 and
                       math.abs((currentOffsetY or 0) - newOffsetY) < 0.1 then
                        needsUpdate = false
                    else
                        pcall(function() currentHandle:Release() end)
                        CDM.anchorHandles[anchorHandleKey] = nil
                    end
                else
                    CDM.anchorHandles[anchorHandleKey] = nil
                end
            end
            
            if needsUpdate then
                if not CDM.anchorHandles then
                    CDM.anchorHandles = {}
                end
                local handle = Anchor:AnchorTo(viewer, {
                    target = target,
                    point = settings.anchorPoint or "TOP",
                    relativePoint = settings.anchorRelativePoint or "BOTTOM",
                    offsetX = settings.anchorOffsetX or 0,
                    offsetY = -(settings.anchorGap or 5),
                    deferred = false,
                })
                
                if handle then
                    CDM.anchorHandles[anchorHandleKey] = handle
                end
            end
        end
        CDM.applyingAnchors[anchorHandleKey] = nil
        return
    end
    
    if CDM.anchorHandles and CDM.anchorHandles[anchorHandleKey] then
        pcall(function() CDM.anchorHandles[anchorHandleKey]:Release() end)
        CDM.anchorHandles[anchorHandleKey] = nil
    end
    
    CDM.applyingAnchors[anchorHandleKey] = nil
end

if not CDM.anchorTimers then
    CDM.anchorTimers = {}
end

local function ApplyEssentialAnchor()
    if CDM.anchorTimers.essential then
        CDM.anchorTimers.essential:Cancel()
    end
    CDM.anchorTimers.essential = C_Timer.NewTimer(0.05, function()
        CDM.anchorTimers.essential = nil
        ApplyAnchor(VIEWER_ESSENTIAL, "essential", "essential")
    end)
end

local function ApplyUtilityAnchor()
    if CDM.anchorTimers.utility then
        CDM.anchorTimers.utility:Cancel()
    end
    CDM.anchorTimers.utility = C_Timer.NewTimer(0.05, function()
        CDM.anchorTimers.utility = nil
        ApplyAnchor(VIEWER_UTILITY, "utility", "utility")
    end)
end

local function RegisterAnchors()
    if not Anchor then return end
    
    local essentialViewer = _G[VIEWER_ESSENTIAL]
    local utilityViewer = _G[VIEWER_UTILITY]
    
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
end

local function UpdateCDMAnchorMetadata(viewerName, viewer)
    if not Anchor then return end
    
    local anchorName = viewerName == VIEWER_ESSENTIAL and "TavernUI.CDM.Essential" or "TavernUI.CDM.Utility"
    
    if not Anchor:Exists(anchorName) then
        return
    end
    
    local GetFrameData = module.GetFrameData
    if not GetFrameData then return end
    
    local data = GetFrameData(viewer)
    
    Anchor:UpdateMetadata(anchorName, {
        row1Width = data.row1Width,
        totalHeight = data.totalHeight,
    })
end

local function HookViewerForEditMode(viewerName, viewer)
    if not viewer or viewer.__cdmEditModeHooked then return end
    
    local key = viewerName == VIEWER_ESSENTIAL and "essential" or "utility"
    
    local originalOnDragStart = viewer:GetScript("OnDragStart")
    local originalOnDragStop = viewer:GetScript("OnDragStop")
    
    viewer:SetScript("OnDragStart", function(self)
        if originalOnDragStart then
            originalOnDragStart(self)
        end
        
        if IsEditModeActive() then
            local point, relativeTo, relativePoint, x, y = self:GetPoint()
            self._cdmDragStartPoint = {
                point = point,
                relativeTo = relativeTo,
                relativePoint = relativePoint,
                x = x,
                y = y
            }
        end
    end)
    
    viewer:SetScript("OnDragStop", function(self)
        if originalOnDragStop then
            originalOnDragStop(self)
        end
        
        if IsEditModeActive() and self._cdmDragStartPoint then
            local newPoint, newRelativeTo, newRelativePoint, newX, newY = self:GetPoint()
            local startPoint = self._cdmDragStartPoint
            
            local moved = false
            if newRelativeTo ~= startPoint.relativeTo then
                moved = true
            elseif math.abs(newX - startPoint.x) > 1 or math.abs(newY - startPoint.y) > 1 then
                moved = true
            end
            
            if moved then
                local anchorHandle = CDM.anchorHandles and CDM.anchorHandles[key]
                if anchorHandle then
                    local ok, isReleased = pcall(function() return anchorHandle.released end)
                    if ok and not isReleased then
                        pcall(function() anchorHandle:Release() end)
                        CDM.anchorHandles[key] = nil
                    end
                end
            end
            
            self._cdmDragStartPoint = nil
        end
    end)
    
    viewer.__cdmEditModeHooked = true
end

if module then
    module.SaveEssentialPosition = SaveEssentialPosition
    module.SaveUtilityPosition = SaveUtilityPosition
    module.ApplyEssentialAnchor = ApplyEssentialAnchor
    module.ApplyUtilityAnchor = ApplyUtilityAnchor
    module.RegisterAnchors = RegisterAnchors
    module.UpdateCDMAnchorMetadata = UpdateCDMAnchorMetadata
    module.HookViewerForEditMode = HookViewerForEditMode
    module.IsEditModeActive = IsEditModeActive
end
