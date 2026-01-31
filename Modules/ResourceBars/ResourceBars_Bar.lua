local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("ResourceBars")

local Bar = {}

local DEFAULT_SEGMENT_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local DEFAULT_BACKGROUND_TEXTURE = "Interface\\Buttons\\WHITE8x8"
local SEGMENTED_PARENT_PADDING = 5

local function GetSegmentTexturePath(config)
    local key = config and config.segmentTexture
    return TavernUI:GetTexturePath(key, "statusbar", DEFAULT_SEGMENT_TEXTURE)
end

local function GetBackgroundTexturePath(backgroundConfig)
    if not backgroundConfig then return DEFAULT_BACKGROUND_TEXTURE end
    return TavernUI:GetTexturePath(backgroundConfig.texture, "statusbar", DEFAULT_BACKGROUND_TEXTURE)
end

local function GetBarTexturePath(config)
    local key = config and config.barTexture
    return TavernUI:GetTexturePath(key, "statusbar", DEFAULT_SEGMENT_TEXTURE)
end

local function ApplyBarBorder(frame, config)
    local border = config and config.barBorder
    local target = frame.borderOverlay or frame
    if not border or not border.enabled then
        if frame.SetBackdrop then frame:SetBackdrop(nil) end
        if target.SetBackdrop then target:SetBackdrop(nil) end
        if frame.bar then
            frame.bar:ClearAllPoints()
            frame.bar:SetAllPoints(frame)
        end
        return
    end
    if not target.SetBackdrop then return end
    local rawSize = (type(border.size) == "number" and border.size >= 0) and border.size or 1
    local size = TavernUI:GetPixelSize(frame, rawSize, 0)
    local c = border.color or {}
    local r, g, b = (c.r or 0), (c.g or 0), (c.b or 0)
    local a = (type(c.a) == "number") and c.a or 1
    target:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = size,
    })
    target:SetBackdropBorderColor(r, g, b, a)
    if frame.bar then
        frame.bar:ClearAllPoints()
        frame.bar:SetPoint("TOPLEFT", frame, "TOPLEFT", size, -size)
        frame.bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -size, size)
    end
end

local function ApplySegmentBackground(segment, config)
    local bg = config and config.segmentBackground
    if not bg or not bg.enabled then
        if segment.bgTexture then segment.bgTexture:Hide() end
        return
    end
    local texPath = GetBackgroundTexturePath(bg)
    local c = bg.color or {}
    local r, g, b = (c.r or 0), (c.g or 0), (c.b or 0)
    local a = (type(c.a) == "number") and c.a or 0.5
    if not segment.bgTexture then
        segment.bgTexture = segment:CreateTexture(nil, "BACKGROUND")
        segment.bgTexture:SetAllPoints()
    end
    segment.bgTexture:SetTexture(texPath)
    segment.bgTexture:SetVertexColor(r, g, b, a)
    segment.bgTexture:Show()
end

local function ApplyBarBackground(frame, config)
    local bg = config and config.barBackground
    if not bg or not bg.enabled then
        if frame.bgTexture then frame.bgTexture:Hide() end
        return
    end
    local texPath = GetBackgroundTexturePath(bg)
    local c = bg.color or {}
    local r, g, b = (c.r or 0), (c.g or 0), (c.b or 0)
    local a = (type(c.a) == "number") and c.a or 0.5
    if not frame.bgTexture then
        frame.bgTexture = frame:CreateTexture(nil, "BACKGROUND")
        frame.bgTexture:SetAllPoints()
    end
    frame.bgTexture:SetTexture(texPath)
    frame.bgTexture:SetVertexColor(r, g, b, a)
    frame.bgTexture:Show()
end

local THRESHOLD_EVALUATORS = {
    HEALTH = function(curve)
        if not UnitHealthPercent then return nil end
        return UnitHealthPercent("player", false, curve)
    end,
    PRIMARY_POWER = function(curve)
        if not UnitPowerPercent then return nil end
        return UnitPowerPercent("player", UnitPowerType("player"), false, curve)
    end,
    ALTERNATE_POWER = function(curve)
        if not UnitPowerPercent or not Enum or not Enum.PowerType then return nil end
        return UnitPowerPercent("player", Enum.PowerType.Alternate, false, curve)
    end,
    STAGGER = function(curve)
        if not UnitStagger or not UnitHealthMax or not curve or not curve.Evaluate then return nil end
        local current = UnitStagger("player")
        local max = UnitHealthMax("player")
        if not max or max <= 0 then return nil end
        local pct = (current and current > 0) and (current / max) or 0
        if type(pct) ~= "number" or pct ~= pct or pct < 0 then pct = 0 end
        if pct > 1 then pct = 1 end
        return curve:Evaluate(pct)
    end,
}

