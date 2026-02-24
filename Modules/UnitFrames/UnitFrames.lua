local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:NewModule("UnitFrames", "AceEvent-3.0")

local oUF = TavernUI.oUF
local LSM = LibStub("LibSharedMedia-3.0", true)
local WHITE8X8 = TavernUI.WHITE8X8

module.frames = {}
module.requiresReload = true

-- Theme defaults (hardcoded fallbacks)
local THEME_DEFAULTS = {
    statusBarTexture = "",
    frameBg = { r = 0.078, g = 0.078, b = 0.078, a = 0.98 },
    borderColor = { r = 0.169, g = 0.169, b = 0.169, a = 1 },
    borderWidth = 1,
    textColor = { r = 0.82, g = 0.82, b = 0.82, a = 1 },
    healthColorMode = "CLASS",
    healthColor = { r = 0.2, g = 0.8, b = 0.2, a = 1 },
    healthBgColor = { r = 0.06, g = 0.06, b = 0.06, a = 0.9 },
    powerColorMode = "POWER_TYPE",
    powerColor = { r = 0.2, g = 0.2, b = 0.8, a = 1 },
    powerBgColor = { r = 0.06, g = 0.06, b = 0.06, a = 0.9 },
    castbarColor = { r = 0.82, g = 0.82, b = 0.82, a = 1 },
    castbarNotInterruptibleColor = { r = 0.65, g = 0.25, b = 0.25, a = 1 },
}
module.THEME_DEFAULTS = THEME_DEFAULTS

local function GetThemeSetting(key)
    local value = module:GetSetting(key)
    if value ~= nil then return value end
    return THEME_DEFAULTS[key]
end

local function GetThemeColorValues(key)
    local color = GetThemeSetting(key)
    if type(color) == "table" then
        return color.r or 1, color.g or 1, color.b or 1, color.a or 1
    end
    return 1, 1, 1, 1
end

