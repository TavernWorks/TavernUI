local TavernUI = TavernUI
if not TavernUI then return end

local EDGE_FILE = "Interface\\Buttons\\WHITE8x8"
local floor = math.floor

local function PixelPerfectBorder(value)
    if not value or value <= 0 then return 0 end
    local _, screenHeight = GetPhysicalScreenSize()
    local uiScale = UIParent and UIParent:GetEffectiveScale() or 1
    if not screenHeight or screenHeight <= 0 or not uiScale or uiScale <= 0 then return value end
    local pixelSize = 768 / screenHeight / uiScale
    return pixelSize * floor(value / pixelSize + 0.5333)
end

function TavernUI:EnsureBorderOverlay(parent, contentFrame)
    if not parent then return nil end
    if not parent.borderOverlay then
        parent.borderOverlay = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        if parent.SetClipsChildren then
            parent:SetClipsChildren(false)
        end
    end
    local base = parent.GetFrameLevel and parent:GetFrameLevel() or 0
    parent.borderOverlay:SetFrameLevel(base + 20)
    parent.borderOverlay:Show()
    return parent.borderOverlay
end

function TavernUI:ApplyBorder(frame, config, options)
    if not frame then return end

    local border = config or {}
    local hasSize = type(border.size) == "number"
    local enabled = (border.enabled ~= false) and (not hasSize or border.size > 0)
    local overlay = frame.borderOverlay

    if not enabled then
        if frame.SetBackdrop then frame:SetBackdrop(nil) end
        if overlay then
            if overlay.SetBackdrop then overlay:SetBackdrop(nil) end
            overlay:ClearAllPoints()
            overlay:SetAllPoints(frame)
        end
        if options and options.contentRegion then
            options.contentRegion:ClearAllPoints()
            options.contentRegion:SetAllPoints(frame)
        end
        return
    end

    local borderExtent = (type(border.size) == "number" and border.size >= 0) and math.max(1, border.size) or 1
    local c = border.color or {}
    local r, g, b = (c.r or 0), (c.g or 0), (c.b or 0)
    local a = (type(c.a) == "number") and c.a or 1

    self:EnsureBorderOverlay(frame, options and options.contentRegion)
    overlay = frame.borderOverlay

    overlay:ClearAllPoints()
    overlay:SetPoint("TOPLEFT", frame, "TOPLEFT", -borderExtent, borderExtent)
    overlay:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", borderExtent, -borderExtent)

    if overlay.SetBackdrop then
        overlay:SetBackdrop({
            edgeFile = EDGE_FILE,
            edgeSize = borderExtent,
            -- Insets should be 0 for an edge-only backdrop
            -- The edge draws AT the frame boundary, not inside it
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        overlay:SetBackdropColor(0, 0, 0, 0)
        overlay:SetBackdropBorderColor(r, g, b, a)
    end

    -- Content region stays at full size of the original frame
    if options and options.contentRegion then
        options.contentRegion:ClearAllPoints()
        options.contentRegion:SetAllPoints(frame)
    end
end

-- Helper function to apply a simple 1px border quickly
function TavernUI:ApplySimpleBorder(frame, r, g, b, a)
    self:ApplyBorder(frame, {
        enabled = true,
        size = 1,
        color = { r = r or 0, g = g or 0, b = b or 0, a = a or 1 }
    })
end

-- Helper function to remove border
function TavernUI:RemoveBorder(frame)
    self:ApplyBorder(frame, { enabled = false })
end

function TavernUI:ApplyPixelBorder(parentFrame, borderSize, color, options)
    if not parentFrame then return end
    options = options or {}
    local borderKey = options.overlayKey or "__pixelBorderOverlay"
    local borderAnchor = parentFrame.Icon or parentFrame
    local c = color or { r = 0, g = 0, b = 0, a = 1 }
    local r, g, b = c.r or 0, c.g or 0, c.b or 0
    local a = type(c.a) == "number" and c.a or 1

    if (borderSize or 0) <= 0 then
        local borders = parentFrame[borderKey]
        if borders and type(borders) == "table" then
            for _, tex in ipairs(borders) do
                if tex then tex:Hide() end
            end
        end
        return
    end

    local borders = parentFrame[borderKey]
    if not borders or type(borders) ~= "table" or #borders ~= 4 then
        local function CreateBorderLine() return parentFrame:CreateTexture(nil, "OVERLAY") end
        parentFrame[borderKey] = {
            CreateBorderLine(),
            CreateBorderLine(),
            CreateBorderLine(),
            CreateBorderLine(),
        }
        borders = parentFrame[borderKey]
    end

    local inset = PixelPerfectBorder(0)
    local thicknessUI = PixelPerfectBorder(math.max(1, borderSize))
    local top, bottom, left, right = borders[1], borders[2], borders[3], borders[4]

    top:ClearAllPoints()
    top:SetPoint("TOPLEFT", borderAnchor, "TOPLEFT", thicknessUI, -inset)
    top:SetPoint("TOPRIGHT", borderAnchor, "TOPRIGHT", -thicknessUI, -inset)
    top:SetHeight(thicknessUI)
    top:SetColorTexture(r, g, b, a)

    bottom:ClearAllPoints()
    bottom:SetPoint("BOTTOMLEFT", borderAnchor, "BOTTOMLEFT", thicknessUI, inset)
    bottom:SetPoint("BOTTOMRIGHT", borderAnchor, "BOTTOMRIGHT", -thicknessUI, inset)
    bottom:SetHeight(thicknessUI)
    bottom:SetColorTexture(r, g, b, a)

    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", borderAnchor, "TOPLEFT", inset, -inset)
    left:SetPoint("BOTTOMLEFT", borderAnchor, "BOTTOMLEFT", inset, inset)
    left:SetWidth(thicknessUI)
    left:SetColorTexture(r, g, b, a)

    right:ClearAllPoints()
    right:SetPoint("TOPRIGHT", borderAnchor, "TOPRIGHT", -inset, -inset)
    right:SetPoint("BOTTOMRIGHT", borderAnchor, "BOTTOMRIGHT", -inset, inset)
    right:SetWidth(thicknessUI)
    right:SetColorTexture(r, g, b, a)

    top:Show()
    bottom:Show()
    left:Show()
    right:Show()
end
