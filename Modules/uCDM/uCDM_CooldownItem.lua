local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

--[[
    CooldownItem - Unified representation of any cooldown-tracked element
    
    All items (Blizzard and custom) go through CooldownItem: ItemRegistry wraps
    Blizzard viewer frames in CooldownItem.new({ source = "blizzard", frame = frame }),
    and custom entries use source = "custom". LayoutEngine calls applyStyle() for every
    item in a row regardless of source.

    Blizzard frames (from Blizzard_CooldownViewer): template size is the icon rect
    (Essential 50x50, Utility 30x30, BuffIcon 40x40). They add a decorative
    UI-HUD-CoolDownManager-IconOverlay texture anchored *outside* the frame (e.g. -9,8
    to 9,-8). We strip that overlay in _stripBlizzardOverlay so our frame rect
    matches the inner icon rect. Size is applied using the frame's effective scale
    so Blizzard (often scale 1) and custom (viewer scale) both render at pxW x pxH.
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

    self.spellID = config.spellID
    self.itemID = config.itemID
    self.slotID = config.slotID
    self.actionSlotID = config.actionSlotID
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

function CooldownItem:applyStyle(rowConfig, optPxW, optPxH, scaleRegion)
    local frame = self.frame
    if not frame then return end

    if not self._styled then
        self:_setupFrame()
        self._styled = true
    end

    local iconSize_px = rowConfig.iconSize or rowConfig.size or 40
    local aspectRatio = rowConfig.aspectRatioCrop or 1.0
    local iconHeight_px = iconSize_px / aspectRatio
    local pxW = (type(optPxW) == "number" and optPxW > 0) and optPxW or math.max(1, math.floor(iconSize_px))
    local pxH = (type(optPxH) == "number" and optPxH > 0) and optPxH or math.max(1, math.floor(iconHeight_px))
    pxW = math.max(2, math.floor(pxW / 2 + 0.5) * 2)
    pxH = math.max(2, math.floor(pxH / 2 + 0.5) * 2)

    frame:SetSize(pxW, pxH)

    -- Store for tex coord calculation
    frame._ucdmZoom = rowConfig.zoom or 0
    frame._ucdmAspectRatio = aspectRatio
    frame._ucdmIconSize = iconSize_px

    -- Texture coordinates (zoom + aspect ratio cropping)
    self:_applyTexCoord(rowConfig)

    -- Text styling (duration, stacks)
    self:_applyTextStyle(rowConfig)

    self:_normalizeIconTexture()
    self:_normalizeCooldown()
    self:_applyBorder(rowConfig.iconBorderSize, rowConfig.iconBorderColor, scaleRegion)

    self._lastRowConfig = rowConfig
end

function CooldownItem:_removeMaskTextures()
    local frame = self.frame
    if not frame then return end
    local name = frame.GetName and frame:GetName()
    if name and name:find("^uCDMCustomFrame_") then return end
    local textures = {frame.Icon, frame.icon}
    for _, tex in ipairs(textures) do
        if tex and tex.GetMaskTexture and tex.RemoveMaskTexture then
            for i = CONSTANTS.MAX_MASK_TEXTURES, 1, -1 do
                local m = tex:GetMaskTexture(i)
                if m then tex:RemoveMaskTexture(m) end
            end
        end
    end
end

function CooldownItem:_stripBlizzardOverlay()
    local frame = self.frame
    if not frame or not frame.GetRegions then return end
    for _, region in ipairs({frame:GetRegions()}) do
        if region:IsObjectType("Texture") and region.GetAtlas then
            local ok, atlas = pcall(region.GetAtlas, region)
            if ok and atlas == "UI-HUD-CoolDownManager-IconOverlay" then
                region:SetTexture("")
                region:Hide()
                region.Show = function() end
            end
        end
    end
end

function CooldownItem:_setupFrame()
    local frame = self.frame
    if not frame then return end

    self:_removeMaskTextures()
    self:_stripBlizzardOverlay()

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

    if self.source == "custom" then
        self:_setupTooltip()
    end
end

function CooldownItem:_setupTooltip()
    local frame = self.frame
    if not frame or frame.__ucdmTooltipHooked then return end
    frame.__ucdmTooltipHooked = true

    local item = self
    frame:SetScript("OnEnter", function(f)
        if not item.spellID and not item.itemID and not item.slotID and not item.actionSlotID then return end
        GameTooltip_SetDefaultAnchor(GameTooltip, f)
        if item.spellID then
            GameTooltip:SetSpellByID(item.spellID)
        elseif item.itemID then
            GameTooltip:SetItemByID(item.itemID)
        elseif item.slotID then
            GameTooltip:SetInventoryItem("player", item.slotID)
        elseif item.actionSlotID then
            GameTooltip:SetAction(item.actionSlotID)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
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

function CooldownItem:_applyBorder(borderSize, borderColor, scaleRegion)
    local frame = self.frame
    if not frame then return end
    local size = (borderSize or 0) > 0 and (borderSize or 0) or 0
    local c = borderColor or { r = 0, g = 0, b = 0, a = 1 }

    if TavernUI and TavernUI.ApplyPixelBorder then
        TavernUI:ApplyPixelBorder(frame, size, c, {
            overlayKey = "__ucdmBorderOverlay",
            anchorRegion = frame,
            frameLevelOffset = 1,
        })
    end

    local cooldown = frame.Cooldown or frame.cooldown
    if cooldown then
        cooldown:ClearAllPoints()
        cooldown:SetAllPoints(frame)
    end
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

    if durationSize > 0 then
        local cooldown = frame.Cooldown or frame.cooldown
        if cooldown then
            if cooldown.text then
                TavernUI:ApplyFont(cooldown.text, frame, durationSize)
                cooldown.text:ClearAllPoints()
                cooldown.text:SetPoint(durationPoint, frame, durationPoint, durationOffsetX, durationOffsetY)
            end

            local ok, regions = pcall(function() return {cooldown:GetRegions()} end)
            if ok and regions then
                for _, region in ipairs(regions) do
                    if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                        TavernUI:ApplyFont(region, frame, durationSize)
                        region:ClearAllPoints()
                        region:SetPoint(durationPoint, frame, durationPoint, durationOffsetX, durationOffsetY)
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
                fs:SetPoint(stackPoint, frame, stackPoint, stackOffsetX, stackOffsetY)
            end
        end

        local countText = frame.Count or frame.count
        if countText then
            TavernUI:ApplyFont(countText, frame, stackSize)
            countText:ClearAllPoints()
            countText:SetPoint(stackPoint, frame, stackPoint, stackOffsetX, stackOffsetY)
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
    elseif self.actionSlotID then
        local tex = GetActionTexture(self.actionSlotID)
        if tex then
            iconFileID = tex
        end
    end

    self:setIcon(iconFileID)
end

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------

module.CooldownItem = CooldownItem