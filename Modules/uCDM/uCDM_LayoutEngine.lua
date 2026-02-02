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

end

--------------------------------------------------------------------------------
-- Viewer Access
--------------------------------------------------------------------------------

function LayoutEngine.GetViewerFrame(viewerKey)
    return _G[module.CONSTANTS.VIEWER_NAMES[viewerKey]]
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
                iconCount = row.iconCount,
                iconSize = (row.iconSize or 50) * scale,
                padding = (row.padding or 0) * scale,
                yOffset = (row.yOffset or 0) * scale,
                aspectRatioCrop = row.aspectRatioCrop or 1.0,
                zoom = row.zoom or 0,
                iconStyle = row.iconStyle or "square",
                iconBorderSize = row.iconBorderSize or 0,  -- NOT scaled - stays pixel-perfect
                iconBorderColor = row.iconBorderColor or {r = 0, g = 1, b = 0, a = 1},
                rowBorderSize = row.rowBorderSize or 0,  -- NOT scaled - stays pixel-perfect
                rowBorderColor = row.rowBorderColor or {r = 0, g = 0, b = 0, a = 1},
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
    
    for rowNum, rowConfig in ipairs(rows) do
        local rowItems = rowAssignments[rowNum] or {}
        local actualIcons = #rowItems
        local iconSize = rowConfig.iconSize
        local aspectRatio = rowConfig.aspectRatioCrop
        local iconHeight = iconSize / aspectRatio
        local padding = rowConfig.padding or 0
        local keepHeight = rowConfig.keepRowHeightWhenEmpty
        
        if actualIcons > 0 or keepHeight then
            local pxIcon = viewer and TavernUI:GetPixelSize(viewer, iconSize, 0) or iconSize
            local pxIconH = viewer and TavernUI:GetPixelSize(viewer, iconHeight, 1) or iconHeight
            local pxPad = viewer and TavernUI:GetPixelSize(viewer, padding, 0) or padding
            local rowWidth = rowConfig.iconCount * pxIcon + (rowConfig.iconCount - 1) * pxPad
            maxRowWidth = math.max(maxRowWidth, rowWidth)
            if actualIcons > 0 then
                local actualBlockWidth = actualIcons * pxIcon + (actualIcons - 1) * pxPad
                maxActualContentWidth = math.max(maxActualContentWidth, actualBlockWidth)
            end
            totalHeight = totalHeight + pxIconH + (rowNum > 1 and pxRowGap or 0)
        end
    end
    
    return maxRowWidth, totalHeight, pxRowGap, maxActualContentWidth
end

--------------------------------------------------------------------------------
-- Layout Application
--------------------------------------------------------------------------------

local function ApplyRowBorder(viewer, rowNum, rowConfig, rowWidth, rowHeight, rowCenterY)
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
    local centerY = math.floor(rowCenterY + 0.5)
    local color = rowConfig.rowBorderColor or {r = 0, g = 0, b = 0, a = 1}
    
    border:SetColorTexture(color.r, color.g, color.b, color.a)
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", viewer, "CENTER", -halfWidth - borderSize, centerY + halfHeight + borderSize)
    border:SetPoint("BOTTOMRIGHT", viewer, "CENTER", halfWidth + borderSize, centerY - halfHeight - borderSize)
    border:Show()
end

