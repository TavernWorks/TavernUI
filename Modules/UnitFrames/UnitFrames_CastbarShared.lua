local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("UnitFrames")
if not module then return end

local LSM = LibStub("LibSharedMedia-3.0", true)
local WHITE8X8 = TavernUI.WHITE8X8

local CastbarShared = {}
module.CastbarShared = CastbarShared

-- ============================================================================
-- Upvalues and Constants
-- ============================================================================

local format = string.format
local max = math.max
local min = math.min
local floor = math.floor
local unpack = unpack
local GetTime = GetTime

local DEFAULT_BAR_COLOR = { r = 0.82, g = 0.82, b = 0.82, a = 1 }
local DEFAULT_BG_COLOR = { r = 0, g = 0, b = 0, a = 0.5 }
local DEFAULT_BORDER_COLOR = { r = 0.169, g = 0.169, b = 0.169, a = 1 }
local DEFAULT_ICON_BORDER_COLOR = { r = 0.169, g = 0.169, b = 0.169, a = 1 }
local DEFAULT_NOT_INTERRUPTIBLE_COLOR = { r = 0.65, g = 0.25, b = 0.25, a = 1 }

local STAGE_COLORS = {
    { 0.12, 0.16, 0.22, 1 },
    { 0.22, 0.12, 0.14, 1 },
    { 0.22, 0.18, 0.10, 1 },
    { 0.12, 0.20, 0.14, 1 },
    { 0.18, 0.12, 0.22, 1 },
}

local STAGE_FILL_COLORS = {
    { 0.35, 0.60, 0.85, 1 },
    { 0.80, 0.35, 0.40, 1 },
    { 0.85, 0.68, 0.30, 1 },
    { 0.40, 0.72, 0.40, 1 },
    { 0.65, 0.42, 0.78, 1 },
}

CastbarShared.STAGE_COLORS = STAGE_COLORS
CastbarShared.STAGE_FILL_COLORS = STAGE_FILL_COLORS

local PREVIEW_DURATION = 3.0
local PREVIEW_ICON_ID = 136048
local TEXT_THROTTLE = 0.1

-- ============================================================================
-- Helpers
-- ============================================================================

local function GetTexturePath(textureName)
    if textureName and textureName ~= "" and LSM then
        local path = LSM:Fetch("statusbar", textureName, true)
        if path then return path end
    end
    return TavernUI:GetThemeStatusBarTexture()
end

local function GetSettingColor(unit, key, default)
    local c = TavernUI:GetCastbarSetting(unit, key)
    if c and type(c) == "table" then
        return c
    end
    return default
end

local function UnpackColor(c)
    if not c then return 1, 1, 1, 1 end
    local r = c.r or c[1] or 1
    local g = c.g or c[2] or 1
    local b = c.b or c[3] or 1
    local a = c.a or c[4] or 1
    return r, g, b, a
end

local function GetCastbarColor(castbar, unit)
    if castbar.TUI_useClassColor then
        local _, class = UnitClass(unit)
        if class then
            local color = C_ClassColor.GetClassColor(class)
            if color then
                return color.r, color.g, color.b, 1
            end
        end
    end

    if castbar.TUI_castColor then
        return UnpackColor(castbar.TUI_castColor)
    end

    return TavernUI:GetThemeColor("castbarColor")
end

local function GetStageColor(castbar, stageIndex)
    if castbar.TUI_empoweredStageColors and castbar.TUI_empoweredStageColors[stageIndex] then
        return castbar.TUI_empoweredStageColors[stageIndex]
    end
    return STAGE_COLORS[stageIndex] or STAGE_COLORS[1]
end

local function GetFillColor(castbar, stageIndex)
    if castbar.TUI_empoweredFillColors and castbar.TUI_empoweredFillColors[stageIndex] then
        return castbar.TUI_empoweredFillColors[stageIndex]
    end
    return STAGE_FILL_COLORS[stageIndex] or STAGE_FILL_COLORS[1]
end

local function PositionFontString(fs, parent, anchor, offX, offY)
    if not fs then return end
    fs:ClearAllPoints()
    fs:SetWordWrap(false)
    fs:SetNonSpaceWrap(false)
    local point = anchor or "LEFT"
    fs:SetPoint(point, parent, point, offX or 0, offY or 0)
    -- Add opposing anchor to constrain text within parent bounds
    if point == "LEFT" then
        fs:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    elseif point == "RIGHT" then
        fs:SetPoint("LEFT", parent, "LEFT", 0, 0)
    end
end

