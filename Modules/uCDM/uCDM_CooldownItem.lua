local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local CooldownItem = {}
CooldownItem.__index = CooldownItem

local CONSTANTS = {
    MAX_MASK_TEXTURES = 10,
    TEXTURE_BASE_CROP_PIXELS = 4,  -- Blizzard icons have ~4px border artifacts
    TEXTURE_SOURCE_SIZE = 64,      -- Standard WoW icon texture size
}

-- Normalize frame element access (Blizzard uses inconsistent casing)
local function GetIcon(frame)
    return frame and (frame.Icon or frame.icon)
end

local function GetCooldown(frame)
    return frame and (frame.Cooldown or frame.cooldown)
end

local function GetCount(frame)
    return frame and (frame.Count or frame.count)
end

function CooldownItem.new(config)
    local self = setmetatable({}, CooldownItem)

    self.id = config.id
    self.source = config.source
    self.viewerKey = config.viewerKey
    self.frame = config.frame
    self.spellID = config.spellID
    self.itemID = config.itemID
    self.slotID = config.slotID
    self.actionSlotID = config.actionSlotID
    self.cooldownID = config.cooldownID
    self.index = config.index or 1
    self.layoutIndex = config.layoutIndex
    self.config = config.config
    self.enabled = config.enabled ~= false
    self._styled = false
    self._lastRowConfig = nil

    return self
end

function CooldownItem:isVisible()
    if not self.enabled then return false end
    if not self.frame then return false end

    if self.source == "blizzard" and self.viewerKey == "buff" then
        return self:_checkBuffVisibility()
    end

    return true
end

function CooldownItem:_checkBuffVisibility()
    local frame = self.frame
    if not frame then return false end

    local cooldownID = frame.GetCooldownID and frame:GetCooldownID()
    if not cooldownID then return false end

    if not frame.allowHideWhenInactive then return true end
    if not frame.hideWhenInactive then return true end

    return frame.auraInstanceID ~= nil
end

function CooldownItem:setInLayout(inLayout)
    if not self.frame then return end
    if inLayout then
        self.frame:Show()
    else
        self.frame:Hide()
        self.frame:ClearAllPoints()
    end
end

function CooldownItem:setParent(parent)
    if not self.frame then return end
    self.frame:SetParent(parent or UIParent)
end

function CooldownItem:setLayoutPosition(parent, relativeTo, x, y)
    if not self.frame then return end
    self:setParent(parent)
    self.frame:ClearAllPoints()
    local anchorTo = relativeTo or parent
    local scale = self.frame:GetEffectiveScale()
    local pxX = (PixelUtil and scale and scale > 0 and PixelUtil.GetNearestPixelSize(x, scale)) or x
    local pxY = (PixelUtil and scale and scale > 0 and PixelUtil.GetNearestPixelSize(y, scale)) or y
    self.frame:SetPoint("CENTER", anchorTo, "CENTER", pxX, pxY)
end

function CooldownItem:applyStyle(rowConfig)
    local frame = self.frame
    if not frame then return end

    if not self._styled then
        self:_setupFrame()
        self._styled = true
    end

    local iconSize = rowConfig.iconSize or rowConfig.size or 40
    local aspectRatio = rowConfig.aspectRatioCrop or 1.0
    local iconHeight = iconSize / aspectRatio
    local scaleRef = module:GetViewerFrame(self.viewerKey) or frame
    local pxW = TavernUI:GetPixelSize(scaleRef, iconSize, 0)
    local pxH = TavernUI:GetPixelSize(scaleRef, iconHeight, 1)
    local scale = frame:GetEffectiveScale() or 1
    if scale > 0 then
        pxW = math.floor(pxW * scale + 0.5) / scale
        pxH = math.floor(pxH * scale + 0.5) / scale
    end
    frame:SetSize(pxW, pxH)
    if frame.SetSnapToPixelGrid then frame:SetSnapToPixelGrid(true) end
    if frame.SetTexelSnappingBias then frame:SetTexelSnappingBias(0) end

    frame._ucdmZoom = rowConfig.zoom or 0
    frame._ucdmAspectRatio = aspectRatio
    frame._ucdmIconSize = iconSize

    self:_applyTexCoord(rowConfig)
    self:_applyIconStyle(rowConfig)
    self:_applyBorder(rowConfig.iconBorderSize, rowConfig.iconBorderColor)
    self:_applyTextStyle(rowConfig)
    self:_normalizeIconTexture()
    self:_normalizeCooldown()

    if self.source == "custom" then
        local viewerFrame = module:GetViewerFrame(self.viewerKey)
        if viewerFrame and viewerFrame.GetEffectiveScale and frame.GetEffectiveScale and frame.SetScale then
            local targetScale = viewerFrame:GetEffectiveScale()
            local currentScale = frame:GetEffectiveScale()
            if targetScale and currentScale and currentScale > 0 and math.abs(currentScale - targetScale) > 0.0001 then
                frame:SetScale((frame:GetScale() or 1) * targetScale / currentScale)
            end
        end
    end
    
    self._lastRowConfig = rowConfig
