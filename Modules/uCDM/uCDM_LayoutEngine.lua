local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

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

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

local function InstallRefreshLayoutHooks()
    local names = module.CONSTANTS.VIEWER_NAMES
    for viewerKey, globalName in pairs(names) do
        if viewerKey == "essential" or viewerKey == "utility" then
            local viewer = _G[globalName]
            if viewer and viewer.RefreshLayout then
                hooksecurefunc(viewer, "RefreshLayout", function()
                    if not module:IsEnabled() then return end
                    if module.ItemRegistry then
                        module.ItemRegistry.CollectBlizzardItems(viewerKey)
                    end
                    LayoutEngine.RefreshViewer(viewerKey)
                end)
            end
        end
    end
end

function LayoutEngine.Initialize()
    layoutRunning = {}

    C_Timer.After(0, InstallRefreshLayoutHooks)

    for _, viewerKey in ipairs(module.CONSTANTS.VIEWER_KEYS) do
        module:WatchSetting(string.format("viewers.%s.enabled", viewerKey), function(newValue)
            local viewer = LayoutEngine.GetViewerFrame(viewerKey)
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

function LayoutEngine.GetViewerFrame(viewerKey)
    return module:GetViewerFrame(viewerKey)
end

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
        local slotEnd = slotStart + rowConfig.iconCount - 1
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

local ViewerBehavior = {}

function ViewerBehavior.ShouldHideBeforeLayout(viewerKey, viewer, settings)
    if viewerKey ~= "buff" then return false end
    local blizz = _G["BuffIconCooldownViewer"]
    local wantPreview = (settings.showPreview == true) and (settings.previewIconCount or 0) > 0
    return blizz and not blizz:IsShown() and not wantPreview
end

function ViewerBehavior.WantsPreviewWhenEmpty(viewerKey, settings)
    return viewerKey == "buff"
        and (settings.showPreview == true)
        and (settings.previewIconCount or 0) > 0
end

function ViewerBehavior.ShouldRunLayoutWithNoItems(viewerKey, settings)
    if ViewerBehavior.WantsPreviewWhenEmpty(viewerKey, settings) then return true end
    return module.IsCustomViewerId and module:IsCustomViewerId(viewerKey)
end

function ViewerBehavior.HidePreviewIfBuff(viewerKey, viewer)
    if viewerKey == "buff" and Preview and Preview.HidePreviewFrames then
        Preview.HidePreviewFrames(viewer)
    end
end

function ViewerBehavior.ApplyPostLayout(viewerKey, viewer, visibleItems)
    if viewerKey ~= "buff" or not Preview or not visibleItems[1] then return end
    if Preview.IsPreviewItem and Preview.IsPreviewItem(visibleItems[1].item) then
        if Preview.ApplyPreviewFakeData then
            Preview.ApplyPreviewFakeData(viewer, visibleItems)
        end
    end
end

local function GetRowAssignmentsWithPreview(viewer, viewerKey, settings, items, rows)
    local rowAssignments, visibleItems = AssignItemsToRows(items, rows, viewerKey)
    local showPreview = ViewerBehavior.WantsPreviewWhenEmpty(viewerKey, settings) and #visibleItems == 0

    if showPreview and Preview and Preview.BuildPreviewItems then
        local totalSlots = GetTotalCapacity(rows)
        local count = math.min(settings.previewIconCount or 6, totalSlots)
        local fakeItems = Preview.BuildPreviewItems(viewer, count)
        rowAssignments, visibleItems = AssignItemsToRows(fakeItems, rows, viewerKey)
    else
        ViewerBehavior.HidePreviewIfBuff(viewerKey, viewer)
    end

    return rowAssignments, visibleItems
end

--------------------------------------------------------------------------------
-- Dimension Calculation (from row config capacity so viewer size is stable)
--------------------------------------------------------------------------------

local function CalculateDimensions(viewer, rowAssignments, rows, viewerKey)
    local maxRowWidth = 0
    local maxActualContentWidth = 0
    local totalHeight = 0
    local settings = viewerKey and module:GetViewerSettings(viewerKey) or nil
    local scale = (settings and settings.scale) or 1.0
    local rowSpacing = ((settings and settings.rowSpacing ~= nil) and settings.rowSpacing or CONSTANTS.DEFAULT_ROW_GAP) * scale
    local pxRowGap = viewer and TavernUI:GetPixelSize(viewer, rowSpacing, 1) or rowSpacing
    
    local currentGroupWidth = 0
    local currentGroupHeight = 0
    
    for rowNum, rowConfig in ipairs(rows) do
        local rowItems = rowAssignments[rowNum] or {}
        local actualIcons = 0
        if rowItems then
            for slot = 1, rowConfig.iconCount do
                if rowItems[slot] then
                    actualIcons = actualIcons + 1
                end
            end
        end
        local iconSize = rowConfig.iconSize
        local aspectRatio = rowConfig.aspectRatioCrop
        local iconHeight = iconSize / aspectRatio
        local padding = rowConfig.padding or 0
        local keepHeight = rowConfig.keepRowHeightWhenEmpty
        local isCustom = module.IsCustomViewerId and module:IsCustomViewerId(viewerKey)
        local vertical = isCustom and rowConfig.orientation == "vertical"
        local positionAtSide = isCustom and rowConfig.positionAtSide == true
        
        if actualIcons > 0 or keepHeight then
            local pxIcon = viewer and TavernUI:GetPixelSize(viewer, iconSize, 0) or iconSize
            local pxIconH = viewer and TavernUI:GetPixelSize(viewer, iconHeight, 1) or iconHeight
            local pxPad = viewer and TavernUI:GetPixelSize(viewer, padding, 0) or padding

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

            if count and count > 0 then
                local rowWidth, rowHeight
                if vertical then
                    rowWidth = pxIcon
                    rowHeight = count * pxIconH + (count - 1) * pxPad
                else
                    rowWidth = count * pxIcon + (count - 1) * pxPad
                    rowHeight = pxIconH
                end

                if positionAtSide and rowNum > 1 then
                    currentGroupWidth = currentGroupWidth + rowWidth + pxRowGap
                    currentGroupHeight = math.max(currentGroupHeight, rowHeight)
                else
                    if rowNum > 1 then
                        totalHeight = totalHeight + currentGroupHeight + pxRowGap
                        maxRowWidth = math.max(maxRowWidth, currentGroupWidth)
                    end
                    currentGroupWidth = rowWidth
                    currentGroupHeight = rowHeight
                end

                if actualIcons > 0 then
                    local actualBlockWidth
                    if vertical then
                        actualBlockWidth = pxIcon
                    else
                        actualBlockWidth = actualIcons * pxIcon + (actualIcons - 1) * pxPad
                    end
                    maxActualContentWidth = math.max(maxActualContentWidth, actualBlockWidth)
                end
            end
        end
    end
    
    if currentGroupWidth > 0 then
        totalHeight = totalHeight + currentGroupHeight
        maxRowWidth = math.max(maxRowWidth, currentGroupWidth)
    end
    
    return maxRowWidth, totalHeight, pxRowGap, maxActualContentWidth
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
    
    local borderSize = TavernUI:GetPixelSize(viewer, rawBorderSize, 0)
    local border = viewer[borderKey]
    local halfWidth = math.floor(rowWidth / 2)
    local halfHeight = math.floor(rowHeight / 2)
    local centerX = math.floor((rowCenterX or 0) + 0.5)
    local centerY = math.floor(rowCenterY + 0.5)
    local color = rowConfig.rowBorderColor or CONSTANTS.DEFAULT_ROW_BORDER_COLOR
    
    border:SetColorTexture(color.r, color.g, color.b, color.a)
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", viewer, "CENTER", centerX - halfWidth - borderSize, centerY + halfHeight + borderSize)
    border:SetPoint("BOTTOMRIGHT", viewer, "CENTER", centerX + halfWidth + borderSize, centerY - halfHeight - borderSize)
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
    local pxIcon = TavernUI:GetPixelSize(viewer, iconSize, 0)
    local pxIconH = TavernUI:GetPixelSize(viewer, iconHeight, 1)
    local pxPad = TavernUI:GetPixelSize(viewer, padding, 0)
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

local function LayoutRowItems(parentFrame, viewer, rowItems, rowConfig, metrics, rowCenterY, rowCenterX)
    if metrics.actualIcons <= 0 then
        return
    end

    local pxIcon = metrics.pxIcon
    local pxIconH = metrics.pxIconH
    local pxPad = metrics.pxPad
    local actualIcons = metrics.actualIcons
    rowCenterX = rowCenterX or 0

    if metrics.vertical then
        local actualBlockHeight = actualIcons * pxIconH + (actualIcons - 1) * pxPad
        local startY = rowCenterY + actualBlockHeight / 2 - pxIconH / 2
        for col, item in ipairs(rowItems) do
            if item.frame then
                local offsetY = startY - (col - 1) * (pxIconH + pxPad)
                offsetY = math.floor(offsetY + 0.5)
                item:setLayoutPosition(parentFrame, viewer, rowCenterX, offsetY)
                item:applyStyle(rowConfig)
            end
        end
    else
        local actualBlockWidth = actualIcons * pxIcon + (actualIcons - 1) * pxPad
        local startX = rowCenterX - actualBlockWidth / 2 + pxIcon / 2
        for col, item in ipairs(rowItems) do
            if item.frame then
                local offsetX = startX + (col - 1) * (pxIcon + pxPad)
                item:setLayoutPosition(parentFrame, viewer, offsetX, rowCenterY)
                item:applyStyle(rowConfig)
            end
        end
    end
end

local function BuildGridStructure(rows, viewerKey)
    local gridRows = {}
    local rowToGridRow = {}
    local rowToGridCol = {}
    
    local isCustom = module.IsCustomViewerId and module:IsCustomViewerId(viewerKey)
    local currentGridRow = 0
    local currentGridCol = 0
    
    for rowNum, rowConfig in ipairs(rows) do
        local positionAtSide = isCustom and rowConfig.positionAtSide == true
        
        if positionAtSide and rowNum > 1 then
            currentGridCol = currentGridCol + 1
        else
            currentGridRow = currentGridRow + 1
            currentGridCol = 0
        end
        
        if not gridRows[currentGridRow] then
            gridRows[currentGridRow] = {}
        end
        
        gridRows[currentGridRow][currentGridCol] = {
            rowNum = rowNum,
            rowConfig = rowConfig,
        }
        
        rowToGridRow[rowNum] = currentGridRow
        rowToGridCol[rowNum] = currentGridCol
    end
    
    return gridRows, rowToGridRow, rowToGridCol
end

local function AssignItemsToGridCells(items, rows, viewerKey)
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
    
    local gridCells = {}
    local slotStart = 1
    
    for rowNum, rowConfig in ipairs(rows) do
        local slotEnd = slotStart + rowConfig.iconCount - 1
        
        for _, entry in ipairs(visibleItems) do
            local slot = entry.layoutIndex
            if slot >= slotStart and slot <= slotEnd then
                local cellSlot = slot - slotStart + 1
                if not gridCells[rowNum] then
                    gridCells[rowNum] = {}
                end
                gridCells[rowNum][cellSlot] = entry.item
            end
        end
        
        slotStart = slotEnd + 1
    end
    
    return gridCells, visibleItems
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

local function ApplyGridLayout(viewer, parentFrame, gridCells, rows, viewerKey)
    local settings = module:GetViewerSettings(viewerKey)
    local growDirection = (settings and settings.rowGrowDirection) or "down"
    
    local gridRows, rowToGridRow, rowToGridCol = BuildGridStructure(rows, viewerKey)
    
    local maxRowWidth, totalHeight, rowGap, maxActualContentWidth = CalculateDimensions(viewer, gridCells, rows, viewerKey)
    
    HideAllRowBorders(viewer, rows)
    
    local startY = (growDirection == "up") and (-totalHeight / 2) or (totalHeight / 2)
    local currentY = startY
    
    local columnCenters = {}
    local columnWidths = {}
    
    for gridRowNum = 0, #gridRows do
        local gridRow = gridRows[gridRowNum]
        if not gridRow then break end
        
        local maxRowHeight = 0
        local currentX = 0
        
        for gridColNum = 0, #gridRow do
            local gridCell = gridRow[gridColNum]
            if not gridCell then break end
            
            local rowNum = gridCell.rowNum
            local rowConfig = gridCell.rowConfig
            local rowItems = gridCells[rowNum] or {}
            
            local metrics = BuildRowMetrics(viewer, viewerKey, rowConfig, rowItems)
            if metrics then
                local pxYOffset = TavernUI:GetPixelSize(viewer, rowConfig.yOffset or 0, 1)
                
                if gridColNum == 0 then
                    columnCenters[gridColNum] = 0
                    columnWidths[gridColNum] = metrics.actualRowWidth
                else
                    local prevWidth = columnWidths[gridColNum - 1] or 0
                    local prevCenter = columnCenters[gridColNum - 1] or 0
                    columnCenters[gridColNum] = prevCenter + prevWidth / 2 + rowGap + metrics.actualRowWidth / 2
                    columnWidths[gridColNum] = metrics.actualRowWidth
                end
                
                local rowCenterX = columnCenters[gridColNum]
                local rowCenterY = (growDirection == "up")
                    and (currentY - metrics.rowHeight / 2 + pxYOffset)
                    or (currentY + metrics.rowHeight / 2 + pxYOffset)
                
                if metrics.vertical then
                    local actualBlockHeight = metrics.actualIcons * metrics.pxIconH + (metrics.actualIcons - 1) * metrics.pxPad
                    local startY = rowCenterY + actualBlockHeight / 2 - metrics.pxIconH / 2
                    for slot = 1, rowConfig.iconCount do
                        local item = rowItems[slot]
                        if item and item.frame then
                            local offsetY = startY - (slot - 1) * (metrics.pxIconH + metrics.pxPad)
                            offsetY = math.floor(offsetY + 0.5)
                            item:setLayoutPosition(parentFrame, viewer, rowCenterX, offsetY)
                            item:applyStyle(rowConfig)
                        end
                    end
                else
                    local actualBlockWidth = metrics.actualIcons * metrics.pxIcon + (metrics.actualIcons - 1) * metrics.pxPad
                    local startX = rowCenterX - actualBlockWidth / 2 + metrics.pxIcon / 2
                    for slot = 1, rowConfig.iconCount do
                        local item = rowItems[slot]
                        if item and item.frame then
                            local offsetX = startX + (slot - 1) * (metrics.pxIcon + metrics.pxPad)
                            item:setLayoutPosition(parentFrame, viewer, offsetX, rowCenterY)
                            item:applyStyle(rowConfig)
                        end
                    end
                end
                
                ApplyRowBorder(viewer, rowNum, rowConfig, metrics.rowWidth, metrics.rowHeight, rowCenterY, rowCenterX)
                
                maxRowHeight = math.max(maxRowHeight, metrics.rowHeight)
            end
        end
        
        if gridRowNum > 0 then
            if growDirection == "up" then
                currentY = currentY + maxRowHeight + rowGap
            else
                currentY = currentY - maxRowHeight - rowGap
            end
        else
            if growDirection == "up" then
                currentY = currentY + maxRowHeight
            else
                currentY = currentY - maxRowHeight
            end
        end
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
end

local function ApplyLayout(viewer, parentFrame, rowAssignments, rows, viewerKey)
    local settings = module:GetViewerSettings(viewerKey)
    local growDirection = (settings and settings.rowGrowDirection) or "down"
    
    local maxRowWidth, totalHeight, rowGap, maxActualContentWidth = CalculateDimensions(viewer, rowAssignments, rows, viewerKey)
    
    -- Hide all row borders first to prevent artifacts
    HideAllRowBorders(viewer, rows)
    
    -- Starting Y position
    local currentY = (growDirection == "up") and (-totalHeight / 2) or (totalHeight / 2)
    local currentX = 0
    local previousActualRowWidth = 0
    local currentGroupHeight = 0

    for rowNum, rowConfig in ipairs(rows) do
        local rowItems = rowAssignments[rowNum] or {}
        local metrics = BuildRowMetrics(viewer, viewerKey, rowConfig, rowItems)

        if metrics then
            local pxYOffset = TavernUI:GetPixelSize(viewer, rowConfig.yOffset or 0, 1)
            local rowCenterX, rowCenterY
            rowCenterX, rowCenterY, currentX, previousActualRowWidth, currentGroupHeight, currentY =
                ComputeRowPosition(growDirection, rowNum, metrics, currentX, previousActualRowWidth, currentY, currentGroupHeight, rowGap, pxYOffset)

            LayoutRowItems(parentFrame, viewer, rowItems, rowConfig, metrics, rowCenterY, rowCenterX)
            ApplyRowBorder(viewer, rowNum, rowConfig, metrics.rowWidth, metrics.rowHeight, rowCenterY, rowCenterX)

            previousActualRowWidth = metrics.actualRowWidth
        end
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

--------------------------------------------------------------------------------
-- Main Refresh
--------------------------------------------------------------------------------

function LayoutEngine.RefreshViewer(viewerKey)
    if layoutRunning[viewerKey] then return end
    layoutRunning[viewerKey] = true
    local function done()
        layoutRunning[viewerKey] = nil
    end

    local viewer = LayoutEngine.GetViewerFrame(viewerKey)
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

    local Visibility = TavernUI and TavernUI.Visibility
    local visibilityConfig = module:GetSetting("general.visibility")
    if Visibility and visibilityConfig and not Visibility.ShouldShow(visibilityConfig) then
        viewer:Hide()
        done()
        return
    end

    if ViewerBehavior.ShouldHideBeforeLayout(viewerKey, viewer, settings) then
        viewer:Hide()
        ViewerBehavior.HidePreviewIfBuff(viewerKey, viewer)
        done()
        return
    end

    viewer:Show()

    local rows = GetActiveRows(settings)
    if #rows == 0 then
        done()
        return
    end

    local items = module.ItemRegistry.GetItemsForViewer(viewerKey) or {}
    if #items == 0 and not ViewerBehavior.ShouldRunLayoutWithNoItems(viewerKey, settings) then
        ViewerBehavior.HidePreviewIfBuff(viewerKey, viewer)
        done()
        return
    end

    local rowAssignments, visibleItems = GetRowAssignmentsWithPreview(viewer, viewerKey, settings, items, rows)

    local assignedItems = {}
    for _, entry in ipairs(visibleItems) do
        assignedItems[entry.item] = true
    end
    for _, item in ipairs(items) do
        if item.frame and not assignedItems[item] then
            item.frame:Hide()
            item.frame:ClearAllPoints()
        end
    end
    for _, item in ipairs(items) do
        item:setInLayout(assignedItems[item] == true)
    end

    local parentFrame = module.ItemRegistry.GetParentFrameForViewer(viewerKey)
    ApplyLayout(viewer, parentFrame, rowAssignments, rows, viewerKey)
    ViewerBehavior.ApplyPostLayout(viewerKey, viewer, visibleItems)
    StyleViewerCooldowns(viewerKey)
    done()
end

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------

module.LayoutEngine = LayoutEngine
