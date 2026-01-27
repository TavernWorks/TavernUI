-- TavernUI CDM Module
-- Core layout engine for cooldown viewers

local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:NewModule("CDM", "AceEvent-3.0")

local defaults = {
    essential = {
        enabled = true,
        anchorConfig = nil,
        showKeybinds = false,
        keybindSize = 10,
        keybindPoint = "TOPLEFT",
        keybindOffsetX = 2,
        keybindOffsetY = -2,
        keybindColor = {r = 1, g = 1, b = 1, a = 1},
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
        showKeybinds = false,
        keybindSize = 10,
        keybindPoint = "TOPLEFT",
        keybindOffsetX = 2,
        keybindOffsetY = -2,
        keybindColor = {r = 1, g = 1, b = 1, a = 1},
        rows = {
            {iconCount = 6, iconSize = 42, padding = -8, yOffset = 0, aspectRatioCrop = 1.0, zoom = 0, iconBorderSize = 0, iconBorderColor = {r = 0, g = 0, b = 0, a = 1}, rowBorderSize = 0, rowBorderColor = {r = 0, g = 0, b = 0, a = 1}, durationSize = 18, durationPoint = "CENTER", durationOffsetX = 0, durationOffsetY = 0, stackSize = 16, stackPoint = "BOTTOMRIGHT", stackOffsetX = 0, stackOffsetY = 0},
        }
    },
    buff = {
        enabled = true,
        anchorConfig = nil,
        showKeybinds = false,
        keybindSize = 10,
        keybindPoint = "TOPLEFT",
        keybindOffsetX = 2,
        keybindOffsetY = -2,
        keybindColor = {r = 1, g = 1, b = 1, a = 1},
        rows = {
            {iconCount = 6, iconSize = 42, padding = -8, yOffset = 0, aspectRatioCrop = 1.0, zoom = 0, iconBorderSize = 0, iconBorderColor = {r = 0, g = 0, b = 0, a = 1}, rowBorderSize = 0, rowBorderColor = {r = 0, g = 0, b = 0, a = 1}, durationSize = 18, durationPoint = "CENTER", durationOffsetX = 0, durationOffsetY = 0, stackSize = 16, stackPoint = "BOTTOMRIGHT", stackOffsetX = 0, stackOffsetY = 0},
        }
    },
}

TavernUI:RegisterModuleDefaults("CDM", defaults, true)

module.VIEWER_ESSENTIAL = "EssentialCooldownViewer"
module.VIEWER_UTILITY = "UtilityCooldownViewer"
module.VIEWER_BUFF = "BuffIconCooldownViewer"

local VIEWERS = {
    {name = module.VIEWER_ESSENTIAL, key = "essential"},
    {name = module.VIEWER_UTILITY, key = "utility"},
    {name = module.VIEWER_BUFF, key = "buff"},
}

local CDM = {
    frameData = {},
    applying = {},
    settingsVersion = {},
    hooked = {},
    initialized = false,
    refreshing = false,
    refreshTimer = nil,
}

module.CDM = CDM

local function GetSettings(key)
    local db = module:GetDB()
    return db and db[key]
end

module.GetSettings = GetSettings

local LayoutViewer

local function IsIcon(child)
    if not child then return false end
    return (child.Icon or child.icon) and (child.Cooldown or child.cooldown)
end

