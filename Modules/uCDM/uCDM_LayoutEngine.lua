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
    end

    module:WatchSetting("general.scaleFactor", function()
        if module:IsEnabled() then
            for _, key in ipairs(module.CONSTANTS.VIEWER_KEYS) do
                if key ~= "custom" then
                    LayoutEngine.RefreshViewer(key)
                end
            end
        end
    end)
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
    
    for _, row in ipairs(settings.rows) do
        if row.iconCount and row.iconCount > 0 then
            rows[#rows + 1] = {
                iconCount = row.iconCount,
                iconSize = row.iconSize or 50,
                padding = row.padding or 0,
                yOffset = row.yOffset or 0,
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
    
    -- Create visibility context
    local context = {
        viewerKey = viewerKey,
        inCombat = InCombatLockdown(),
    }
    
    -- Filter visible items and assign layout indices
    local visibleItems = {}
    for _, item in ipairs(items) do
        if item.enabled ~= false and item.frame and item:isVisible(context) then
            local layoutIdx = item.layoutIndex or item.index or (#visibleItems + 1)
            if layoutIdx <= capacity then
                visibleItems[#visibleItems + 1] = {
                    item = item,
                    layoutIndex = layoutIdx,
                }
            end
        end
    end
    
    -- Sort by layout index
    table.sort(visibleItems, function(a, b)
        return a.layoutIndex < b.layoutIndex
    end)
    
    -- Assign to rows based on breakpoints
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

local function CalculateDimensions(rowAssignments, rows)
    local maxRowWidth = 0
    local totalHeight = 0
    local rowGap = CONSTANTS.DEFAULT_ROW_GAP
    
    for rowNum, rowConfig in ipairs(rows) do
        local rowItems = rowAssignments[rowNum] or {}
        local actualIcons = #rowItems
        local iconSize = rowConfig.iconSize
        local aspectRatio = rowConfig.aspectRatioCrop
        local iconHeight = iconSize / aspectRatio
        local keepHeight = rowConfig.keepRowHeightWhenEmpty
        
        if actualIcons > 0 or keepHeight then
            local rowWidth = rowConfig.iconCount * iconSize + (rowConfig.iconCount - 1) * rowConfig.padding
            maxRowWidth = math.max(maxRowWidth, rowWidth)
            totalHeight = totalHeight + iconHeight + (rowNum > 1 and rowGap or 0)
        end
    end
    
    return maxRowWidth, totalHeight, rowGap
end

--------------------------------------------------------------------------------
-- Layout Application
--------------------------------------------------------------------------------

local function ApplyRowBorder(viewer, rowNum, rowConfig, rowWidth, rowHeight, rowCenterY)
    local borderSize = rowConfig.rowBorderSize or 0
    local borderKey = "__ucdmRowBorder" .. rowNum
    
    if borderSize <= 0 then
        if viewer[borderKey] then
            viewer[borderKey]:Hide()
        end
        return
    end
    
    if not viewer[borderKey] then
        viewer[borderKey] = viewer:CreateTexture(nil, "BACKGROUND", nil, -7)
    end
    
    local border = viewer[borderKey]
    local halfWidth = rowWidth / 2
    local halfHeight = rowHeight / 2
    local color = rowConfig.rowBorderColor or {r = 0, g = 0, b = 0, a = 1}
    
    border:SetColorTexture(color.r, color.g, color.b, color.a)
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", viewer, "CENTER", -halfWidth - borderSize, rowCenterY + halfHeight + borderSize)
    border:SetPoint("BOTTOMRIGHT", viewer, "CENTER", halfWidth + borderSize, rowCenterY - halfHeight - borderSize)
    border:Show()
end

local function ApplyLayout(viewer, rowAssignments, rows, viewerKey)
    local settings = module:GetViewerSettings(viewerKey)
    local growDirection = (settings and settings.rowGrowDirection) or "down"
    
    local maxRowWidth, totalHeight, rowGap = CalculateDimensions(rowAssignments, rows)
    
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
        local padding = rowConfig.padding
        
        if actualIcons > 0 or keepHeight then
            local rowWidth = rowConfig.iconCount * iconSize + (rowConfig.iconCount - 1) * padding
            
            local rowCenterY = (growDirection == "up")
                and (currentY + iconHeight / 2 + (rowConfig.yOffset or 0))
                or (currentY - iconHeight / 2 + (rowConfig.yOffset or 0))
            
            if actualIcons > 0 then
                local actualBlockWidth = actualIcons * iconSize + (actualIcons - 1) * padding
                local startX = -actualBlockWidth / 2 + iconSize / 2
                for col, item in ipairs(rowItems) do
                    local frame = item.frame
                    if frame then
                        local offsetX = startX + (col - 1) * (iconSize + padding)
                        frame:SetParent(viewer)
                        frame:ClearAllPoints()
                        frame:SetPoint("CENTER", viewer, "CENTER", offsetX, rowCenterY)

                        -- Let the item style itself with this row's config
                        item:applyStyle(rowConfig)

                        if item.source == "custom" then
                            frame:SetScale(viewer.iconScale or 1)
                            local cellW = iconSize + 2 * padding
                            local cellH = iconHeight + 2 * padding
                            frame:SetSize(cellW, cellH)
                            if frame.Icon then
                                frame.Icon:ClearAllPoints()
                                frame.Icon:SetSize(iconSize, iconHeight)
                                frame.Icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
                                if frame.IconMask then
                                    frame.IconMask:ClearAllPoints()
                                    frame.IconMask:SetAllPoints(frame.Icon)
                                end
                            end
                            if frame.Cooldown then
                                frame.Cooldown:ClearAllPoints()
                                frame.Cooldown:SetSize(iconSize, iconHeight)
                                frame.Cooldown:SetPoint("CENTER", frame, "CENTER", 0, 0)
                            end
                        end
                        
                        frame:Show()
                    end
                end
            end
            
            -- Apply row border
            ApplyRowBorder(viewer, rowNum, rowConfig, rowWidth, iconHeight, rowCenterY)
            
            -- Advance to next row
            if growDirection == "up" then
                currentY = currentY + iconHeight + rowGap
            else
                currentY = currentY - iconHeight - rowGap
            end
        end
    end
    
    if maxRowWidth > 0 and totalHeight > 0 then
        layoutSettingSize[viewerKey] = true
        pcall(function()
            viewer:SetSize(maxRowWidth, totalHeight)
        end)
        layoutSettingSize[viewerKey] = nil
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
    viewer:SetScale(module:GetSetting("general.scaleFactor", 1))

    local rows = GetActiveRows(settings)
    if #rows == 0 then
        layoutRunning[viewerKey] = false
        return
    end
    
    -- Get items from registry
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
    
    -- Hide items that weren't assigned BEFORE layout to prevent artifacts
    local hiddenCount = 0
    for _, item in ipairs(items) do
        if item.frame and not assignedItems[item] then
            item.frame:Hide()
            item.frame:ClearAllPoints()
            hiddenCount = hiddenCount + 1
        end
    end

    -- Apply layout
    ApplyLayout(viewer, rowAssignments, rows, viewerKey)
    layoutRunning[viewerKey] = false
end

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------

module.LayoutEngine = LayoutEngine
