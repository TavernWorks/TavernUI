local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:NewModule("Castbar", "AceEvent-3.0")

local LSM = LibStub("LibSharedMedia-3.0", true)

local CONSTANTS = {
    UNIT_PLAYER = "player",
    UNIT_TARGET = "target",
    UNIT_FOCUS  = "focus",

    TEXT_THROTTLE = 0.1,
    PREVIEW_DURATION = 3.0,
    PREVIEW_ICON_ID = 136048,

    KEY_ENABLED              = "enabled",
    KEY_WIDTH                = "width",
    KEY_HEIGHT               = "height",
    KEY_BAR_TEXTURE          = "barTexture",
    KEY_BAR_COLOR            = "barColor",
    KEY_BG_COLOR             = "bgColor",
    KEY_BORDER_SIZE          = "borderSize",
    KEY_BORDER_COLOR         = "borderColor",
    KEY_NOT_INTERRUPTIBLE_COLOR = "notInterruptibleColor",
    KEY_USE_CLASS_COLOR      = "useClassColor",
    KEY_CHANNEL_FILL_FORWARD = "channelFillForward",
    KEY_SHOW_ICON            = "showIcon",
    KEY_ICON_SIZE            = "iconSize",
    KEY_ICON_SCALE           = "iconScale",
    KEY_ICON_ANCHOR          = "iconAnchor",
    KEY_ICON_SPACING         = "iconSpacing",
    KEY_ICON_BORDER_SIZE     = "iconBorderSize",
    KEY_ICON_BORDER_COLOR    = "iconBorderColor",
    KEY_FONT_SIZE            = "fontSize",
    KEY_MAX_TEXT_LENGTH       = "maxTextLength",
    KEY_SHOW_SPELL_TEXT      = "showSpellText",
    KEY_SPELL_TEXT_ANCHOR    = "spellTextAnchor",
    KEY_SPELL_TEXT_OFFSET_X  = "spellTextOffsetX",
    KEY_SPELL_TEXT_OFFSET_Y  = "spellTextOffsetY",
    KEY_SHOW_TIME_TEXT       = "showTimeText",
    KEY_TIME_TEXT_ANCHOR     = "timeTextAnchor",
    KEY_TIME_TEXT_OFFSET_X   = "timeTextOffsetX",
    KEY_TIME_TEXT_OFFSET_Y   = "timeTextOffsetY",
    KEY_ANCHOR_CONFIG        = "anchorConfig",
    KEY_PREVIEW_MODE         = "previewMode",
    KEY_SHOW_EMPOWERED_LEVEL          = "showEmpoweredLevel",
    KEY_EMPOWERED_LEVEL_TEXT_ANCHOR   = "empoweredLevelTextAnchor",
    KEY_EMPOWERED_LEVEL_TEXT_OFFSET_X = "empoweredLevelTextOffsetX",
    KEY_EMPOWERED_LEVEL_TEXT_OFFSET_Y = "empoweredLevelTextOffsetY",
    KEY_HIDE_TIME_TEXT_ON_EMPOWERED   = "hideTimeTextOnEmpowered",
    KEY_EMPOWERED_STAGE_COLORS        = "empoweredStageColors",
    KEY_EMPOWERED_FILL_COLORS         = "empoweredFillColors",

    STAGE_POSITIONS = {
        [5] = { 0, 0.15, 0.32, 0.50, 0.68, 0.85, 1.0 },
        [4] = { 0, 0.18, 0.42, 0.63, 0.84, 1.0 },
        [3] = { 0, 0.25, 0.50, 0.75, 1.0 },
        [2] = { 0, 0.50, 1.0 },
        [1] = { 0, 1.0 },
    },
}

module.CONSTANTS = CONSTANTS

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

module.STAGE_COLORS = STAGE_COLORS
module.STAGE_FILL_COLORS = STAGE_FILL_COLORS

local DEFAULT_BAR_COLOR = { r = 0.82, g = 0.82, b = 0.82, a = 1 }
local DEFAULT_BG_COLOR = { r = 0, g = 0, b = 0, a = 0.5 }
local DEFAULT_BORDER_COLOR = { r = 0.169, g = 0.169, b = 0.169, a = 1 }
local DEFAULT_ICON_BORDER_COLOR = { r = 0.169, g = 0.169, b = 0.169, a = 1 }
local DEFAULT_NOT_INTERRUPTIBLE_COLOR = { r = 0.65, g = 0.25, b = 0.25, a = 1 }

local function CopyColor(c)
    return { r = c.r, g = c.g, b = c.b, a = c.a }