end

function CooldownItem:_setupFrame()
    local frame = self.frame
    if not frame then return end

    local name = frame.GetName and frame:GetName()
    local isCustomFrame = name and name:find("^uCDMCustomFrame_")

    if not isCustomFrame then
        self:_stripBlizzardCruft()
    end

    self:_setupIconMasks(frame)
    self:_setupCooldownStyle(frame)
    if isCustomFrame then
        self:_setupCustomFrameTooltips(frame)
    end
end

function CooldownItem:_setupIconMasks(frame)
    local iconTex = GetIcon(frame)
    if not iconTex then return end
    if not frame.IconMaskBlizzard then
        local maskBlizz = frame:CreateMaskTexture()
        maskBlizz:SetAtlas("UI-HUD-CoolDownManager-Mask")
        maskBlizz:SetAllPoints(iconTex)
        if maskBlizz.SetSnapToPixelGrid then maskBlizz:SetSnapToPixelGrid(true) end
        frame.IconMaskBlizzard = maskBlizz
    end
    if not frame.IconMaskSquare then
        local maskSquare = frame:CreateMaskTexture()
        maskSquare:SetTexture("Interface\\AddOns\\TavernUI\\assets\\masks\\square.tga")
        maskSquare:SetAllPoints(iconTex)
        if maskSquare.SetSnapToPixelGrid then maskSquare:SetSnapToPixelGrid(true) end
        frame.IconMaskSquare = maskSquare
    end
end

function CooldownItem:_setupCooldownStyle(frame)
    local cooldown = GetCooldown(frame)
    if not cooldown then return end
    if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
    if cooldown.SetDrawBling then cooldown:SetDrawBling(false) end
    if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture("Interface\\Buttons\\WHITE8X8") end
    if cooldown.SetSwipeColor then cooldown:SetSwipeColor(0, 0, 0, 0.8) end
    if not cooldown.__ucdmSwipeHooked and module.CooldownTracker then
        cooldown.__ucdmSwipeHooked = true
        if cooldown.SetCooldown then
            hooksecurefunc(cooldown, "SetCooldown", function(self) module.CooldownTracker.ApplySwipeStyle(self) end)
        end
        if cooldown.SetCooldownFromDurationObject then
            hooksecurefunc(cooldown, "SetCooldownFromDurationObject", function(self) module.CooldownTracker.ApplySwipeStyle(self) end)
        end
    end
end

