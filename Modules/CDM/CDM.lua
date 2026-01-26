-- TavernUI CDM Module

local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:NewModule("CDM", "AceEvent-3.0")

local Anchor = LibStub("LibAnchorRegistry-1.0", true)

local defaults = {
    essential = {
        enabled = true,
        anchorConfig = nil,
        rows = {
            {iconCount = 4, iconSize = 50, padding = -8, yOffset = 0, aspectRatioCrop = 1.0, zoom = 0, iconBorderSize = 0, iconBorderColor = {r = 0, g = 0, b = 0, a = 1}, rowBorderSize = 0, rowBorderColor = {r = 0, g = 0, b = 0, a = 1}, durationSize = 18, durationPoint = "CENTER", durationOffsetX = 0, durationOffsetY = 0, stackSize = 16, stackPoint = "BOTTOMRIGHT", stackOffsetX = 0, stackOffsetY = 0},
            {iconCount = 4, iconSize = 50, padding = -8, yOffset = 0, aspectRatioCrop = 1.0, zoom = 0, iconBorderSize = 0, iconBorderColor = {r = 0, g = 0, b = 0, a = 1}, rowBorderSize = 0, rowBorderColor = {r = 0, g = 0, b = 0, a = 1}, durationSize = 18, durationPoint = "CENTER", durationOffsetX = 0, durationOffsetY = 0, stackSize = 16, stackPoint = "BOTTOMRIGHT", stackOffsetX = 0, stackOffsetY = 0},
        }
    },
    utility = {
        enabled = true,
        anchorBelowEssential = true,
        anchorPoint = "TOP",
        anchorRelativePoint = "BOTTOM",
        anchorOffsetX = 0,
        anchorGap = 5,
        anchorConfig = nil,
        rows = {
            {iconCount = 6, iconSize = 42, padding = -8, yOffset = 0, aspectRatioCrop = 1.0, zoom = 0, iconBorderSize = 0, iconBorderColor = {r = 0, g = 0, b = 0, a = 1}, rowBorderSize = 0, rowBorderColor = {r = 0, g = 0, b = 0, a = 1}, durationSize = 18, durationPoint = "CENTER", durationOffsetX = 0, durationOffsetY = 0, stackSize = 16, stackPoint = "BOTTOMRIGHT", stackOffsetX = 0, stackOffsetY = 0},
        }
    },
}

TavernUI:RegisterModuleDefaults("CDM", defaults, true)

local VIEWER_ESSENTIAL = "EssentialCooldownViewer"
local VIEWER_UTILITY = "UtilityCooldownViewer"

local CDM = {
    frameData = {},
    applying = {},
    settingsVersion = {},
    anchorHandles = {},
    hooked = {},
    initialized = false,
}

module.CDM = CDM

local function GetDB()
    return module:GetDB()
end

local function GetSettings(key)
    local db = GetDB()
    if db and db[key] then
        return db[key]
    end
    return nil
end

local function IsIcon(child)
    if not child then return false end
    return (child.Icon or child.icon) and (child.Cooldown or child.cooldown)
end

local function CollectIcons(viewer)
    local icons = {}
    if not viewer or not viewer.GetNumChildren then return icons end
    
    local numChildren = viewer:GetNumChildren()
    for i = 1, numChildren do
        local child = select(i, viewer:GetChildren())
        if child and child ~= viewer.Selection and IsIcon(child) then
            if child:IsShown() or child.__cdmHidden then
                table.insert(icons, child)
            end
        end
    end
    
    table.sort(icons, function(a, b)
        local indexA = a.layoutIndex or 9999
        local indexB = b.layoutIndex or 9999
        return indexA < indexB
    end)
    
    return icons
end

local function GetActiveRows(settings)
    local activeRows = {}
    if not settings or not settings.rows then return activeRows end
    
    for i, row in ipairs(settings.rows) do
        if row.iconCount and row.iconCount > 0 then
            table.insert(activeRows, row)
        end
    end
    
    return activeRows
end

local function GetCapacity(settings)
    local total = 0
    if not settings or not settings.rows then return total end
    
    for i, row in ipairs(settings.rows) do
        total = total + (row.iconCount or 0)
    end
    
    return total
