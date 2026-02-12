local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)
if not module or not module.CooldownItem then return end

local CooldownItem = module.CooldownItem
local PP = TavernUI.PixelPerfect

local function GetIcon(frame)
    return frame and (frame.Icon or frame.icon)
end
local function GetCooldown(frame)
    return frame and (frame.Cooldown or frame.cooldown)
end
local function GetCount(frame)
    return frame and (frame.Count or frame.count)
end

local TEXT_OVERLAY_LEVEL = 600
local SWIPE_TEXTURE = ""
local BLIZZARD_ICON_OVERLAY_ATLAS = "UI-HUD-CoolDownManager-IconOverlay"

function CooldownItem:_applyBorder(borderSize, borderColor, iconStyle)
    local frame = self.frame
    if not frame then return end

    borderSize = borderSize or 0
    iconStyle = iconStyle or "square"
    local useRounded = (iconStyle == "blizzard") and borderSize and borderSize > 0

    local borderAnchor = frame
    local cooldown = GetCooldown(frame)
    local cooldownLevel = (cooldown and cooldown.GetFrameLevel) and cooldown:GetFrameLevel() or 0
    local frameLevel = (frame and frame.GetFrameLevel) and frame:GetFrameLevel() or 0
    local baseLevel = (cooldownLevel > frameLevel) and cooldownLevel or frameLevel

    frame._ucdmBorders = frame._ucdmBorders or {}
    if #frame._ucdmBorders == 0 then
        local overlay = CreateFrame("Frame", nil, frame)
        overlay:SetAllPoints(frame)
        frame._ucdmBorderOverlay = overlay

        local function CreateBorderLine()
            local border = overlay:CreateTexture(nil, "OVERLAY")
            if border.SetSnapToPixelGrid then border:SetSnapToPixelGrid(true) end
            if border.SetTexelSnappingBias then border:SetTexelSnappingBias(0.5) end
            return border
        end
        local borderInset = 0
        local topBorder = CreateBorderLine()
        topBorder:SetPoint("TOPLEFT", borderAnchor, "TOPLEFT", borderInset, -borderInset)
        topBorder:SetPoint("TOPRIGHT", borderAnchor, "TOPRIGHT", -borderInset, -borderInset)
        local bottomBorder = CreateBorderLine()
        bottomBorder:SetPoint("BOTTOMLEFT", borderAnchor, "BOTTOMLEFT", borderInset, borderInset)
        bottomBorder:SetPoint("BOTTOMRIGHT", borderAnchor, "BOTTOMRIGHT", -borderInset, borderInset)
        local leftBorder = CreateBorderLine()
        leftBorder:SetPoint("TOPLEFT", borderAnchor, "TOPLEFT", borderInset, -borderInset)
        leftBorder:SetPoint("BOTTOMLEFT", borderAnchor, "BOTTOMLEFT", borderInset, borderInset)
        local rightBorder = CreateBorderLine()
        rightBorder:SetPoint("TOPRIGHT", borderAnchor, "TOPRIGHT", -borderInset, -borderInset)
        rightBorder:SetPoint("BOTTOMRIGHT", borderAnchor, "BOTTOMRIGHT", -borderInset, borderInset)
        frame._ucdmBorders = { topBorder, bottomBorder, leftBorder, rightBorder }
    end

    if frame._ucdmBorderOverlay then
        frame._ucdmBorderOverlay:SetFrameLevel(baseLevel + 1)
    end
    if not frame._ucdmRoundedBorder and frame._ucdmBorderOverlay then
        local tex = frame._ucdmBorderOverlay:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints(frame)
        if tex.SetAtlas then tex:SetAtlas(BLIZZARD_ICON_OVERLAY_ATLAS) end
        frame._ucdmRoundedBorder = tex
    end

    local bc = borderColor or { r = 0, g = 0, b = 0, a = 1 }
    frame._ucdmOriginalBorderColor = { r = bc.r, g = bc.g, b = bc.b, a = bc.a }
    frame._ucdmOriginalBorderWidth = borderSize

    if borderSize <= 0 then
        if frame._ucdmRoundedBorder then frame._ucdmRoundedBorder:Hide() end
        for _, border in ipairs(frame._ucdmBorders) do border:Hide() end
        return
    end
    if useRounded and frame._ucdmRoundedBorder then
        frame._ucdmRoundedBorder:SetVertexColor(bc.r, bc.g, bc.b, bc.a)
        frame._ucdmRoundedBorder:Show()
        for _, border in ipairs(frame._ucdmBorders) do border:Hide() end
        return
    end
    if frame._ucdmRoundedBorder then frame._ucdmRoundedBorder:Hide() end

    local top, bottom, left, right = unpack(frame._ucdmBorders)
    if not (top and bottom and left and right) then return end
    local pixelSize = PP.Scale(borderSize, frame, 0)
    if pixelSize <= 0 then
        for _, border in ipairs(frame._ucdmBorders) do border:Hide() end
        return
    end
    top:SetHeight(pixelSize)
    bottom:SetHeight(pixelSize)
    left:SetWidth(pixelSize)
    right:SetWidth(pixelSize)
    for _, border in ipairs(frame._ucdmBorders) do
        border:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
        border:Show()
    end