function CooldownItem:_setupCustomFrameTooltips(frame)
    local item = self
    frame:SetScript("OnEnter", function()
        if module:GetSetting("viewers." .. (item.viewerKey or "custom") .. ".disableTooltips") then return end
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        if item.spellID then
            GameTooltip:SetSpellByID(item.spellID)
        elseif item.itemID then
            GameTooltip:SetItemByID(item.itemID)
        elseif item.slotID then
            GameTooltip:SetInventoryItem("player", item.slotID)
        elseif item.actionSlotID then
            GameTooltip:SetAction(item.actionSlotID)
        else
            GameTooltip:SetText(item.config and item.config.name or "Custom")
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function CooldownItem:_stripBlizzardCruft()
    local frame = self.frame
    if not frame then return end
    local iconTex = GetIcon(frame)
    if iconTex and iconTex.GetMaskTexture and iconTex.RemoveMaskTexture then
        for i = 1, CONSTANTS.MAX_MASK_TEXTURES do
            local mask = iconTex:GetMaskTexture(i)
            if mask then
                iconTex:RemoveMaskTexture(mask)
            end
        end
    end
    if frame.OutOfRange then frame.OutOfRange:Hide() end
end

function CooldownItem:_applyTexCoord(rowConfig)
    local frame = self.frame
    if not frame then return end
    
    local zoom = rowConfig.zoom or 0
    local aspectRatio = rowConfig.aspectRatioCrop or 1.0
    local iconSize = rowConfig.iconSize or 40
    
    local cropPixels = CONSTANTS.TEXTURE_BASE_CROP_PIXELS
    local sourceSize = CONSTANTS.TEXTURE_SOURCE_SIZE
    local baseCrop = (cropPixels * iconSize) / (sourceSize * sourceSize)
    
    local left = baseCrop + zoom
    local right = 1 - baseCrop - zoom
    local top = baseCrop + zoom
    local bottom = 1 - baseCrop - zoom

    if aspectRatio > 1.0 then
        local cropAmount = 1.0 - (1.0 / aspectRatio)
        local availableHeight = bottom - top
        local offset = (cropAmount * availableHeight) / 2.0
        top = top + offset
        bottom = bottom - offset
    end
    
    local tex = GetIcon(frame)
    if tex and tex.SetTexCoord then
        tex:SetTexCoord(left, right, top, bottom)
    end
end

function CooldownItem:_applyIconStyle(rowConfig)
    local frame = self.frame
    if not frame then return end

    local iconTex = GetIcon(frame)
    if not iconTex then return end

    local style = rowConfig.iconStyle or "blizzard"

    if iconTex.GetMaskTexture and iconTex.RemoveMaskTexture then
        for i = 1, CONSTANTS.MAX_MASK_TEXTURES do
            local mask = iconTex:GetMaskTexture(i)
            if not mask then
                break
            end
            iconTex:RemoveMaskTexture(mask)
        end
    end

    if style == "square" then
        if frame.IconMaskSquare and iconTex.AddMaskTexture then
            iconTex:AddMaskTexture(frame.IconMaskSquare)
        end
    else
        if frame.IconMaskBlizzard and iconTex.AddMaskTexture then
            iconTex:AddMaskTexture(frame.IconMaskBlizzard)
        end
    end
end

function CooldownItem:_applyBorder(borderSize, borderColor)
    local frame = self.frame
    if not frame then return end

    borderSize = borderSize or 0

    local iconBorderSize = borderSize
    if not iconBorderSize or iconBorderSize <= 0 then
        if frame._ucdmBorders then
            for _, border in ipairs(frame._ucdmBorders) do
                border:Hide()
            end
        end
        return
    end

    local borderAnchor = frame
    local cooldown = GetCooldown(frame)
    local cooldownLevel = (cooldown and cooldown.GetFrameLevel) and cooldown:GetFrameLevel() or 0

    frame._ucdmBorders = frame._ucdmBorders or {}
    if #frame._ucdmBorders == 0 then
        local overlay = CreateFrame("Frame", nil, frame)
        overlay:SetAllPoints(frame)
        frame._ucdmBorderOverlay = overlay

        local function CreateBorderLine()
            local border = overlay:CreateTexture(nil, "OVERLAY")
            if border.SetSnapToPixelGrid then
                border:SetSnapToPixelGrid(true)
            end
            if border.SetTexelSnappingBias then
                border:SetTexelSnappingBias(0)
            end
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
        frame._ucdmBorderOverlay:SetFrameLevel(cooldownLevel + 1)
    end

    local top, bottom, left, right = unpack(frame._ucdmBorders)
    if not (top and bottom and left and right) then return end

    local pixelSize = TavernUI:GetPixelSize(frame, iconBorderSize, 0)

    if pixelSize <= 0 then
        for _, border in ipairs(frame._ucdmBorders) do
            border:Hide()
        end
        return
    end

    top:SetHeight(pixelSize)
    bottom:SetHeight(pixelSize)
    left:SetWidth(pixelSize)
    right:SetWidth(pixelSize)

    local bc = borderColor or { r = 0, g = 0, b = 0, a = 1 }
    local shouldShow = iconBorderSize > 0
    for _, border in ipairs(frame._ucdmBorders) do
        border:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
        border:SetShown(shouldShow)
    end
end

function CooldownItem:_applyTextStyle(rowConfig)
    local frame = self.frame
    if not frame then return end

    local scaleRef = module:GetViewerFrame(self.viewerKey) or frame
    local durationSize = rowConfig.durationSize or 0
    local stackSize = rowConfig.stackSize or 0
    local durationPoint = rowConfig.durationPoint or "CENTER"
    local durationOffsetX = rowConfig.durationOffsetX or 0
    local durationOffsetY = rowConfig.durationOffsetY or 0
    local stackPoint = rowConfig.stackPoint or "BOTTOMRIGHT"
    local stackOffsetX = rowConfig.stackOffsetX or 0
    local stackOffsetY = rowConfig.stackOffsetY or 0

    local pxDurX = TavernUI:GetPixelSize(scaleRef, durationOffsetX, 0)
    local pxDurY = TavernUI:GetPixelSize(scaleRef, durationOffsetY, 1)
    local pxStackX = TavernUI:GetPixelSize(scaleRef, stackOffsetX, 0)
    local pxStackY = TavernUI:GetPixelSize(scaleRef, stackOffsetY, 1)

    if durationSize > 0 then
        local cooldown = GetCooldown(frame)
        if cooldown then
            if cooldown.text then
                TavernUI:ApplyFont(cooldown.text, scaleRef, durationSize)
                cooldown.text:ClearAllPoints()
                cooldown.text:SetPoint(durationPoint, frame, durationPoint, pxDurX, pxDurY)
            end
            for _, region in ipairs({cooldown:GetRegions()}) do
                if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                    TavernUI:ApplyFont(region, scaleRef, durationSize)
                    region:ClearAllPoints()
                    region:SetPoint(durationPoint, frame, durationPoint, pxDurX, pxDurY)
                end
            end
        end
    end

    if stackSize > 0 then
        local chargeFrame = frame.ChargeCount
        if chargeFrame then
            local fs = chargeFrame.Current or chargeFrame.Count or chargeFrame.count
            if fs then
                TavernUI:ApplyFont(fs, scaleRef, stackSize)
                fs:ClearAllPoints()
                fs:SetPoint(stackPoint, frame, stackPoint, pxStackX, pxStackY)
            end
        end

        local countText = GetCount(frame)
        if countText then
            TavernUI:ApplyFont(countText, scaleRef, stackSize)
            countText:ClearAllPoints()
            countText:SetPoint(stackPoint, frame, stackPoint, pxStackX, pxStackY)
        end
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

    -- Helper to normalize a mask texture with pixel-perfect settings
    local function normalizeMask(mask)
        if not mask then return end
        mask:ClearAllPoints()
        mask:SetAllPoints(iconTex)
        if mask.SetSnapToPixelGrid then mask:SetSnapToPixelGrid(true) end
    end

    -- Normalize all mask textures (including IconMask from custom frames)
    normalizeMask(frame.IconMask)
    normalizeMask(frame.IconMaskBlizzard)
    normalizeMask(frame.IconMaskSquare)
end

function CooldownItem:_normalizeCooldown()
    local cooldown = GetCooldown(self.frame)
    if not cooldown then return end

    cooldown:ClearAllPoints()
    cooldown:SetAllPoints(self.frame)
    cooldown:SetSwipeTexture("Interface\\Buttons\\WHITE8X8")
    cooldown:SetSwipeColor(0, 0, 0, 0.8)

    -- Apply pixel-perfect settings to cooldown frame
    if cooldown.SetSnapToPixelGrid then cooldown:SetSnapToPixelGrid(true) end
    if cooldown.SetTexelSnappingBias then cooldown:SetTexelSnappingBias(0) end
end

-- High frame level ensures keybind text renders above cooldown swipe
local KEYBIND_OVERLAY_LEVEL = 500
local DEFAULT_KEYBIND_SIZE = 10

function CooldownItem:setKeybind(keybind, settings)
    local frame = self.frame
    if not frame then return end

    if not settings or not settings.showKeybinds then
        if frame._ucdmKeybindOverlay then
            frame._ucdmKeybindOverlay:Hide()
            frame._ucdmKeybindOverlay = nil
        end
        if frame._ucdmKeybindText then
            frame._ucdmKeybindText:Hide()
            frame._ucdmKeybindText = nil
        end
        return
    end

    if not frame._ucdmKeybindOverlay then
        frame._ucdmKeybindOverlay = CreateFrame("Frame", nil, frame)
        frame._ucdmKeybindOverlay:SetFrameLevel(KEYBIND_OVERLAY_LEVEL)
        frame._ucdmKeybindOverlay:SetAllPoints(frame)
    end
    local overlay = frame._ucdmKeybindOverlay
    overlay:SetFrameLevel(KEYBIND_OVERLAY_LEVEL)

    if not frame._ucdmKeybindText then
        frame._ucdmKeybindText = TavernUI:CreateFontString(overlay, settings.keybindSize or DEFAULT_KEYBIND_SIZE)
    end
    local keybindText = frame._ucdmKeybindText
    local keybindSize = settings.keybindSize or DEFAULT_KEYBIND_SIZE
    TavernUI:ApplyFont(keybindText, frame, keybindSize, true)
    if keybindText.SetJustifyH then keybindText:SetJustifyH("RIGHT") end

    local point = settings.keybindPoint or "TOPRIGHT"
    local offsetX = settings.keybindOffsetX or -2
    local offsetY = settings.keybindOffsetY or -2
    local pxX = (TavernUI.GetPixelSize and TavernUI:GetPixelSize(frame, offsetX, 0)) or offsetX
    local pxY = (TavernUI.GetPixelSize and TavernUI:GetPixelSize(frame, offsetY, 1)) or offsetY

    if keybind then
        local color = settings.keybindColor or {r = 1, g = 1, b = 1, a = 1}
        keybindText:SetText(keybind)
        keybindText:SetTextColor(color.r, color.g, color.b, color.a)
        keybindText:ClearAllPoints()
        keybindText:SetPoint(point, overlay, point, pxX, pxY)
        keybindText:Show()
        overlay:Show()
    else
        keybindText:Hide()
        overlay:Hide()
    end
end

function CooldownItem:update()
    if not self.frame then return end
    if self.viewerKey and self.layoutIndex and module.GetSlotCooldownOverride then
        local startTime, duration = module:GetSlotCooldownOverride(self.viewerKey, self.layoutIndex)
        if startTime and duration then
            local entry = { frame = self.frame, viewerKey = self.viewerKey, layoutIndex = self.layoutIndex }
            if module.CooldownTracker then
                module.CooldownTracker.UpdateEntry(entry)
            end
            return
        end
    end
    if self.source ~= "custom" then return end
    if not self.spellID and not self.itemID and not self.slotID and not self.actionSlotID then return end

    local entry = {
        frame = self.frame,
        type = self.source,
        spellID = self.spellID,
        itemID = self.itemID,
        slotID = self.slotID,
        actionSlotID = self.actionSlotID,
        viewerKey = self.viewerKey,
        layoutIndex = self.layoutIndex,
    }
    if module.CooldownTracker then
        module.CooldownTracker.UpdateEntry(entry)
    end
end

function CooldownItem:setIcon(iconFileID)
    local tex = GetIcon(self.frame)
    if not tex then return end
    tex:SetTexture(iconFileID or "Interface\\Icons\\INV_Misc_QuestionMark")
end

function CooldownItem:refreshIcon()
    local iconFileID = nil
    
    if self.spellID then
        local spellInfo = C_Spell.GetSpellInfo(self.spellID)
        if spellInfo then
            iconFileID = spellInfo.iconID
        end
    elseif self.itemID then
        local itemInfo = C_Item.GetItemInfoByID and C_Item.GetItemInfoByID(self.itemID)
        if itemInfo then
            iconFileID = itemInfo.iconFileID
        else
            local _, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(self.itemID)
            iconFileID = itemTexture
        end
    elseif self.slotID then
        local itemID = GetInventoryItemID("player", self.slotID)
        if itemID then
            local itemInfo = C_Item.GetItemInfoByID and C_Item.GetItemInfoByID(itemID)
            if itemInfo then
                iconFileID = itemInfo.iconFileID
            else
                local _, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(itemID)
                iconFileID = itemTexture
            end
        end
    elseif self.actionSlotID then
        local tex = GetActionTexture(self.actionSlotID)
        if tex then
            iconFileID = tex
        end
    end

    self:setIcon(iconFileID)
end

module.CooldownItem = CooldownItem