local function ClearEmpoweredVisuals(castbar)
    if castbar.TUI_stageOverlays then
        for _, overlay in ipairs(castbar.TUI_stageOverlays) do
            if overlay then overlay:Hide() end
        end
    end
    castbar.TUI_stagePositions = nil
    castbar.TUI_numStages = nil
    if castbar.TUI_bg then
        castbar.TUI_bg:Show()
    end
    if castbar.TUI_EmpoweredLevel then
        castbar.TUI_EmpoweredLevel:SetText("")
    end
end

local function ResumePreviewCallback(castbar)
    if castbar.TUI_isPreview and not castbar.casting and not castbar.channeling and not castbar.empowering then
        if castbar.Icon then castbar.Icon:SetTexture(PREVIEW_ICON_ID) end
        if castbar.TUI_IconContainer and castbar.TUI_showIcon then
            castbar.TUI_IconContainer:Show()
        end
        if castbar.Text then castbar.Text:SetText("Preview Cast") end
        if castbar.Spark then castbar.Spark:Show() end
        local r, g, b, a = GetCastbarColor(castbar, castbar.TUI_unit or "player")
        castbar:SetStatusBarColor(r, g, b, a)
    end
end

local function ResumePreviewAfterCast(self)
    if not self.TUI_previewEnabled then return end
    self.TUI_isPreview = true
    self.TUI_previewStart = nil
    if not self.TUI_resumePreviewCb then
        self.TUI_resumePreviewCb = function() ResumePreviewCallback(self) end
    end
    C_Timer.After(0, self.TUI_resumePreviewCb)
end

-- ============================================================================
-- Custom OnUpdate (replaces oUF default)
-- ============================================================================

local function CustomOnUpdate(self, elapsed)
    if self.casting or self.channeling or self.empowering then
        -- Time text (replicate oUF default behavior)
        if self.Time then
            local durationObject = self:GetTimerDuration()
            if durationObject then
                if self.delay and self.delay ~= 0 then
                    if self.CustomDelayText then
                        self:CustomDelayText(durationObject)
                    else
                        local dur = durationObject:GetRemainingDuration()
                        self.Time:SetFormattedText("%.1f|cffff0000%s%.2f|r", dur, self.channeling and "-" or "+", self.delay)
                    end
                else
                    if self.CustomTimeText then
                        self:CustomTimeText(durationObject)
                    else
                        self.Time:SetFormattedText("%.1f", durationObject:GetRemainingDuration())
                    end
                end
            end
        end

        -- Empowered fill color per stage (player only, uses stored startTime/endTime)
        if self.empowering and self.TUI_stagePositions and self.startTime and self.endTime then
            local now = GetTime()
            local duration = self.endTime - self.startTime
            if duration > 0 then
                local progress = (now - self.startTime) / duration
                progress = max(0, min(1, progress))

                local currentStage = 1
                for i = 2, #self.TUI_stagePositions do
                    if progress >= self.TUI_stagePositions[i] then
                        currentStage = i
                    else
                        break
                    end
                end

                local fillColor = GetFillColor(self, currentStage)
                if fillColor then
                    self:SetStatusBarColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 1)
                end

                if self.TUI_EmpoweredLevel and self.TUI_showEmpoweredLevel then
                    self.TUI_textThrottle = (self.TUI_textThrottle or 0) + elapsed
                    if self.TUI_textThrottle >= TEXT_THROTTLE then
                        self.TUI_textThrottle = 0
                        self.TUI_EmpoweredLevel:SetText(tostring(floor(currentStage)))
                        self.TUI_EmpoweredLevel:Show()
                    end
                end

                if self.TUI_hideTimeOnEmpowered and self.Time then
                    self.Time:Hide()
                end
            end
        end

    elseif self.holdTime and self.holdTime > 0 then
        self.holdTime = self.holdTime - elapsed

    elseif self.TUI_isPreview then
        -- Preview mode animation
        local now = GetTime()
        if not self.TUI_previewStart then
            self.TUI_previewStart = now
        end

        local previewElapsed = now - self.TUI_previewStart
        if previewElapsed >= PREVIEW_DURATION then
            self.TUI_previewStart = now
            previewElapsed = 0
        end

        self:SetMinMaxValues(0, 1)
        self:SetValue(previewElapsed / PREVIEW_DURATION)

        if self.Time then
            self.Time:SetFormattedText("%.1f", PREVIEW_DURATION - previewElapsed)
        end
        if self.Spark then
            self.Spark:Show()
        end
    else
        -- No cast, no hold, no preview: reset and hide
        self.castID = nil
        self.casting = nil
        self.channeling = nil
        self.empowering = nil
        self.notInterruptible = nil
        self.spellID = nil
        self.spellName = nil
        if self.Pips then
            for _, pip in next, self.Pips do
                pip:Hide()
            end
        end
        self:Hide()
    end
end

-- ============================================================================
-- oUF Callbacks
-- ============================================================================