end

function CooldownItem:_setBorderColor(r, g, b, a)
    local frame = self.frame
    if not frame then return end
    a = a or (frame._ucdmOriginalBorderColor and frame._ucdmOriginalBorderColor.a) or 1
    if frame._ucdmRoundedBorder and frame._ucdmRoundedBorder:IsShown() then
        frame._ucdmRoundedBorder:SetVertexColor(r, g, b, a)
    end
    if frame._ucdmBorders then
        for _, border in ipairs(frame._ucdmBorders) do
            border:SetColorTexture(r, g, b, a)
        end
    end
end

function CooldownItem:_restoreBorderColor()
    local frame = self.frame
    if not frame or not frame._ucdmOriginalBorderColor then return end
    local bc = frame._ucdmOriginalBorderColor
    self:_setBorderColor(bc.r, bc.g, bc.b, bc.a)
end

function CooldownItem:_setBorderWidth(width)
    local frame = self.frame
    if not frame or not frame._ucdmBorders then return end
    if frame._ucdmRoundedBorder and frame._ucdmRoundedBorder:IsShown() then return end
    if not frame._ucdmOriginalBorderWidth then
        local top = frame._ucdmBorders[1]
        if top then frame._ucdmOriginalBorderWidth = top:GetHeight() end
    end
    local pixelSize = PP and PP.Scale(width, frame, 0) or width
    local top, bottom, left, right = unpack(frame._ucdmBorders)
    if top then top:SetHeight(pixelSize) end
    if bottom then bottom:SetHeight(pixelSize) end
    if left then left:SetWidth(pixelSize) end
    if right then right:SetWidth(pixelSize) end
    if width and width > 0 then
        for _, b in ipairs(frame._ucdmBorders) do b:Show() end
    end
end

function CooldownItem:_restoreBorderWidth()
    local frame = self.frame
    if not frame or not frame._ucdmBorders or frame._ucdmOriginalBorderWidth == nil then return end
    local pixelSize = PP and PP.Scale(frame._ucdmOriginalBorderWidth, frame, 0) or frame._ucdmOriginalBorderWidth
    local top, bottom, left, right = unpack(frame._ucdmBorders)
    if top then top:SetHeight(pixelSize) end
    if bottom then bottom:SetHeight(pixelSize) end
    if left then left:SetWidth(pixelSize) end
    if right then right:SetWidth(pixelSize) end
    if pixelSize <= 0 then
        for _, b in ipairs(frame._ucdmBorders) do b:Hide() end
    end
end