-- Global accessors (same signatures as before so callers don't change)
function TavernUI:GetThemeValue(key)
    return GetThemeSetting(key)
end

function TavernUI:GetThemeColor(key)
    return GetThemeColorValues(key)
end

function TavernUI:GetThemeStatusBarTexture()
    local key = GetThemeSetting("statusBarTexture")
    if key and key ~= "" and LSM then
        local path = LSM:Fetch("statusbar", key, true)
        if path then return path end
    end
    return WHITE8X8
end

local UNIT_CONFIG = {
    player       = { order = 1,  name = "Player" },
    target       = { order = 2,  name = "Target" },
    targettarget = { order = 3,  name = "Target of Target" },
    focus        = { order = 4,  name = "Focus" },
    focustarget  = { order = 5,  name = "Focus Target" },
    pet          = { order = 6,  name = "Pet" },
    boss         = { order = 10, name = "Boss" },
    arena        = { order = 11, name = "Arena" },
}

module.UNIT_CONFIG = UNIT_CONFIG

local UNIT_INDICATORS = {
    player       = { "raidTarget", "combat", "resting", "leader" },
    target       = { "raidTarget", "leader" },
    targettarget = { "raidTarget" },
    focus        = { "raidTarget" },
    focustarget  = { "raidTarget" },
    pet          = { "raidTarget" },
    boss         = { "raidTarget" },
    arena        = { "raidTarget" },
}
module.UNIT_INDICATORS = UNIT_INDICATORS

local defaults = {
    -- Theme settings (flat, read via GetThemeSetting)
    statusBarTexture = THEME_DEFAULTS.statusBarTexture,
    frameBg = THEME_DEFAULTS.frameBg,
    borderColor = THEME_DEFAULTS.borderColor,
    borderWidth = THEME_DEFAULTS.borderWidth,
    textColor = THEME_DEFAULTS.textColor,
    healthColorMode = THEME_DEFAULTS.healthColorMode,
    healthColor = THEME_DEFAULTS.healthColor,
    healthBgColor = THEME_DEFAULTS.healthBgColor,
    powerColorMode = THEME_DEFAULTS.powerColorMode,
    powerColor = THEME_DEFAULTS.powerColor,
    powerBgColor = THEME_DEFAULTS.powerBgColor,
    castbarColor = THEME_DEFAULTS.castbarColor,
    castbarNotInterruptibleColor = THEME_DEFAULTS.castbarNotInterruptibleColor,
    units = {
        player = {
            enabled = true, width = 200, height = 40,
            showPower = true, showCastbar = true, showPortrait = false,
            showClassPower = true, showInfoBar = false,
            portrait = { side = "LEFT" },
            useClassColor = false, rangeAlpha = 1,
            barLayout = "HP",
            themeOverrides = {},
            nameTag = { enabled = false, tag = "[TUI:classcolor][TUI:name]|r" },
            healthTag = { enabled = true, tag = "[TUI:curhp:short]/[TUI:maxhp:short]" },
            powerTag = { enabled = true, tag = "[TUI:curpp:short]" },
            health = { height = 0 },
            power = { height = 8 },
            castbar = {},
            classpower = { height = 4 },
            infoBar = { height = 8, tagString = "", },
            indicators = {
                raidTarget = { enabled = true, size = 16, point = "CENTER", relPoint = "TOP", offX = 0, offY = 0 },
                combat = { enabled = true, size = 16, point = "CENTER", relPoint = "TOPLEFT", offX = 0, offY = 0 },
                resting = { enabled = true, size = 16, point = "CENTER", relPoint = "TOPLEFT", offX = 0, offY = 0 },
                leader = { enabled = true, size = 16, point = "CENTER", relPoint = "TOPRIGHT", offX = 0, offY = 0 },
            },
            buffs = { enabled = false, num = 0, anchorPoint = "TOPLEFT", growthX = "RIGHT", growthY = "UP", size = 24, spacing = 2, onlyShowPlayer = false },
            debuffs = { enabled = false, num = 0, anchorPoint = "BOTTOMLEFT", growthX = "RIGHT", growthY = "DOWN", size = 24, spacing = 2, onlyShowPlayer = false },
            anchorConfig = {},
        },
        target = {
            enabled = true, width = 200, height = 40,
            showPower = true, showCastbar = true, showPortrait = false,
            showClassPower = false, showInfoBar = false,
            portrait = { side = "RIGHT" },
            useClassColor = false, rangeAlpha = 1,
            barLayout = "HP",
            themeOverrides = {},
            nameTag = { enabled = true, tag = "[TUI:classcolor][TUI:name]|r" },
            healthTag = { enabled = true, tag = "[TUI:curhp:short]/[TUI:maxhp:short]" },
            powerTag = { enabled = true, tag = "[TUI:curpp:short]" },
            health = { height = 0 },
            power = { height = 8 },
            castbar = {},
            infoBar = { height = 8, tagString = "[TUI:classcolor][TUI:level] [TUI:name] [TUI:race]", },
            indicators = {
                raidTarget = { enabled = true, size = 16, point = "CENTER", relPoint = "TOP", offX = 0, offY = 0 },
                leader = { enabled = true, size = 16, point = "CENTER", relPoint = "TOPRIGHT", offX = 0, offY = 0 },
            },
            buffs = { enabled = true, num = 20, anchorPoint = "TOPLEFT", growthX = "RIGHT", growthY = "UP", size = 24, spacing = 2, onlyShowPlayer = false },
            debuffs = { enabled = true, num = 20, anchorPoint = "BOTTOMLEFT", growthX = "RIGHT", growthY = "DOWN", size = 24, spacing = 2, onlyShowPlayer = false },
            anchorConfig = {},
        },
        targettarget = {
            enabled = true, width = 120, height = 24,
            showPower = false, showCastbar = false, showPortrait = false,
            showClassPower = false, showInfoBar = false,
            useClassColor = false, rangeAlpha = 1,
            barLayout = "HP",
            themeOverrides = {},
            nameTag = { enabled = true, tag = "[TUI:classcolor][TUI:name]|r" },
            healthTag = { enabled = true, tag = "[TUI:curhp:short]/[TUI:maxhp:short]" },
            powerTag = { enabled = true, tag = "[TUI:curpp:short]" },
            health = { height = 0 },
            power = { height = 6 },
            castbar = {},
            classpower = { height = 4 },
            infoBar = { height = 6, tagString = "", },
            indicators = {
                raidTarget = { enabled = true, size = 16, point = "CENTER", relPoint = "TOP", offX = 0, offY = 0 },
            },
            buffs = { enabled = false, num = 0, anchorPoint = "TOPLEFT", growthX = "RIGHT", growthY = "UP", size = 24, spacing = 2, onlyShowPlayer = false },
            debuffs = { enabled = false, num = 0, anchorPoint = "BOTTOMLEFT", growthX = "RIGHT", growthY = "DOWN", size = 24, spacing = 2, onlyShowPlayer = false },
            anchorConfig = {},
        },
        focus = {
            enabled = true, width = 200, height = 40,
            showPower = true, showCastbar = true, showPortrait = false,
            showClassPower = false, showInfoBar = false,
            useClassColor = false, rangeAlpha = 1,
            barLayout = "HP",
            themeOverrides = {},
            nameTag = { enabled = true, tag = "[TUI:classcolor][TUI:name]|r" },
            healthTag = { enabled = true, tag = "[TUI:curhp:short]/[TUI:maxhp:short]" },
            powerTag = { enabled = true, tag = "[TUI:curpp:short]" },
            health = { height = 0 },
            power = { height = 8 },
            castbar = {},
            classpower = { height = 4 },
            infoBar = { height = 8, tagString = "", },
            indicators = {
                raidTarget = { enabled = true, size = 16, point = "CENTER", relPoint = "TOP", offX = 0, offY = 0 },
            },
            buffs = { enabled = true, num = 12, anchorPoint = "TOPLEFT", growthX = "RIGHT", growthY = "UP", size = 24, spacing = 2, onlyShowPlayer = false },
            debuffs = { enabled = true, num = 12, anchorPoint = "BOTTOMLEFT", growthX = "RIGHT", growthY = "DOWN", size = 24, spacing = 2, onlyShowPlayer = false },
            anchorConfig = {},
        },
        focustarget = {
            enabled = true, width = 120, height = 24,
            showPower = false, showCastbar = false, showPortrait = false,
            showClassPower = false, showInfoBar = false,
            useClassColor = false, rangeAlpha = 1,
            barLayout = "HP",
            themeOverrides = {},
            nameTag = { enabled = true, tag = "[TUI:classcolor][TUI:name]|r" },
            healthTag = { enabled = true, tag = "[TUI:curhp:short]/[TUI:maxhp:short]" },
            powerTag = { enabled = true, tag = "[TUI:curpp:short]" },
            health = { height = 0 },
            power = { height = 6 },
            castbar = {},
            classpower = { height = 4 },
            infoBar = { height = 6, tagString = "", },
            indicators = {
                raidTarget = { enabled = true, size = 16, point = "CENTER", relPoint = "TOP", offX = 0, offY = 0 },
            },
            buffs = { enabled = false, num = 0, anchorPoint = "TOPLEFT", growthX = "RIGHT", growthY = "UP", size = 24, spacing = 2, onlyShowPlayer = false },
            debuffs = { enabled = false, num = 0, anchorPoint = "BOTTOMLEFT", growthX = "RIGHT", growthY = "DOWN", size = 24, spacing = 2, onlyShowPlayer = false },
            anchorConfig = {},
        },
        pet = {
            enabled = true, width = 120, height = 24,
            showPower = true, showCastbar = false, showPortrait = false,
            showClassPower = false, showInfoBar = false,
            useClassColor = false, rangeAlpha = 1,
            barLayout = "HP",
            themeOverrides = {},
            nameTag = { enabled = true, tag = "[TUI:classcolor][TUI:name]|r" },
            healthTag = { enabled = true, tag = "[TUI:curhp:short]/[TUI:maxhp:short]" },
            powerTag = { enabled = false, tag = "[TUI:curpp:short]" },
            health = { height = 0 },
            power = { height = 6 },
            castbar = {},
            classpower = { height = 4 },
            infoBar = { height = 6, tagString = "", },
            indicators = {
                raidTarget = { enabled = true, size = 16, point = "CENTER", relPoint = "TOP", offX = 0, offY = 0 },
            },
            buffs = { enabled = false, num = 0, anchorPoint = "TOPLEFT", growthX = "RIGHT", growthY = "UP", size = 24, spacing = 2, onlyShowPlayer = false },
            debuffs = { enabled = false, num = 0, anchorPoint = "BOTTOMLEFT", growthX = "RIGHT", growthY = "DOWN", size = 24, spacing = 2, onlyShowPlayer = false },
            anchorConfig = {},
        },
        boss = {
            enabled = false, width = 200, height = 40,
            showPower = true, showCastbar = true, showPortrait = false,
            showClassPower = false, showInfoBar = false,
            useClassColor = false, rangeAlpha = 1,
            barLayout = "HP",
            themeOverrides = {},
            nameTag = { enabled = true, tag = "[TUI:classcolor][TUI:name]|r" },
            healthTag = { enabled = true, tag = "[TUI:curhp:short]/[TUI:maxhp:short]" },
            powerTag = { enabled = true, tag = "[TUI:curpp:short]" },
            health = { height = 0 },
            power = { height = 8 },
            castbar = {},
            classpower = { height = 4 },
            infoBar = { height = 8, tagString = "", },
            indicators = {
                raidTarget = { enabled = true, size = 16, point = "CENTER", relPoint = "TOP", offX = 0, offY = 0 },
            },
            buffs = { enabled = true, num = 8, anchorPoint = "TOPLEFT", growthX = "RIGHT", growthY = "UP", size = 24, spacing = 2, onlyShowPlayer = false },
            debuffs = { enabled = true, num = 8, anchorPoint = "BOTTOMLEFT", growthX = "RIGHT", growthY = "DOWN", size = 24, spacing = 2, onlyShowPlayer = false },
            anchorConfig = {},
        },
        arena = {
            enabled = false, width = 200, height = 40,
            showPower = true, showCastbar = true, showPortrait = false,
            showClassPower = false, showInfoBar = false,
            portrait = { side = "RIGHT" },
            useClassColor = false, rangeAlpha = 1,
            barLayout = "HP",
            themeOverrides = {},
            nameTag = { enabled = true, tag = "[TUI:classcolor][TUI:name]|r" },
            healthTag = { enabled = true, tag = "[TUI:curhp:short]/[TUI:maxhp:short]" },
            powerTag = { enabled = true, tag = "[TUI:curpp:short]" },
            health = { height = 0 },
            power = { height = 8 },
            castbar = {},
            classpower = { height = 4 },
            infoBar = { height = 8, tagString = "", },
            indicators = {
                raidTarget = { enabled = true, size = 16, point = "CENTER", relPoint = "TOP", offX = 0, offY = 0 },
            },
            buffs = { enabled = true, num = 8, anchorPoint = "TOPLEFT", growthX = "RIGHT", growthY = "UP", size = 24, spacing = 2, onlyShowPlayer = false },
            debuffs = { enabled = true, num = 8, anchorPoint = "BOTTOMLEFT", growthX = "RIGHT", growthY = "DOWN", size = 24, spacing = 2, onlyShowPlayer = false },
            anchorConfig = {},
        },
    },
}

TavernUI:RegisterModuleDefaults("UnitFrames", defaults, false)

function module:GetUnitType(unit)
    if not unit then return nil end
    unit = unit:lower()
    local unitType = unit:gsub("%d+$", "")
    if UNIT_CONFIG[unitType] then
        return unitType
    end
    if UNIT_CONFIG[unit] then
        return unit
    end
    return nil
end

function module:GetUnitDB(unitType)
    if not unitType then return nil end
    local units = self:GetSetting("units", {})
    return units[unitType]
end

function module:OnInitialize()
    self:RegisterMessage("TavernUI_ProfileChanged", "OnProfileChanged")
    self:RegisterOptions()
end

function module:OnEnable()
    TavernUI.oUFFactory:SpawnFrames()

    if self.Anchoring then
        self.Anchoring:Initialize()
    end
end

function module:OnDisable()
    for _, frame in pairs(self.frames) do
        if frame and frame.Disable then
            frame:Disable()
        end
    end
end

function module:OnProfileChanged()
    self:RefreshAllFrames()
end


function module:RefreshAllFrames()
    for unit, _ in pairs(self.frames) do
        self:UpdateFrame(unit)
    end
end

function module:RefreshFrame(unit)
    self:UpdateFrame(unit)
end

function module:RefreshUnitType(unitType)
    for unit, _ in pairs(self.frames) do
        if self:GetUnitType(unit) == unitType then
            self:UpdateFrame(unit)
        end
    end
end

local BAR_LAYOUTS = {
    HP   = "Health / Power",
    PH   = "Power / Health",
    HIP  = "Health / Info / Power",
    IHP  = "Info / Health / Power",
    HPI  = "Health / Power / Info",
    PIH  = "Power / Info / Health",
    CHP  = "Class / Health / Power",
    HCP  = "Health / Class / Power",
    CHIP = "Class / Health / Info / Power",
    HCIP = "Health / Class / Info / Power",
}
module.BAR_LAYOUTS = BAR_LAYOUTS

local LAYOUT_DEFS = {
    HP   = { above = {},               below = {"POWER"} },
    PH   = { above = {"POWER"},        below = {} },
    HIP  = { above = {},               below = {"POWER", "INFOBAR"} },
    IHP  = { above = {"INFOBAR"},      below = {"POWER"} },
    HPI  = { above = {},               below = {"INFOBAR", "POWER"} },
    PIH  = { above = {"POWER", "INFOBAR"}, below = {} },
    CHP  = { above = {"CLASSPOWER"},   below = {"POWER"} },
    HCP  = { above = {},               below = {"POWER", "CLASSPOWER"} },
    CHIP = { above = {"CLASSPOWER"},   below = {"POWER", "INFOBAR"} },
    HCIP = { above = {},               below = {"POWER", "INFOBAR", "CLASSPOWER"} },
}

local function GetBarHeight(db, barName)
    if barName == "POWER" then
        if not db.showPower then return 0 end
        return db.power and db.power.height or 8
    elseif barName == "INFOBAR" then
        if not db.showInfoBar then return 0 end
        return db.infoBar and db.infoBar.height or 8
    elseif barName == "CLASSPOWER" then
        if not db.showClassPower then return 0 end
        return db.classpower and db.classpower.height or 4
    end
    return 0
end

local function GetBarFrame(frame, barName)
    if barName == "POWER" then return frame.TUI_Power
    elseif barName == "INFOBAR" then return frame.TUI_InfoBar
    elseif barName == "CLASSPOWER" then return frame.TUI_ClassPowerContainer
    end
end

function module:ApplyBarLayout(frame, db)
    local layout = db.barLayout or "HP"
    local def = LAYOUT_DEFS[layout] or LAYOUT_DEFS["HP"]

    local bottomOffset = 0
    for _, barName in ipairs(def.below) do
        local h = GetBarHeight(db, barName)
        if h > 0 then
            local bar = GetBarFrame(frame, barName)
            if bar then
                bar:ClearAllPoints()
                bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, bottomOffset)
                bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, bottomOffset)
                bar:SetHeight(h)
            end
            bottomOffset = bottomOffset + h
        end
    end

    local topOffset = 0
    for _, barName in ipairs(def.above) do
        local h = GetBarHeight(db, barName)
        if h > 0 then
            local bar = GetBarFrame(frame, barName)
            if bar then
                bar:ClearAllPoints()
                bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -topOffset)
                bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -topOffset)
                bar:SetHeight(h)
            end
            topOffset = topOffset + h
        end
    end

    local health = frame.Health
    if health then
        health:ClearAllPoints()
        local healthHeight = db.health and db.health.height or 0
        if healthHeight > 0 then
            health:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -topOffset)
            health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -topOffset)
            health:SetHeight(healthHeight)
        else
            health:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -topOffset)
            health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -topOffset)
            health:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, bottomOffset)
            health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, bottomOffset)
        end
    end