local function PostCastStart(self, castUnit)
    -- Sanitize notInterruptible (may be a secret value in combat)
    if self.notInterruptible ~= nil and canaccessvalue and not canaccessvalue(self.notInterruptible) then
        self.notInterruptible = nil
    end

    -- Clear preview state
    self.TUI_isPreview = false
    self.TUI_previewStart = nil

    -- Apply bar color
    if self.notInterruptible then
        local c = self.TUI_notInterruptibleColor or DEFAULT_NOT_INTERRUPTIBLE_COLOR
        self:SetStatusBarColor(UnpackColor(c))
    else
        local r, g, b, a = GetCastbarColor(self, castUnit)
        self:SetStatusBarColor(r, g, b, a)
    end

    -- Truncate spell text
    if self.Text and self.TUI_maxTextLength and self.TUI_maxTextLength > 0 then
        local text = self.Text:GetText()
        if text and #text > self.TUI_maxTextLength then
            self.Text:SetText(text:sub(1, self.TUI_maxTextLength) .. "...")
        end
    end

    -- Handle channel fill forward
    if self.channeling and self.TUI_channelFillForward then
        local duration = UnitChannelDuration(castUnit)
        if duration ~= nil and (not canaccessvalue or canaccessvalue(duration)) then
            self:SetTimerDuration(duration, self.smoothing, Enum.StatusBarTimerDirection.ElapsedTime)
        end
    end

    -- Show/hide icon container
    if self.TUI_IconContainer then
        if self.TUI_showIcon then
            self.TUI_IconContainer:Show()
        else
            self.TUI_IconContainer:Hide()
        end
    end

    -- Restore time text visibility
    if self.Time and self.TUI_showTimeText then
        self.Time:Show()
    end

    -- Clear empowered visuals for non-empowered casts
    if not self.empowering then
        ClearEmpoweredVisuals(self)
    end

    self.TUI_textThrottle = 0
end

local function PostCastInterruptible(self, castUnit)
    if self.notInterruptible then
        local c = self.TUI_notInterruptibleColor or DEFAULT_NOT_INTERRUPTIBLE_COLOR
        self:SetStatusBarColor(UnpackColor(c))
    else
        local r, g, b, a = GetCastbarColor(self, castUnit)
        self:SetStatusBarColor(r, g, b, a)
    end
end

local function PostCastStop(self, castUnit)
    ClearEmpoweredVisuals(self)
    if self.Time and self.TUI_showTimeText then
        self.Time:Show()
    end
    ResumePreviewAfterCast(self)
end

local function PostCastInterrupted(self, castUnit)
    ClearEmpoweredVisuals(self)
    if self.Time and self.TUI_showTimeText then
        self.Time:Show()
    end
    ResumePreviewAfterCast(self)
end

local function PostCastFail(self, castUnit)
    ClearEmpoweredVisuals(self)
    if self.Time and self.TUI_showTimeText then
        self.Time:Show()
    end
    ResumePreviewAfterCast(self)
end

-- ============================================================================
-- Empowered: Custom CreatePip and PostUpdatePips
-- ============================================================================

local function CustomCreatePip(self, stage)
    local pip = self:CreateTexture(nil, "OVERLAY", nil, 2)
    pip:SetColorTexture(1, 1, 1, 0.95)
    pip:SetWidth(2)
    return pip
end

local function CustomPostUpdatePips(self, stages)
    if not stages or #stages == 0 then return end

    -- Build cumulative positions from stage percentages
    local positions = { 0 }
    local cumulative = 0
    for i, pct in ipairs(stages) do
        cumulative = cumulative + pct
        positions[i + 1] = cumulative
    end
    self.TUI_stagePositions = positions

    -- Hide normal bg to show stage overlays instead
    if self.TUI_bg then self.TUI_bg:Hide() end

    -- Defer one frame for dimensions to be valid
    C_Timer.After(0, function()
        if not self:IsVisible() then return end
        local barWidth = self:GetWidth()
        local barHeight = self:GetHeight()
        if barWidth <= 0 then barWidth = 150 end

        self.TUI_stageOverlays = self.TUI_stageOverlays or {}

        for i = 1, #positions - 1 do
            local overlay = self.TUI_stageOverlays[i]
            if not overlay then
                overlay = self:CreateTexture(nil, "BACKGROUND", nil, 1)
                self.TUI_stageOverlays[i] = overlay
            end

            local startPos = positions[i] * barWidth
            local endPos = positions[i + 1] * barWidth
            local width = endPos - startPos

            local stageColor = GetStageColor(self, i)
            overlay:SetColorTexture(unpack(stageColor))
            overlay:SetSize(width, barHeight)
            overlay:ClearAllPoints()
            overlay:SetPoint("LEFT", self, "LEFT", startPos, 0)
            overlay:SetPoint("TOP", self, "TOP", 0, 0)
            overlay:SetPoint("BOTTOM", self, "BOTTOM", 0, 0)
            overlay:Show()
        end

        -- Hide unused overlays
        for i = #positions, #self.TUI_stageOverlays do
            if self.TUI_stageOverlays[i] then
                self.TUI_stageOverlays[i]:Hide()
            end
        end
    end)