local function SetTextLevel(textElement)
    if not textElement or not textElement.GetParent then return end
    local parent = textElement:GetParent()
    if parent and parent.GetObjectType and parent:GetObjectType() == "Frame" and parent.SetFrameLevel and parent.GetFrameLevel then
        local currentLevel = parent:GetFrameLevel() or 0
        if currentLevel < TEXT_OVERLAY_LEVEL then
            parent:SetFrameLevel(TEXT_OVERLAY_LEVEL)
        end
    end
end

local function SyncDurationTexts(cd, visible)
    if cd._ucdmDurationTexts then
        for txt in pairs(cd._ucdmDurationTexts) do txt:SetShown(visible) end
    end
end

function CooldownItem:_applyDurationTextStyle(textOverlay, scaleRef, config)
    local cooldown = GetCooldown(self.frame)
    if not cooldown then return end
    local size, point = config.size, config.point
    local offsetX, offsetY = config.offsetX, config.offsetY
    local viewerSettings = self.viewerKey and module:GetViewerSettings(self.viewerKey) or nil
    cooldown._ucdmDurationTexts = cooldown._ucdmDurationTexts or {}

    if cooldown.text then
        SetTextLevel(cooldown.text)
        cooldown.text:SetParent(textOverlay)
        TavernUI:ApplyFont(cooldown.text, scaleRef, size)
        cooldown.text:ClearAllPoints()
        cooldown.text:SetPoint(point, self.frame, point, offsetX, offsetY)
        if viewerSettings then module:ApplyTextColor(cooldown.text, viewerSettings, "durationTextColor") end
        cooldown._ucdmDurationTexts[cooldown.text] = true
    end
    for _, region in ipairs({cooldown:GetRegions()}) do
        if region and region.GetObjectType and region:GetObjectType() == "FontString" then
            SetTextLevel(region)
            region:SetParent(textOverlay)
            TavernUI:ApplyFont(region, scaleRef, size)
            region:ClearAllPoints()
            region:SetPoint(point, self.frame, point, offsetX, offsetY)
            if viewerSettings then module:ApplyTextColor(region, viewerSettings, "durationTextColor") end
            cooldown._ucdmDurationTexts[region] = true
        end
    end
    if not cooldown._ucdmDurationVisibilityHooked then
        cooldown._ucdmDurationVisibilityHooked = true
        hooksecurefunc(cooldown, "Hide", function(self) SyncDurationTexts(self, false) end)
        hooksecurefunc(cooldown, "Show", function(self) SyncDurationTexts(self, true) end)
        hooksecurefunc(cooldown, "SetShown", function(self, shown) SyncDurationTexts(self, shown) end)
        cooldown:HookScript("OnHide", function(self) SyncDurationTexts(self, false) end)
        cooldown:HookScript("OnShow", function(self) SyncDurationTexts(self, true) end)
    end
end

function CooldownItem:_applyStackTextStyle(textOverlay, scaleRef, config)
    local frame = self.frame
    local size, point = config.size, config.point
    local offsetX, offsetY = config.offsetX, config.offsetY
    local viewerSettings = self.viewerKey and module:GetViewerSettings(self.viewerKey) or nil

    local chargeFrame = frame.ChargeCount
    if chargeFrame then
        local fs = chargeFrame.Current or chargeFrame.Count or chargeFrame.count
        if fs then
            SetTextLevel(fs)
            fs:SetParent(textOverlay)
            TavernUI:ApplyFont(fs, scaleRef, size)
            fs:ClearAllPoints()
            fs:SetPoint(point, frame, point, offsetX, offsetY)
            if viewerSettings then module:ApplyTextColor(fs, viewerSettings, "stackTextColor") end
        end
    end
    local countText = GetCount(frame)
    if countText then
        SetTextLevel(countText)
        countText:SetParent(textOverlay)
        TavernUI:ApplyFont(countText, scaleRef, size)
        countText:ClearAllPoints()
        countText:SetPoint(point, frame, point, offsetX, offsetY)
        if viewerSettings then module:ApplyTextColor(countText, viewerSettings, "stackTextColor") end
    end
    local applicationsFrame = frame.Applications or frame.applications
    if applicationsFrame then
        local applicationsText = applicationsFrame
        if applicationsFrame.GetObjectType and applicationsFrame:GetObjectType() ~= "FontString" then
            applicationsText = applicationsFrame.Applications or applicationsFrame.Text or applicationsFrame.text
        end
        if applicationsText and applicationsText.GetObjectType and applicationsText:GetObjectType() == "FontString" then
            SetTextLevel(applicationsText)
            applicationsText:SetParent(textOverlay)
            TavernUI:ApplyFont(applicationsText, scaleRef, size)
            applicationsText:ClearAllPoints()
            applicationsText:SetPoint(point, frame, point, offsetX, offsetY)
            if viewerSettings then module:ApplyTextColor(applicationsText, viewerSettings, "stackTextColor") end
        end
    end