local function ApplyLayout(viewer, parentFrame, rowAssignments, rows, viewerKey)
    local settings = module:GetViewerSettings(viewerKey)
    local growDirection = (settings and settings.rowGrowDirection) or "down"
    
    local maxRowWidth, totalHeight, rowGap, maxActualContentWidth = CalculateDimensions(viewer, rowAssignments, rows, viewerKey)
    
    -- Hide all row borders first to prevent artifacts
    for rowNum = 1, #rows do
        local borderKey = "__ucdmRowBorder" .. rowNum
        if viewer[borderKey] then
            viewer[borderKey]:Hide()
        end
    end
    
    -- Starting Y position
    local currentY = (growDirection == "up") and (-totalHeight / 2) or (totalHeight / 2)

    for rowNum, rowConfig in ipairs(rows) do
        local rowItems = rowAssignments[rowNum] or {}
        local actualIcons = #rowItems
        local keepHeight = rowConfig.keepRowHeightWhenEmpty

        local iconSize = rowConfig.iconSize
        local aspectRatio = rowConfig.aspectRatioCrop
        local iconHeight = iconSize / aspectRatio
        local padding = rowConfig.padding or 0
        local pxIcon = TavernUI:GetPixelSize(viewer, iconSize, 0)
        local pxIconH = TavernUI:GetPixelSize(viewer, iconHeight, 1)
        local pxPad = TavernUI:GetPixelSize(viewer, padding, 0)

        if actualIcons > 0 or keepHeight then
            local rowWidth = rowConfig.iconCount * pxIcon + (rowConfig.iconCount - 1) * pxPad
            local pxYOffset = TavernUI:GetPixelSize(viewer, rowConfig.yOffset or 0, 1)
            local rowCenterY = (growDirection == "up")
                and (currentY + pxIconH / 2 + pxYOffset)
                or (currentY - pxIconH / 2 + pxYOffset)
            local viewerScale = viewer:GetEffectiveScale() or 1
            if viewerScale > 0 then
                rowCenterY = math.floor(rowCenterY * viewerScale + 0.5) / viewerScale
            end

            if actualIcons > 0 then
                local actualBlockWidth = actualIcons * pxIcon + (actualIcons - 1) * pxPad
                local startX = -actualBlockWidth / 2 + pxIcon / 2
                for col, item in ipairs(rowItems) do
                    if item.frame then
                        local offsetX = startX + (col - 1) * (pxIcon + pxPad)
                        if viewerScale > 0 then
                            offsetX = math.floor(offsetX * viewerScale + 0.5) / viewerScale
                        end
                        item:setLayoutPosition(parentFrame, viewer, offsetX, rowCenterY)
                        item:applyStyle(rowConfig)
                    end
                end
            end
            
            ApplyRowBorder(viewer, rowNum, rowConfig, rowWidth, pxIconH, rowCenterY)
            
            if growDirection == "up" then
                currentY = currentY + pxIconH + rowGap
            else
                currentY = currentY - pxIconH - rowGap
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

    local viewer = LayoutEngine.GetViewerFrame(viewerKey)
    if not viewer then
        layoutRunning[viewerKey] = false
        return
    end
    
    local settings = module:GetViewerSettings(viewerKey)
    if not settings or settings.enabled == false then
        viewer:Hide()
        layoutRunning[viewerKey] = false
        return
    end
    
    -- Buff viewer special case: respect Blizzard's visibility
    if viewerKey == "buff" then
        local blizzBuffViewer = _G["BuffIconCooldownViewer"]
        if blizzBuffViewer and not blizzBuffViewer:IsShown() then
            viewer:Hide()
            layoutRunning[viewerKey] = false
            return
        end
    end
    
    viewer:Show()

    local rows = GetActiveRows(settings)
    if #rows == 0 then
        layoutRunning[viewerKey] = false
        return
    end
    
    local items = module.ItemRegistry.GetItemsForViewer(viewerKey)
    if not items or #items == 0 then
        layoutRunning[viewerKey] = false
        return
    end
    
    local rowAssignments, visibleItems = AssignItemsToRows(items, rows, viewerKey)

    -- Build set of assigned items for cleanup
    local assignedItems = {}
    for _, entry in ipairs(visibleItems) do
        assignedItems[entry.item] = true
    end
    
    for _, item in ipairs(items) do
        item:setInLayout(assignedItems[item] == true)
    end

    local parentFrame = module.ItemRegistry.GetParentFrameForViewer(viewerKey)
    ApplyLayout(viewer, parentFrame, rowAssignments, rows, viewerKey)
    StyleViewerCooldowns(viewerKey)

    layoutRunning[viewerKey] = false
end

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------

module.LayoutEngine = LayoutEngine