end

local function CalcContainerHeight(frameWidth, num, size, spacing)
    if num <= 0 then return 0 end
    local cols = math.floor(frameWidth / (size + spacing))
    if cols < 1 then cols = 1 end
    local rows = math.ceil(num / cols)
    if rows < 1 then rows = 1 end
    return rows * size + math.max(rows - 1, 0) * spacing
end

local INITIAL_ANCHOR_MAP = {
    TOPLEFT = "BOTTOMLEFT",
    TOPRIGHT = "BOTTOMRIGHT",
    BOTTOMLEFT = "TOPLEFT",
    BOTTOMRIGHT = "TOPRIGHT",
}
module.CalcContainerHeight = CalcContainerHeight
module.INITIAL_ANCHOR_MAP = INITIAL_ANCHOR_MAP

local function UpdateAuraContainer(frame, elementKey, tui_key, db)
    local container = frame[tui_key]
    if not container then return end

    local size = db.size or 24
    local spacing = db.spacing or 2
    local num = db.num or 0
    local ap = db.anchorPoint or "TOPLEFT"
    container.num = num
    container.size = size
    container.spacing = spacing
    container.growthX = db.growthX or "RIGHT"
    container.growthY = db.growthY or "UP"
    container.initialAnchor = INITIAL_ANCHOR_MAP[ap] or "BOTTOMLEFT"
    container.onlyShowPlayer = db.onlyShowPlayer or false
    container.createdButtons = container.createdButtons or 0
    container.anchoredButtons = container.anchoredButtons or 0
    container.visibleButtons = container.visibleButtons or 0
    container:SetSize(frame:GetWidth(), CalcContainerHeight(frame:GetWidth(), num, size, spacing))

    container:ClearAllPoints()
    if ap == "TOPLEFT" then
        container:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 4)
    elseif ap == "TOPRIGHT" then
        container:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 4)
    elseif ap == "BOTTOMLEFT" then
        container:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -4)
    elseif ap == "BOTTOMRIGHT" then
        container:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -4)
    end

    if db.enabled and db.num > 0 then
        frame[elementKey] = container
    else
        frame[elementKey] = nil
        container:Hide()
    end
