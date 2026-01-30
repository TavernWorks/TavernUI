local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

--[[
    CooldownItem - Unified representation of any cooldown-tracked element
    
    This is the core abstraction. Whether it's a Blizzard spell frame, a trinket,
    a custom spell, or a buff - they all become CooldownItem instances that:
    
    1. Know how to check their own visibility
    2. Know how to style their own frame (uniformly!)
    3. Know how to update their own cooldown state
    4. Know how to get their keybind
    
    This eliminates the need for separate Styler, CooldownTracker, Conditions modules.
]]

local CooldownItem = {}
CooldownItem.__index = CooldownItem

local CONSTANTS = {
    MAX_MASK_TEXTURES = 10,
    TEXTURE_BASE_CROP_PIXELS = 4,
    TEXTURE_SOURCE_SIZE = 64,
}

--------------------------------------------------------------------------------
-- Constructor
--------------------------------------------------------------------------------

function CooldownItem.new(config)
    local self = setmetatable({}, CooldownItem)
    
    -- Identity
    self.id = config.id
    self.source = config.source -- "blizzard" | "custom"
    self.viewerKey = config.viewerKey
    
    -- Frame reference
    self.frame = config.frame
    
    -- What we're tracking (mutually exclusive in most cases)
    self.spellID = config.spellID
    self.itemID = config.itemID
    self.slotID = config.slotID
    self.cooldownID = config.cooldownID
    
    -- Ordering
    self.index = config.index or 1
    self.layoutIndex = config.layoutIndex
    
    -- Custom entry config (for conditional display, etc.)
    self.config = config.config
    self.enabled = config.enabled ~= false
    
    -- State tracking
    self._styled = false
    self._lastRowConfig = nil

    return self
end

--------------------------------------------------------------------------------
-- Visibility
--------------------------------------------------------------------------------

function CooldownItem:isVisible(context)
    if not self.enabled then return false end
    if not self.frame then return false end
    
    -- Blizzard buff frames have special aura-based visibility
    if self.source == "blizzard" and self.viewerKey == "buff" then
        return self:_checkBuffVisibility()
    end
    
    -- Custom entries can have conditional display rules
    if self.source == "custom" and self.config and self.config.conditionalDisplay then
        return self:_checkConditions(context)
    end
    
    return true
end

function CooldownItem:_checkBuffVisibility()
    local frame = self.frame
    if not frame then return false end
    
    -- Check if frame has a cooldown ID
    local cooldownID = frame.GetCooldownID and frame:GetCooldownID()
    if not cooldownID then return false end
    
    -- Check Blizzard's hide-when-inactive logic
    if not frame.allowHideWhenInactive then return true end
    if not frame.hideWhenInactive then return true end
    
    -- Only show if there's an active aura
    return frame.auraInstanceID ~= nil
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

--------------------------------------------------------------------------------
-- Styling - Applied uniformly to ALL item types
--------------------------------------------------------------------------------

function CooldownItem:applyStyle(rowConfig)
    local frame = self.frame
    if not frame then return end
    
    -- One-time setup (remove masks, strip overlays, etc.)
    if not self._styled then
        self:_setupFrame()
        self._styled = true
    end
    
    -- Apply row-specific styling
    local iconSize = rowConfig.iconSize or rowConfig.size or 40
    local aspectRatio = rowConfig.aspectRatioCrop or 1.0
    local iconHeight = iconSize / aspectRatio
    
    local pxW = TavernUI:GetPixelSize(frame, iconSize, 0)
    local pxH = TavernUI:GetPixelSize(frame, iconHeight, 1)
    frame:SetSize(pxW, pxH)
    
    -- Store for tex coord calculation
    frame._ucdmZoom = rowConfig.zoom or 0
    frame._ucdmAspectRatio = aspectRatio
    frame._ucdmIconSize = iconSize
    
    -- Texture coordinates (zoom + aspect ratio cropping)
    self:_applyTexCoord(rowConfig)
    
    -- Border
    self:_applyBorder(rowConfig.iconBorderSize, rowConfig.iconBorderColor)
    
    -- Text styling (duration, stacks)
    self:_applyTextStyle(rowConfig)
    
    -- Ensure icon fills frame
    self:_normalizeIconTexture()
    
    -- Ensure cooldown fills frame
    self:_normalizeCooldown()
    
    self._lastRowConfig = rowConfig
end

function CooldownItem:_setupFrame()
    local frame = self.frame
    if not frame then return end
    
    -- Our frames are created clean, but ensure cooldown is properly configured
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
    
    -- Hide various Blizzard border elements
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
    
    -- Hide normal texture
    if frame.NormalTexture then
        frame.NormalTexture:SetAlpha(0)
    end
    if frame.GetNormalTexture then
        local normalTex = frame:GetNormalTexture()
        if normalTex then normalTex:SetAlpha(0) end
    end
    
    -- Suppress cooldown flash
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
    
    -- Apply aspect ratio cropping (crops top/bottom for wide icons)
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
    
    local pxBorder = TavernUI:GetPixelSize(frame, borderSize, 0)
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
    
    local durationSize = rowConfig.durationSize or 0
    local stackSize = rowConfig.stackSize or 0
    local durationPoint = rowConfig.durationPoint or "CENTER"
    local durationOffsetX = rowConfig.durationOffsetX or 0
    local durationOffsetY = rowConfig.durationOffsetY or 0
    local stackPoint = rowConfig.stackPoint or "BOTTOMRIGHT"
    local stackOffsetX = rowConfig.stackOffsetX or 0
    local stackOffsetY = rowConfig.stackOffsetY or 0
    
    local pxDurX = TavernUI:GetPixelSize(frame, durationOffsetX, 0)
    local pxDurY = TavernUI:GetPixelSize(frame, durationOffsetY, 1)
    local pxStackX = TavernUI:GetPixelSize(frame, stackOffsetX, 0)
    local pxStackY = TavernUI:GetPixelSize(frame, stackOffsetY, 1)
    
    if durationSize > 0 then
        local cooldown = frame.Cooldown or frame.cooldown
        if cooldown then
            if cooldown.text then
                TavernUI:ApplyFont(cooldown.text, frame, durationSize)
                cooldown.text:ClearAllPoints()
                cooldown.text:SetPoint(durationPoint, frame, durationPoint, pxDurX, pxDurY)
            end
            
            local ok, regions = pcall(function() return {cooldown:GetRegions()} end)
            if ok and regions then
                for _, region in ipairs(regions) do
                    if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                        TavernUI:ApplyFont(region, frame, durationSize)
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
                TavernUI:ApplyFont(fs, frame, stackSize)
                fs:ClearAllPoints()
                fs:SetPoint(stackPoint, frame, stackPoint, pxStackX, pxStackY)
            end
        end
        
        local countText = frame.Count or frame.count
        if countText then
            TavernUI:ApplyFont(countText, frame, stackSize)
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

--------------------------------------------------------------------------------
-- Cooldown State Updates (delegate to CooldownTracker)
--------------------------------------------------------------------------------

function CooldownItem:update()
    if not self.frame then return end
    if self.source ~= "custom" then return end
    if not self.spellID and not self.itemID and not self.slotID then return end

    local entry = {
        frame = self.frame,
        type = self.source,
        spellID = self.spellID,
        itemID = self.itemID,
        slotID = self.slotID,
    }
    if module.CooldownTracker then
        module.CooldownTracker.UpdateEntry(entry)
    end
end

--------------------------------------------------------------------------------
-- Icon Management (for custom entries)
--------------------------------------------------------------------------------

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
    end
    
    self:setIcon(iconFileID)
end

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------

module.CooldownItem = CooldownItem