end

-- ============================================================================
-- CreateCastbar
-- ============================================================================

function CastbarShared:CreateCastbar(frame, unit, db)
    local unitType = module:GetUnitType(unit) or unit
    local cbLayout = db.castbar or {}
    local anchor = cbLayout.anchor or {}

    -- Read all visual settings from the unified castbar settings path
    local height = TavernUI:GetCastbarSetting(unitType, "height", 20)
    local barTexture = TavernUI:GetCastbarSetting(unitType, "barTexture")
    local texturePath = GetTexturePath(barTexture)
    local barColor = GetSettingColor(unitType, "barColor", DEFAULT_BAR_COLOR)
    local bgColor = GetSettingColor(unitType, "bgColor", DEFAULT_BG_COLOR)
    local borderSize = TavernUI:GetCastbarSetting(unitType, "borderSize", 1)
    local borderColor = GetSettingColor(unitType, "borderColor", DEFAULT_BORDER_COLOR)
    local useClassColor = TavernUI:GetCastbarSetting(unitType, "useClassColor", false)
    local channelFillForward = TavernUI:GetCastbarSetting(unitType, "channelFillForward", false)
    local maxTextLength = TavernUI:GetCastbarSetting(unitType, "maxTextLength", 0)
    local notInterruptibleColor = GetSettingColor(unitType, "notInterruptibleColor", DEFAULT_NOT_INTERRUPTIBLE_COLOR)

    local showIcon = TavernUI:GetCastbarSetting(unitType, "showIcon", true)
    local iconAnchor = TavernUI:GetCastbarSetting(unitType, "iconAnchor", "LEFT")
    local iconSpacing = TavernUI:GetCastbarSetting(unitType, "iconSpacing", 0)
    local iconBorderSize = TavernUI:GetCastbarSetting(unitType, "iconBorderSize", 2)
    local iconBorderColor = GetSettingColor(unitType, "iconBorderColor", DEFAULT_ICON_BORDER_COLOR)
    local iconClampToBar = TavernUI:GetCastbarSetting(unitType, "iconClampToBar", true)
    local iconPixels
    if iconClampToBar then
        iconPixels = height
    else
        local iconSize = TavernUI:GetCastbarSetting(unitType, "iconSize", height)
        local iconScale = TavernUI:GetCastbarSetting(unitType, "iconScale", 1.0)
        iconPixels = iconSize * iconScale
    end

    local fontSize = TavernUI:GetCastbarSetting(unitType, "fontSize", 12)
    local showSpellText = TavernUI:GetCastbarSetting(unitType, "showSpellText", true)
    local spellTextAnchor = TavernUI:GetCastbarSetting(unitType, "spellTextAnchor", "LEFT")
    local spellTextOffsetX = TavernUI:GetCastbarSetting(unitType, "spellTextOffsetX", 4)
    local spellTextOffsetY = TavernUI:GetCastbarSetting(unitType, "spellTextOffsetY", 0)
    local showTimeText = TavernUI:GetCastbarSetting(unitType, "showTimeText", true)
    local timeTextAnchor = TavernUI:GetCastbarSetting(unitType, "timeTextAnchor", "RIGHT")
    local timeTextOffsetX = TavernUI:GetCastbarSetting(unitType, "timeTextOffsetX", -4)
    local timeTextOffsetY = TavernUI:GetCastbarSetting(unitType, "timeTextOffsetY", 0)
    local previewMode = TavernUI:GetCastbarSetting(unitType, "previewMode", false)

    -- Player-only empowered settings
    local isPlayer = (unitType == "player")
    local showEmpoweredLevel, empLevelAnchor, empLevelOffX, empLevelOffY
    local hideTimeOnEmpowered, empoweredStageColors, empoweredFillColors
    if isPlayer then
        showEmpoweredLevel = TavernUI:GetCastbarSetting(unitType, "showEmpoweredLevel", false)
        empLevelAnchor = TavernUI:GetCastbarSetting(unitType, "empoweredLevelTextAnchor", "CENTER")
        empLevelOffX = TavernUI:GetCastbarSetting(unitType, "empoweredLevelTextOffsetX", 0)
        empLevelOffY = TavernUI:GetCastbarSetting(unitType, "empoweredLevelTextOffsetY", 0)
        hideTimeOnEmpowered = TavernUI:GetCastbarSetting(unitType, "hideTimeTextOnEmpowered", false)
        empoweredStageColors = TavernUI:GetCastbarSetting(unitType, "empoweredStageColors")
        empoweredFillColors = TavernUI:GetCastbarSetting(unitType, "empoweredFillColors")
    end

    -- ====================================================================
    -- StatusBar (this IS the oUF Castbar element)
    -- ====================================================================

    local castbar = CreateFrame("StatusBar", nil, frame)
    castbar:SetStatusBarTexture(texturePath)
    castbar:SetStatusBarColor(UnpackColor(barColor))
    castbar:SetHeight(height)

    local p1 = anchor.point or "TOPLEFT"
    local rp1 = anchor.relPoint or "BOTTOMLEFT"
    local offX = anchor.offX or 0
    local offY = anchor.offY or -4
    local p2 = anchor.point2 or "TOPRIGHT"
    local rp2 = anchor.relPoint2 or "BOTTOMRIGHT"
    castbar:SetPoint(p1, frame, rp1, offX, offY)
    castbar:SetPoint(p2, frame, rp2, offX, offY)

    -- ====================================================================
    -- Background
    -- ====================================================================

    local bg = castbar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(texturePath)
    bg:SetVertexColor(UnpackColor(bgColor))
    castbar.TUI_bg = bg

    -- ====================================================================
    -- Border
    -- ====================================================================

    local border = CreateFrame("Frame", nil, castbar, "BackdropTemplate")
    border:SetFrameLevel(castbar:GetFrameLevel() + 2)
    if borderSize > 0 then
        border:SetPoint("TOPLEFT", castbar, "TOPLEFT", -borderSize, borderSize)
        border:SetPoint("BOTTOMRIGHT", castbar, "BOTTOMRIGHT", borderSize, -borderSize)
        border:SetBackdrop({ edgeFile = WHITE8X8, edgeSize = borderSize })
        border:SetBackdropBorderColor(UnpackColor(borderColor))
    else
        border:Hide()
    end
    castbar.TUI_Border = border

    -- ====================================================================
    -- Icon (Frame container with border texture + inner spell texture)
    -- ====================================================================

    local iconOffset = showIcon and (iconPixels + iconSpacing) or 0
    castbar.TUI_iconOffset = iconOffset
    castbar.TUI_iconAnchorSide = iconAnchor

    if iconOffset > 0 then
        castbar:ClearAllPoints()
        if iconAnchor == "LEFT" then
            castbar:SetPoint(p1, frame, rp1, offX + iconOffset, offY)
            castbar:SetPoint(p2, frame, rp2, offX, offY)
        else
            castbar:SetPoint(p1, frame, rp1, offX, offY)
            castbar:SetPoint(p2, frame, rp2, offX - iconOffset, offY)
        end
    end

    local iconContainer = CreateFrame("Frame", nil, castbar)
    iconContainer:SetSize(iconPixels, iconPixels)
    iconContainer:SetFrameLevel(castbar:GetFrameLevel() + 1)

    local iconBorderTex = iconContainer:CreateTexture(nil, "BACKGROUND", nil, -8)
    iconBorderTex:SetAllPoints(iconContainer)
    iconBorderTex:SetColorTexture(UnpackColor(iconBorderColor))

    local iconTexture = iconContainer:CreateTexture(nil, "ARTWORK")
    iconTexture:SetPoint("TOPLEFT", iconContainer, "TOPLEFT", iconBorderSize, -iconBorderSize)
    iconTexture:SetPoint("BOTTOMRIGHT", iconContainer, "BOTTOMRIGHT", -iconBorderSize, iconBorderSize)
    iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    iconContainer:ClearAllPoints()
    if iconAnchor == "RIGHT" then
        iconContainer:SetPoint("LEFT", castbar, "RIGHT", iconSpacing, 0)
    else
        iconContainer:SetPoint("RIGHT", castbar, "LEFT", -iconSpacing, 0)
    end

    if not showIcon then
        iconContainer:Hide()
    end

    castbar.Icon = iconTexture
    castbar.TUI_IconContainer = iconContainer
    castbar.TUI_IconBorder = iconBorderTex
    castbar.TUI_showIcon = showIcon

    -- ====================================================================
    -- Spark
    -- ====================================================================

    local spark = castbar:CreateTexture(nil, "OVERLAY")
    spark:SetSize(2, height)
    spark:SetColorTexture(1, 1, 1, 0.8)
    castbar.Spark = spark

    -- ====================================================================
    -- Shield (not-interruptible indicator)
    -- ====================================================================

    local shield = castbar:CreateTexture(nil, "OVERLAY", nil, 1)
    shield:SetSize(16, 16)
    shield:SetPoint("CENTER", castbar, "LEFT", 0, 0)
    castbar.Shield = shield

    -- ====================================================================
    -- Spell Text
    -- ====================================================================

    local spellText = TavernUI:CreateFontString(castbar, fontSize, nil, "OVERLAY", castbar)
    if spellText then
        spellText:SetJustifyH(spellTextAnchor)
        PositionFontString(spellText, castbar, spellTextAnchor, spellTextOffsetX, spellTextOffsetY)
        local tr, tg, tb, ta = TavernUI:GetThemeColor("textColor")
        spellText:SetTextColor(tr, tg, tb, ta)
        if not showSpellText then spellText:Hide() end
        castbar.Text = spellText
    end

    -- ====================================================================
    -- Time Text
    -- ====================================================================

    local timeText = TavernUI:CreateFontString(castbar, fontSize, nil, "OVERLAY", castbar)
    if timeText then
        timeText:SetJustifyH(timeTextAnchor)
        PositionFontString(timeText, castbar, timeTextAnchor, timeTextOffsetX, timeTextOffsetY)
        local tr, tg, tb, ta = TavernUI:GetThemeColor("textColor")
        timeText:SetTextColor(tr, tg, tb, ta)
        if not showTimeText then timeText:Hide() end
        castbar.Time = timeText
    end

    -- ====================================================================
    -- Empowered Level Text (player only)
    -- ====================================================================

    if isPlayer then
        local empLevelText = TavernUI:CreateFontString(castbar, fontSize, nil, "OVERLAY", castbar)
        if empLevelText then
            PositionFontString(empLevelText, castbar, empLevelAnchor, empLevelOffX, empLevelOffY)
            local tr, tg, tb, ta = TavernUI:GetThemeColor("textColor")
            empLevelText:SetTextColor(tr, tg, tb, ta)
            empLevelText:Hide()
            castbar.TUI_EmpoweredLevel = empLevelText
        end
    end

    -- ====================================================================
    -- Store settings on the castbar for callback access
    -- ====================================================================

    castbar.TUI_unit = unitType
    castbar.TUI_castColor = barColor
    castbar.TUI_useClassColor = useClassColor
    castbar.TUI_notInterruptibleColor = notInterruptibleColor
    castbar.TUI_channelFillForward = channelFillForward
    castbar.TUI_maxTextLength = maxTextLength
    castbar.TUI_showTimeText = showTimeText
    castbar.TUI_previewEnabled = previewMode

    if isPlayer then
        castbar.TUI_showEmpoweredLevel = showEmpoweredLevel
        castbar.TUI_hideTimeOnEmpowered = hideTimeOnEmpowered
        castbar.TUI_empoweredStageColors = empoweredStageColors
        castbar.TUI_empoweredFillColors = empoweredFillColors
    end

    -- ====================================================================
    -- Wire oUF callbacks
    -- ====================================================================

    castbar.OnUpdate = CustomOnUpdate
    castbar.PostCastStart = PostCastStart
    castbar.PostCastInterruptible = PostCastInterruptible
    castbar.PostCastStop = PostCastStop
    castbar.PostCastInterrupted = PostCastInterrupted
    castbar.PostCastFail = PostCastFail
    castbar.CreatePip = CustomCreatePip
    castbar.PostUpdatePips = CustomPostUpdatePips

    -- ====================================================================
    -- Assign to oUF
    -- ====================================================================

    frame.TUI_Castbar = castbar

    local cbHandling = TavernUI.oUFFactory
        and TavernUI.oUFFactory.IsCastbarModuleHandling
        and TavernUI.oUFFactory.IsCastbarModuleHandling(unitType)
    if db.showCastbar and not cbHandling then
        frame.Castbar = castbar
    else
        if not db.showCastbar then
            castbar:Hide()
        end
    end

    return castbar
