local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)
local PP = TavernUI.PixelPerfect

if not module then return end

local CooldownItem = {}
CooldownItem.__index = CooldownItem

local CONSTANTS = {
    MAX_MASK_TEXTURES = 10,
    TEXTURE_BASE_CROP_PIXELS = 4,  -- Blizzard icons have ~4px border artifacts
    TEXTURE_SOURCE_SIZE = 64,      -- Standard WoW icon texture size
}

local SWIPE_TEXTURE = ""  -- solid fill, no texture padding

-- High frame level ensures keybind text renders above cooldown swipe
local KEYBIND_OVERLAY_LEVEL = 500
local TEXT_OVERLAY_LEVEL = 600
local DEFAULT_KEYBIND_SIZE = 10

local GetIcon = module.GetIcon
local GetCooldown = module.GetCooldown

local function AreTooltipsDisabledInEditMode(viewerKey)
    if not viewerKey then return false end
    
    local viewerFrame = module:GetViewerFrame(viewerKey)
    if not viewerFrame then return false end
    
    if module:IsCustomViewerId(viewerKey) then
        local LibEditMode = LibStub("LibEditMode", true)
        if LibEditMode then
            if LibEditMode.frameSettings and LibEditMode.frameSettings[viewerFrame] then
                local settings = LibEditMode.frameSettings[viewerFrame]
                if settings.showTooltip == false or settings.tooltipEnabled == false then
                    return true
                end
            end
            
            if LibEditMode.GetFrameSetting then
                local tooltipSetting = LibEditMode:GetFrameSetting(viewerFrame, "showTooltip")
                if tooltipSetting == false then
                    return true
                end
                tooltipSetting = LibEditMode:GetFrameSetting(viewerFrame, "tooltipEnabled")
                if tooltipSetting == false then
                    return true
                end
            end
        end
    else
        if viewerFrame.GetSettingValue and Enum.EditModeCooldownViewerSetting then
            local showTooltips = viewerFrame:GetSettingValue(Enum.EditModeCooldownViewerSetting.ShowTooltips)
            if showTooltips == 0 then
                return true
            end
        end
    end
    
    return false
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

    if frame.auraInstanceID ~= nil then return true end
    return frame:IsShown()
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

    -- Use the viewer's effective scale for pixel snapping when available,
    -- so custom viewers and Blizzard viewers share the same spacing math.
    local scaleRef = (module and self.viewerKey and module.GetViewerFrame and module:GetViewerFrame(self.viewerKey))
        or self.frame
    local scale = (scaleRef and scaleRef.GetEffectiveScale and scaleRef:GetEffectiveScale())
        or (self.frame and self.frame.GetEffectiveScale and self.frame:GetEffectiveScale())
        or 1

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
    local pxW = PP.Scale(iconSize, scaleRef, 0)
    local pxH = PP.Scale(iconHeight, scaleRef, 1)
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
    self:_applyBorder(rowConfig.iconBorderSize, rowConfig.iconBorderColor, rowConfig.iconStyle)
    self:_applyTextStyle(rowConfig)
    self:_normalizeIconTexture()
    self:_normalizeCooldown()

    if self.source == "custom" then
        local viewerFrame = module:GetViewerFrame(self.viewerKey)
        if viewerFrame and viewerFrame.GetEffectiveScale and frame.GetEffectiveScale and frame.SetScale then
            local targetScale = viewerFrame:GetEffectiveScale()
            local parentScale = (frame:GetParent() and frame:GetParent():GetEffectiveScale()) or targetScale
            if parentScale and parentScale > 0 and math.abs(parentScale - targetScale) > 0.0001 then
                frame:SetScale(targetScale / parentScale)
            else
                frame:SetScale(1)
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
    if module.CooldownTracker and module.CooldownTracker.EnsureSwipeStyleAndHooks then
        module.CooldownTracker.EnsureSwipeStyleAndHooks(cooldown)
    end
end

local OVERLAY_DEFAULTS = {
    pandemic = { borderColor = {r = 1, g = 0, b = 0, a = 1}, borderWidth = 2 },
    proc = { borderColor = {r = 1, g = 1, b = 0, a = 1}, borderWidth = 2 },
}

local function applyOverlayBorder(frame, key)
    local item = module.ItemRegistry and module.ItemRegistry.GetItemByFrame(frame)
    if not item then return end
    local def = OVERLAY_DEFAULTS[key]
    local color = module:GetSetting("overlays." .. key .. ".borderColor", def and def.borderColor or {r = 0, g = 0, b = 0, a = 1})
    local width = module:GetSetting("overlays." .. key .. ".borderWidth", def and def.borderWidth or 2)
    if item._setBorderColor then item:_setBorderColor(color.r, color.g, color.b, color.a) end
    if item._setBorderWidth then item:_setBorderWidth(width) end
end

local function restoreOverlayBorder(frame)
    local item = module.ItemRegistry and module.ItemRegistry.GetItemByFrame(frame)
    if not item then return end
    if item._restoreBorderColor then item:_restoreBorderColor() end
    if item._restoreBorderWidth then item:_restoreBorderWidth() end