local function ApplyThresholdBarColor(frame, a)
    local evaluator = THRESHOLD_EVALUATORS[frame.barId]
    if not evaluator or not module.ColorModes or not frame.config.breakpoints then return false end
    local curve = module.ColorModes:CreateThresholdCurve(frame.config.breakpoints)
    if not curve then return false end
    local colorObj = evaluator(curve)
    if not colorObj or not colorObj.GetRGB then return false end
    local tex = frame.bar:GetStatusBarTexture()
    if not tex then return false end
    local r, g, b = colorObj:GetRGB()
    tex:SetVertexColor(r, g, b, a)
    return true
end

local function ApplyPowerBarColor(frame)
    if not module.ColorModes then return end
    local colorMode = frame.config.colorMode or module.CONSTANTS.COLOR_MODE_SOLID
    local a = (frame.config.color and type(frame.config.color.a) == "number") and frame.config.color.a or 1
    if colorMode == module.CONSTANTS.COLOR_MODE_THRESHOLD and ApplyThresholdBarColor(frame, a) then
        return
    end
    local r, g, b = module.ColorModes:GetColorForPercentage(0, colorMode, frame.config)
    frame.bar:SetStatusBarColor(r, g, b, a)
end

local function ApplySegmentBorder(segment, config)
    local border = config and config.segmentBorder
    local target = segment.borderOverlay or segment
    if not border or not border.enabled then
        if segment.SetBackdrop then segment:SetBackdrop(nil) end
        if target.SetBackdrop then target:SetBackdrop(nil) end
        return
    end
    if not target.SetBackdrop then return end
    local rawSize = (type(border.size) == "number" and border.size >= 0) and border.size or 1
    local region = segment:GetParent() or segment
    local size = TavernUI:GetPixelSize(region, rawSize, 0)
    local c = border.color or {}
    local r, g, b = (c.r or 0), (c.g or 0), (c.b or 0)
    local a = (type(c.a) == "number") and c.a or 1
    target:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = size,
    })
    target:SetBackdropBorderColor(r, g, b, a)
end

local function CreatePowerBar(barId, config)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(TavernUI:GetPixelSize(frame, config.width or 200, 0), TavernUI:GetPixelSize(frame, config.height or 14, 1))
    if not config.anchorConfig or not config.anchorConfig.target then
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, -TavernUI:GetPixelSize(frame, 180, 1))
    end

    ApplyBarBackground(frame, config)

    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetFrameLevel(1)
    bar:SetStatusBarTexture(GetBarTexturePath(config))
    bar:SetStatusBarColor(1, 1, 1, 1)
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(0)
    bar:SetAllPoints(frame)

    frame.bar = bar
    frame.borderOverlay = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.borderOverlay:SetAllPoints(frame)
    frame.borderOverlay:SetFrameLevel(frame.bar:GetFrameLevel() + 1)
    ApplyBarBorder(frame, config)
    frame.barId = barId
    frame.config = config
    
    function frame:Update(data)
        if not data then
            self:Hide()
            return
        end

        self:Show()
        local w = TavernUI:GetPixelSize(self, self.config.width or 200, 0)
        self:SetSize(w, TavernUI:GetPixelSize(self, self.config.height or 14, 1))
        ApplyBarBackground(self, self.config)
        ApplyBarBorder(self, self.config)
        self.bar:SetStatusBarTexture(GetBarTexturePath(self.config))

        self.bar:SetMinMaxValues(0, data.max)
        self.bar:SetValue(data.current)
        ApplyPowerBarColor(self)
    end

    function frame:ApplyVisualConfig()
        self:Show()
        local w = TavernUI:GetPixelSize(self, self.config.width or 200, 0)
        self:SetSize(w, TavernUI:GetPixelSize(self, self.config.height or 14, 1))
        ApplyBarBackground(self, self.config)
        ApplyBarBorder(self, self.config)
        self.bar:SetStatusBarTexture(GetBarTexturePath(self.config))
        ApplyPowerBarColor(self)
    end
    
    function frame:Show()
        frame:SetShown(true)
    end
    
    function frame:Hide()
        frame:SetShown(false)
    end
    
    function frame:Destroy()
        frame:SetParent(nil)
        frame:Hide()
    end
    
    frame:Hide()
    
    return frame
end