end

local function GetFrameData(viewer)
    if not CDM.frameData[viewer] then
        CDM.frameData[viewer] = {}
    end
    return CDM.frameData[viewer]
end

local function SetupIconOnce(icon)
    if not icon or icon.__cdmSetup then return end
    icon.__cdmSetup = true
    
    local textures = { icon.Icon, icon.icon }
    for _, tex in ipairs(textures) do
        if tex and tex.GetMaskTexture and tex.RemoveMaskTexture then
            for i = 1, 10 do
                local mask = tex:GetMaskTexture(i)
                if mask then
                    tex:RemoveMaskTexture(mask)
                end
            end
        end
    end
    
    if icon.NormalTexture then
        icon.NormalTexture:SetAlpha(0)
    end
    if icon.GetNormalTexture then
        local normalTex = icon:GetNormalTexture()
        if normalTex then
            normalTex:SetAlpha(0)
        end
    end
    
    if icon.CooldownFlash then
        icon.CooldownFlash:SetAlpha(0)
        if not icon.CooldownFlash.__cdmHooked then
            icon.CooldownFlash.__cdmHooked = true
            hooksecurefunc(icon.CooldownFlash, "Show", function(self)
                self:SetAlpha(0)
            end)
        end
    end
    
    for _, tex in ipairs(textures) do
        if tex then
            tex:ClearAllPoints()
            tex:SetAllPoints(icon)
        end
    end
    
    local cooldown = icon.Cooldown or icon.cooldown
    if cooldown then
        cooldown:ClearAllPoints()
        cooldown:SetAllPoints(icon)
        cooldown:SetSwipeTexture("Interface\\Buttons\\WHITE8X8")
        cooldown:SetSwipeColor(0, 0, 0, 0.8)
    end
end

local function ApplyTexCoord(icon, aspectRatioCrop, zoom)
    if not icon then return end
    aspectRatioCrop = aspectRatioCrop or 1.0
    zoom = zoom or 0
    local baseCrop = 0.08
    
    local left = baseCrop + zoom
    local right = 1 - baseCrop - zoom
    local top = baseCrop + zoom
    local bottom = 1 - baseCrop - zoom
    
    if aspectRatioCrop > 1.0 then
        local cropAmount = 1.0 - (1.0 / aspectRatioCrop)
        local availableHeight = bottom - top
        local offset = (cropAmount * availableHeight) / 2.0
        top = top + offset
        bottom = bottom - offset
    end
    
    local tex = icon.Icon or icon.icon
    if tex and tex.SetTexCoord then
        tex:SetTexCoord(left, right, top, bottom)
    end
end

local function ApplyIconBorder(icon, borderSize, borderColor)
    if not icon then return end
    borderSize = borderSize or 0
    
    if borderSize > 0 then
        if not icon.__cdmBorder then
            icon.__cdmBorder = icon:CreateTexture(nil, "BACKGROUND", nil, -8)
        end
        local bc = borderColor or {r = 0, g = 0, b = 0, a = 1}
        icon.__cdmBorder:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
        icon.__cdmBorder:ClearAllPoints()
        icon.__cdmBorder:SetPoint("TOPLEFT", icon, "TOPLEFT", -borderSize, borderSize)
        icon.__cdmBorder:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", borderSize, -borderSize)
        icon.__cdmBorder:Show()
        icon:SetHitRectInsets(-borderSize, -borderSize, -borderSize, -borderSize)
    else
        if icon.__cdmBorder then
            icon.__cdmBorder:Hide()
        end
        icon:SetHitRectInsets(0, 0, 0, 0)
    end
end

