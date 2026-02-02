local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local CooldownItem = {}
CooldownItem.__index = CooldownItem

local CONSTANTS = {
    MAX_MASK_TEXTURES = 10,
    TEXTURE_BASE_CROP_PIXELS = 4,
    TEXTURE_SOURCE_SIZE = 64,
}

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

function CooldownItem:isVisible(context)
    if not self.enabled then return false end
    if not self.frame then return false end

    if self.source == "blizzard" and self.viewerKey == "buff" then
        return self:_checkBuffVisibility()
    end

    if self.source == "custom" and self.config and self.config.conditionalDisplay then
        return self:_checkConditions(context)
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
    self.frame:SetPoint("CENTER", anchorTo, "CENTER", x, y)
end

function CooldownItem:_checkConditions(context)
    local conditions = self.config.conditionalDisplay
    if not conditions or not conditions.enabled then return true end
    
    local inCombat = UnitAffectingCombat("player")
    if inCombat and not conditions.showInCombat then return false end
    if not inCombat and not conditions.showOutOfCombat then return false end
    
    local inGroup = IsInGroup() or IsInRaid()
    if inGroup and not conditions.showInGroup then return false end
    if not inGroup and not conditions.showSolo then return false end
    
    local inInstance = IsInInstance()
    if inInstance and not conditions.showInInstance then return false end
    if not inInstance and not conditions.showInOpenWorld then return false end
    
    if conditions.healthThreshold and conditions.healthThreshold > 0 then
        local healthPercent = (UnitHealth("player") / UnitHealthMax("player")) * 100
        if healthPercent >= conditions.healthThreshold then return false end
    end
    
    return true
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
    frame:SetSize(pxW, pxH)

    frame._ucdmZoom = rowConfig.zoom or 0
    frame._ucdmAspectRatio = aspectRatio
    frame._ucdmIconSize = iconSize

    self:_applyTexCoord(rowConfig)
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

    local iconTex = frame.Icon or frame.icon
    if iconTex and not frame.IconMask then
        local mask = frame:CreateMaskTexture()
        mask:SetAtlas("UI-HUD-CoolDownManager-Mask")
        mask:SetAllPoints(iconTex)
        iconTex:AddMaskTexture(mask)
        frame.IconMask = mask
    end

    local cooldown = frame.Cooldown or frame.cooldown
    if cooldown then
        if cooldown.SetDrawEdge then
            cooldown:SetDrawEdge(false)
        end
        if cooldown.SetDrawBling then
            cooldown:SetDrawBling(false)
        end
        if cooldown.SetSwipeTexture then
            cooldown:SetSwipeTexture("Interface\\Buttons\\WHITE8X8")
        end
        if cooldown.SetSwipeColor then
            cooldown:SetSwipeColor(0, 0, 0, 0.8)
        end
    end

    local borderElements = {
        frame.DebuffBorder,
        frame.BuffBorder,
        frame.TempEnchantBorder,
    }
    for _, border in ipairs(borderElements) do
        if border then
            self:_preventAtlasBorder(border)
        end
    end

    if frame.NormalTexture then
        frame.NormalTexture:SetAlpha(0)
    end
    if frame.GetNormalTexture then
        local normalTex = frame:GetNormalTexture()
        if normalTex then normalTex:SetAlpha(0) end
    end

    if frame.CooldownFlash then
        frame.CooldownFlash:SetAlpha(0)
        if not frame.CooldownFlash.__ucdmHooked then
            frame.CooldownFlash.__ucdmHooked = true
            hooksecurefunc(frame.CooldownFlash, "Show", function(self)
                self:SetAlpha(0)
            end)
        end
    end
end

function CooldownItem:_stripBlizzardCruft()
    local frame = self.frame
    if not frame then return end

    local iconTex = frame.Icon or frame.icon
    if iconTex and iconTex.GetMaskTexture and iconTex.RemoveMaskTexture then
        for i = 1, CONSTANTS.MAX_MASK_TEXTURES do
            local mask = iconTex:GetMaskTexture(i)
            if mask then
                iconTex:RemoveMaskTexture(mask)
            end
        end
    end

    if frame.GetRegions then
        for _, region in ipairs({frame:GetRegions()}) do
            if region:IsObjectType("Texture") and region ~= iconTex and region:IsShown() then
                region:SetTexture(nil)
                region:Hide()
                if not region.__ucdmShowHooked then
                    region.__ucdmShowHooked = true
                    region.Show = function() end
                end
            end
        end
    end

    if frame.OutOfRange then
        frame.OutOfRange:Hide()
        if not frame.OutOfRange.__ucdmShowHooked then
            frame.OutOfRange.__ucdmShowHooked = true
            frame.OutOfRange.Show = function() end
        end
    end
end

