local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)
local PP = TavernUI.PixelPerfect

if not module then return end

--[[
    LayoutEngine - Positions items and applies per-row styling
    
    This is now much simpler because:
    1. ItemRegistry provides the items
    2. Each CooldownItem styles itself
    3. LayoutEngine just handles positioning and row assignment
]]

local LayoutEngine = {}

local CONSTANTS = {
    DEFAULT_ROW_GAP = 5,
    DEFAULT_ICON_BORDER_COLOR = {r = 0, g = 0, b = 0, a = 1},
    DEFAULT_ROW_BORDER_COLOR = {r = 0, g = 0, b = 0, a = 1},
}

local layoutRunning = {}
local layoutSettingSize = {}
local refreshDebounceTimers = {}

local LAYOUT_DEBUG = false
local function LayoutDebug(fmt, ...)
    if LAYOUT_DEBUG and (fmt ~= nil) then
        print("[uCDM Layout]", string.format(tostring(fmt), ...))
    end
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

local function InstallRefreshLayoutHooks()
    local names = module.CONSTANTS.VIEWER_NAMES
    for viewerKey, globalName in pairs(names) do
        if LayoutEngine.IsLayoutDrivenByBlizzardHook(viewerKey) then
            local viewer = _G[globalName]
            if viewer then
                if viewer.RefreshLayout then
                    hooksecurefunc(viewer, "RefreshLayout", function()
                        if not module:IsEnabled() then return end
                        if module.ItemRegistry then
                            module.ItemRegistry.CollectBlizzardItems(viewerKey)
                        end
                        LayoutEngine.RefreshViewer(viewerKey)
                        if module.Keybinds then
                            module.Keybinds.RefreshViewer(viewerKey)
                        end
                    end)
                end
                
                viewer:HookScript("OnShow", function()
                    if not module:IsEnabled() then return end
                    LayoutEngine.ApplyVisibilityToViewer(viewerKey, false)
                end)
            end
        end
    end
end

function LayoutEngine.Initialize()
    layoutRunning = {}

    InstallRefreshLayoutHooks()

    for _, viewerKey in ipairs(module.CONSTANTS.VIEWER_KEYS) do
        module:WatchSetting(string.format("viewers.%s.enabled", viewerKey), function(newValue)
            local viewer = module:GetViewerFrame(viewerKey)
            if viewer then
                if newValue then
                    LayoutEngine.RefreshViewer(viewerKey)
                else
                    viewer:Hide()
                end
            end
        end)
        
        module:WatchSetting(string.format("viewers.%s.rowGrowDirection", viewerKey), function()
            if module:IsEnabled() then
                LayoutEngine.RefreshViewer(viewerKey)
            end
        end)
        module:WatchSetting(string.format("viewers.%s.rowSpacing", viewerKey), function()
            if module:IsEnabled() then
                LayoutEngine.RefreshViewer(viewerKey)
            end
        end)
    end

    module:WatchSetting("viewers.buff.showPreview", function()
        if module:IsEnabled() then
            LayoutEngine.RefreshViewer("buff")
        end
    end)
    module:WatchSetting("viewers.buff.previewIconCount", function()
        if module:IsEnabled() then
            LayoutEngine.RefreshViewer("buff")
        end
    end)
end

--------------------------------------------------------------------------------
-- Viewer Access
--------------------------------------------------------------------------------


function LayoutEngine.IsLayoutDrivenByBlizzardHook(viewerKey)
    return viewerKey == "essential" or viewerKey == "utility"
end

function LayoutEngine.IsSettingViewerSize(viewerKey)
    return layoutSettingSize[viewerKey] == true
end

--------------------------------------------------------------------------------
-- Row Configuration
--------------------------------------------------------------------------------