end

local function MakeUnitDefaults(isPlayer)
    local d = {
        enabled = true,
        width = 220,
        height = 20,
        barTexture = nil,
        barColor = CopyColor(DEFAULT_BAR_COLOR),
        bgColor = CopyColor(DEFAULT_BG_COLOR),
        borderSize = 1,
        borderColor = CopyColor(DEFAULT_BORDER_COLOR),
        notInterruptibleColor = CopyColor(DEFAULT_NOT_INTERRUPTIBLE_COLOR),
        useClassColor = false,
        channelFillForward = false,

        showIcon = true,
        iconSize = 20,
        iconScale = 1.0,
        iconAnchor = "LEFT",
        iconSpacing = 0,
        iconBorderSize = 2,
        iconBorderColor = CopyColor(DEFAULT_ICON_BORDER_COLOR),

        fontSize = 12,
        maxTextLength = 0,
        showSpellText = true,
        spellTextAnchor = "LEFT",
        spellTextOffsetX = 4,
        spellTextOffsetY = 0,
        showTimeText = true,
        timeTextAnchor = "RIGHT",
        timeTextOffsetX = -4,
        timeTextOffsetY = 0,

        anchorConfig = nil,
        previewMode = false,
    }

    if isPlayer then
        d.useClassColor = true
        d.showEmpoweredLevel = false
        d.empoweredLevelTextAnchor = "CENTER"
        d.empoweredLevelTextOffsetX = 0
        d.empoweredLevelTextOffsetY = 0
        d.hideTimeTextOnEmpowered = false
        d.empoweredStageColors = nil
        d.empoweredFillColors = nil
    end

    return d
end

local defaults = {
    enabled = false,
    units = {
        player = MakeUnitDefaults(true),
        target = MakeUnitDefaults(false),
        focus  = MakeUnitDefaults(false),
    },
}

TavernUI:RegisterModuleDefaults("Castbar", defaults, true)

local castbars = {}
module.castbars = castbars

local UNITS = { CONSTANTS.UNIT_PLAYER, CONSTANTS.UNIT_TARGET, CONSTANTS.UNIT_FOCUS }

local function GetUnitSettings(unitKey)
    return module:GetSetting("units." .. unitKey)
end

local function GetTexturePath(textureName)
    if not textureName or textureName == "" then
        return LSM and LSM:Fetch("statusbar", "Solid") or "Interface\\Buttons\\WHITE8X8"
    end
    if LSM then
        local path = LSM:Fetch("statusbar", textureName)
        if path then return path end
    end
    return "Interface\\Buttons\\WHITE8X8"
end

module.GetTexturePath = GetTexturePath

local function TruncateName(name, maxLength)
    if not name then return "" end
    if not maxLength or maxLength <= 0 then return name end
    if name:len() <= maxLength then return name end
    return name:sub(1, maxLength) .. "..."
end

module.TruncateName = TruncateName

local function CreateIcon(anchorFrame, settings)
    local iconSize = settings.iconSize or 20
    local borderSize = settings.iconBorderSize or 2

    local icon = CreateFrame("Frame", nil, anchorFrame)
    icon:SetSize(iconSize, iconSize)

    local border = icon:CreateTexture(nil, "BACKGROUND", nil, -8)
    border:SetAllPoints(icon)
    border:SetColorTexture(
        settings.iconBorderColor and settings.iconBorderColor.r or 0,
        settings.iconBorderColor and settings.iconBorderColor.g or 0,
        settings.iconBorderColor and settings.iconBorderColor.b or 0,
        settings.iconBorderColor and settings.iconBorderColor.a or 1
    )
    icon.border = border

    local texture = icon:CreateTexture(nil, "ARTWORK")
    texture:SetPoint("TOPLEFT", icon, "TOPLEFT", borderSize, -borderSize)
    texture:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -borderSize, borderSize)
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon.texture = texture

    return icon
end

