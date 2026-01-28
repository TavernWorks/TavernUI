local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local LayoutEngine = {}

local layoutRunning = {}
local layoutThrottle = {}
local VIEWER_NAMES = {
    essential = "EssentialCooldownViewer",
    utility = "UtilityCooldownViewer",
    buff = "BuffIconCooldownViewer",
}

local function GetViewerFrame(viewerKey)
    return _G[VIEWER_NAMES[viewerKey]]
end

local function GetActiveRows(settings)
    local activeRows = {}
    if not settings or not settings.rows then return activeRows end
    
    for _, row in ipairs(settings.rows) do
        if row.iconCount and row.iconCount > 0 then
            table.insert(activeRows, {
                count = row.iconCount,
                size = row.iconSize or 50,
                padding = row.padding or 0,
                yOffset = row.yOffset or 0,
                maxIconsForRow = row.iconCount,
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

local function FilterEntries(entries, viewerKey, settings)
    local capacity = GetCapacity(settings)
    local isBuff = viewerKey == "buff"
    local filtered = {}
    
    if isBuff then
        for _, entry in ipairs(entries) do
            local slot = entry.layoutIndex or entry.index
            if slot and slot <= capacity then
                local isShown = false
                local frame = entry.frame
                if frame.ShouldBeShown then
                    local ok, result = pcall(function() return frame:ShouldBeShown() end)
                    if ok then
                        isShown = result
                    else
                        isShown = frame:IsShown()
                    end
                else
                    isShown = frame:IsShown()
                end
                
                if isShown then
                    table.insert(filtered, entry)
                else
                    frame:Hide()
                    pcall(function() frame:ClearAllPoints() end)
                end
            else
                entry.frame:Hide()
                pcall(function() entry.frame:ClearAllPoints() end)
            end
        end
    else
        for i = 1, math.min(#entries, capacity) do
            if entries[i] then
                table.insert(filtered, entries[i])
                entries[i].frame:Show()
            end
        end
        
        for i = capacity + 1, #entries do
            if entries[i] then
                entries[i].frame:Hide()
                pcall(function() entries[i].frame:ClearAllPoints() end)
            end
        end
    end
    
    return filtered
end

local function CalculateRows(entries, rowConfigs, viewerKey)
    local rowDistribution = {}
    local isBuff = viewerKey == "buff"
    
    if isBuff then
        local slotStart = 1
        for rowNum, rowConfig in ipairs(rowConfigs) do
            local stride = rowConfig.maxIconsForRow
            local slotEnd = slotStart + stride - 1
            local entriesInRow = {}
            
            for _, entry in ipairs(entries) do
                local slot = entry.layoutIndex or entry.index
                if slot and slot >= slotStart and slot <= slotEnd then
                    table.insert(entriesInRow, entry)
                end
            end
            
            table.sort(entriesInRow, function(a, b)
                return (a.layoutIndex or a.index or 9999) < (b.layoutIndex or b.index or 9999)
            end)
            
            rowDistribution[rowNum] = entriesInRow
            slotStart = slotEnd + 1
        end
    else
        local slotStart = 1
        for rowNum, rowConfig in ipairs(rowConfigs) do
            local stride = rowConfig.maxIconsForRow
            local rowEndIndex = math.min(slotStart + stride - 1, #entries)
            local entriesInRow = {}
            
            for i = slotStart, rowEndIndex do
                if entries[i] then
                    table.insert(entriesInRow, entries[i])
                end
            end
            
            rowDistribution[rowNum] = entriesInRow
            slotStart = rowEndIndex + 1
        end
    end
    
    return rowDistribution
end

local function ApplyRowBorder(viewer, rowNum, rowConfig, rowWidth, rowHeight, rowCenterX, rowCenterY)
    if not viewer or not rowConfig then return end
    
    local rowBorderSize = rowConfig.rowBorderSize or 0
    local borderKey = "__ucdmRowBorder" .. rowNum
    
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

local function ApplyLayout(viewer, rowDistribution, rowConfigs, viewerKey)
    local maxRowWidth, totalHeight, rowWidths, rowGap = CalculateRowDimensions(rowConfigs)
    
    local settings = module:GetViewerSettings(viewerKey)
    local growDirection = (settings and settings.rowGrowDirection) or "down"
    
    local currentY
    if growDirection == "up" then
        currentY = -totalHeight / 2
    else
        currentY = totalHeight / 2
    end
    
    for rowNum, rowConfig in ipairs(rowConfigs) do
        local entriesInRow = rowDistribution[rowNum] or {}
        local actualIconsInRow = #entriesInRow
        
        if actualIconsInRow > 0 then
            local iconSize = rowConfig.size
            local aspectRatio = rowConfig.aspectRatioCrop or 1.0
            local iconHeight = iconSize / aspectRatio
            local rowWidth = actualIconsInRow * iconSize + (actualIconsInRow - 1) * rowConfig.padding
            local startX = -rowWidth / 2 + iconSize / 2
            local rowCenterY
            if growDirection == "up" then
                rowCenterY = currentY + (iconHeight / 2) + rowConfig.yOffset
            else
                rowCenterY = currentY - (iconHeight / 2) + rowConfig.yOffset
            end
            
            for col, entry in ipairs(entriesInRow) do
                local iconOffsetX = startX + (col - 1) * (iconSize + rowConfig.padding)
                
                pcall(function()
                    if module.FrameManager then
                        module.FrameManager.PositionFrame(entry.frame, iconOffsetX, rowCenterY, viewer)
                    else
                        entry.frame:ClearAllPoints()
                        entry.frame:SetPoint("CENTER", viewer, "CENTER", iconOffsetX, rowCenterY)
                    end
                    entry.frame:Show()
                end)
            end
            
            ApplyRowBorder(viewer, rowNum, rowConfig, rowWidth, iconHeight, 0, rowCenterY)
        end
        
        local iconSize = rowConfig.size
        local aspectRatio = rowConfig.aspectRatioCrop or 1.0
        local iconHeight = iconSize / aspectRatio
        if growDirection == "up" then
            currentY = currentY + iconHeight + rowGap
        else
            currentY = currentY - iconHeight - rowGap
        end
    end
    
    if maxRowWidth > 0 and totalHeight > 0 then
        pcall(function()
            viewer:SetSize(maxRowWidth, totalHeight)
        end)
    end
end

function LayoutEngine.LayoutViewer(viewerKey)
    if layoutRunning[viewerKey] then return end
    layoutRunning[viewerKey] = true
    
    local viewer = GetViewerFrame(viewerKey)
    if not viewer then
        layoutRunning[viewerKey] = false
        return
    end
    
    local settings = module:GetViewerSettings(viewerKey)
    if not settings or settings.enabled == false then
        local viewer = GetViewerFrame(viewerKey)
        if viewer then
            viewer:Hide()
        end
        layoutRunning[viewerKey] = false
        return
    end
    
    if viewerKey == "buff" then
        local blizzBuffViewer = _G["BuffIconCooldownViewer"]
        if blizzBuffViewer and not blizzBuffViewer:IsShown() then
            local viewer = GetViewerFrame(viewerKey)
            if viewer then
                viewer:Hide()
            end
            layoutRunning[viewerKey] = false
            return
        end
    end
    
    local viewer = GetViewerFrame(viewerKey)
    if viewer then
        viewer:Show()
    end
    
    local activeRows = GetActiveRows(settings)
    if #activeRows == 0 then
        layoutRunning[viewerKey] = false
        return
    end
    
    local allEntries = module.EntrySystem.GetMergedEntriesForViewer(viewerKey)
    local entriesToLayout = FilterEntries(allEntries, viewerKey, settings)
    
    if #entriesToLayout == 0 then
        layoutRunning[viewerKey] = false
        return
    end
    
    local rowDistribution = CalculateRows(entriesToLayout, activeRows, viewerKey)
    ApplyLayout(viewer, rowDistribution, activeRows, viewerKey)
    
    if module.Styler then
        module.Styler.ApplyViewerStyling(viewer, rowDistribution, activeRows, viewerKey)
    end
    
    if module.Keybinds then
        module.Keybinds.UpdateViewer(viewerKey, entriesToLayout)
    end
    
    if module.Anchoring then
        module.Anchoring.ApplyAnchorsAfterLayout(viewerKey)
    end
    
    layoutRunning[viewerKey] = false
end

function LayoutEngine.Initialize()
    layoutRunning = {}
    layoutThrottle = {}
    module:LogInfo("LayoutEngine initialized")
end

LayoutEngine.GetViewerFrame = GetViewerFrame
LayoutEngine.GetActiveRows = GetActiveRows
LayoutEngine.GetCapacity = GetCapacity
LayoutEngine.CalculateRowDimensions = CalculateRowDimensions
LayoutEngine.FilterEntries = FilterEntries
LayoutEngine.CalculateRows = CalculateRows

module.LayoutEngine = LayoutEngine