local function CollectIcons(viewer)
    local icons = {}
    if not viewer or not viewer.GetNumChildren then return icons end
    
    local numChildren = viewer:GetNumChildren()
    local viewerName = viewer:GetName() or "unknown"
    local isBuff = viewerName == module.VIEWER_BUFF
    
    for i = 1, numChildren do
        local child = select(i, viewer:GetChildren())
        
        if child and child ~= viewer.Selection and IsIcon(child) then
            if isBuff then
                if not child.__cdmEventHooked then
                    child.__cdmEventHooked = true
                    local buffViewer = viewer
                    local buffViewerName = viewerName
                    
                    local function TriggerLayout()
                        if module:IsEnabled() and buffViewer:IsShown() then
                            C_Timer.After(0.1, function()
                                if module:IsEnabled() and buffViewer:IsShown() then
                                    LayoutViewer(buffViewerName, "buff")
                                end
                            end)
                        end
                    end
                    
                    if child.OnActiveStateChanged then
                        hooksecurefunc(child, "OnActiveStateChanged", TriggerLayout)
                    end
                    if child.OnUnitAuraAddedEvent then
                        hooksecurefunc(child, "OnUnitAuraAddedEvent", TriggerLayout)
                    end
                    if child.OnUnitAuraRemovedEvent then
                        hooksecurefunc(child, "OnUnitAuraRemovedEvent", TriggerLayout)
                    end
                    
                    child:HookScript("OnShow", function()
                        TriggerLayout()
                    end)
                    
                    child:HookScript("OnHide", function()
                        TriggerLayout()
                    end)
                end
                
                if not child.originalX then
                    local point, relativeTo, relativePoint, x, y = child:GetPoint(1)
                    child.originalX = x or 0
                    child.originalY = y or 0
                end
                table.insert(icons, child)
            else
                if child:IsShown() or child.__cdmHidden then
                    table.insert(icons, child)
                end
            end
        end
    end
    
    if isBuff then
        table.sort(icons, function(a, b)
            local indexA = a.layoutIndex
            local indexB = b.layoutIndex
            
            if indexA and indexB then
                return indexA < indexB
            elseif indexA then
                return true
            elseif indexB then
                return false
            end
            
            if math.abs((a.originalY or 0) - (b.originalY or 0)) < 1 then
                return (a.originalX or 0) < (b.originalX or 0)
            end
            return (a.originalY or 0) > (b.originalY or 0)
        end)
    else
        table.sort(icons, function(a, b)
            local indexA = a.layoutIndex or 9999
            local indexB = b.layoutIndex or 9999
            return indexA < indexB
        end)
    end
    
    return icons
end

local function GetActiveRows(settings)
    local activeRows = {}
    if not settings or not settings.rows then return activeRows end
    
    for _, row in ipairs(settings.rows) do
        if row.iconCount and row.iconCount > 0 then
            table.insert(activeRows, row)
        end
    end
    
    return activeRows
end

local function GetCapacity(settings)
    local total = 0
    if not settings or not settings.rows then return total end
    
    for _, row in ipairs(settings.rows) do
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

module.GetFrameData = GetFrameData

local function SetupIconOnce(icon)
    if not icon or icon.__cdmSetup then return end
    icon.__cdmSetup = true
    
    local textures = { icon.Icon, icon.icon }
    for _, tex in ipairs(textures) do
        if tex then
            if tex.GetMaskTexture and tex.RemoveMaskTexture then
                for i = 1, 10 do
                    local mask = tex:GetMaskTexture(i)
                    if mask then
                        tex:RemoveMaskTexture(mask)
                    end
                end
            end
            if tex.ClearAllPoints then
                tex:ClearAllPoints()
            end
            if tex.SetAllPoints then
                tex:SetAllPoints(icon)
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
    if not tex then
        for i = 1, icon:GetNumRegions() do
            local region = select(i, icon:GetRegions())
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                local regionName = region:GetName()
                if not regionName or (regionName ~= "Border" and regionName ~= "Cooldown" and regionName ~= "NormalTexture") then
                    tex = region
                    break
                end
            end
        end
    end
    if tex and tex.SetTexCoord then
        tex:SetTexCoord(left, right, top, bottom)
    end
end