end

function CooldownItem:_applyTextStyle(rowConfig)
    local frame = self.frame
    if not frame then return end
    local scaleRef = module:GetViewerFrame(self.viewerKey) or frame
    local durationSize = rowConfig.durationSize or 0
    local stackSize = rowConfig.stackSize or 0
    if not frame._ucdmTextOverlay then
        frame._ucdmTextOverlay = CreateFrame("Frame", nil, frame)
        frame._ucdmTextOverlay:SetFrameLevel(TEXT_OVERLAY_LEVEL)
        frame._ucdmTextOverlay:SetAllPoints(frame)
    end
    local textOverlay = frame._ucdmTextOverlay
    textOverlay:SetFrameLevel(TEXT_OVERLAY_LEVEL)
    if durationSize > 0 then
        self:_applyDurationTextStyle(textOverlay, scaleRef, {
            size = durationSize,
            point = rowConfig.durationPoint or "CENTER",
            offsetX = PP.Scale(rowConfig.durationOffsetX or 0, scaleRef, 0),
            offsetY = PP.Scale(rowConfig.durationOffsetY or 0, scaleRef, 1),
        })
    end
    if stackSize > 0 then
        self:_applyStackTextStyle(textOverlay, scaleRef, {
            size = stackSize,
            point = rowConfig.stackPoint or "BOTTOMRIGHT",
            offsetX = PP.Scale(rowConfig.stackOffsetX or 0, scaleRef, 0),
            offsetY = PP.Scale(rowConfig.stackOffsetY or 0, scaleRef, 1),
        })
    end
end

function CooldownItem:_normalizeIconTexture()
    local frame = self.frame
    local iconTex = GetIcon(frame)
    if not iconTex then return end
    iconTex:ClearAllPoints()
    iconTex:SetAllPoints(frame)
    if iconTex.SetSnapToPixelGrid then iconTex:SetSnapToPixelGrid(false) end
    if iconTex.SetBlendMode then iconTex:SetBlendMode("BLEND") end
    local function normalizeMask(mask)
        if not mask then return end
        mask:ClearAllPoints()
        mask:SetAllPoints(iconTex)
        if mask.SetSnapToPixelGrid then mask:SetSnapToPixelGrid(true) end
    end
    normalizeMask(frame.IconMaskBlizzard)
    normalizeMask(frame.IconMaskSquare)
end

function CooldownItem:_normalizeCooldown()
    local cooldown = GetCooldown(self.frame)
    if not cooldown then return end
    cooldown:ClearAllPoints()
    cooldown:SetAllPoints(self.frame)
    if cooldown.SetEdgeScale then cooldown:SetEdgeScale(0) end
    cooldown:SetSwipeTexture(SWIPE_TEXTURE)
    cooldown:SetSwipeColor(0, 0, 0, 0.8)
    if cooldown.SetSnapToPixelGrid then cooldown:SetSnapToPixelGrid(true) end
    if cooldown.SetTexelSnappingBias then cooldown:SetTexelSnappingBias(0) end
end