end

-- ============================================================================
-- RefreshCastbar — update all visual properties from settings
-- ============================================================================

function CastbarShared:RefreshCastbar(castbar, unit)
    if not castbar then return end
    local unitType = unit or castbar.TUI_unit
    if not unitType then return end

    -- Texture
    local barTexture = TavernUI:GetCastbarSetting(unitType, "barTexture")
    local texturePath = GetTexturePath(barTexture)
    castbar:SetStatusBarTexture(texturePath)

    -- Background
    if castbar.TUI_bg then
        local bgColor = GetSettingColor(unitType, "bgColor", DEFAULT_BG_COLOR)
        castbar.TUI_bg:SetTexture(texturePath)
        castbar.TUI_bg:SetVertexColor(UnpackColor(bgColor))
    end

    -- Border
    if castbar.TUI_Border then
        local borderSize = TavernUI:GetCastbarSetting(unitType, "borderSize", 1)
        local borderColor = GetSettingColor(unitType, "borderColor", DEFAULT_BORDER_COLOR)
        if borderSize > 0 then
            castbar.TUI_Border:ClearAllPoints()
            castbar.TUI_Border:SetPoint("TOPLEFT", castbar, "TOPLEFT", -borderSize, borderSize)
            castbar.TUI_Border:SetPoint("BOTTOMRIGHT", castbar, "BOTTOMRIGHT", borderSize, -borderSize)
            castbar.TUI_Border:SetBackdrop({ edgeFile = WHITE8X8, edgeSize = borderSize })
            castbar.TUI_Border:SetBackdropBorderColor(UnpackColor(borderColor))
            castbar.TUI_Border:Show()
        else
            castbar.TUI_Border:SetBackdrop(nil)
            castbar.TUI_Border:Hide()
        end
    end

    -- Height + Spark
    local height = TavernUI:GetCastbarSetting(unitType, "height", 20)
    castbar:SetHeight(height)
    if castbar.Spark then
        castbar.Spark:SetSize(2, height)
    end

    -- Icon
    local showIcon = TavernUI:GetCastbarSetting(unitType, "showIcon", true)
    local iconAnchor = TavernUI:GetCastbarSetting(unitType, "iconAnchor", "LEFT")
    local iconSpacing = TavernUI:GetCastbarSetting(unitType, "iconSpacing", 0)
    local iconBorderSize = TavernUI:GetCastbarSetting(unitType, "iconBorderSize", 2)
    local iconBorderColor = GetSettingColor(unitType, "iconBorderColor", DEFAULT_ICON_BORDER_COLOR)
    local iconClampToBar = TavernUI:GetCastbarSetting(unitType, "iconClampToBar", true)
    local iconPixels
    if iconClampToBar then
        iconPixels = height
    else
        local iconSize = TavernUI:GetCastbarSetting(unitType, "iconSize", height)
        local iconScale = TavernUI:GetCastbarSetting(unitType, "iconScale", 1.0)
        iconPixels = iconSize * iconScale
    end

    local iconOffset = showIcon and (iconPixels + iconSpacing) or 0
    castbar.TUI_iconOffset = iconOffset
    castbar.TUI_iconAnchorSide = iconAnchor
    castbar.TUI_showIcon = showIcon

    if castbar.TUI_IconContainer then
        castbar.TUI_IconContainer:SetSize(iconPixels, iconPixels)
        castbar.TUI_IconContainer:ClearAllPoints()
        if iconAnchor == "RIGHT" then
            castbar.TUI_IconContainer:SetPoint("LEFT", castbar, "RIGHT", iconSpacing, 0)
        else
            castbar.TUI_IconContainer:SetPoint("RIGHT", castbar, "LEFT", -iconSpacing, 0)
        end

        if castbar.TUI_IconBorder then
            castbar.TUI_IconBorder:SetColorTexture(UnpackColor(iconBorderColor))
        end
        if castbar.Icon then
            castbar.Icon:ClearAllPoints()
            castbar.Icon:SetPoint("TOPLEFT", castbar.TUI_IconContainer, "TOPLEFT", iconBorderSize, -iconBorderSize)
            castbar.Icon:SetPoint("BOTTOMRIGHT", castbar.TUI_IconContainer, "BOTTOMRIGHT", -iconBorderSize, iconBorderSize)
        end

        if showIcon then
            castbar.TUI_IconContainer:Show()
        else
            castbar.TUI_IconContainer:Hide()
        end
    end

    -- Font strings
    local fontSize = TavernUI:GetCastbarSetting(unitType, "fontSize", 12)

    if castbar.Text then
        TavernUI:ApplyFont(castbar.Text, castbar, fontSize)
        local spellTextAnchor = TavernUI:GetCastbarSetting(unitType, "spellTextAnchor", "LEFT")
        local spellTextOffsetX = TavernUI:GetCastbarSetting(unitType, "spellTextOffsetX", 4)
        local spellTextOffsetY = TavernUI:GetCastbarSetting(unitType, "spellTextOffsetY", 0)
        castbar.Text:SetJustifyH(spellTextAnchor)
        PositionFontString(castbar.Text, castbar, spellTextAnchor, spellTextOffsetX, spellTextOffsetY)
        local showSpellText = TavernUI:GetCastbarSetting(unitType, "showSpellText", true)
        if showSpellText then castbar.Text:Show() else castbar.Text:Hide() end
    end

    if castbar.Time then
        TavernUI:ApplyFont(castbar.Time, castbar, fontSize)
        local timeTextAnchor = TavernUI:GetCastbarSetting(unitType, "timeTextAnchor", "RIGHT")
        local timeTextOffsetX = TavernUI:GetCastbarSetting(unitType, "timeTextOffsetX", -4)
        local timeTextOffsetY = TavernUI:GetCastbarSetting(unitType, "timeTextOffsetY", 0)
        castbar.Time:SetJustifyH(timeTextAnchor)
        PositionFontString(castbar.Time, castbar, timeTextAnchor, timeTextOffsetX, timeTextOffsetY)
        local showTimeText = TavernUI:GetCastbarSetting(unitType, "showTimeText", true)
        castbar.TUI_showTimeText = showTimeText
        if showTimeText then castbar.Time:Show() else castbar.Time:Hide() end
    end

    -- Empowered settings (player only)
    if castbar.TUI_EmpoweredLevel then
        TavernUI:ApplyFont(castbar.TUI_EmpoweredLevel, castbar, fontSize)
        local empAnchor = TavernUI:GetCastbarSetting(unitType, "empoweredLevelTextAnchor", "CENTER")
        local empOffX = TavernUI:GetCastbarSetting(unitType, "empoweredLevelTextOffsetX", 0)
        local empOffY = TavernUI:GetCastbarSetting(unitType, "empoweredLevelTextOffsetY", 0)
        PositionFontString(castbar.TUI_EmpoweredLevel, castbar, empAnchor, empOffX, empOffY)
        castbar.TUI_showEmpoweredLevel = TavernUI:GetCastbarSetting(unitType, "showEmpoweredLevel", false)
        castbar.TUI_hideTimeOnEmpowered = TavernUI:GetCastbarSetting(unitType, "hideTimeTextOnEmpowered", false)
        castbar.TUI_empoweredStageColors = TavernUI:GetCastbarSetting(unitType, "empoweredStageColors")
        castbar.TUI_empoweredFillColors = TavernUI:GetCastbarSetting(unitType, "empoweredFillColors")
    end

    -- Color settings
    castbar.TUI_castColor = TavernUI:GetCastbarSetting(unitType, "barColor")
    castbar.TUI_useClassColor = TavernUI:GetCastbarSetting(unitType, "useClassColor", false)
    castbar.TUI_notInterruptibleColor = GetSettingColor(unitType, "notInterruptibleColor", DEFAULT_NOT_INTERRUPTIBLE_COLOR)
    castbar.TUI_channelFillForward = TavernUI:GetCastbarSetting(unitType, "channelFillForward", false)
    castbar.TUI_maxTextLength = TavernUI:GetCastbarSetting(unitType, "maxTextLength", 0)

    -- Apply current bar color (including during active casts for live setting changes)
    if castbar.casting or castbar.channeling or castbar.empowering then
        if castbar.notInterruptible then
            local c = castbar.TUI_notInterruptibleColor or DEFAULT_NOT_INTERRUPTIBLE_COLOR
            castbar:SetStatusBarColor(UnpackColor(c))
        else
            local r, g, b, a = GetCastbarColor(castbar, unitType)
            castbar:SetStatusBarColor(r, g, b, a)
        end
    else
        local r, g, b, a = GetCastbarColor(castbar, unitType)
        castbar:SetStatusBarColor(r, g, b, a)
    end

    -- Preview mode
    local previewMode = TavernUI:GetCastbarSetting(unitType, "previewMode", false)
    castbar.TUI_previewEnabled = previewMode
    if previewMode then
        if not castbar.casting and not castbar.channeling and not castbar.empowering then
            self:EnablePreview(castbar, unitType)
        end
    else
        self:DisablePreview(castbar)
    end