local function CreateStatusBar(anchorFrame, settings)
    local statusBar = CreateFrame("StatusBar", nil, anchorFrame)
    statusBar:SetStatusBarTexture(GetTexturePath(settings.barTexture))
    statusBar:SetStatusBarColor(
        settings.barColor and settings.barColor.r or 0.82,
        settings.barColor and settings.barColor.g or 0.82,
        settings.barColor and settings.barColor.b or 0.82,
        settings.barColor and settings.barColor.a or 1
    )
    statusBar:SetMinMaxValues(0, 1)
    statusBar:SetValue(0)
    statusBar:SetReverseFill(false)

    local bgBar = statusBar:CreateTexture(nil, "BACKGROUND")
    bgBar:SetAllPoints(statusBar)
    bgBar:SetTexture(GetTexturePath(settings.barTexture))
    bgBar:SetVertexColor(
        settings.bgColor and settings.bgColor.r or 0,
        settings.bgColor and settings.bgColor.g or 0,
        settings.bgColor and settings.bgColor.b or 0,
        settings.bgColor and settings.bgColor.a or 0.5
    )
    statusBar.bgBar = bgBar

    local borderSize = settings.borderSize or 1
    if borderSize > 0 then
        local borderFrame = CreateFrame("Frame", nil, statusBar, "BackdropTemplate")
        borderFrame:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", -borderSize, borderSize)
        borderFrame:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMRIGHT", borderSize, -borderSize)
        borderFrame:SetFrameLevel(math.max(1, statusBar:GetFrameLevel() - 1))
        borderFrame:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = borderSize,
        })
        borderFrame:SetBackdropBorderColor(
            settings.borderColor and settings.borderColor.r or 0,
            settings.borderColor and settings.borderColor.g or 0,
            settings.borderColor and settings.borderColor.b or 0,
            settings.borderColor and settings.borderColor.a or 1
        )
        statusBar.borderFrame = borderFrame
    end

    return statusBar
end

local function PositionIcon(castbar, settings)
    local icon = castbar.icon
    if not icon then return end

    local anchor = settings.iconAnchor or "LEFT"
    local spacing = settings.iconSpacing or 0
    local iconSize = (settings.iconSize or 20) * (settings.iconScale or 1.0)

    icon:ClearAllPoints()
    icon:SetSize(iconSize, iconSize)

    if anchor == "LEFT" then
        icon:SetPoint("RIGHT", castbar.statusBar, "LEFT", -spacing, 0)
    elseif anchor == "RIGHT" then
        icon:SetPoint("LEFT", castbar.statusBar, "RIGHT", spacing, 0)
    end
end

local function PositionStatusBar(castbar, settings)
    local statusBar = castbar.statusBar
    local anchorFrame = castbar.frame
    if not statusBar or not anchorFrame then return end

    local showIcon = settings.showIcon ~= false
    local iconAnchor = settings.iconAnchor or "LEFT"
    local iconSize = showIcon and ((settings.iconSize or 20) * (settings.iconScale or 1.0)) or 0
    local iconSpacing = showIcon and (settings.iconSpacing or 0) or 0

    statusBar:ClearAllPoints()

    if showIcon and iconAnchor == "LEFT" then
        statusBar:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", iconSize + iconSpacing, 0)
        statusBar:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMRIGHT", 0, 0)
    elseif showIcon and iconAnchor == "RIGHT" then
        statusBar:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", 0, 0)
        statusBar:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMRIGHT", -(iconSize + iconSpacing), 0)
    else
        statusBar:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", 0, 0)
        statusBar:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMRIGHT", 0, 0)
    end
end

local function PositionText(fontString, statusBar, anchor, offsetX, offsetY)
    if not fontString or not statusBar then return end
    fontString:ClearAllPoints()

    local point, relPoint
    if anchor == "LEFT" then
        point, relPoint = "LEFT", "LEFT"
    elseif anchor == "RIGHT" then
        point, relPoint = "RIGHT", "RIGHT"
    elseif anchor == "CENTER" then
        point, relPoint = "CENTER", "CENTER"
    else
        point, relPoint = "LEFT", "LEFT"
    end

    fontString:SetPoint(point, statusBar, relPoint, offsetX or 0, offsetY or 0)
end

