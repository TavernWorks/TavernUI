-- TavernUI Pixel Perfect Scaling
-- Provides utilities for pixel-perfect UI element sizing and positioning

local TavernUI = _G.TavernUI
if not TavernUI then return end

TavernUI.PixelPerfect = {}
local PP = TavernUI.PixelPerfect

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

-- Round a number to specified decimal places
local function RoundNumber(value, decimals)
    if not decimals or decimals == 0 then
        return value >= 0 and math.floor(value + 0.5) or math.ceil(value - 0.5)
    end

    local multiplier = 10 ^ decimals
    return RoundNumber(value * multiplier) / multiplier
end

--------------------------------------------------------------------------------
-- Resolution and Scaling
--------------------------------------------------------------------------------

-- Get the physical screen dimensions
function PP.GetScreenDimensions()
    return GetPhysicalScreenSize()
end

-- Calculate the ideal UI scale for pixel-perfect rendering
-- WoW renders pixel-perfect at 768 vertical resolution
function PP.CalculateIdealScale()
    local _, verticalRes = PP.GetScreenDimensions()
    if not verticalRes then
        return 1
    end
    return 768 / verticalRes
end

-- Get recommended scale with multipliers for common resolutions
function PP.GetRecommendedScale()
    local pixelScale = PP.CalculateIdealScale()
    local multiplier

    -- Adjust multiplier based on resolution
    if pixelScale >= 0.71 then      -- 1080p
        multiplier = 1.0
    elseif pixelScale >= 0.53 then  -- 1440p
        multiplier = 1.2
    else                            -- 4K
        multiplier = 1.7
    end

    local recommended = pixelScale / UIParent:GetScale() * multiplier
    return Clamp(RoundNumber(recommended, 2), 0.5, 2)
end

--------------------------------------------------------------------------------
-- Frame Scaling
--------------------------------------------------------------------------------

-- Get pixel-perfect size; optional region (frame) uses its effective scale, else UIParent; optional minPixels passed to PixelUtil
function PP.Scale(desiredSize, region, minPixels)
    if desiredSize == 0 and (not minPixels or minPixels == 0) then return 0 end
    local scale
    if region and region.GetEffectiveScale and region:GetEffectiveScale() and region:GetEffectiveScale() > 0 then
        scale = region:GetEffectiveScale()
    else
        scale = UIParent:GetEffectiveScale()
    end
    if not PixelUtil or not PixelUtil.GetNearestPixelSize then
        return desiredSize
    end
    if minPixels ~= nil then
        return PixelUtil.GetNearestPixelSize(desiredSize, scale, minPixels)
    end
    return PixelUtil.GetNearestPixelSize(desiredSize, scale)
end

-- Snap a position offset to pixel boundaries (for use with SetPoint offsets)
-- Unlike Scale, this doesn't enforce a minimum pixel size
function PP.SnapPosition(value, region)
    if not PixelUtil or not PixelUtil.GetNearestPixelSize then return value end
    local scale
    if region and region.GetEffectiveScale and region:GetEffectiveScale() and region:GetEffectiveScale() > 0 then
        scale = region:GetEffectiveScale()
    else
        scale = UIParent:GetEffectiveScale()
    end
    if scale and scale > 0 then
        return PixelUtil.GetNearestPixelSize(value, scale)
    end
    return value
end