end

-- ============================================================================
-- Preview Mode
-- ============================================================================

function CastbarShared:EnablePreview(castbar, unit)
    if not castbar then return end

    castbar.TUI_isPreview = true
    castbar.TUI_previewStart = GetTime()

    castbar:SetMinMaxValues(0, 1)
    castbar:SetValue(0)

    if castbar.Icon then
        castbar.Icon:SetTexture(PREVIEW_ICON_ID)
    end
    if castbar.TUI_IconContainer and castbar.TUI_showIcon then
        castbar.TUI_IconContainer:Show()
    end
    if castbar.Text then
        castbar.Text:SetText("Preview Cast")
    end
    if castbar.Time then
        castbar.Time:SetFormattedText("%.1f", PREVIEW_DURATION)
    end
    if castbar.Spark then
        castbar.Spark:Show()
    end

    local r, g, b, a = GetCastbarColor(castbar, unit or castbar.TUI_unit or "player")
    castbar:SetStatusBarColor(r, g, b, a)

    castbar:Show()
end

function CastbarShared:DisablePreview(castbar)
    if not castbar then return end

    castbar.TUI_isPreview = false
    castbar.TUI_previewStart = nil

    if not castbar.casting and not castbar.channeling and not castbar.empowering then
        castbar:Hide()
    end
end