function module:CreateCastbar(unitKey)
    if castbars[unitKey] then return castbars[unitKey] end

    local settings = GetUnitSettings(unitKey) or {}
    local isPlayer = (unitKey == CONSTANTS.UNIT_PLAYER)
    local frameName = "TavernUI_Castbar_" .. unitKey

    local frame = CreateFrame("Frame", frameName, UIParent)
    frame:SetSize(settings.width or 220, settings.height or 20)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, isPlayer and -150 or (unitKey == "target" and 150 or 100))
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(200)
    frame:Hide()

    local castbar = {
        frame = frame,
        unitKey = unitKey,
        isPlayer = isPlayer,
    }

    castbar.statusBar = CreateStatusBar(frame, settings)
    castbar.icon = CreateIcon(frame, settings)

    local fontSize = settings.fontSize or 12
    castbar.spellText = TavernUI:CreateFontString(castbar.statusBar, fontSize, nil, "OVERLAY", castbar.statusBar)
    castbar.timeText = TavernUI:CreateFontString(castbar.statusBar, fontSize, nil, "OVERLAY", castbar.statusBar)

    if isPlayer then
        castbar.empoweredLevelText = TavernUI:CreateFontString(castbar.statusBar, fontSize, nil, "OVERLAY", castbar.statusBar)
        castbar.empoweredLevelText:Hide()
    end

    PositionStatusBar(castbar, settings)
    PositionIcon(castbar, settings)
    PositionText(castbar.spellText, castbar.statusBar, settings.spellTextAnchor or "LEFT", settings.spellTextOffsetX or 4, settings.spellTextOffsetY or 0)
    PositionText(castbar.timeText, castbar.statusBar, settings.timeTextAnchor or "RIGHT", settings.timeTextOffsetX or -4, settings.timeTextOffsetY or 0)

    if settings.showSpellText == false then castbar.spellText:Hide() else castbar.spellText:Show() end
    if settings.showTimeText == false then castbar.timeText:Hide() else castbar.timeText:Show() end
    if not settings.showIcon then castbar.icon:Hide() else castbar.icon:Show() end

    castbar.isChanneled = false
    castbar.isEmpowered = false
    castbar.notInterruptible = false
    castbar.timerDriven = false
    castbar.startTime = 0
    castbar.endTime = 0
    castbar.textThrottle = 0
    castbar.numStages = 0
    castbar.stageOverlays = {}
    castbar.empoweredStages = {}
    castbar.stagePositions = {}
    castbar.isPreviewSimulation = false

    castbars[unitKey] = castbar
    return castbar
end

function module:DestroyCastbar(unitKey)
    local castbar = castbars[unitKey]
    if not castbar then return end

    if castbar.frame then
        castbar.frame:SetScript("OnUpdate", nil)
        castbar.frame:SetScript("OnEvent", nil)
        castbar.frame:UnregisterAllEvents()
        castbar.frame:Hide()
        castbar.frame:SetParent(nil)
    end

    castbars[unitKey] = nil
end

function module:RefreshCastbar(unitKey)
    local castbar = castbars[unitKey]
    if not castbar then return end

    local settings = GetUnitSettings(unitKey) or {}
    local frame = castbar.frame

    frame:SetSize(settings.width or 220, settings.height or 20)

    local statusBar = castbar.statusBar
    statusBar:SetStatusBarTexture(GetTexturePath(settings.barTexture))
    statusBar.bgBar:SetTexture(GetTexturePath(settings.barTexture))
    statusBar.bgBar:SetVertexColor(
        settings.bgColor and settings.bgColor.r or 0,
        settings.bgColor and settings.bgColor.g or 0,
        settings.bgColor and settings.bgColor.b or 0,
        settings.bgColor and settings.bgColor.a or 0.5
    )

    if statusBar.borderFrame then
        local borderSize = settings.borderSize or 1
        statusBar.borderFrame:ClearAllPoints()
        statusBar.borderFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", -borderSize, borderSize)
        statusBar.borderFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", borderSize, -borderSize)
        statusBar.borderFrame:SetBackdropBorderColor(
            settings.borderColor and settings.borderColor.r or 0,
            settings.borderColor and settings.borderColor.g or 0,
            settings.borderColor and settings.borderColor.b or 0,
            settings.borderColor and settings.borderColor.a or 1
        )
    end

    local iconBorderColor = settings.iconBorderColor or DEFAULT_ICON_BORDER_COLOR
    castbar.icon.border:SetColorTexture(iconBorderColor.r, iconBorderColor.g, iconBorderColor.b, iconBorderColor.a or 1)
    local borderSize = settings.iconBorderSize or 2
    castbar.icon.texture:ClearAllPoints()
    castbar.icon.texture:SetPoint("TOPLEFT", castbar.icon, "TOPLEFT", borderSize, -borderSize)
    castbar.icon.texture:SetPoint("BOTTOMRIGHT", castbar.icon, "BOTTOMRIGHT", -borderSize, borderSize)

    PositionStatusBar(castbar, settings)
    PositionIcon(castbar, settings)
    PositionText(castbar.spellText, statusBar, settings.spellTextAnchor or "LEFT", settings.spellTextOffsetX or 4, settings.spellTextOffsetY or 0)
    PositionText(castbar.timeText, statusBar, settings.timeTextAnchor or "RIGHT", settings.timeTextOffsetX or -4, settings.timeTextOffsetY or 0)

    local fontSize = settings.fontSize or 12
    TavernUI:ApplyFont(castbar.spellText, castbar.statusBar, fontSize)
    TavernUI:ApplyFont(castbar.timeText, castbar.statusBar, fontSize)
    if castbar.empoweredLevelText then
        TavernUI:ApplyFont(castbar.empoweredLevelText, castbar.statusBar, fontSize)
    end

    if settings.showSpellText == false then castbar.spellText:Hide() else castbar.spellText:Show() end
    if settings.showTimeText == false then castbar.timeText:Hide() else castbar.timeText:Show() end
    if not settings.showIcon then castbar.icon:Hide() else castbar.icon:Show() end

    if self.Anchoring and self.Anchoring.ApplyAnchor then
        self.Anchoring:ApplyAnchor(unitKey)
    end