local function CreateSegmentedBar(barId, config)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetClipsChildren(false)
    frame:SetSize(1, 1)
    if not config.anchorConfig or not config.anchorConfig.target then
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, -TavernUI:GetPixelSize(frame, 180, 1))
    end
    
    ApplyBarBackground(frame, config)
    
    frame.segments = {}
    frame.barId = barId
    frame.config = config
    
    local function CreateSegment(parent, index, segConfig)
        local segment = CreateFrame("Frame", nil, parent)
        segment.index = index
        segment.bar = CreateFrame("StatusBar", nil, segment)
        segment.bar:SetMinMaxValues(0, 1)
        segment.bar:SetValue(1)
        segment.borderOverlay = CreateFrame("Frame", nil, segment, "BackdropTemplate")
        segment.borderOverlay:SetAllPoints(segment)
        segment.borderOverlay:SetFrameLevel(segment.bar:GetFrameLevel() + 1)
        local cfg = segConfig or parent.config
        ApplySegmentBackground(segment, cfg)
        ApplySegmentBorder(segment, cfg)
        local texPath = GetSegmentTexturePath(cfg)
        segment.bar:SetStatusBarTexture(texPath)
        segment.bar:SetStatusBarColor(1, 1, 1, 1)
        return segment
    end
    
    function frame:Update(data)
        if not data then
            self:Hide()
            return
        end
        
        self:Show()
        ApplyBarBackground(self, self.config)
        
        local max = data.max or 5
        local current = data.current
        local config = self.config
        
        while #self.segments < max do
            local segment = CreateSegment(self, #self.segments + 1, config)
            table.insert(self.segments, segment)
        end
        
        local spacing = (type(config.segmentSpacing) == "number" and config.segmentSpacing >= -1) and config.segmentSpacing or 2
        local gapPx = TavernUI:GetPixelSize(self, spacing, 0)
        local texPath = GetSegmentTexturePath(config)
        local border = config.segmentBorder
        local borderInset = (border and border.enabled and type(border.size) == "number" and border.size >= 0) and TavernUI:GetPixelSize(self, border.size, 0) or 0
        local borderPadding = 2 * borderInset
        local parentPadding = TavernUI:GetPixelSize(self, SEGMENTED_PARENT_PADDING, 0)
        local inset = parentPadding + borderPadding
        local segmentWidthPx = TavernUI:GetPixelSize(self, (type(config.segmentWidth) == "number" and config.segmentWidth > 0) and config.segmentWidth or 50, 0)
        local segmentHeightPx = TavernUI:GetPixelSize(self, (type(config.segmentHeight) == "number" and config.segmentHeight > 0) and config.segmentHeight or 20, 1)
        local contentW = max * segmentWidthPx + (max - 1) * gapPx
        local contentH = segmentHeightPx
        
        for i = 1, max do
            local segment = self.segments[i]
            if not segment then
                segment = CreateSegment(self, i, config)
                self.segments[i] = segment
            end
            
            ApplySegmentBackground(segment, config)
            ApplySegmentBorder(segment, config)
            segment:SetSize(segmentWidthPx, segmentHeightPx)
            segment:ClearAllPoints()
            if i == 1 then
                segment:SetPoint("TOPLEFT", self, "TOPLEFT", inset, -inset)
            else
                segment:SetPoint("TOPLEFT", self.segments[i - 1], "TOPRIGHT", gapPx, 0)
            end
            
            segment.bar:ClearAllPoints()
            segment.bar:SetPoint("TOPLEFT", segment, "TOPLEFT", borderInset, -borderInset)
            segment.bar:SetPoint("BOTTOMRIGHT", segment, "BOTTOMRIGHT", -borderInset, borderInset)
            segment.bar:SetStatusBarTexture(texPath)
            
            local fillPercent = 0.0
            if data.segments and data.segments[i] then
                local segData = data.segments[i]
                if segData.fillPercent ~= nil and type(segData.fillPercent) == "number" then
                    fillPercent = math.max(0, math.min(1, segData.fillPercent))
                elseif segData.ready ~= nil then
                    fillPercent = segData.ready and 1.0 or 0.0
                end
            else
                local cur = (type(current) == "number") and current or 0
                local fullCount = math.floor(cur)
                local partial = cur - fullCount
                if i <= fullCount then
                    fillPercent = 1.0
                elseif i == fullCount + 1 and partial > 0 then
                    fillPercent = math.max(0, math.min(1, partial))
                end
            end

            segment.bar:SetMinMaxValues(0, 1)
            segment.bar:SetValue(fillPercent)
            
            if module.ColorModes then
                local percentage = 0
                local r, g, b = module.ColorModes:GetColorForPercentage(percentage, config.colorMode or module.CONSTANTS.COLOR_MODE_SOLID, config)
                local a = (config.color and type(config.color.a) == "number") and config.color.a or 1
                segment.bar:SetStatusBarColor(r, g, b, a)
            end
            
            segment:Show()
        end
        
        local totalWidth = contentW + 2 * inset
        local totalHeight = contentH + 2 * inset
        self:SetSize(totalWidth, totalHeight)
        
        for i = max + 1, #self.segments do
            self.segments[i]:Hide()
        end
    end
    
    function frame:Show()
        frame:SetShown(true)
    end
    
    function frame:Hide()
        frame:SetShown(false)
    end
    
    function frame:Destroy()
        self.segments = {}
        frame:SetParent(nil)
        frame:Hide()
    end
    
    frame:Hide()
    
    return frame
end

function Bar:CreateBar(barId, barType, config)
    if barType == module.CONSTANTS.BAR_TYPE_POWER then
        return CreatePowerBar(barId, config)
    elseif barType == module.CONSTANTS.BAR_TYPE_SEGMENTED then
        return CreateSegmentedBar(barId, config)
    end
    return nil
end

module.Bar = Bar