local function ResizeBlizzardBorders(icon)
    if not icon then return end
    
    local iconTexture = icon.Icon or icon.icon
    if not iconTexture then return end
    
    if iconTexture.GetMaskTexture then
        for i = 1, 10 do
            local mask = iconTexture:GetMaskTexture(i)
            if mask then
                mask:SetAllPoints(iconTexture)
            end
        end
    end
    
    if icon.GetNumChildren then
        for i = 1, icon:GetNumChildren() do
            local child = select(i, icon:GetChildren())
            if child then
                local childName = child:GetName()
                
                if childName == "DebuffBorder" then
                    local point, relativeTo = child:GetPoint(1)
                    if not point or (relativeTo and relativeTo ~= iconTexture) then
                        child:ClearAllPoints()
                        child:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", -3, 3)
                        child:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", 3, -3)
                    end
                    if child.Texture then
                        child.Texture:SetAllPoints(child)
                    end
                elseif childName == "PandemicIcon" then
                    if child.Border then
                        child.Border:SetAllPoints(child)
                        if child.Border.Border then
                            child.Border.Border:SetAllPoints(child.Border)
                        end
                    end
                    if child.FX then
                        child.FX:SetAllPoints(child)
                        if child.FX.Mask then
                            child.FX.Mask:SetAllPoints(child.FX)
                        end
                    end
                end
            end
        end
    end
    
    if icon.DebuffBorder then
        local borderFrame = icon.DebuffBorder
        if borderFrame.Texture then
            borderFrame.Texture:SetAllPoints(borderFrame)
        end
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

local FONT_PATH = "Fonts\\FRIZQT__.TTF"

local function SetFontStringPoint(fs, point, relativeTo, relativePoint, offsetX, offsetY)
    if not fs or not fs.SetFont then return end
    pcall(function()
        fs:ClearAllPoints()
        fs:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)
    end)
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
    
    if durationSize > 0 then
        local cooldown = icon.Cooldown or icon.cooldown
        if cooldown then
            if cooldown.text then
                cooldown.text:SetFont(FONT_PATH, durationSize, "OUTLINE")
                SetFontStringPoint(cooldown.text, durationPoint, icon, durationPoint, durationOffsetX, durationOffsetY)
            end
            local ok, regions = pcall(function() return { cooldown:GetRegions() } end)
            if ok and regions then
                for _, region in ipairs(regions) do
                    if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                        region:SetFont(FONT_PATH, durationSize, "OUTLINE")
                        SetFontStringPoint(region, durationPoint, icon, durationPoint, durationOffsetX, durationOffsetY)
                    end
                end
            end
        end
    end
    
    if stackSize > 0 then
        local chargeFrame = icon.ChargeCount
        if chargeFrame then
            local fs = chargeFrame.Current or chargeFrame.Count or chargeFrame.count
            if fs then
                fs:SetFont(FONT_PATH, stackSize, "OUTLINE")
                SetFontStringPoint(fs, stackPoint, icon, stackPoint, stackOffsetX, stackOffsetY)
            end
        end
        
        local countText = icon.Count or icon.count
        if countText then
            countText:SetFont(FONT_PATH, stackSize, "OUTLINE")
            SetFontStringPoint(countText, stackPoint, icon, stackPoint, stackOffsetX, stackOffsetY)
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
    
    ResizeBlizzardBorders(icon)
    ApplyTexCoord(icon, aspectRatioCrop, zoom)
    ApplyIconBorder(icon, iconBorderSize, iconBorderColor)
    ApplyIconTextSettings(icon, rowConfig)
end

local function ApplyRowBorder(viewer, rowNum, rowConfig, rowWidth, rowHeight, rowCenterX, rowCenterY)
    if not viewer or not rowConfig then return end
    
    local rowBorderSize = rowConfig.rowBorderSize or 0
    local borderKey = "__cdmRowBorder" .. rowNum
    
    if rowBorderSize <= 0 then
        if viewer[borderKey] then
            viewer[borderKey]:Hide()
        end
        return
    end
    
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

local function IncrementSettingsVersion(trackerKey)
    if trackerKey then
        CDM.settingsVersion[trackerKey] = (CDM.settingsVersion[trackerKey] or 0) + 1
    else
        CDM.settingsVersion.essential = (CDM.settingsVersion.essential or 0) + 1
        CDM.settingsVersion.utility = (CDM.settingsVersion.utility or 0) + 1
        CDM.settingsVersion.buff = (CDM.settingsVersion.buff or 0) + 1
    end