local function ApplyIconTextSettings(icon, rowConfig)
    if not icon then return end
    
    local durationSize = rowConfig.durationSize or 0
    local stackSize = rowConfig.stackSize or 0
    local durationPoint = rowConfig.durationPoint or "CENTER"
    local durationOffsetX = rowConfig.durationOffsetX or 0
    local durationOffsetY = rowConfig.durationOffsetY or 0
    local stackPoint = rowConfig.stackPoint or "BOTTOMRIGHT"
    local stackOffsetX = rowConfig.stackOffsetX or 0
    local stackOffsetY = rowConfig.stackOffsetY or 0
    
    if durationSize and durationSize > 0 then
        local cooldown = icon.Cooldown or icon.cooldown
        if cooldown then
            if cooldown.text then
                cooldown.text:SetFont("Fonts\\FRIZQT__.TTF", durationSize, "OUTLINE")
                pcall(function()
                    cooldown.text:ClearAllPoints()
                    cooldown.text:SetPoint(durationPoint, icon, durationPoint, durationOffsetX, durationOffsetY)
                end)
            end
            local ok, regions = pcall(function() return { cooldown:GetRegions() } end)
            if ok and regions then
                for _, region in ipairs(regions) do
                    if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                        region:SetFont("Fonts\\FRIZQT__.TTF", durationSize, "OUTLINE")
                        pcall(function()
                            region:ClearAllPoints()
                            region:SetPoint(durationPoint, icon, durationPoint, durationOffsetX, durationOffsetY)
                        end)
                    end
                end
            end
        end
    end
    
    if stackSize and stackSize > 0 then
        local chargeFrame = icon.ChargeCount
        if chargeFrame then
            local fs = chargeFrame.Current or chargeFrame.Count or chargeFrame.count
            if fs and fs.SetFont then
                fs:SetFont("Fonts\\FRIZQT__.TTF", stackSize, "OUTLINE")
                pcall(function()
                    fs:ClearAllPoints()
                    fs:SetPoint(stackPoint, icon, stackPoint, stackOffsetX, stackOffsetY)
                end)
            end
        end
        
        local countText = icon.Count or icon.count
        if countText and countText.SetFont then
            countText:SetFont("Fonts\\FRIZQT__.TTF", stackSize, "OUTLINE")
            pcall(function()
                countText:ClearAllPoints()
                countText:SetPoint(stackPoint, icon, stackPoint, stackOffsetX, stackOffsetY)
            end)
        end
    end
end

local function StyleIcon(icon, rowConfig)
    if not icon or not rowConfig then return end
    
    SetupIconOnce(icon)
    
    local aspectRatioCrop = rowConfig.aspectRatioCrop or 1.0
    local zoom = rowConfig.zoom or 0
    local iconBorderSize = rowConfig.iconBorderSize or 0
    local iconBorderColor = rowConfig.iconBorderColor or {r = 0, g = 0, b = 0, a = 1}
    
    local iconSize = rowConfig.size or 50
    local width = iconSize
    local height = iconSize / aspectRatioCrop
    
    pcall(function()
        icon:SetSize(width, height)
    end)
    
    ApplyTexCoord(icon, aspectRatioCrop, zoom)
    ApplyIconBorder(icon, iconBorderSize, iconBorderColor)
    ApplyIconTextSettings(icon, rowConfig)
end