local function GetActiveRows(settings)
    local rows = {}
    if not settings or not settings.rows then return rows end

    -- Scale multiplier for icon dimensions (borders remain pixel-perfect)
    local scale = settings.scale or 1.0

    for _, row in ipairs(settings.rows) do
        if row.iconCount and row.iconCount > 0 then
            rows[#rows + 1] = {
                orientation = row.orientation,
                positionAtSide = row.positionAtSide,
                iconCount = row.iconCount,
                iconSize = (row.iconSize or 50) * scale,
                padding = (row.padding or 0) * scale,
                yOffset = (row.yOffset or 0) * scale,
                aspectRatioCrop = row.aspectRatioCrop or 1.0,
                zoom = row.zoom or 0,
                iconStyle = row.iconStyle or "square",
                iconBorderSize = row.iconBorderSize or 0,  -- NOT scaled - stays pixel-perfect
                iconBorderColor = row.iconBorderColor or CONSTANTS.DEFAULT_ICON_BORDER_COLOR,
                rowBorderSize = row.rowBorderSize or 0,  -- NOT scaled - stays pixel-perfect
                rowBorderColor = row.rowBorderColor or CONSTANTS.DEFAULT_ROW_BORDER_COLOR,
                durationSize = (row.durationSize or 18) * scale,
                durationPoint = row.durationPoint or "CENTER",
                durationOffsetX = (row.durationOffsetX or 0) * scale,
                durationOffsetY = (row.durationOffsetY or 0) * scale,
                stackSize = (row.stackSize or 16) * scale,
                stackPoint = row.stackPoint or "BOTTOMRIGHT",
                stackOffsetX = (row.stackOffsetX or 0) * scale,
                stackOffsetY = (row.stackOffsetY or 0) * scale,
                keepRowHeightWhenEmpty = row.keepRowHeightWhenEmpty ~= false,
            }
        end
    end

    return rows
end

local function GetTotalCapacity(rows)
    local total = 0
    for _, row in ipairs(rows) do
        total = total + row.iconCount
    end
    return total
end

--------------------------------------------------------------------------------
-- Row Assignment
--------------------------------------------------------------------------------

