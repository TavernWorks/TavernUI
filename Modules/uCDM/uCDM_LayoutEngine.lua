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
local layoutDimensions = {}

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

function LayoutEngine.GetViewerFrame(viewerKey)
    return module:GetViewerFrame(viewerKey)
end

function LayoutEngine.IsLayoutDrivenByBlizzardHook(viewerKey)
    return viewerKey == "essential" or viewerKey == "utility"
end

function LayoutEngine.IsSettingViewerSize(viewerKey)
    return layoutSettingSize[viewerKey] == true
end

function LayoutEngine.GetViewerContentSize(viewerKey)
    local d = layoutDimensions[viewerKey]
    if d and d.w and d.h then return d.w, d.h end
    return nil, nil
end

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
    if viewerKey == "buff" and Preview then
        Preview.HidePreviewFrames(viewer)
    end
end

function ViewerBehavior.ApplyPostLayout(viewerKey, viewer, visibleItems)
    if viewerKey ~= "buff" or not Preview or not visibleItems[1] then return end
    if Preview.IsPreviewItem(visibleItems[1].item) then
        Preview.ApplyPreviewFakeData(viewer, visibleItems)
    end
end

local function GetActiveRows(settings)
    local rows = {}
    if not settings or not settings.rows then return rows end

    for _, row in ipairs(settings.rows) do
        if row.iconCount and row.iconCount > 0 then
            rows[#rows + 1] = {
                iconCount = row.iconCount,
                orientation = (row.orientation == "vertical") and "vertical" or "horizontal",
                iconSize = row.iconSize or 50,
                spacing = row.spacing or row.padding or 0,
                yOffset = row.yOffset or 0,
                aspectRatioCrop = row.aspectRatioCrop or 1.0,
                zoom = row.zoom or 0.02,
                iconBorderSize = row.iconBorderSize or 0,
                iconBorderColor = row.iconBorderColor or {r = 0, g = 0, b = 0, a = 1},
                durationSize = row.durationSize or 18,
                durationPoint = row.durationPoint or "CENTER",
                durationOffsetX = row.durationOffsetX or 0,
                durationOffsetY = row.durationOffsetY or 0,
                stackSize = row.stackSize or 16,
                stackPoint = row.stackPoint or "BOTTOMRIGHT",
                stackOffsetX = row.stackOffsetX or 0,
                stackOffsetY = row.stackOffsetY or 0,
                keepRowSizeWhenEmpty = row.keepRowSizeWhenEmpty ~= false,
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

-- Row config values (iconSize, spacing, etc.) are design pixels. Return raw integer pixels for layout math.
local function GetRowPixelDimensions(viewer, rowConfig)
    if not viewer then return nil end
    local iconSize_px = rowConfig.iconSize or 50
    local aspectRatio = rowConfig.aspectRatioCrop or 1.0
    local iconHeight_px = iconSize_px / aspectRatio
    local spacing_px = rowConfig.spacing or rowConfig.padding or 0
    return math.max(1, math.floor(iconSize_px)),
        math.max(1, math.floor(iconHeight_px)),
        math.max(0, math.floor(spacing_px))
end

local function GetRowSize(pxIcon, pxIconH, pxSpacing, count, vertical)
    if not count or count < 1 then return 0, 0 end
    if vertical then
        return pxIcon, count * pxIconH + (count - 1) * pxSpacing
    end
    return count * pxIcon + (count - 1) * pxSpacing, pxIconH
end

local function GetItemOffsetInRow(vertical, col, actualIcons, pxIcon, pxIconH, pxSpacing, rowCenterY)
    if vertical then
        local actualBlockHeight = actualIcons * pxIconH + (actualIcons - 1) * pxSpacing
        local startY = rowCenterY + math.floor(actualBlockHeight / 2 + 0.5) - math.floor(pxIconH / 2 + 0.5)
        local y = startY - (col - 1) * (pxIconH + pxSpacing)
        return 0, math.floor(y + 0.5)
    end
    local actualBlockWidth = actualIcons * pxIcon + (actualIcons - 1) * pxSpacing
    local startX = -math.floor(actualBlockWidth / 2 + 0.5) + math.floor(pxIcon / 2 + 0.5)
    local x = startX + (col - 1) * (pxIcon + pxSpacing)
    return math.floor(x + 0.5), math.floor(rowCenterY + 0.5)
end

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

local function CalculateDimensions(viewer, rowAssignments, rows, viewerKey)
    if not viewer then return 0, 0, 0 end
    local maxRowWidth = 0
    local totalHeight = 0
    local settings = viewerKey and module:GetViewerSettings(viewerKey) or nil
    local rowSpacing = (settings and settings.rowSpacing ~= nil) and settings.rowSpacing or CONSTANTS.DEFAULT_ROW_GAP
    local pxRowGap = math.max(0, math.floor((type(rowSpacing) == "number" and rowSpacing) or CONSTANTS.DEFAULT_ROW_GAP))

    for rowNum, rowConfig in ipairs(rows) do
        local rowItems = rowAssignments[rowNum] or {}
        local actualIcons = #rowItems
        local keepSize = rowConfig.keepRowSizeWhenEmpty
        local vertical = rowConfig.orientation == "vertical"
        local pxIcon, pxIconH, pxSpacing = GetRowPixelDimensions(viewer, rowConfig)
        if not pxIcon or not pxIconH then return 0, 0, 0 end

        if actualIcons > 0 or keepSize then
            local count = (keepSize and rowConfig.iconCount) or math.max(1, actualIcons)
            local rowW, rowH = GetRowSize(pxIcon, pxIconH, pxSpacing, count, vertical)
            maxRowWidth = math.max(maxRowWidth, rowW)
            totalHeight = totalHeight + rowH + (rowNum > 1 and pxRowGap or 0)
        end
    end

    return maxRowWidth, totalHeight, pxRowGap
end

local Preview = module.Preview

local function ApplyLayout(viewer, rowAssignments, rows, viewerKey)
    local settings = module:GetViewerSettings(viewerKey)
    local growDirection = (settings and settings.rowGrowDirection) or "down"

    if viewer.SetClipsChildren then
        viewer:SetClipsChildren(false)
    end

    local maxRowWidth, totalHeight, rowGap = CalculateDimensions(viewer, rowAssignments, rows, viewerKey)

    local halfTotal = math.floor(totalHeight / 2 + 0.5)
    local currentY = (growDirection == "up") and -halfTotal or halfTotal

    for rowNum, rowConfig in ipairs(rows) do
        local rowItems = rowAssignments[rowNum] or {}
        local actualIcons = #rowItems
        local keepSize = rowConfig.keepRowSizeWhenEmpty
        local vertical = rowConfig.orientation == "vertical"
        local pxIcon, pxIconH, pxSpacing = GetRowPixelDimensions(viewer, rowConfig)

        if (pxIcon and pxIconH) and (actualIcons > 0 or keepSize) then
            local count = (keepSize and rowConfig.iconCount) or math.max(1, actualIcons)
            local rowWidth, rowHeight = GetRowSize(pxIcon, pxIconH, pxSpacing, count, vertical)
            local yOffset = math.floor((rowConfig.yOffset or 0) + 0.5)
            local halfRow = math.floor(rowHeight / 2 + 0.5)
            local rowCenterY = (growDirection == "up")
                    and (currentY + halfRow + yOffset)
                    or (currentY - halfRow + yOffset)

            if actualIcons > 0 then
                local firstX, firstY = GetItemOffsetInRow(vertical, 1, actualIcons, pxIcon, pxIconH, pxSpacing, rowCenterY)
                local stepX = (not vertical) and (pxIcon + pxSpacing) or 0
                local stepY = vertical and (pxIconH + pxSpacing) or 0
                for col, item in ipairs(rowItems) do
                    local frame = item.frame
                    if frame then
                        local uX = firstX + (col - 1) * stepX
                        local uY = firstY + (col - 1) * stepY
                        frame:SetParent(viewer)
                        frame:SetFrameLevel(viewer:GetFrameLevel() + 3)
                        frame:ClearAllPoints()
                        frame:SetPoint("CENTER", viewer, "CENTER", uX, uY)
                        frame:SetSize(pxIcon, pxIconH)

                        item:applyStyle(rowConfig, pxIcon, pxIconH, viewer)

                        if item.source == "custom" then
                            if frame.Icon then
                                frame.Icon:ClearAllPoints()
                                frame.Icon:SetAllPoints(frame)
                                if frame.IconMask then
                                    frame.IconMask:ClearAllPoints()
                                    frame.IconMask:SetAllPoints(frame.Icon)
                                end
                            end
                            if frame.Cooldown then
                                frame.Cooldown:ClearAllPoints()
                                frame.Cooldown:SetAllPoints(frame)
                            end
                        end

                        frame:Show()
                    end
                end
            end

            if growDirection == "up" then
                currentY = currentY + rowHeight + rowGap
            else
                currentY = currentY - rowHeight - rowGap
            end
        end
    end

    if maxRowWidth > 0 and totalHeight > 0 then
        layoutDimensions[viewerKey] = { w = maxRowWidth, h = totalHeight }
        if not LayoutEngine.IsLayoutDrivenByBlizzardHook(viewerKey) then
            layoutSettingSize[viewerKey] = true
            pcall(function()
                viewer:SetSize(maxRowWidth, totalHeight)
            end)
            layoutSettingSize[viewerKey] = nil
        end
    else
        layoutDimensions[viewerKey] = nil
    end
end

local function GetRowAssignmentsWithPreview(viewer, viewerKey, settings, items, rows)
    local rowAssignments, visibleItems = AssignItemsToRows(items, rows, viewerKey)
    local showPreview = ViewerBehavior.WantsPreviewWhenEmpty(viewerKey, settings) and #visibleItems == 0

    if showPreview and Preview then
        local totalSlots = GetTotalCapacity(rows)
        local count = math.min(settings.previewIconCount or 6, totalSlots)
        local fakeItems = Preview.BuildPreviewItems(viewer, count)
        rowAssignments, visibleItems = AssignItemsToRows(fakeItems, rows, viewerKey)
    else
        ViewerBehavior.HidePreviewIfBuff(viewerKey, viewer)
    end

    return rowAssignments, visibleItems
end

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

    if ViewerBehavior.ShouldHideBeforeLayout(viewerKey, viewer, settings) then
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

    ApplyLayout(viewer, rowAssignments, rows, viewerKey)
    ViewerBehavior.ApplyPostLayout(viewerKey, viewer, visibleItems)
    done()
end

module.LayoutEngine = LayoutEngine