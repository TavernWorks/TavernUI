local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:NewModule("Castbar", "AceEvent-3.0")
module.requiresReload = true

local LSM = LibStub("LibSharedMedia-3.0", true)

local CONSTANTS = {
    UNIT_PLAYER = "player",
    UNIT_TARGET = "target",
    UNIT_FOCUS  = "focus",

    TEXT_THROTTLE = 0.1,
    CAST_RETRY_DELAY = 0.1,
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
    KEY_FRAME_STRATA         = "frameStrata",
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
        bgColor = { r = 0, g = 0, b = 0, a = 0.5 },
        borderSize = 1,
        borderColor = { r = 0.169, g = 0.169, b = 0.169, a = 1 },
        notInterruptibleColor = { r = 0.65, g = 0.25, b = 0.25, a = 1 },
        useClassColor = false,
        channelFillForward = false,

        showIcon = true,
        iconSize = 20,
        iconScale = 1.0,
        iconAnchor = "LEFT",
        iconSpacing = 0,
        iconBorderSize = 2,
        iconBorderColor = { r = 0.169, g = 0.169, b = 0.169, a = 1 },

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

        frameStrata = "MEDIUM",
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

-- ============================================================================
-- Castbar Access (oUF-based)
-- ============================================================================

function module:GetOufFrame(unitKey)
    return self.oufFrames and self.oufFrames[unitKey] or nil
end

function module:GetCastbar(unitKey)
    local oufFrame = self:GetOufFrame(unitKey)
    return oufFrame and oufFrame.TUI_Castbar or nil
end

-- ============================================================================
-- Blizzard Castbar Management
-- ============================================================================

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

-- ============================================================================
-- Bar Color
-- ============================================================================

function module:GetBarColor(unitKey)
    local settings = GetUnitSettings(unitKey) or {}
    if settings.useClassColor then
        local _, classToken = UnitClass(unitKey)
        if classToken then
            local cc = C_ClassColor.GetClassColor(classToken)
            if cc then return cc.r, cc.g, cc.b, 1 end
        end
    end
    local c = settings.barColor or DEFAULT_BAR_COLOR
    return c.r, c.g, c.b, c.a or 1
end

-- ============================================================================
-- Enable/Disable Unit Castbar on oUF Frame
-- ============================================================================

local function GetCastbarShared()
    local ufModule = TavernUI:GetModule("UnitFrames", true)
    return ufModule and ufModule.CastbarShared or nil
end

local function IsFullMode(unitKey)
    local factory = TavernUI.oUFFactory
    return factory and factory.GetSpawnMode and factory.GetSpawnMode(unitKey) == "full"
end

function module:EnableUnitCastbar(unitKey)
    local oufFrame = self:GetOufFrame(unitKey)
    if not oufFrame then return end

    local castbar = oufFrame.TUI_Castbar
    if not castbar then return end

    local fullMode = IsFullMode(unitKey)

    -- In full mode, defer to UF if it's managing the castbar
    if fullMode and oufFrame.TUI_CastbarOwner == "UF" then
        return
    end

    if not oufFrame.Castbar then
        oufFrame.Castbar = castbar
        oufFrame:EnableElement("Castbar")
    end

    local shared = GetCastbarShared()
    if shared then
        shared:RefreshCastbar(castbar, unitKey)
    end

    local settings = GetUnitSettings(unitKey) or {}

    if fullMode then
        oufFrame.TUI_CastbarOwner = "CB"
        local totalWidth = settings.width or 220
        local barHeight = settings.height or 20
        local iconOffset = castbar.TUI_iconOffset or 0
        local iconSide = castbar.TUI_iconAnchorSide or "LEFT"

        local container = oufFrame.TUI_CastbarContainer
        if not container then
            container = CreateFrame("Frame", nil, UIParent)
            oufFrame.TUI_CastbarContainer = container
            castbar:SetParent(container)
        end
        container:SetFrameStrata(settings.frameStrata or "MEDIUM")

        container:SetSize(totalWidth, barHeight)
        container:ClearAllPoints()
        if not settings.anchorConfig or not settings.anchorConfig.target or settings.anchorConfig.target == "" then
            container:SetPoint("TOPLEFT", oufFrame, "BOTTOMLEFT", 0, -4)
        end
        container:Show()

        castbar:ClearAllPoints()
        castbar:SetSize(totalWidth - iconOffset, barHeight)
        if iconSide == "LEFT" then
            castbar:SetPoint("RIGHT", container, "RIGHT", 0, 0)
        else
            castbar:SetPoint("LEFT", container, "LEFT", 0, 0)
        end
    else
        if castbar:GetParent() ~= oufFrame then
            castbar:SetParent(oufFrame)
        end
        oufFrame:SetFrameStrata(settings.frameStrata or "MEDIUM")
        oufFrame:SetAlpha(1)
        oufFrame:Show()
    end

    if self.Anchoring then
        local anchorTarget = fullMode and (oufFrame.TUI_CastbarContainer or castbar) or oufFrame
        self.Anchoring:RegisterBar(unitKey, anchorTarget)
        self.Anchoring:ApplyAnchor(unitKey)
    end

    HideBlizzardCastbar(unitKey)
end

function module:DisableUnitCastbar(unitKey)
    local oufFrame = self:GetOufFrame(unitKey)
    if not oufFrame then return end

    local fullMode = IsFullMode(unitKey)
    local anchorTarget = fullMode and (oufFrame.TUI_CastbarContainer or oufFrame.TUI_Castbar) or oufFrame

    if self.Anchoring then
        self.Anchoring:UnregisterBar(unitKey, anchorTarget)
    end

    if oufFrame.Castbar then
        oufFrame:DisableElement("Castbar")
        oufFrame.Castbar = nil
    end

    if fullMode then
        oufFrame.TUI_CastbarOwner = nil
        if oufFrame.TUI_CastbarContainer then
            oufFrame.TUI_CastbarContainer:Hide()
        end
        if oufFrame.TUI_Castbar then
            oufFrame.TUI_Castbar:Hide()
        end
    else
        oufFrame:Hide()
    end

    ShowBlizzardCastbar(unitKey)
end

-- ============================================================================
-- Refresh
-- ============================================================================

function module:RefreshCastbar(unitKey)
    local oufFrame = self:GetOufFrame(unitKey)
    if not oufFrame then return end

    local castbar = oufFrame.TUI_Castbar
    if not castbar then return end

    local fullMode = IsFullMode(unitKey)
    local ufOwns = fullMode and oufFrame.TUI_CastbarOwner == "UF"

    -- Always refresh visuals (settings are shared, UF options may change them too)
    local shared = GetCastbarShared()
    if shared then
        shared:RefreshCastbar(castbar, unitKey)
    end

    -- Only size and anchor when Castbar module owns
    if not ufOwns then
        local settings = GetUnitSettings(unitKey) or {}
        local totalWidth = settings.width or 220
        local barHeight = settings.height or 20
        local iconOffset = castbar.TUI_iconOffset or 0
        local iconSide = castbar.TUI_iconAnchorSide or "LEFT"

        if fullMode then
            local container = oufFrame.TUI_CastbarContainer
            if container then
                container:SetFrameStrata(settings.frameStrata or "MEDIUM")
                container:SetSize(totalWidth, barHeight)
                if not settings.anchorConfig or not settings.anchorConfig.target or settings.anchorConfig.target == "" then
                    container:ClearAllPoints()
                    container:SetPoint("TOPLEFT", oufFrame, "BOTTOMLEFT", 0, -4)
                end

                castbar:ClearAllPoints()
                castbar:SetSize(totalWidth - iconOffset, barHeight)
                if iconSide == "LEFT" then
                    castbar:SetPoint("RIGHT", container, "RIGHT", 0, 0)
                else
                    castbar:SetPoint("LEFT", container, "LEFT", 0, 0)
                end
            end
        else
            oufFrame:SetFrameStrata(settings.frameStrata or "MEDIUM")
            oufFrame:SetSize(totalWidth, barHeight)
        end

        if self.Anchoring and self.Anchoring.ApplyAnchor then
            self.Anchoring:ApplyAnchor(unitKey)
        end
    end
end

-- ============================================================================
-- Module Lifecycle
-- ============================================================================

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

function module:OnEnable()
    -- Ensure oUF frames are spawned when UnitFrames module is disabled
    if TavernUI.oUFFactory then
        TavernUI.oUFFactory:SpawnFrames()
    end

    for _, unitKey in ipairs(UNITS) do
        local settings = GetUnitSettings(unitKey)
        if settings and settings.enabled ~= false then
            HideBlizzardCastbar(unitKey)
        end
    end
end

function module:InitializeCastbars()
    if not self.oufFrames then return end

    for _, unitKey in ipairs(UNITS) do
        local settings = GetUnitSettings(unitKey)
        if settings and settings.enabled ~= false then
            self:EnableUnitCastbar(unitKey)
        else
            self:DisableUnitCastbar(unitKey)
        end
    end
end

function module:OnDisable()
    for _, unitKey in ipairs(UNITS) do
        self:DisableUnitCastbar(unitKey)
    end
    if self.Anchoring and self.Anchoring.Cleanup then
        self.Anchoring:Cleanup()
    end
end

function module:OnProfileChanged()
    if self:IsEnabled() then
        self:InitializeCastbars()
    end
end

function module:OnPlayerEnteringWorld()
    if not self:IsEnabled() then return end
    self:InitializeCastbars()
end

function module:GetUnitSettings(unitKey)
    return GetUnitSettings(unitKey)
end