end

function module:OnInitialize()
    self:RegisterMessage("TavernUI_ProfileChanged", "OnProfileChanged")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")

    if self.Anchoring then
        self.Anchoring:Initialize()
    end

    if self.Options then
        self.Options:Initialize()
    end

    self:WatchSetting("enabled", function(newValue)
        if newValue then
            self:Enable()
        else
            self:Disable()
        end
    end)
end

local BLIZZARD_CASTBARS = {
    player = "PlayerCastingBarFrame",
    target = "TargetFrameSpellBar",
    focus  = "FocusFrameSpellBar",
}

local function HideBlizzardCastbar(unitKey)
    local frameName = BLIZZARD_CASTBARS[unitKey]
    if not frameName then return end
    local frame = _G[frameName]
    if not frame then return end

    if unitKey == "player" and frame.SetAndUpdateShowCastbar then
        frame:SetAndUpdateShowCastbar(false)
    elseif frame.UpdateIsShown then
        frame.showCastbar = false
        frame:UpdateIsShown()
    else
        frame:Hide()
        frame:UnregisterAllEvents()
    end
end

local function ShowBlizzardCastbar(unitKey)
    local frameName = BLIZZARD_CASTBARS[unitKey]
    if not frameName then return end
    local frame = _G[frameName]
    if not frame then return end

    if unitKey == "player" and frame.SetAndUpdateShowCastbar then
        frame:SetAndUpdateShowCastbar(true)
    elseif frame.UpdateIsShown then
        frame.showCastbar = true
        frame:UpdateIsShown()
    end
end

module.HideBlizzardCastbar = HideBlizzardCastbar
module.ShowBlizzardCastbar = ShowBlizzardCastbar

function module:OnEnable()
    for _, unitKey in ipairs(UNITS) do
        local settings = GetUnitSettings(unitKey)
        if settings and settings.enabled ~= false then
            local castbar = self:CreateCastbar(unitKey)
            if self.Cast then
                self.Cast:SetupEvents(castbar, unitKey)
            end
            if self.Anchoring then
                self.Anchoring:RegisterBar(unitKey, castbar.frame)
                self.Anchoring:ApplyAnchor(unitKey)
            end
            HideBlizzardCastbar(unitKey)
        end
    end
end

function module:OnDisable()
    for _, unitKey in ipairs(UNITS) do
        self:DestroyCastbar(unitKey)
        ShowBlizzardCastbar(unitKey)
    end
    if self.Anchoring and self.Anchoring.Cleanup then
        self.Anchoring:Cleanup()
    end
end

function module:OnProfileChanged()
    for _, unitKey in ipairs(UNITS) do
        self:DestroyCastbar(unitKey)
    end
    if self:IsEnabled() then
        self:OnEnable()
    end
end

function module:OnPlayerEnteringWorld()
    if not self:IsEnabled() then return end
    for _, unitKey in ipairs(UNITS) do
        if castbars[unitKey] then
            self:RefreshCastbar(unitKey)
            HideBlizzardCastbar(unitKey)
        end
    end
end

function module:GetCastbar(unitKey)
    return castbars[unitKey]
end

function module:GetUnitSettings(unitKey)
    return GetUnitSettings(unitKey)
end

function module:GetBarColor(unitKey)
    local settings = GetUnitSettings(unitKey) or {}
    if unitKey == CONSTANTS.UNIT_PLAYER and settings.useClassColor then
        local _, classToken = UnitClass("player")
        if classToken then
            local cc = C_ClassColor.GetClassColor(classToken)
            if cc then return cc.r, cc.g, cc.b, 1 end
        end
    end
    local c = settings.barColor or DEFAULT_BAR_COLOR
    return c.r, c.g, c.b, c.a or 1
end