end

local function UpdateTag(frame, fontString, newTag)
    if not fontString then return end
    local currentTag = fontString.TUI_tagString
    if currentTag ~= newTag then
        if currentTag and currentTag ~= "" then
            frame:Untag(fontString)
        end
        if newTag and newTag ~= "" then
            frame:Tag(fontString, newTag)
        end
        fontString.TUI_tagString = newTag
    end
end

local function HealthSolidPostUpdateColor(self, unit, color)
    local sc = TavernUI:GetThemeValue("healthColor")
    if sc then
        self:SetStatusBarColor(sc.r, sc.g, sc.b, sc.a or 1)
    end
end

local function PowerSolidPostUpdateColor(self, unit, color, r, g, b)
    local sc = TavernUI:GetThemeValue("powerColor")
    if sc then
        self:SetStatusBarColor(sc.r, sc.g, sc.b, sc.a or 1)
    end
end

function module:UpdateFrame(unit)
    local frame = self.frames[unit]
    if not frame then return end

    local unitType = self:GetUnitType(unit)
    local db = self:GetUnitDB(unitType)
    if not db then return end

    frame:SetSize(db.width, db.height)

    if db.showPower then
        if not frame.Power and frame.TUI_Power then
            frame.Power = frame.TUI_Power
            frame.Power.bg = frame.TUI_PowerBg
            frame:EnableElement("Power")
        end
    else
        if frame.Power then
            frame:DisableElement("Power")
            frame.Power = nil
        end
        if frame.TUI_Power then
            frame.TUI_Power:Hide()
        end
    end

    local texture = TavernUI:GetThemeStatusBarTexture()

    if frame.TUI_Bg then
        frame.TUI_Bg:SetColorTexture(TavernUI:GetThemeColor("frameBg"))
    end
    local borderWidth = TavernUI:GetThemeValue("borderWidth") or 1
    if frame.TUI_Border then
        if borderWidth > 0 then
            frame.TUI_Border:ClearAllPoints()
            frame.TUI_Border:SetPoint("TOPLEFT", -borderWidth, borderWidth)
            frame.TUI_Border:SetPoint("BOTTOMRIGHT", borderWidth, -borderWidth)
            frame.TUI_Border:SetBackdrop({ edgeFile = WHITE8X8, edgeSize = borderWidth })
            frame.TUI_Border:SetBackdropBorderColor(TavernUI:GetThemeColor("borderColor"))
            frame.TUI_Border:Show()
        else
            frame.TUI_Border:SetBackdrop(nil)
            frame.TUI_Border:Hide()
        end
    end

    if frame.Health then
        local health = frame.Health
        health:SetStatusBarTexture(texture)
        if health.bg then
            health.bg:SetTexture(texture)
            local hbg = TavernUI:GetThemeValue("healthBgColor")
            if hbg then
                health.bg:SetVertexColor(hbg.r, hbg.g, hbg.b, hbg.a or 1)
            end
        end

        health.colorClass = false
        health.colorReaction = false
        health.colorSmooth = false
        health.PostUpdateColor = nil

        if db.useClassColor then
            health.colorClass = true
            health.colorReaction = true
        else
            local colorMode = TavernUI:GetThemeValue("healthColorMode") or "CLASS"
            if colorMode == "CLASS" then
                health.colorClass = true
                health.colorReaction = true
            elseif colorMode == "REACTION" then
                health.colorReaction = true
            elseif colorMode == "HEALTH_GRADIENT" then
                health.colorSmooth = true
            elseif colorMode == "SOLID" then
                local c = TavernUI:GetThemeValue("healthColor")
                if c then
                    health:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
                end
                health.PostUpdateColor = HealthSolidPostUpdateColor
            end
        end
    end

    if frame.TUI_Power then
        frame.TUI_Power:SetStatusBarTexture(texture)
        if frame.TUI_PowerBg then
            frame.TUI_PowerBg:SetTexture(texture)
            local pbg = TavernUI:GetThemeValue("powerBgColor")
            if pbg then
                frame.TUI_PowerBg:SetVertexColor(pbg.r, pbg.g, pbg.b, pbg.a or 1)
            end
        end
        local power = frame.TUI_Power
        power.colorPower = false
        power.colorClass = false
        power.PostUpdateColor = nil

        local powerColorMode = TavernUI:GetThemeValue("powerColorMode") or "POWER_TYPE"
        if powerColorMode == "POWER_TYPE" then
            power.colorPower = true
        elseif powerColorMode == "CLASS" then
            power.colorClass = true
        elseif powerColorMode == "SOLID" then
            local c = TavernUI:GetThemeValue("powerColor")
            if c then
                power:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
            end
            power.PostUpdateColor = PowerSolidPostUpdateColor
        end
    end

    if frame.TUI_Castbar then
        frame.TUI_Castbar:SetStatusBarTexture(texture)
        if frame.TUI_Castbar.TUI_Border then
            local cbBorder = frame.TUI_Castbar.TUI_Border
            if borderWidth > 0 then
                cbBorder:ClearAllPoints()
                cbBorder:SetPoint("TOPLEFT", -borderWidth, borderWidth)
                cbBorder:SetPoint("BOTTOMRIGHT", borderWidth, -borderWidth)
                cbBorder:SetBackdrop({ edgeFile = WHITE8X8, edgeSize = borderWidth })
                cbBorder:SetBackdropBorderColor(TavernUI:GetThemeColor("borderColor"))
                cbBorder:Show()
            else
                cbBorder:SetBackdrop(nil)
                cbBorder:Hide()
            end
        end
    end

    if frame.TUI_ClassPower then
        for i = 1, #frame.TUI_ClassPower do
            frame.TUI_ClassPower[i]:SetStatusBarTexture(texture)
        end
    end

    local tr, tg, tb, ta = TavernUI:GetThemeColor("textColor")
    if frame.TUI_NameTag then frame.TUI_NameTag:SetTextColor(tr, tg, tb, ta) end
    if frame.TUI_HealthTag then frame.TUI_HealthTag:SetTextColor(tr, tg, tb, ta) end
    if frame.TUI_PowerTag then frame.TUI_PowerTag:SetTextColor(tr, tg, tb, ta) end
    if frame.TUI_InfoBarText then frame.TUI_InfoBarText:SetTextColor(tr, tg, tb, ta) end

    if db.showPortrait then
        if frame.TUI_PortraitFrame then
            local pDb = db.portrait or {}
            local side = pDb.side or "LEFT"
            local size = frame:GetHeight()
            frame.TUI_PortraitFrame:SetSize(size, size)
            frame.TUI_PortraitFrame:ClearAllPoints()
            if side == "RIGHT" then
                frame.TUI_PortraitFrame:SetPoint("LEFT", frame, "RIGHT", 0, 0)
            else
                frame.TUI_PortraitFrame:SetPoint("RIGHT", frame, "LEFT", 0, 0)
            end
            frame.TUI_PortraitFrame:Show()
        end
        if not frame.Portrait and frame.TUI_Portrait then
            frame.Portrait = frame.TUI_Portrait
            frame:EnableElement("Portrait")
        end
    else
        if frame.Portrait then
            frame:DisableElement("Portrait")
            frame.Portrait = nil
        end
        if frame.TUI_PortraitFrame then
            frame.TUI_PortraitFrame:Hide()
        end
    end

    local cbModuleHandling = TavernUI.oUFFactory.IsCastbarModuleHandling(unitType)
    if frame.TUI_Castbar then
        if db.showCastbar then
            -- UF manages castbar (takes priority)
            if frame.TUI_CastbarOwner == "CB" then
                local cbModule = TavernUI:GetModule("Castbar", true)
                if cbModule then
                    if cbModule.DisableUnitCastbar then
                        cbModule:DisableUnitCastbar(unitType)
                    end
                    if cbModule.HideBlizzardCastbar then
                        cbModule.HideBlizzardCastbar(unitType)
                    end
                end
            end
            frame.TUI_CastbarOwner = "UF"
            if not frame.Castbar then
                frame.Castbar = frame.TUI_Castbar
                frame:EnableElement("Castbar")
            end
            local cbHeight = TavernUI:GetCastbarSetting(unitType, "height", 20)
            frame.TUI_Castbar:SetHeight(cbHeight)
            if frame.TUI_Castbar.Spark then
                frame.TUI_Castbar.Spark:SetSize(2, cbHeight)
            end
            if frame.TUI_Castbar.TUI_IconContainer then
                local iconClampToBar = TavernUI:GetCastbarSetting(unitType, "iconClampToBar", true)
                local iconPixels
                if iconClampToBar then
                    iconPixels = cbHeight
                else
                    local iconSize = TavernUI:GetCastbarSetting(unitType, "iconSize", cbHeight)
                    local iconScale = TavernUI:GetCastbarSetting(unitType, "iconScale", 1.0)
                    iconPixels = iconSize * iconScale
                end
                frame.TUI_Castbar.TUI_IconContainer:SetSize(iconPixels, iconPixels)
            end

            frame.TUI_Castbar:ClearAllPoints()
            local preset = TavernUI:GetCastbarSetting(unitType, "anchorPreset", "below")
            if preset == "above" then
                frame.TUI_Castbar:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 4)
                frame.TUI_Castbar:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 4)
            else
                frame.TUI_Castbar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -4)
                frame.TUI_Castbar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -4)
            end

            frame.TUI_Castbar.TUI_castColor = TavernUI:GetCastbarSetting(unitType, "barColor")
            frame.TUI_Castbar.TUI_useClassColor = TavernUI:GetCastbarSetting(unitType, "useClassColor", false)
            frame.TUI_Castbar.TUI_notInterruptibleColor = TavernUI:GetCastbarSetting(unitType, "notInterruptibleColor")
        elseif cbModuleHandling then
            -- Castbar module handles — hand off if UF was managing
            if frame.TUI_CastbarOwner == "UF" then
                frame.TUI_CastbarOwner = nil
                if frame.Castbar then
                    frame:DisableElement("Castbar")
                    frame.Castbar = nil
                end
                local cbModule = TavernUI:GetModule("Castbar", true)
                if cbModule and cbModule:IsEnabled() and cbModule.EnableUnitCastbar then
                    cbModule:EnableUnitCastbar(unitType)
                end
            end
        else
            -- Nobody wants it, disable + hide
            if frame.TUI_CastbarOwner == "CB" then
                local cbModule = TavernUI:GetModule("Castbar", true)
                if cbModule and cbModule.DisableUnitCastbar then
                    cbModule:DisableUnitCastbar(unitType)
                end
            end
            frame.TUI_CastbarOwner = nil
            if frame.Castbar then
                frame:DisableElement("Castbar")
                frame.Castbar = nil
            end
            frame.TUI_Castbar:Hide()
        end
    end

    if frame.TUI_ClassPower then
        if db.showClassPower then
            if not frame.ClassPower then
                frame.ClassPower = frame.TUI_ClassPower
                frame:EnableElement("ClassPower")
            end
            if frame.TUI_ClassPowerContainer then
                frame.TUI_ClassPowerContainer:Show()
            end
        else
            if frame.ClassPower then
                frame:DisableElement("ClassPower")
                frame.ClassPower = nil
            end
            if frame.TUI_ClassPowerContainer then
                frame.TUI_ClassPowerContainer:Hide()
            end
        end
    end

    local indDb = db.indicators or {}
    local function UpdateIndicator(indicator, cfg, elementName)
        if not indicator then return end
        local size = cfg.size or 16
        indicator:SetSize(size, size)
        indicator:ClearAllPoints()
        indicator:SetPoint(cfg.point or "CENTER", frame, cfg.relPoint or "TOP", cfg.offX or 0, cfg.offY or 0)
        if cfg.enabled == false then
            if frame[elementName] then
                frame:DisableElement(elementName)
                frame[elementName] = nil
            end
            indicator:Hide()
        else
            if not frame[elementName] then
                frame[elementName] = indicator
                frame:EnableElement(elementName)
            end
        end
    end

    UpdateIndicator(frame.TUI_RaidTargetIndicator, indDb.raidTarget or {}, "RaidTargetIndicator")
    UpdateIndicator(frame.TUI_CombatIndicator, indDb.combat or {}, "CombatIndicator")
    UpdateIndicator(frame.TUI_RestingIndicator, indDb.resting or {}, "RestingIndicator")
    UpdateIndicator(frame.TUI_LeaderIndicator, indDb.leader or {}, "LeaderIndicator")
    UpdateIndicator(frame.TUI_AssistantIndicator, indDb.leader or {}, "AssistantIndicator")

    local buffsDb = db.buffs or {}
    local debuffsDb = db.debuffs or {}
    local wantBuffs = buffsDb.enabled and (buffsDb.num or 0) > 0
    local wantDebuffs = debuffsDb.enabled and (debuffsDb.num or 0) > 0

    if not wantBuffs and not wantDebuffs then
        if frame.Buffs or frame.Debuffs then
            frame:DisableElement("Auras")
        end
    end

    UpdateAuraContainer(frame, "Buffs", "TUI_Buffs", buffsDb)
    UpdateAuraContainer(frame, "Debuffs", "TUI_Debuffs", debuffsDb)

    if wantBuffs or wantDebuffs then
        frame:EnableElement("Auras")
    end

    if frame.TUI_InfoBar then
        if db.showInfoBar then
            local infoR, infoG, infoB, infoA = TavernUI:GetThemeColor("frameBg")
            frame.TUI_InfoBar:SetStatusBarColor(infoR, infoG, infoB, infoA)
            if frame.TUI_InfoBarText then
                local infoDb = db.infoBar or {}
                UpdateTag(frame, frame.TUI_InfoBarText, infoDb.tagString or "")
            end
            frame.TUI_InfoBar:Show()
        else
            frame.TUI_InfoBar:Hide()
        end
    end

    self:ApplyBarLayout(frame, db)

    local nameDb = db.nameTag or {}
    if frame.TUI_NameTag then
        UpdateTag(frame, frame.TUI_NameTag, nameDb.tag or "[TUI:classcolor][TUI:name]|r")
        frame.TUI_NameTag:SetShown(nameDb.enabled ~= false)
    end

    local healthDb = db.healthTag or {}
    if frame.TUI_HealthTag then
        UpdateTag(frame, frame.TUI_HealthTag, healthDb.tag or "[TUI:curhp:short]/[TUI:maxhp:short]")
        frame.TUI_HealthTag:SetShown(healthDb.enabled ~= false)
    end

    local powerDb = db.powerTag or {}
    if frame.TUI_PowerTag then
        UpdateTag(frame, frame.TUI_PowerTag, powerDb.tag or "[TUI:curpp:short]")
        frame.TUI_PowerTag:SetShown(powerDb.enabled ~= false and db.showPower)
    end

    if db.rangeAlpha and db.rangeAlpha < 1 then
        frame.Range = frame.Range or {}
        frame.Range.insideAlpha = 1
        frame.Range.outsideAlpha = db.rangeAlpha
    else
        frame.Range = nil
    end

    frame:UpdateAllElements("ForceUpdate")
end

function module:EnableTestMode()
    if self.testMode then return end
    self.testMode = true

    for unit, frame in pairs(self.frames) do
        if frame then
            UnregisterUnitWatch(frame)
            frame:Show()

            if frame.Health then
                frame.Health:SetMinMaxValues(0, 100)
                frame.Health:SetValue(math.random(40, 95))
            end
            if frame.TUI_Power and frame.TUI_Power:IsShown() then
                frame.TUI_Power:SetMinMaxValues(0, 100)
                frame.TUI_Power:SetValue(math.random(20, 80))
            end
        end
    end
end

function module:DisableTestMode()
    if not self.testMode then return end
    self.testMode = false

    for unit, frame in pairs(self.frames) do
        if frame then
            RegisterUnitWatch(frame)
            frame:UpdateAllElements("ForceUpdate")
        end
    end
end

function module:ToggleTestMode()
    if self.testMode then
        self:DisableTestMode()
    else
        self:EnableTestMode()
    end
end
