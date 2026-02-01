local TavernUI = TavernUI
if not TavernUI then return end

--[[
    Pixel layout: single source for "N pixels" -> UI units.

    Rule: Use GetPixelSize(region, pixels, direction) for any size or offset you want
    in physical pixels. Pass the result to SetSize/SetPoint or to PixelSetSize/PixelSetPoint.
    PixelSetSize / PixelSetPoint are thin wrappers (no snapping); pixel-perfectness
    comes from always converting via GetPixelSize before setting.

    GetPixelSize(region, pixels, direction) -> UI units (direction: 0 round, 1 ceil, -1 floor)
    PixelSetSize(region, wUI, hUI) / PixelSetPoint(region, point, relTo, relPoint, xUI, yUI)
]]

-- Cache for performance
local floor, ceil, abs = math.floor, math.ceil, math.abs

function TavernUI:GetEffectiveScale(region)
    if region and region.GetEffectiveScale then
        local scale = region:GetEffectiveScale()
        if scale and scale > 0 then
            return scale
        end
    end
    if UIParent and UIParent.GetEffectiveScale then
        local scale = UIParent:GetEffectiveScale()
        if scale and scale > 0 then
            return scale
        end
    end
    return 1
end

local function GetEffectiveScale(region)
    return TavernUI:GetEffectiveScale(region)
end

-- Convert a desired physical pixel size to UI units for a given region
-- This is the inverse of what the game does (UI units * scale = pixels)
-- Result: the UI unit value that will render as exactly N pixels
function TavernUI:GetPixelSize(region, physicalPixels, direction)
    if not physicalPixels then
        return 0
    end
    if physicalPixels <= 0 then
        return physicalPixels
    end

    local scale = GetEffectiveScale(region)

    -- Convert to UI units and snap to pixel grid
    -- physicalPixels / scale = UI units
    -- But we need to ensure the result * scale = whole number
    local uiUnits = physicalPixels / scale

    direction = direction or 0
    if direction > 0 then
        -- Round up - ensure at least this many pixels
        uiUnits = ceil(uiUnits * scale) / scale
    elseif direction < 0 then
        -- Round down
        uiUnits = floor(uiUnits * scale) / scale
    else
        -- Round to nearest
        uiUnits = floor(uiUnits * scale + 0.5) / scale
    end

    return uiUnits
end

-- Font size in WoW is in "points"; rendered height depends on UI scale. Returns point size that renders as whole pixel height.
function TavernUI:SnappedFontSize(region, pointSize)
    if not pointSize or pointSize <= 0 then return pointSize or 0 end
    local scale = GetEffectiveScale(region)
    if not scale or scale <= 0 then return pointSize end
    local pixelHeight = pointSize * scale
    local snapped = floor(pixelHeight + 0.5)
    return snapped / scale
end

function TavernUI:GetPhysicalPixels(region, uiUnits)
    if not uiUnits or uiUnits <= 0 then
        return 0
    end
    local scale = GetEffectiveScale(region)
    return floor(uiUnits * scale + 0.5)
end

-- Divide total width (in pixels) into segmentCount segments with gapPx between each.
-- Returns integer segment width (at least 1). Use this for layout math; then GetPixelSize(region, result, 0) for UI.
function TavernUI:DistributeIntegerPixels(totalWidthPx, segmentCount, gapPx)
    if not segmentCount or segmentCount < 1 then return 1 end
    totalWidthPx = totalWidthPx or 0
    gapPx = gapPx or 0
    local totalGap = (segmentCount - 1) * gapPx
    local available = totalWidthPx - totalGap
    return math.max(1, floor(available / segmentCount))
end

-- Layout N segments in a row: total width/height in pixels, gap between segments.
-- Returns integer segmentWidthPx, segmentHeightPx. Convert to UI with GetPixelSize(region, w, 0), GetPixelSize(region, h, 1).
function TavernUI:LayoutSegmentsInPixels(totalWidthPx, totalHeightPx, segmentCount, gapPx)
    local segW = self:DistributeIntegerPixels(totalWidthPx, segmentCount, gapPx)
    local segH = math.max(1, floor(totalHeightPx or 0))
    return segW, segH
end