local function AssignItemsToRows(items, rows, viewerKey)
    local rowAssignments = {}
    local capacity = GetTotalCapacity(rows)
    local context = { viewerKey = viewerKey, inCombat = InCombatLockdown() }

    local visibleItems = {}
    for _, item in ipairs(items) do
        if item.enabled ~= false and item.frame and item:isVisible(context) then
            local layoutIdx = item.layoutIndex or item.index or (#visibleItems + 1)
            if layoutIdx <= capacity then
                visibleItems[#visibleItems + 1] = { item = item, layoutIndex = layoutIdx }
            end
        end
    end

    table.sort(visibleItems, function(a, b) return a.layoutIndex < b.layoutIndex end)

    local slotStart = 1
    for rowNum, rowConfig in ipairs(rows) do
        local slotEnd = slotStart + (rowConfig.iconCount or 0) - 1
        rowAssignments[rowNum] = {}

        for _, entry in ipairs(visibleItems) do
            local slot = entry.layoutIndex
            if slot >= slotStart and slot <= slotEnd then
                rowAssignments[rowNum][#rowAssignments[rowNum] + 1] = entry.item
            end
        end

        slotStart = slotEnd + 1
    end

    return rowAssignments, visibleItems
end

local Preview = module.Preview

local function ShouldHideBeforeLayout(viewerKey, viewer, settings)
    if viewerKey ~= "buff" then return false end
    local blizz = _G["BuffIconCooldownViewer"]
    local wantPreview = (settings.showPreview == true) and (settings.previewIconCount or 0) > 0
    return blizz and not blizz:IsShown() and not wantPreview
end

local function WantsPreviewWhenEmpty(viewerKey, settings)
    return viewerKey == "buff"
        and (settings.showPreview == true)
        and (settings.previewIconCount or 0) > 0
end

local function ShouldRunLayoutWithNoItems(viewerKey, settings)
    if WantsPreviewWhenEmpty(viewerKey, settings) then return true end
    return module.IsCustomViewerId and module:IsCustomViewerId(viewerKey)
end

local function HidePreviewIfBuff(viewerKey, viewer)
    if viewerKey == "buff" and Preview and Preview.HidePreviewFrames then
        Preview.HidePreviewFrames(viewer)
    end
end

local function ApplyPostLayout(viewerKey, viewer, visibleItems)
    if viewerKey ~= "buff" or not Preview or not visibleItems[1] then return end
    if Preview.IsPreviewItem and Preview.IsPreviewItem(visibleItems[1].item) then
        if Preview.ApplyPreviewFakeData then
            Preview.ApplyPreviewFakeData(viewer, visibleItems)
        end
    end
end

local function GetRowAssignmentsWithPreview(viewer, viewerKey, settings, items, rows)
    local rowAssignments, visibleItems = AssignItemsToRows(items, rows, viewerKey)
    local showPreview = WantsPreviewWhenEmpty(viewerKey, settings) and #visibleItems == 0

    if showPreview and Preview and Preview.BuildPreviewItems then
        local totalSlots = GetTotalCapacity(rows)
        local count = math.min(settings.previewIconCount or 6, totalSlots)
        local fakeItems = Preview.BuildPreviewItems(viewer, count)
        rowAssignments, visibleItems = AssignItemsToRows(fakeItems, rows, viewerKey)
    else
        HidePreviewIfBuff(viewerKey, viewer)
    end

    return rowAssignments, visibleItems
end

--------------------------------------------------------------------------------
-- Layout Application
--------------------------------------------------------------------------------

local function ApplyRowBorder(viewer, rowNum, rowConfig, rowWidth, rowHeight, rowCenterY, rowCenterX)
    local rawBorderSize = rowConfig.rowBorderSize or 0
    local borderKey = "__ucdmRowBorder" .. rowNum
    
    if rawBorderSize <= 0 then
        if viewer[borderKey] then
            viewer[borderKey]:Hide()
        end
        return
    end
    
    if not viewer[borderKey] then
        viewer[borderKey] = viewer:CreateTexture(nil, "BACKGROUND", nil, -7)
    end
    
    local borderSize = PP.Scale(rawBorderSize, viewer, 0)
    local border = viewer[borderKey]
    local halfWidth = rowWidth / 2
    local halfHeight = rowHeight / 2
    local centerX = PP.SnapPosition(rowCenterX or 0, viewer)
    local centerY = PP.SnapPosition(rowCenterY, viewer)
    local color = rowConfig.rowBorderColor or CONSTANTS.DEFAULT_ROW_BORDER_COLOR
    
    border:SetColorTexture(color.r, color.g, color.b, color.a)
    border:ClearAllPoints()
    local topLeftX = PP.SnapPosition(centerX - halfWidth - borderSize, viewer)
    local topLeftY = PP.SnapPosition(centerY + halfHeight + borderSize, viewer)
    local bottomRightX = PP.SnapPosition(centerX + halfWidth + borderSize, viewer)
    local bottomRightY = PP.SnapPosition(centerY - halfHeight - borderSize, viewer)
    border:SetPoint("TOPLEFT", viewer, "CENTER", topLeftX, topLeftY)
    border:SetPoint("BOTTOMRIGHT", viewer, "CENTER", bottomRightX, bottomRightY)
    border:Show()
end

local function HideAllRowBorders(viewer, rows)
    for rowNum = 1, #rows do
        local borderKey = "__ucdmRowBorder" .. rowNum
        if viewer[borderKey] then
            viewer[borderKey]:Hide()
        end
    end
end

local function BuildRowMetrics(viewer, viewerKey, rowConfig, rowItems)
    local actualIcons = #rowItems
    local keepHeight = rowConfig.keepRowHeightWhenEmpty

    if not (actualIcons > 0 or keepHeight) then
        return nil
    end

    local iconSize = rowConfig.iconSize
    local aspectRatio = rowConfig.aspectRatioCrop
    local iconHeight = iconSize / aspectRatio
    local padding = rowConfig.padding or 0
    local pxIcon = PP.Scale(iconSize, viewer, 0)
    local pxIconH = PP.Scale(iconHeight, viewer, 1)
    local pxPad = PP.Scale(padding, viewer, 0)
    local isCustom = module.IsCustomViewerId and module:IsCustomViewerId(viewerKey)
    local vertical = isCustom and rowConfig.orientation == "vertical"
    local positionAtSide = isCustom and rowConfig.positionAtSide == true

    local count
    if vertical then
        if actualIcons > 0 then
            count = actualIcons
        elseif keepHeight then
            count = rowConfig.iconCount or 0
        else
            count = 0
        end
    else
        count = keepHeight and rowConfig.iconCount or math.max(1, actualIcons)
    end

    if not count or count <= 0 then
        return nil
    end

    local rowWidth, rowHeight
    if vertical then
        rowWidth = pxIcon
        rowHeight = count * pxIconH + (count - 1) * pxPad
    else
        rowWidth = count * pxIcon + (count - 1) * pxPad
        rowHeight = pxIconH
    end

    local actualRowWidth
    if vertical then
        actualRowWidth = pxIcon
    else
        actualRowWidth = actualIcons > 0 and (actualIcons * pxIcon + (actualIcons - 1) * pxPad) or rowWidth
    end

    return {
        vertical = vertical,
        positionAtSide = positionAtSide,
        actualIcons = actualIcons,
        rowWidth = rowWidth,
        actualRowWidth = actualRowWidth,
        rowHeight = rowHeight,
        pxIcon = pxIcon,
        pxIconH = pxIconH,
        pxPad = pxPad,
    }
end

local function LayoutRowItems(viewer, rowItems, rowConfig, metrics, rowCenterY, rowCenterX)
    if metrics.actualIcons <= 0 then
        return
    end

    local pxIcon = metrics.pxIcon
    local pxIconH = metrics.pxIconH
    local pxPad = metrics.pxPad
    local actualIcons = metrics.actualIcons
    rowCenterX = rowCenterX or 0

    for col, item in ipairs(rowItems) do
        local frame = item.frame
        if frame then
            frame:SetParent(viewer)
            frame:SetFrameLevel(viewer:GetFrameLevel() + 3)
            PP.ClearPoints(frame)

            local uX, uY
            if metrics.vertical then
                local actualBlockHeight = actualIcons * pxIconH + (actualIcons - 1) * pxPad
                local startY = rowCenterY + actualBlockHeight / 2 - pxIconH / 2
                uX = PP.SnapPosition(rowCenterX or 0, viewer)
                uY = PP.SnapPosition(startY - (col - 1) * (pxIconH + pxPad), viewer)
            else
                local actualBlockWidth = actualIcons * pxIcon + (actualIcons - 1) * pxPad
                local startX = rowCenterX - actualBlockWidth / 2 + pxIcon / 2
                uX = PP.SnapPosition(startX + (col - 1) * (pxIcon + pxPad), viewer)
                uY = PP.SnapPosition(rowCenterY, viewer)
            end

            frame:SetPoint("CENTER", viewer, "CENTER", uX, uY)
            PP.Size(frame, rowConfig.iconSize, rowConfig.iconSize / rowConfig.aspectRatioCrop)
            item:applyStyle(rowConfig)
            frame:Show()
        end
    end
end

local function ComputeRowPosition(growDirection, rowNum, metrics, currentX, previousActualRowWidth, currentY, currentGroupHeight, rowGap, pxYOffset)
    local rowCenterX = currentX
    local rowCenterY

    if metrics.positionAtSide and rowNum > 1 then
        rowCenterX = currentX + previousActualRowWidth / 2 + rowGap + metrics.actualRowWidth / 2
        rowCenterY = (growDirection == "up")
            and (currentY + currentGroupHeight / 2 + pxYOffset)
            or (currentY - currentGroupHeight / 2 + pxYOffset)
        currentX = rowCenterX
        currentGroupHeight = math.max(currentGroupHeight, metrics.rowHeight)
    else
        if rowNum > 1 then
            if growDirection == "up" then
                currentY = currentY + currentGroupHeight + rowGap
            else
                currentY = currentY - currentGroupHeight - rowGap
            end
        end
        rowCenterY = (growDirection == "up")
            and (currentY + metrics.rowHeight / 2 + pxYOffset)
            or (currentY - metrics.rowHeight / 2 + pxYOffset)
        currentGroupHeight = metrics.rowHeight
    end

    return rowCenterX, rowCenterY, currentX, previousActualRowWidth, currentGroupHeight, currentY
end

local function ApplyLayout(viewer, rowAssignments, rows, viewerKey)
    local settings = module:GetViewerSettings(viewerKey)
    local growDirection = (settings and settings.rowGrowDirection) or "down"
    local scale = (settings and settings.scale) or 1.0
    local rowSpacing = ((settings and settings.rowSpacing ~= nil) and settings.rowSpacing or CONSTANTS.DEFAULT_ROW_GAP) * scale
    local pxRowGap = PP.Scale(rowSpacing, viewer, 1)
    
    HideAllRowBorders(viewer, rows)
    
    local allMetrics = {}
    local maxRowWidth = 0
    local maxActualContentWidth = 0
    local totalHeight = 0
    local currentGroupWidth = 0
    local currentGroupHeight = 0

    for rowNum, rowConfig in ipairs(rows) do
        local rowItems = rowAssignments[rowNum] or {}
        local metrics = BuildRowMetrics(viewer, viewerKey, rowConfig, rowItems)

        if metrics then
            allMetrics[rowNum] = { metrics = metrics, rowItems = rowItems, rowConfig = rowConfig }
            
            if metrics.positionAtSide and rowNum > 1 then
                currentGroupWidth = currentGroupWidth + metrics.rowWidth + pxRowGap
                currentGroupHeight = math.max(currentGroupHeight, metrics.rowHeight)
            else
                if rowNum > 1 then
                    totalHeight = totalHeight + currentGroupHeight + pxRowGap
                    maxRowWidth = math.max(maxRowWidth, currentGroupWidth)
                end
                currentGroupWidth = metrics.rowWidth
                currentGroupHeight = metrics.rowHeight
            end

            if metrics.actualIcons > 0 then
                maxActualContentWidth = math.max(maxActualContentWidth, metrics.actualRowWidth)
            end
        end
    end
    
    if currentGroupWidth > 0 then
        totalHeight = totalHeight + currentGroupHeight
        maxRowWidth = math.max(maxRowWidth, currentGroupWidth)
    end
    
    local effectiveWidth = (maxActualContentWidth > 0) and maxActualContentWidth or maxRowWidth
    if effectiveWidth > 0 and totalHeight > 0 then
        layoutSettingSize[viewerKey] = true
        pcall(function()
            viewer:SetSize(effectiveWidth, totalHeight)
        end)
        layoutSettingSize[viewerKey] = nil
        local Anchor = LibStub("LibAnchorRegistry-1.0", true)
        if Anchor and Anchor.NotifySizeChanged then
            Anchor:NotifySizeChanged("TavernUI.uCDM." .. viewerKey)
        end
    end
    
    local currentY = (growDirection == "up") and (-totalHeight / 2) or (totalHeight / 2)
    local currentX = 0
    local previousActualRowWidth = 0
    currentGroupHeight = 0

    for rowNum, rowData in ipairs(allMetrics) do
        local metrics = rowData.metrics
        local rowItems = rowData.rowItems
        local rowConfig = rowData.rowConfig
        
        local pxYOffset = PP.Scale(rowConfig.yOffset or 0, viewer, 1)
        local rowCenterX, rowCenterY
        rowCenterX, rowCenterY, currentX, previousActualRowWidth, currentGroupHeight, currentY =
            ComputeRowPosition(growDirection, rowNum, metrics, currentX, previousActualRowWidth, currentY, currentGroupHeight, pxRowGap, pxYOffset)

        LayoutRowItems(viewer, rowItems, rowConfig, metrics, rowCenterY, rowCenterX)
        ApplyRowBorder(viewer, rowNum, rowConfig, metrics.rowWidth, metrics.rowHeight, rowCenterY, rowCenterX)

        previousActualRowWidth = metrics.actualRowWidth
    end
end

local function StyleViewerCooldowns(viewerKey)
    local viewerName = module.CONSTANTS.VIEWER_NAMES[viewerKey]
    if not viewerName then return end
    local blizzViewer = _G[viewerName]
    if not blizzViewer or not blizzViewer.GetChildren then return end
    local applySwipe = module.CooldownTracker and module.CooldownTracker.ApplySwipeStyle
    for _, child in ipairs({ blizzViewer:GetChildren() }) do
        local cooldown = child.Cooldown or child.cooldown
        if cooldown and applySwipe then
            applySwipe(cooldown)
        end
    end
end

function LayoutEngine.ApplyVisibilityToViewer(viewerKey, deferInHookContext)
    local viewer = module:GetViewerFrame(viewerKey)
    if not viewer then return end
    local settings = module:GetViewerSettings(viewerKey)
    if not settings or settings.enabled == false then
        viewer:Hide()
        return
    end
    
    local function apply()
        local Visibility = TavernUI and TavernUI.Visibility
        local show = not Visibility or Visibility:ShouldShow()
        local hiddenAlpha = Visibility and Visibility:GetHiddenOpacity() or 0

        if show then
            viewer:Show()
            viewer:SetAlpha(1)
            viewer:SetScript("OnEnter", nil)
            viewer:SetScript("OnLeave", nil)
        else
            local visibleOnHover = Visibility and Visibility:GetVisibleOnHover()
            local alpha = (hiddenAlpha and hiddenAlpha > 0) and hiddenAlpha or 0

            if visibleOnHover and viewer:IsMouseOver() then
                viewer:SetAlpha(1)
            else
                viewer:SetAlpha(alpha)
            end
            if visibleOnHover then
                viewer:SetScript("OnEnter", function()
                    viewer:SetAlpha(1)
                end)
                viewer:SetScript("OnLeave", function()
                    viewer:SetAlpha(alpha)
                end)
            else
                viewer:SetScript("OnEnter", nil)
                viewer:SetScript("OnLeave", nil)
            end
        end
    end
    
    if deferInHookContext then
        C_Timer.After(0, apply)
    else
        apply()
    end
end

--------------------------------------------------------------------------------
-- Main Refresh
--------------------------------------------------------------------------------

function LayoutEngine.RefreshViewer(viewerKey, skipDebounce)
    if layoutRunning[viewerKey] then return end
    
    if viewerKey == "buff" and not skipDebounce then
        if refreshDebounceTimers[viewerKey] then
            return
        end
        refreshDebounceTimers[viewerKey] = C_Timer.After(0.1, function()
            refreshDebounceTimers[viewerKey] = nil
        end)
    end
    
    layoutRunning[viewerKey] = true
    local function done()
        layoutRunning[viewerKey] = nil
    end

    local viewer = module:GetViewerFrame(viewerKey)
    if not viewer then
        done()
        return
    end

    local settings = module:GetViewerSettings(viewerKey)
    if not settings or settings.enabled == false then
        viewer:Hide()
        done()
        return
    end

    if ShouldHideBeforeLayout(viewerKey, viewer, settings) then
        viewer:Hide()
        HidePreviewIfBuff(viewerKey, viewer)
        done()
        return
    end

    local Visibility = TavernUI and TavernUI.Visibility
    local shouldShow = not Visibility or Visibility:ShouldShow()
    local hiddenAlpha = Visibility and Visibility:GetHiddenOpacity() or 0

    if shouldShow then
        viewer:SetAlpha(1)
    else
        viewer:SetAlpha((hiddenAlpha > 0) and hiddenAlpha or 0)
    end
    viewer:Show()

    local rows = GetActiveRows(settings)
    local items = module.ItemRegistry.GetItemsForViewer(viewerKey) or {}
    
    if #rows > 0 and (#items > 0 or ShouldRunLayoutWithNoItems(viewerKey, settings)) then
        local rowAssignments, visibleItems = GetRowAssignmentsWithPreview(viewer, viewerKey, settings, items, rows)

        local assignedItems = {}
        for _, entry in ipairs(visibleItems) do
            assignedItems[entry.item] = true
        end
        for _, item in ipairs(items) do
            if item.frame and not assignedItems[item] then
                item.frame:Hide()
                PP.ClearPoints(item.frame)
            end
        end
        for _, item in ipairs(items) do
            item:setInLayout(assignedItems[item] == true)
        end

        ApplyLayout(viewer, rowAssignments, rows, viewerKey)
        ApplyPostLayout(viewerKey, viewer, visibleItems)
    else
        HidePreviewIfBuff(viewerKey, viewer)
    end

    StyleViewerCooldowns(viewerKey)
    if LayoutEngine.IsLayoutDrivenByBlizzardHook(viewerKey) then
        LayoutEngine.ApplyVisibilityToViewer(viewerKey, false)
    end
    done()
end

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------

function LayoutEngine.EnsureHooksInstalled()
    InstallRefreshLayoutHooks()
end

module.LayoutEngine = LayoutEngine