function CooldownItem:_preventAtlasBorder(texture)
    if not texture or texture.__ucdmAtlasBlocked then return end
    texture.__ucdmAtlasBlocked = true
    
    if texture.SetAtlas then
        hooksecurefunc(texture, "SetAtlas", function(self)
            if self.SetTexture then self:SetTexture(nil) end
            if self.SetAlpha then self:SetAlpha(0) end
        end)
    end
    
    if texture.SetTexture then texture:SetTexture(nil) end
    if texture.SetAlpha then texture:SetAlpha(0) end
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
    
    local tex = frame.Icon or frame.icon
    if tex and tex.SetTexCoord then
        tex:SetTexCoord(left, right, top, bottom)
    end
end

function CooldownItem:_applyBorder(borderSize, borderColor)
    local frame = self.frame
    if not frame then return end
    
    borderSize = borderSize or 0
    
    if borderSize <= 0 then
        if frame._ucdmBorder then
            frame._ucdmBorder:Hide()
        end
        frame:SetHitRectInsets(0, 0, 0, 0)
        return
    end

    local scaleRef = module:GetViewerFrame(self.viewerKey) or frame
    local pxBorder = TavernUI:GetPixelSize(scaleRef, borderSize, 0)
    if not frame._ucdmBorder then
        frame._ucdmBorder = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    end
    
    local bc = borderColor or {r = 0, g = 0, b = 0, a = 1}
    frame._ucdmBorder:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
    frame._ucdmBorder:ClearAllPoints()
    frame._ucdmBorder:SetPoint("TOPLEFT", frame, "TOPLEFT", -pxBorder, pxBorder)
    frame._ucdmBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", pxBorder, -pxBorder)
    frame._ucdmBorder:Show()
    
    frame:SetHitRectInsets(-pxBorder, -pxBorder, -pxBorder, -pxBorder)
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
        local cooldown = frame.Cooldown or frame.cooldown
        if cooldown then
            if cooldown.text then
                TavernUI:ApplyFont(cooldown.text, scaleRef, durationSize)
                cooldown.text:ClearAllPoints()
                cooldown.text:SetPoint(durationPoint, frame, durationPoint, pxDurX, pxDurY)
            end
            local ok, regions = pcall(function() return {cooldown:GetRegions()} end)
            if ok and regions then
                for _, region in ipairs(regions) do
                    if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                        TavernUI:ApplyFont(region, scaleRef, durationSize)
                        region:ClearAllPoints()
                        region:SetPoint(durationPoint, frame, durationPoint, pxDurX, pxDurY)
                    end
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
        
        local countText = frame.Count or frame.count
        if countText then
            TavernUI:ApplyFont(countText, scaleRef, stackSize)
            countText:ClearAllPoints()
            countText:SetPoint(stackPoint, frame, stackPoint, pxStackX, pxStackY)
        end
    end
end

function CooldownItem:_normalizeIconTexture()
    local frame = self.frame
    local textures = {frame.Icon, frame.icon}
    
    for _, tex in ipairs(textures) do
        if tex then
            tex:ClearAllPoints()
            tex:SetAllPoints(frame)
            if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
            if tex.SetBlendMode then tex:SetBlendMode("BLEND") end
        end
    end
    if frame.IconMask then
        frame.IconMask:ClearAllPoints()
        frame.IconMask:SetAllPoints(frame.Icon or frame.icon)
    end
end

function CooldownItem:_normalizeCooldown()
    local frame = self.frame
    local cooldown = frame.Cooldown or frame.cooldown

    if cooldown then
        cooldown:ClearAllPoints()
        cooldown:SetAllPoints(frame)
        cooldown:SetSwipeTexture("Interface\\Buttons\\WHITE8X8")
        cooldown:SetSwipeColor(0, 0, 0, 0.8)
    end
end

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
    if keybindText:GetParent() ~= overlay then
        keybindText:SetParent(overlay)
    end
    local keybindSize = settings.keybindSize or DEFAULT_KEYBIND_SIZE
    TavernUI:ApplyFont(keybindText, frame, keybindSize, true)
    if keybindText.SetJustifyH then
        keybindText:SetJustifyH("RIGHT")
    end

    local point = settings.keybindPoint or "TOPRIGHT"
    local offsetX = settings.keybindOffsetX or -2
    local offsetY = settings.keybindOffsetY or -2
    local pxX = TavernUI.GetPixelSize and TavernUI:GetPixelSize(frame, offsetX, 0) or offsetX
    local pxY = TavernUI.GetPixelSize and TavernUI:GetPixelSize(frame, offsetY, 1) or offsetY

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
    local frame = self.frame
    if not frame then return end
    
    local tex = frame.Icon or frame.icon
    if tex then
        if iconFileID then
            tex:SetTexture(iconFileID)
        else
            tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end
    end
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