-- Same as LayoutSegmentsInPixels but returns UI units for the segment size (for region's scale).
-- Use when setting segment frame size: segment:SetSize(segW_ui, segH_ui).
function TavernUI:SegmentSizeUI(region, totalWidthPx, totalHeightPx, segmentCount, gapPx)
    local segW_px, segH_px = self:LayoutSegmentsInPixels(totalWidthPx, totalHeightPx, segmentCount, gapPx)
    return self:GetPixelSize(region, segW_px, 0), self:GetPixelSize(region, segH_px, 1)
end

-- Snap a UI unit value to the nearest pixel boundary
function TavernUI:SnapToPixel(region, uiUnits, direction)
    if not uiUnits then
        return 0
    end
    local scale = GetEffectiveScale(region)
    direction = direction or 0

    if direction > 0 then
        return ceil(uiUnits * scale) / scale
    elseif direction < 0 then
        return floor(uiUnits * scale) / scale
    else
        return floor(uiUnits * scale + 0.5) / scale
    end
end

-- Snap a rect (center + size) so all four edges land on whole pixels. Returns left_ui, top_ui, width_ui, height_ui for TOPLEFT+SetSize.
function TavernUI:SnapRectToPixel(region, centerX_ui, centerY_ui, width_ui, height_ui)
    if not region then return centerX_ui or 0, centerY_ui or 0, width_ui or 0, height_ui or 0 end
    local scale = GetEffectiveScale(region)
    width_ui = width_ui or 0
    height_ui = height_ui or 0
    centerX_ui = centerX_ui or 0
    centerY_ui = centerY_ui or 0
    local left_px = (centerX_ui - width_ui * 0.5) * scale
    local bottom_px = (centerY_ui - height_ui * 0.5) * scale
    local right_px = left_px + width_ui * scale
    local top_px = bottom_px + height_ui * scale
    left_px = floor(left_px + 0.5)
    bottom_px = floor(bottom_px + 0.5)
    right_px = floor(right_px + 0.5)
    top_px = floor(top_px + 0.5)
    local left_ui = left_px / scale
    local top_ui = top_px / scale
    width_ui = (right_px - left_px) / scale
    height_ui = (top_px - bottom_px) / scale
    return left_ui, top_ui, width_ui, height_ui
end

-- Thin wrappers: pass UI units from GetPixelSize(region, pixels, direction). No extra snapping.
function TavernUI:PixelSetSize(region, width, height)
    if region and region.SetSize then
        region:SetSize(width or 0, height or 0)
    end
end

function TavernUI:PixelSetPoint(region, point, relativeTo, relativePoint, offsetX, offsetY)
    if region and region.SetPoint then
        region:SetPoint(point, relativeTo, relativePoint, offsetX or 0, offsetY or 0)
    end
end

function TavernUI:PixelSetWidth(region, width)
    if region and region.SetWidth then
        region:SetWidth(width or 0)
    end
end

function TavernUI:PixelSetHeight(region, height)
    if region and region.SetHeight then
        region:SetHeight(height or 0)
    end
end

-- Calculate pixel-perfect dimensions for a frame that will have a custom scale applied
-- Use this BEFORE applying a custom scale to pre-calculate the correct sizes
function TavernUI:GetPixelSizeForScale(region, physicalPixels, customScale, direction)
    if not physicalPixels or physicalPixels <= 0 then
        return physicalPixels or 0
    end

    -- Get the base effective scale (without the custom scale)
    local baseScale = GetEffectiveScale(region)

    -- The final effective scale will be baseScale * customScale
    -- But if region already has the custom scale applied, we need the parent's scale
    local finalScale = baseScale
    if customScale and customScale > 0 then
        -- Assume we're calculating for BEFORE the scale is applied
        -- So the final scale will be current * customScale
        finalScale = baseScale * customScale
    end

    direction = direction or 0
    local uiUnits = physicalPixels / finalScale

    if direction > 0 then
        uiUnits = ceil(uiUnits * finalScale) / finalScale
    elseif direction < 0 then
        uiUnits = floor(uiUnits * finalScale) / finalScale
    else
        uiUnits = floor(uiUnits * finalScale + 0.5) / finalScale
    end

    return uiUnits
end

-- Utility: Check if a frame's current size is pixel-aligned
function TavernUI:IsPixelAligned(region)
    if not region or not region.GetSize then
        return false
    end

    local scale = GetEffectiveScale(region)
    local width, height = region:GetSize()

    local pixelWidth = width * scale
    local pixelHeight = height * scale

    -- Check if within 0.01 of a whole number
    local widthAligned = abs(pixelWidth - floor(pixelWidth + 0.5)) < 0.01
    local heightAligned = abs(pixelHeight - floor(pixelHeight + 0.5)) < 0.01

    return widthAligned and heightAligned
end