end

local function PropagateHoverToViewer(frame)
    local viewer = frame:GetParent()
    if viewer and viewer:GetScript("OnEnter") then
        viewer:GetScript("OnEnter")(viewer)
    end
end

local function PropagateLeaveToViewer(frame)
    local viewer = frame:GetParent()
    if viewer then
        if not viewer:IsMouseOver() then
            local onLeave = viewer:GetScript("OnLeave")
            if onLeave then
                onLeave(viewer)
            end
        end
    end
end

function CooldownItem:_setupCustomFrameTooltips(frame)
    local item = self
    frame:SetScript("OnEnter", function()
        if module:GetSetting("viewers." .. (item.viewerKey or "custom") .. ".disableTooltips") then return end
        if AreTooltipsDisabledInEditMode(item.viewerKey) then return end
        if GameTooltip_SetDefaultAnchor then
            GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
            GameTooltip:ClearAllPoints()
            GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
        else
            GameTooltip:SetOwner(UIParent, "ANCHOR_RIGHT")
        end
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
        PropagateHoverToViewer(frame)
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
        PropagateLeaveToViewer(frame)
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
    if frame.DebuffBorder then frame.DebuffBorder:SetAlpha(0) end
    
    for _, region in ipairs({frame:GetRegions()}) do
        if region and region.GetAtlas then
            local atlas = region:GetAtlas()
            if atlas == "UI-HUD-CoolDownManager-IconOverlay" then
                region:SetAlpha(0)
            elseif atlas and (atlas:find("debuff-border") or atlas:find("SpellType") or atlas:find("AuraType") or atlas:find("TypeOverlay")) then
                region:SetAlpha(0)
            end
        end
    end
    
    if frame.SpellType then frame.SpellType:Hide() end
    if frame.AuraType then frame.AuraType:Hide() end
    if frame.TypeIcon then frame.TypeIcon:Hide() end
    if frame.TypeOverlay then frame.TypeOverlay:Hide() end

    local cooldown = GetCooldown(frame)
    if cooldown and module.CooldownTracker and module.CooldownTracker.EnsureSwipeStyleAndHooks then
        module.CooldownTracker.EnsureSwipeStyleAndHooks(cooldown)
    end

    if frame.ShowPandemicStateFrame then
        hooksecurefunc(frame, "ShowPandemicStateFrame", function(self)
            if self.PandemicIcon then self.PandemicIcon:Hide() end
            if module:GetSetting("overlays.pandemic.enabled", true) then
                applyOverlayBorder(self, "pandemic")
            end
        end)
    end
    if frame.HidePandemicStateFrame then
        hooksecurefunc(frame, "HidePandemicStateFrame", function(self)
            if self.PandemicIcon then self.PandemicIcon:Hide() end
            restoreOverlayBorder(self)
        end)
    end
    if frame.OnSpellActivationOverlayGlowShowEvent then
        hooksecurefunc(frame, "OnSpellActivationOverlayGlowShowEvent", function(self)
            if ActionButtonSpellAlertManager then ActionButtonSpellAlertManager:HideAlert(self) end
            if self.SpellActivationAlert then self.SpellActivationAlert:Hide() end
            if module:GetSetting("overlays.proc.enabled", true) then
                applyOverlayBorder(self, "proc")
            end
        end)
    end
    if frame.OnSpellActivationOverlayGlowHideEvent then
        hooksecurefunc(frame, "OnSpellActivationOverlayGlowHideEvent", restoreOverlayBorder)
    end
    if frame.SpellActivationAlert then
        frame.SpellActivationAlert:Hide()
    end

    local originalOnEnter = frame:GetScript("OnEnter")
    local originalOnLeave = frame:GetScript("OnLeave")
    
    frame:SetScript("OnEnter", function(...)
        if originalOnEnter then originalOnEnter(...) end
        PropagateHoverToViewer(frame)
    end)
    
    frame:SetScript("OnLeave", function(...)
        if originalOnLeave then originalOnLeave(...) end
        PropagateLeaveToViewer(frame)
    end)
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

    local style = rowConfig.iconStyle or "square"

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
    local pxX = PP.Scale(offsetX, frame, 0)
    local pxY = PP.Scale(offsetY, frame, 1)

    if keybind then
        keybindText:SetText(keybind)
        module:ApplyTextColor(keybindText, settings, "keybindColor")
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

    -- Check for manual override first (applies to all items)
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

    -- Only process custom items through our tracker - Blizzard handles their own items natively
    if self.source ~= "custom" then return end
    if not self.spellID and not self.itemID and not self.slotID and not self.actionSlotID then return end

    local entry = {
        frame = self.frame,
        type = self.source,
        spellID = self.spellID,
        itemID = self.itemID,
        slotID = self.slotID,
        actionSlotID = self.actionSlotID,
        auraSpellID = self.auraSpellID,  -- Optional: for spells where cast ID ≠ debuff ID
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