-- Set frame size with pixel-perfect scaling (uses frame's effective scale)
function PP.Size(frame, width, height)
    frame._ppWidth = width
    frame._ppHeight = height
    if width and height then
        frame:SetSize(PP.Scale(width, frame), PP.Scale(height, frame))
    end
end

function PP.Width(frame, width)
    frame._ppWidth = width
    frame:SetWidth(PP.Scale(width, frame))
end

function PP.Height(frame, height)
    frame._ppHeight = height
    frame:SetHeight(PP.Scale(height, frame))
end

--------------------------------------------------------------------------------
-- Positioning
--------------------------------------------------------------------------------

-- Set frame point with pixel-perfect offsets
-- Usage: PP.Point(frame, "TOPLEFT", parent, "BOTTOMLEFT", 10, 20)
--        PP.Point(frame, "CENTER", parent, 0, 0)
--        PP.Point(frame, "TOPLEFT")
function PP.Point(frame, ...)
    if not frame._ppPoints then
        frame._ppPoints = {}
    end

    local args = {...}
    local point, relativeTo, relativePoint, x, y

    if #args == 1 then
        -- Simple point like "CENTER"
        point = args[1]
        relativeTo = frame:GetParent()
        relativePoint = point
        x, y = 0, 0
    elseif #args == 3 and type(args[2]) == "number" then
        -- Point with offsets: "CENTER", 10, 20
        point = args[1]
        relativeTo = frame:GetParent()
        relativePoint = point
        x, y = args[2], args[3]
    elseif #args == 4 then
        -- Point with frame and offsets: "CENTER", parent, 10, 20
        point, relativeTo, x, y = args[1], args[2], args[3], args[4]
        relativePoint = point
    else
        -- Full point spec: "TOPLEFT", parent, "BOTTOMRIGHT", 10, 20
        point, relativeTo, relativePoint, x, y = args[1], args[2], args[3], args[4], args[5]
    end

    -- Store for reapplication
    table.insert(frame._ppPoints, {
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint,
        xOffset = x or 0,
        yOffset = y or 0
    })

    frame:SetPoint(point, relativeTo, relativePoint, PP.Scale(x or 0, frame), PP.Scale(y or 0, frame))
end

-- Clear all frame points
function PP.ClearPoints(frame)
    frame:ClearAllPoints()
    if frame._ppPoints then
        wipe(frame._ppPoints)
    end
end

--------------------------------------------------------------------------------
-- Reapplication (for when UI scale changes)
--------------------------------------------------------------------------------

function PP.UpdateSize(frame)
    if frame._ppWidth and frame._ppHeight then
        frame:SetSize(PP.Scale(frame._ppWidth, frame), PP.Scale(frame._ppHeight, frame))
    elseif frame._ppWidth then
        frame:SetWidth(PP.Scale(frame._ppWidth, frame))
    elseif frame._ppHeight then
        frame:SetHeight(PP.Scale(frame._ppHeight, frame))
    end
end

-- Reapply all frame points after scale change
function PP.UpdatePoints(frame)
    if not frame._ppPoints or #frame._ppPoints == 0 then return end

    frame:ClearAllPoints()
    for _, pointData in ipairs(frame._ppPoints) do
        frame:SetPoint(
            pointData.point,
            pointData.relativeTo,
            pointData.relativePoint,
            PP.Scale(pointData.xOffset, frame),
            PP.Scale(pointData.yOffset, frame)
        )
    end
end

-- Update both size and points
function PP.UpdateFrame(frame)
    PP.UpdateSize(frame)
    PP.UpdatePoints(frame)
end

--------------------------------------------------------------------------------
-- Position Calculation Helpers
--------------------------------------------------------------------------------

-- Calculate frame position relative to screen edges
-- Returns point, xOffset, yOffset that can be used to recreate the position
function PP.CalculateRelativePosition(frame)
    local frameX, frameY = frame:GetCenter()
    local screenCenterX, screenCenterY = UIParent:GetCenter()
    local screenWidth = UIParent:GetRight()

    local point, x, y

    -- Determine vertical anchor
    if frameY >= screenCenterY then
        point = "TOP"
        y = -(UIParent:GetTop() - frame:GetTop())
    else
        point = "BOTTOM"
        y = frame:GetBottom()
    end

    -- Determine horizontal anchor
    if frameX >= (screenWidth * 2 / 3) then
        point = point .. "RIGHT"
        x = frame:GetRight() - screenWidth
    elseif frameX <= (screenWidth / 3) then
        point = point .. "LEFT"
        x = frame:GetLeft()
    else
        -- Center horizontal
        x = frameX - screenCenterX
    end

    return point, RoundNumber(x, 1), RoundNumber(y, 1)
end

-- Save frame position to a table
function PP.SavePosition(frame, positionTable)
    wipe(positionTable)
    local point, x, y = PP.CalculateRelativePosition(frame)
    positionTable[1] = point
    positionTable[2] = x
    positionTable[3] = y
end

-- Load frame position from a saved table
function PP.LoadPosition(frame, positionTable)
    if type(positionTable) ~= "table" or #positionTable < 3 then
        return false
    end

    PP.ClearPoints(frame)
    frame:SetPoint(positionTable[1], UIParent, positionTable[1], positionTable[2], positionTable[3])
    return true
end