end

local function BuildRowConfigs(activeRows, iconsToLayout)
    local rowConfigs = {}
    
    for _, row in ipairs(activeRows) do
        local maxIconsForRow = row.iconCount
        
        table.insert(rowConfigs, {
            count = row.iconCount,
            size = row.iconSize or 50,
            padding = row.padding or 0,
            yOffset = row.yOffset or 0,
            maxIconsForRow = maxIconsForRow,
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
    end
    
    return rowConfigs
end

local function CalculateRowDimensions(rowConfigs)
    local maxRowWidth = 0
    local totalHeight = 0
    local rowWidths = {}
    local rowGap = 5
    
    for rowNum, rowConfig in ipairs(rowConfigs) do
        local maxIconsForRow = rowConfig.maxIconsForRow
        local iconSize = rowConfig.size
        local aspectRatio = rowConfig.aspectRatioCrop or 1.0
        local iconHeight = iconSize / aspectRatio
        
        local rowWidth = (maxIconsForRow * iconSize) + ((maxIconsForRow - 1) * rowConfig.padding)
        rowWidths[rowNum] = rowWidth
        maxRowWidth = math.max(maxRowWidth, rowWidth)
        
        totalHeight = totalHeight + iconHeight
        if rowNum > 1 then
            totalHeight = totalHeight + rowGap
        end
    end
    
    return maxRowWidth, totalHeight, rowWidths, rowGap
end

local function LayoutIcons(viewer, iconsToLayout, rowConfigs, rowWidths, rowGap, totalHeight, trackerKey)
    local currentY = totalHeight / 2
    
    local slotStart = 1
    for rowNum, rowConfig in ipairs(rowConfigs) do
        local stride = rowConfig.maxIconsForRow
        local iconSize = rowConfig.size
        local aspectRatio = rowConfig.aspectRatioCrop or 1.0
        local iconHeight = iconSize / aspectRatio
        
        local slotEnd = slotStart + stride - 1
        local iconsInThisRow = {}
        
        if trackerKey == "buff" then
            for _, icon in ipairs(iconsToLayout) do
                local slot = icon.__cdmSlot
                if slot and slot >= slotStart and slot <= slotEnd then
                    table.insert(iconsInThisRow, icon)
                end
            end
            
            table.sort(iconsInThisRow, function(a, b)
                return (a.__cdmSlot or 9999) < (b.__cdmSlot or 9999)
            end)
        else
            local rowStartIndex = slotStart
            local rowEndIndex = math.min(slotStart + stride - 1, #iconsToLayout)
            
            for i = rowStartIndex, rowEndIndex do
                if iconsToLayout[i] then
                    table.insert(iconsInThisRow, iconsToLayout[i])
                end
            end
        end
        
        slotStart = slotEnd + 1
        
        local actualIconsInRow = #iconsInThisRow
        local rowCenterY = currentY - (iconHeight / 2) + rowConfig.yOffset
        
        if actualIconsInRow > 0 then
            local rowWidth = actualIconsInRow * iconSize + (actualIconsInRow - 1) * rowConfig.padding
            local totalWidth = rowWidth
            local startX = -totalWidth / 2 + iconSize / 2
            
            for col, icon in ipairs(iconsInThisRow) do
                local iconOffsetX = startX + (col - 1) * (iconSize + rowConfig.padding)
                
                pcall(function()
                    StyleIcon(icon, rowConfig)
                    icon:ClearAllPoints()
                    icon:SetPoint("CENTER", viewer, "CENTER", iconOffsetX, rowCenterY)
                end)
                
                if module.ApplyKeybindToIcon then
                    pcall(function() module.ApplyKeybindToIcon(icon, viewer:GetName()) end)
                end
                
                icon:Show()
            end
            
            pcall(function()
                ApplyRowBorder(viewer, rowNum, rowConfig, rowWidth, iconHeight, 0, rowCenterY)
            end)
        end
        
        currentY = currentY - iconHeight - rowGap
    end
end

LayoutViewer = function(viewerName, trackerKey)
    if not module:IsEnabled() then
        return
    end
    
    local viewer = _G[viewerName]
    if not viewer then
        return
    end
    
    local settings = GetSettings(trackerKey)
    if not settings then
        return
    end
    if not settings.enabled then
        return
    end
    
    if CDM.applying[trackerKey] or viewer.__cdmLayoutRunning or CDM.refreshing then return end
    
    CDM.applying[trackerKey] = true
    viewer.__cdmLayoutRunning = true
    
    if viewer.__cdmSizeChangeTimer then
        viewer.__cdmSizeChangeTimer:Cancel()
        viewer.__cdmSizeChangeTimer = nil
    end
    
    local activeRows = GetActiveRows(settings)
    local capacity = GetCapacity(settings)
    
    if #activeRows == 0 then
        CDM.applying[trackerKey] = false
        viewer.__cdmLayoutRunning = nil
        viewer.__cdmLayoutSuppressed = nil
        return
    end
    
    local allIcons = CollectIcons(viewer)
    
    local iconsToLayout = {}
    if trackerKey == "buff" then
        for i = 1, #allIcons do
            if allIcons[i] then
                local icon = allIcons[i]
                local slot = icon.layoutIndex
                if not slot or slot < 1 then
                    slot = i
                end
                icon.__cdmSlot = slot
                
                local isShown = icon:IsShown()
                
                if slot <= capacity then
                    if isShown then
                        iconsToLayout[#iconsToLayout + 1] = icon
                        icon.__cdmHidden = nil
                    else
                        icon:Hide()
                        icon.__cdmHidden = true
                        pcall(function() icon:ClearAllPoints() end)
                    end
                else
                    icon:Hide()
                    icon.__cdmHidden = true
                    pcall(function() icon:ClearAllPoints() end)
                end
            end
        end
    else
        for i = 1, math.min(#allIcons, capacity) do
            if allIcons[i] then
                iconsToLayout[#iconsToLayout + 1] = allIcons[i]
                allIcons[i]:Show()
                allIcons[i].__cdmHidden = nil
            end
        end
        
        for i = capacity + 1, #allIcons do
            if allIcons[i] then
                allIcons[i]:Hide()
                allIcons[i].__cdmHidden = true
                pcall(function() allIcons[i]:ClearAllPoints() end)
            end
        end
    end
    
    if #iconsToLayout == 0 then
        CDM.applying[trackerKey] = false
        viewer.__cdmLayoutRunning = nil
        viewer.__cdmLayoutSuppressed = nil
        return
    end
    
    local rowConfigs = BuildRowConfigs(activeRows, iconsToLayout)
    local maxRowWidth, totalHeight, rowWidths, rowGap = CalculateRowDimensions(rowConfigs)
    
    LayoutIcons(viewer, iconsToLayout, rowConfigs, rowWidths, rowGap, totalHeight, trackerKey)
    
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
    
    if module.ApplyAnchorsAfterLayout then
        module.ApplyAnchorsAfterLayout(trackerKey)
    end
end

local function ScheduleLayoutCheck(viewer, viewerName, trackerKey, immediate)
    if viewer.__cdmTimer then
        viewer.__cdmTimer:Cancel()
        viewer.__cdmTimer = nil
    end
    
    if not viewer:IsShown() or not module:IsEnabled() then
        return
    end
    
    local delay = immediate and 0 or (UnitAffectingCombat("player") and 1.0 or 0.5)
    
    viewer.__cdmTimer = C_Timer.NewTimer(delay, function()
        viewer.__cdmTimer = nil
        
        if not module:IsEnabled() or not viewer:IsShown() then
            return
        end
        
        if CDM.applying[trackerKey] then
            ScheduleLayoutCheck(viewer, viewerName, trackerKey, false)
            return
        end
        
        if InCombatLockdown() then
            ScheduleLayoutCheck(viewer, viewerName, trackerKey, false)
            return
        end
        
        local currentBlizzardCount = viewer.__cdmBlizzardCount or 0
        local currentVersion = CDM.settingsVersion[trackerKey] or 0
        local lastBlizzardCount = viewer.__cdmLastBlizzardCount or 0
        local lastVersion = viewer.__cdmLastVersion or 0
        
        local inGracePeriod = viewer.__cdmGraceUntil and GetTime() < viewer.__cdmGraceUntil
        if not inGracePeriod then
            if currentBlizzardCount == lastBlizzardCount and currentVersion == lastVersion then
                ScheduleLayoutCheck(viewer, viewerName, trackerKey, false)
                return
            end
        end
        
        if viewer.__cdmGraceUntil and GetTime() >= viewer.__cdmGraceUntil then
            viewer.__cdmGraceUntil = nil
        end
        
        viewer.__cdmLastBlizzardCount = currentBlizzardCount
        viewer.__cdmLastVersion = currentVersion
        
        local icons = CollectIcons(viewer)
        local count = #icons
        local lastCount = viewer.__cdmLastIconCount or 0
        
        local needsLayout = false
        
        if count ~= lastCount or currentVersion ~= lastVersion then
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
            viewer.__cdmLastIconCount = count
            if not CDM.applying[trackerKey] and not viewer.__cdmLayoutRunning then
                LayoutViewer(viewerName, trackerKey)
            end
        end
        
        ScheduleLayoutCheck(viewer, viewerName, trackerKey, false)
    end)
end


local function HookViewer(viewerName, trackerKey)
    local viewer = _G[viewerName]
    if not viewer then
        return
    end
    if CDM.hooked[trackerKey] then
        return
    end
    
    CDM.hooked[trackerKey] = true
    
    viewer:HookScript("OnShow", function(self)
        if not module:IsEnabled() then return end
        ScheduleLayoutCheck(self, viewerName, trackerKey, true)
        C_Timer.After(0.02, function()
            if module:IsEnabled() and self:IsShown() then
                LayoutViewer(viewerName, trackerKey)
            end
        end)
    end)
    
    viewer:HookScript("OnHide", function(self)
        if self.__cdmTimer then
            self.__cdmTimer:Cancel()
            self.__cdmTimer = nil
        end
    end)
    
    viewer:HookScript("OnSizeChanged", function(self)
        if not module:IsEnabled() then return end
        if CDM.applying[trackerKey] or self.__cdmLayoutRunning or CDM.refreshing then return end
        self.__cdmBlizzardCount = (self.__cdmBlizzardCount or 0) + 1
        if self.__cdmLayoutSuppressed then
            return
        end
        
        if self.__cdmSizeChangeTimer then
            self.__cdmSizeChangeTimer:Cancel()
            self.__cdmSizeChangeTimer = nil
        end
        
        self.__cdmSizeChangeTimer = C_Timer.NewTimer(0.1, function()
            self.__cdmSizeChangeTimer = nil
            if module:IsEnabled() and not CDM.applying[trackerKey] and not self.__cdmLayoutRunning and not CDM.refreshing then
                LayoutViewer(viewerName, trackerKey)
            end
        end)
    end)
    
    if trackerKey == "buff" then
        local eventFrame = CreateFrame("Frame")
        eventFrame:RegisterUnitEvent("UNIT_TARGET", "player")
        
        eventFrame:SetScript("OnEvent", function(self, event, unit)
            if not module:IsEnabled() then return end
            
            if event == "UNIT_TARGET" and unit == "player" then
                if viewer:IsShown() then
                    C_Timer.After(0.1, function()
                        if module:IsEnabled() and viewer:IsShown() then
                            LayoutViewer(viewerName, trackerKey)
                        end
                    end)
                end
            end
        end)
    elseif trackerKey ~= "buff" then
        local eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
        eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
        
        eventFrame:SetScript("OnEvent", function(self, event)
            if not module:IsEnabled() then return end
            if InCombatLockdown() then return end
            
            if viewer:IsShown() then
                ScheduleLayoutCheck(viewer, viewerName, trackerKey, true)
            end
        end)
    end
    
    if viewer:IsShown() then
        ScheduleLayoutCheck(viewer, viewerName, trackerKey, false)
    end
    
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
    
    for _, viewerInfo in ipairs(VIEWERS) do
        local viewer = _G[viewerInfo.name]
        if viewer then
            HookViewer(viewerInfo.name, viewerInfo.key)
        end
    end
    
    if module.RegisterAnchors then
        module.RegisterAnchors()
    end
    
    C_Timer.After(0.5, function()
        if module:IsEnabled() then
            if module.ApplyEssentialAnchor then module.ApplyEssentialAnchor() end
            if module.ApplyUtilityAnchor then module.ApplyUtilityAnchor() end
            if module.ApplyBuffAnchor then module.ApplyBuffAnchor() end
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
        self.eventFrame:RegisterEvent("ADDON_LOADED")
        self.eventFrame:SetScript("OnEvent", function(frame, event, ...)
            if not module:IsEnabled() then return end
            
            if event == "ADDON_LOADED" then
                local addonName = ...
                if addonName == "Blizzard_CooldownManager" then
                end
            elseif event == "PLAYER_LOGIN" then
                C_Timer.After(0.3, Initialize)
            elseif event == "PLAYER_ENTERING_WORLD" then
                local isLogin, isReload = ...
                if not isLogin and not isReload then
                    for _, viewerInfo in ipairs(VIEWERS) do
                        local viewer = _G[viewerInfo.name]
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
    
    if module.InitializeEditMode then
        module.InitializeEditMode()
    end
    
    C_Timer.After(0, function()
        if module:IsEnabled() then
            local hasViewer = false
            for _, viewerInfo in ipairs(VIEWERS) do
                if _G[viewerInfo.name] then
                    hasViewer = true
                    break
                end
            end
            if hasViewer then
                Initialize()
            end
        end
    end)
end

function module:OnDisable()
    CDM.initialized = false
    
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
        self.eventFrame:SetScript("OnEvent", nil)
    end
    
    for _, viewerInfo in ipairs(VIEWERS) do
        local viewer = _G[viewerInfo.name]
        if viewer and viewer.__cdmTimer then
            viewer.__cdmTimer:Cancel()
            viewer.__cdmTimer = nil
        end
    end
    
    if module.CleanupAnchors then
        module.CleanupAnchors()
    end
    
    for trackerKey in pairs(CDM.hooked) do
        CDM.hooked[trackerKey] = nil
    end
    
    CDM.applying.essential = false
    CDM.applying.utility = false
    CDM.applying.buff = false
end

function module:OnProfileChanged()
    if self:IsEnabled() then
        IncrementSettingsVersion()
        self:RefreshAll()
    end
end

function module:RefreshAll()
    if not self:IsEnabled() then return end
    if CDM.refreshing then return end
    
    CDM.refreshing = true
    
    if CDM.refreshTimer then
        CDM.refreshTimer:Cancel()
        CDM.refreshTimer = nil
    end
    
    CDM.refreshTimer = C_Timer.NewTimer(0.1, function()
        CDM.refreshTimer = nil
        CDM.refreshing = false
        
        if not module:IsEnabled() then return end
        
        IncrementSettingsVersion()
        
        C_Timer.After(0.05, function()
            if not module:IsEnabled() then return end
            
            for _, viewerInfo in ipairs(VIEWERS) do
                local viewer = _G[viewerInfo.name]
                if viewer and not CDM.applying[viewerInfo.key] and not viewer.__cdmLayoutRunning then
                    LayoutViewer(viewerInfo.name, viewerInfo.key)
                end
            end
            
            if module.UpdateAllKeybinds then
                module.UpdateAllKeybinds()
            end
        end)
    end)
end