local function ApplyRowBorder(viewer, rowNum, rowConfig, rowWidth, rowHeight, rowCenterX, rowCenterY)
    if not viewer or not rowConfig then return end
    
    local rowBorderSize = rowConfig.rowBorderSize or 0
    if rowBorderSize <= 0 then
        local borderKey = "__cdmRowBorder" .. rowNum
        if viewer[borderKey] then
            viewer[borderKey]:Hide()
        end
        return
    end
    
    local borderKey = "__cdmRowBorder" .. rowNum
    if not viewer[borderKey] then
        viewer[borderKey] = viewer:CreateTexture(nil, "BACKGROUND", nil, -7)
    end
    
    local borderColor = rowConfig.rowBorderColor or {r = 0, g = 0, b = 0, a = 1}
    viewer[borderKey]:SetColorTexture(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
    
    local halfWidth = rowWidth / 2
    local halfHeight = rowHeight / 2
    
    viewer[borderKey]:ClearAllPoints()
    viewer[borderKey]:SetPoint("TOPLEFT", viewer, "CENTER", rowCenterX - halfWidth - rowBorderSize, rowCenterY + halfHeight + rowBorderSize)
    viewer[borderKey]:SetPoint("BOTTOMRIGHT", viewer, "CENTER", rowCenterX + halfWidth + rowBorderSize, rowCenterY - halfHeight - rowBorderSize)
    viewer[borderKey]:Show()
end

local function UpdateCDMAnchorMetadata(viewerName, viewer)
    if module.UpdateCDMAnchorMetadata then
        module.UpdateCDMAnchorMetadata(viewerName, viewer)
    end
end

module.GetFrameData = GetFrameData

local function IncrementSettingsVersion(trackerKey)
    if trackerKey then
        CDM.settingsVersion[trackerKey] = (CDM.settingsVersion[trackerKey] or 0) + 1
    else
        CDM.settingsVersion.essential = (CDM.settingsVersion.essential or 0) + 1
        CDM.settingsVersion.utility = (CDM.settingsVersion.utility or 0) + 1
    end
end

local function LayoutViewer(viewerName, trackerKey)
    if not module:IsEnabled() then return end
    
    local viewer = _G[viewerName]
    if not viewer then return end
    
    local settings = GetSettings(trackerKey)
    if not settings or not settings.enabled then return end
    
    if CDM.applying[trackerKey] or viewer.__cdmLayoutRunning then return end
    
    CDM.applying[trackerKey] = true
    viewer.__cdmLayoutRunning = true
    
    local allIcons = CollectIcons(viewer)
    local activeRows = GetActiveRows(settings)
    local capacity = GetCapacity(settings)
    
    if #activeRows == 0 then
        CDM.applying[trackerKey] = false
        viewer.__cdmLayoutRunning = nil
        return
    end
    
    local iconsToLayout = {}
    for i = 1, math.min(#allIcons, capacity) do
        iconsToLayout[i] = allIcons[i]
        allIcons[i]:Show()
        allIcons[i].__cdmHidden = nil
    end
    
    for i = capacity + 1, #allIcons do
        allIcons[i]:Hide()
        allIcons[i].__cdmHidden = true
        pcall(function() allIcons[i]:ClearAllPoints() end)
    end
    
    if #iconsToLayout == 0 then
        CDM.applying[trackerKey] = false
        viewer.__cdmLayoutRunning = nil
        return
    end
    
    local rowConfigs = {}
    local iconIndex = 1
    for rowNum, row in ipairs(activeRows) do
        local iconsInRow = math.min(row.iconCount, #iconsToLayout - iconIndex + 1)
        if iconsInRow > 0 then
            table.insert(rowConfigs, {
                count = row.iconCount,
                size = row.iconSize or 50,
                padding = row.padding or 0,
                yOffset = row.yOffset or 0,
                iconsInRow = iconsInRow,
                aspectRatioCrop = row.aspectRatioCrop or 1.0,
                zoom = row.zoom or 0,
                iconBorderSize = row.iconBorderSize or 0,
                iconBorderColor = row.iconBorderColor or {r = 0, g = 0, b = 0, a = 1},
                rowBorderSize = row.rowBorderSize or 0,
                rowBorderColor = row.rowBorderColor or {r = 0, g = 0, b = 0, a = 1},
                durationSize = row.durationSize or 18,
                durationPoint = row.durationPoint or "CENTER",
                durationOffsetX = row.durationOffsetX or 0,
                durationOffsetY = row.durationOffsetY or 0,
                stackSize = row.stackSize or 16,
                stackPoint = row.stackPoint or "BOTTOMRIGHT",
                stackOffsetX = row.stackOffsetX or 0,
                stackOffsetY = row.stackOffsetY or 0,
            })
            iconIndex = iconIndex + iconsInRow
        end
    end
    
    local maxRowWidth = 0
    local totalHeight = 0
    local rowWidths = {}
    local rowGap = 5
    
    for rowNum, rowConfig in ipairs(rowConfigs) do
        local iconsInRow = rowConfig.iconsInRow
        local iconSize = rowConfig.size
        local aspectRatio = rowConfig.aspectRatioCrop or 1.0
        local iconHeight = iconSize / aspectRatio
        
        local rowWidth = (iconsInRow * iconSize) + ((iconsInRow - 1) * rowConfig.padding)
        rowWidths[rowNum] = rowWidth
        maxRowWidth = math.max(maxRowWidth, rowWidth)
        
        totalHeight = totalHeight + iconHeight
        if rowNum > 1 then
            totalHeight = totalHeight + rowGap
        end
    end
    
    local currentY = totalHeight / 2
    iconIndex = 1
    
    for rowNum, rowConfig in ipairs(rowConfigs) do
        local iconsInRow = rowConfig.iconsInRow
        local iconSize = rowConfig.size
        local aspectRatio = rowConfig.aspectRatioCrop or 1.0
        local iconHeight = iconSize / aspectRatio
        local rowWidth = rowWidths[rowNum]
        
        local halfRowWidth = rowWidth / 2
        local rowStartX = -halfRowWidth + (iconSize / 2)
        local rowCenterY = currentY - (iconHeight / 2) + rowConfig.yOffset
        
        for i = 1, iconsInRow do
            local icon = iconsToLayout[iconIndex]
            local iconOffsetX = rowStartX + ((i - 1) * (iconSize + rowConfig.padding))
            local iconOffsetY = rowCenterY
            
            pcall(function()
                StyleIcon(icon, rowConfig)
                icon:ClearAllPoints()
                icon:SetPoint("CENTER", viewer, "CENTER", iconOffsetX, iconOffsetY)
            end)
            icon:Show()
            iconIndex = iconIndex + 1
        end
        
        local aspectRatio = rowConfig.aspectRatioCrop or 1.0
        local iconHeight = iconSize / aspectRatio
        
        pcall(function()
            ApplyRowBorder(viewer, rowNum, rowConfig, rowWidth, iconHeight, 0, rowCenterY)
        end)
        
        currentY = currentY - iconHeight - rowGap
    end
    
    local data = GetFrameData(viewer)
    data.row1Width = rowWidths[1] or maxRowWidth
    data.bottomRowWidth = rowWidths[#rowConfigs] or maxRowWidth
    data.totalHeight = totalHeight
    data.iconWidth = maxRowWidth
    
    if maxRowWidth > 0 and totalHeight > 0 then
        viewer.__cdmLayoutSuppressed = (viewer.__cdmLayoutSuppressed or 0) + 1
        pcall(function()
            viewer:SetSize(maxRowWidth, totalHeight)
        end)
        viewer.__cdmLayoutSuppressed = viewer.__cdmLayoutSuppressed - 1
        if viewer.__cdmLayoutSuppressed <= 0 then
            viewer.__cdmLayoutSuppressed = nil
        end
    end
    
    CDM.applying[trackerKey] = false
    viewer.__cdmLayoutRunning = nil
    
    UpdateCDMAnchorMetadata(viewerName, viewer)
    
    if not InCombatLockdown() then
        if trackerKey == "essential" then
            if module.ApplyEssentialAnchor then module.ApplyEssentialAnchor() end
            if module.ApplyUtilityAnchor then module.ApplyUtilityAnchor() end
        elseif trackerKey == "utility" then
            if module.ApplyUtilityAnchor then module.ApplyUtilityAnchor() end
        end
    end
end

local function HookViewer(viewerName, trackerKey)
    local viewer = _G[viewerName]
    if not viewer then return end
    if CDM.hooked[trackerKey] then return end
    
    CDM.hooked[trackerKey] = true
    
    viewer:HookScript("OnShow", function(self)
        if not module:IsEnabled() then return end
        if self.__cdmUpdateFrame then
            self.__cdmUpdateFrame:Show()
        end
        C_Timer.After(0.02, function()
            if module:IsEnabled() and self:IsShown() then
                LayoutViewer(viewerName, trackerKey)
            end
        end)
    end)
    
    viewer:HookScript("OnHide", function(self)
        if self.__cdmUpdateFrame then
            self.__cdmUpdateFrame:Hide()
        end
    end)
    
    viewer:HookScript("OnSizeChanged", function(self)
        if not module:IsEnabled() then return end
        self.__cdmBlizzardCount = (self.__cdmBlizzardCount or 0) + 1
        if self.__cdmLayoutSuppressed or self.__cdmLayoutRunning then
            return
        end
        LayoutViewer(viewerName, trackerKey)
    end)
    
    local updateFrame = CreateFrame("Frame")
    viewer.__cdmUpdateFrame = updateFrame
    
    local lastIconCount = 0
    local lastSettingsVersion = 0
    local lastBlizzardLayoutCount = 0
    
    updateFrame:SetScript("OnUpdate", function(self, elapsed)
        if not module:IsEnabled() then return end
        
        viewer.__cdmElapsed = (viewer.__cdmElapsed or 0) + elapsed
        
        local updateInterval = UnitAffectingCombat("player") and 1.0 or 0.5
        
        if viewer.__cdmEventFired then
            viewer.__cdmEventFired = nil
            viewer.__cdmElapsed = 0
        elseif viewer.__cdmElapsed < updateInterval then
            return
        else
            viewer.__cdmElapsed = 0
        end
        
        if CDM.applying[trackerKey] then return end
        
        if InCombatLockdown() then return end
        
        local currentBlizzardCount = viewer.__cdmBlizzardCount or 0
        local currentVersion = CDM.settingsVersion[trackerKey] or 0
        
        local inGracePeriod = viewer.__cdmGraceUntil and GetTime() < viewer.__cdmGraceUntil
        if not inGracePeriod then
            if currentBlizzardCount == lastBlizzardLayoutCount and currentVersion == lastSettingsVersion then
                return
            end
        end
        
        if viewer.__cdmGraceUntil and GetTime() >= viewer.__cdmGraceUntil then
            viewer.__cdmGraceUntil = nil
        end
        lastBlizzardLayoutCount = currentBlizzardCount
        
        local icons = CollectIcons(viewer)
        local count = #icons
        
        local needsLayout = false
        
        if count ~= lastIconCount or currentVersion ~= lastSettingsVersion then
            needsLayout = true
        end
        
        if not needsLayout and count > 0 then
            local firstIcon = icons[1]
            if firstIcon then
                local point = firstIcon:GetPoint(1)
                if point and point ~= "CENTER" then
                    needsLayout = true
                end
            end
        end
        
        if needsLayout then
            lastIconCount = count
            lastSettingsVersion = currentVersion
            LayoutViewer(viewerName, trackerKey)
        end
    end)
    
    if viewer:IsShown() then
        updateFrame:Show()
    else
        updateFrame:Hide()
    end
    
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    eventFrame:SetScript("OnEvent", function()
        if not module:IsEnabled() then return end
        if InCombatLockdown() then return end
        if viewer:IsShown() then
            viewer.__cdmEventFired = true
        end
    end)
    
    C_Timer.After(0.02, function()
        if module:IsEnabled() and viewer:IsShown() then
            LayoutViewer(viewerName, trackerKey)
        end
    end)
end

local function Initialize()
    if not module:IsEnabled() then return end
    if CDM.initialized then return end
    CDM.initialized = true
    
    if _G[VIEWER_ESSENTIAL] then
        HookViewer(VIEWER_ESSENTIAL, "essential")
    end
    
    if _G[VIEWER_UTILITY] then
        HookViewer(VIEWER_UTILITY, "utility")
    end
    
    if module.RegisterAnchors then
        module.RegisterAnchors()
    end
    
    C_Timer.After(0.5, function()
        if module:IsEnabled() then
            if module.ApplyEssentialAnchor then module.ApplyEssentialAnchor() end
            if module.ApplyUtilityAnchor then module.ApplyUtilityAnchor() end
        end
    end)
end

function module:OnInitialize()
    pcall(function() SetCVar("cooldownViewerEnabled", 1) end)
    self:RegisterMessage("TavernUI_ProfileChanged", "OnProfileChanged")
end

function module:OnEnable()
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        self.eventFrame:RegisterEvent("PLAYER_LOGIN")
        self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        self.eventFrame:SetScript("OnEvent", function(frame, event, ...)
            if not module:IsEnabled() then return end
            
            if event == "PLAYER_LOGIN" then
                C_Timer.After(0.3, Initialize)
            elseif event == "PLAYER_ENTERING_WORLD" then
                local isLogin, isReload = ...
                if not isLogin and not isReload then
                    for _, viewerName in ipairs({VIEWER_ESSENTIAL, VIEWER_UTILITY}) do
                        local viewer = _G[viewerName]
                        if viewer then
                            viewer.__cdmGraceUntil = GetTime() + 2.0
                        end
                    end
                    C_Timer.After(0.3, function()
                        if module:IsEnabled() then
                            module:RefreshAll()
                        end
                    end)
                end
            end
        end)
    end
    
    if _G.EditModeManagerFrame and not CDM.editModeHooked then
        _G.EditModeManagerFrame:HookScript("OnHide", function()
            if module:IsEnabled() then
                C_Timer.After(0.5, function()
                    if not module:IsEnabled() or (module.IsEditModeActive and module.IsEditModeActive()) then return end
                    
                    if module.SaveEssentialPosition then module.SaveEssentialPosition() end
                    if module.SaveUtilityPosition then module.SaveUtilityPosition() end
                    
                    C_Timer.After(0.1, function()
                        if not module:IsEnabled() or (module.IsEditModeActive and module.IsEditModeActive()) then return end
                        if module.ApplyEssentialAnchor then module.ApplyEssentialAnchor() end
                        if module.ApplyUtilityAnchor then module.ApplyUtilityAnchor() end
                    end)
                end)
            end
        end)
        CDM.editModeHooked = true
    end
    
    C_Timer.After(0.5, function()
        if module:IsEnabled() then
            local essentialViewer = _G[VIEWER_ESSENTIAL]
            local utilityViewer = _G[VIEWER_UTILITY]
            
            if essentialViewer and module.HookViewerForEditMode then
                module.HookViewerForEditMode(VIEWER_ESSENTIAL, essentialViewer)
            end
            if utilityViewer and module.HookViewerForEditMode then
                module.HookViewerForEditMode(VIEWER_UTILITY, utilityViewer)
            end
        end
    end)
    
    C_Timer.After(0, function()
        if module:IsEnabled() and (_G[VIEWER_ESSENTIAL] or _G[VIEWER_UTILITY]) then
            Initialize()
        end
    end)
end

function module:OnDisable()
    CDM.initialized = false
    
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
        self.eventFrame:SetScript("OnEvent", nil)
    end
    
    for _, viewerName in ipairs({VIEWER_ESSENTIAL, VIEWER_UTILITY}) do
        local viewer = _G[viewerName]
        if viewer then
            if viewer.__cdmUpdateFrame then
                viewer.__cdmUpdateFrame:Hide()
                viewer.__cdmUpdateFrame:SetScript("OnUpdate", nil)
            end
        end
    end
    
    if Anchor then
        Anchor:Unregister("TavernUI.CDM.Essential")
        Anchor:Unregister("TavernUI.CDM.Utility")
    end
    
    if CDM.anchorHandles.utility then
        CDM.anchorHandles.utility:Release()
        CDM.anchorHandles.utility = nil
    end
    
    if CDM.anchorHandles.essential then
        CDM.anchorHandles.essential:Release()
        CDM.anchorHandles.essential = nil
    end
    
    for trackerKey in pairs(CDM.hooked) do
        CDM.hooked[trackerKey] = nil
    end
    
    CDM.applying.essential = false
    CDM.applying.utility = false
    
    if CDM.anchorTimers then
        if CDM.anchorTimers.essential then
            CDM.anchorTimers.essential:Cancel()
            CDM.anchorTimers.essential = nil
        end
        if CDM.anchorTimers.utility then
            CDM.anchorTimers.utility:Cancel()
            CDM.anchorTimers.utility = nil
        end
    end
    
    if CDM.applyingAnchors then
        CDM.applyingAnchors.essential = nil
        CDM.applyingAnchors.utility = nil
    end
end

function module:OnProfileChanged()
    if self:IsEnabled() then
        IncrementSettingsVersion()
        self:RefreshAll()
    end
end

function module:RefreshAll()
    if not self:IsEnabled() then return end
    
    CDM.applying.essential = false
    CDM.applying.utility = false
    IncrementSettingsVersion()
    C_Timer.After(0.01, function()
        if module:IsEnabled() then
            LayoutViewer(VIEWER_ESSENTIAL, "essential")
            LayoutViewer(VIEWER_UTILITY, "utility")
        end
    end)
end
