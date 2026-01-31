local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:NewModule("ResourceBars", "AceEvent-3.0")

local CONSTANTS = {
    UPDATE_THROTTLE_INTERVAL = 0.1,
    BAR_ID_HEALTH = "HEALTH",
    BAR_ID_PRIMARY_POWER = "PRIMARY_POWER",
    BAR_ID_STAGGER = "STAGGER",
    BAR_ID_ALTERNATE_POWER = "ALTERNATE_POWER",
    BAR_TYPE_POWER = "POWER",
    BAR_TYPE_SEGMENTED = "SEGMENTED",
    DISPLAY_TYPE_BAR = "bar",
    DISPLAY_TYPE_SEGMENTED = "segmented",
    COLOR_MODE_SOLID = "SOLID",
    COLOR_MODE_RESOURCE_TYPE = "RESOURCE_TYPE",
    COLOR_MODE_THRESHOLD = "THRESHOLD",
    COLOR_MODE_CLASS_COLOR = "CLASS_COLOR",
    COLOR_MODE_GRADIENT = "GRADIENT",
    KEY_ENABLED = "enabled",
    KEY_WIDTH = "width",
    KEY_HEIGHT = "height",
    KEY_COLOR_MODE = "colorMode",
    KEY_COLOR = "color",
    KEY_BAR_TEXTURE = "barTexture",
    KEY_BAR_BORDER = "barBorder",
    KEY_BAR_BACKGROUND = "barBackground",
    KEY_SEGMENT_TEXTURE = "segmentTexture",
    KEY_SEGMENT_WIDTH = "segmentWidth",
    KEY_SEGMENT_HEIGHT = "segmentHeight",
    KEY_SEGMENT_SPACING = "segmentSpacing",
    KEY_SEGMENT_BORDER = "segmentBorder",
    KEY_SEGMENT_BACKGROUND = "segmentBackground",
    KEY_BREAKPOINTS = "breakpoints",
    KEY_ANCHOR_CONFIG = "anchorConfig",
    KEY_BAR_TEXT = "barText",
    KEY_BAR_TEXT_POINT = "barTextPoint",
    KEY_BAR_TEXT_RELATIVE_POINT = "barTextRelativePoint",
    KEY_BAR_TEXT_OFFSET_X = "barTextOffsetX",
    KEY_BAR_TEXT_OFFSET_Y = "barTextOffsetY",
    KEY_BAR_TEXT_COLOR = "barTextColor",
    KEY_BAR_TEXT_FONT_SIZE = "barTextFontSize",
}

module.CONSTANTS = CONSTANTS

local DEFAULT_SEGMENT_BORDER = { enabled = true, size = 1, color = { r = 0, g = 0, b = 0, a = 1 } }
local DEFAULT_SEGMENT_BACKGROUND = { enabled = true, texture = nil, color = { r = 0, g = 0, b = 0, a = 0.5 } }
local DEFAULT_BAR_BORDER = { enabled = true, size = 1, color = { r = 0, g = 0, b = 0, a = 1 } }
local DEFAULT_BACKGROUND = { enabled = true, texture = nil, color = { r = 0, g = 0, b = 0, a = 0.5 } }

local DEFAULTS_SEGMENTED = {
    enabled = true,
    colorMode = CONSTANTS.COLOR_MODE_RESOURCE_TYPE,
    segmentTexture = nil,
    segmentWidth = 50,
    segmentHeight = 20,
    segmentSpacing = 2,
    segmentBorder = { enabled = true, size = 1, color = { r = 0, g = 0, b = 0, a = 1 } },
    segmentBackground = { enabled = true, texture = nil, color = { r = 0, g = 0, b = 0, a = 0.5 } },
}

local defaults = {
    enabled = true,
    throttleInterval = 0.1,
    resourceColours = {},
    classColours = {},
    resourceBarAnchorConfig = nil,
    specialResourceAnchorConfig = nil,
    bars = {
        HEALTH = {
            enabled = false,
            anchorConfig = nil,
            width = 200,
            height = 14,
            barTexture = nil,
            barBackground = DEFAULT_BACKGROUND,
            barBorder = DEFAULT_BAR_BORDER,
            colorMode = CONSTANTS.COLOR_MODE_RESOURCE_TYPE,
            color = {r = 1.0, g = 0.0, b = 0.0},
            barText = "none",
            barTextPoint = "CENTER",
            barTextRelativePoint = "CENTER",
            barTextOffsetX = 0,
            barTextOffsetY = 0,
            barTextColor = {r = 1, g = 1, b = 1, a = 1},
            barTextFontSize = 12,
        },
        PRIMARY_POWER = {
            enabled = true,
            anchorConfig = nil,
            width = 200,
            height = 14,
            barTexture = nil,
            barBackground = DEFAULT_BACKGROUND,
            barBorder = DEFAULT_BAR_BORDER,
            colorMode = CONSTANTS.COLOR_MODE_RESOURCE_TYPE,
            color = {r = 0.0, g = 0.5, b = 1.0},
            barText = "none",
            barTextPoint = "CENTER",
            barTextRelativePoint = "CENTER",
            barTextOffsetX = 0,
            barTextOffsetY = 0,
            barTextColor = {r = 1, g = 1, b = 1, a = 1},
            barTextFontSize = 12,
        },
        STAGGER = {
            enabled = true,
            anchorConfig = nil,
            width = 200,
            height = 14,
            barTexture = nil,
            barBackground = DEFAULT_BACKGROUND,
            barBorder = DEFAULT_BAR_BORDER,
            colorMode = CONSTANTS.COLOR_MODE_THRESHOLD,
            breakpoints = {
                {threshold = 0.30, color = {r = 0.0, g = 1.0, b = 0.0}},
                {threshold = 0.60, color = {r = 1.0, g = 1.0, b = 0.0}},
                {threshold = 1.0, color = {r = 1.0, g = 0.0, b = 0.0}},
            },
            barText = "none",
            barTextPoint = "CENTER",
            barTextRelativePoint = "CENTER",
            barTextOffsetX = 0,
            barTextOffsetY = 0,
            barTextColor = {r = 1, g = 1, b = 1, a = 1},
            barTextFontSize = 12,
        },
        ALTERNATE_POWER = {
            enabled = true,
            anchorConfig = nil,
            width = 200,
            height = 14,
            barTexture = nil,
            barBackground = DEFAULT_BACKGROUND,
            barBorder = DEFAULT_BAR_BORDER,
            colorMode = CONSTANTS.COLOR_MODE_RESOURCE_TYPE,
            barText = "none",
            barTextPoint = "CENTER",
            barTextRelativePoint = "CENTER",
            barTextOffsetX = 0,
            barTextOffsetY = 0,
            barTextColor = {r = 1, g = 1, b = 1, a = 1},
            barTextFontSize = 12,
        },
    },
}

TavernUI:RegisterModuleDefaults("ResourceBars", defaults, true)

local bars = {}
local activeBarIds = {}

function module:OnInitialize()
    self:RegisterMessage("TavernUI_ProfileChanged", "OnProfileChanged")
    
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:RegisterEvent("PLAYER_LOGIN", "OnPlayerEnteringWorld")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnSpecializationChanged")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "OnShapeshiftFormChanged")
    
    if self.Anchoring then
        self.Anchoring:Initialize()
    end
    
    if self.Options then
        self.Options:Initialize()
    end
    
    self:WatchSetting("enabled", function(newValue, oldValue)
        if newValue then
            self:Enable()
        else
            self:Disable()
        end
    end)
end

function module:OnEnable()
    self:RebuildActiveBars()
    self:RegisterPowerEvents()
end

function module:OnDisable()
    self:UnregisterAllEvents()
    self:ClearAllBars()
end

function module:OnProfileChanged()
    self:RebuildActiveBars()
end

function module:OnPlayerEnteringWorld()
    self:RebuildActiveBars()
end

function module:OnSpecializationChanged()
    self:RebuildActiveBars()
end

function module:OnShapeshiftFormChanged()
    if UnitClassBase("player") == "DRUID" then
        self:RebuildActiveBars()
    end
end

function module:RebuildActiveBars()
    if not self:IsEnabled() then
        return
    end
    
    local class = select(3, UnitClass("player"))
    local spec = GetSpecialization()
    local form = GetShapeshiftForm()
    
    local newActiveBars = self.Data:GetActiveBarsForClass(class, spec, form)
    
    local toDestroy = {}
    for barId, _ in pairs(bars) do
        local shouldDestroy = not newActiveBars[barId]
        if not shouldDestroy then
            local config = self:GetBarConfig(barId)
            shouldDestroy = config[CONSTANTS.KEY_ENABLED] == false
        end
        if shouldDestroy then
            toDestroy[#toDestroy + 1] = barId
        end
    end
    for _, barId in ipairs(toDestroy) do
        self:DestroyBar(barId)
    end
    
    for barId, _ in pairs(newActiveBars) do
        if not bars[barId] then
            local config = self:GetBarConfig(barId)
            if config[CONSTANTS.KEY_ENABLED] ~= false then
                self:CreateBar(barId)
            end
        end
    end
    
    activeBarIds = newActiveBars
    
    if self.Anchoring then
        self.Anchoring:UpdateAnchors()
    end
end

function module:CreateBar(barId)
    if bars[barId] then
        return
    end
    
    if not self.Bar then
        return
    end
    
    local barType = self:GetBarType(barId)
    if not barType then
        return
    end
    
    local config = self:GetBarConfig(barId)
    if config[CONSTANTS.KEY_ENABLED] == false then
        return
    end
    
    local bar = self.Bar:CreateBar(barId, barType, config)
    if bar then
        bars[barId] = bar
        if self.Anchoring then
            self.Anchoring:RegisterBar(barId, bar)
            self.Anchoring:ApplyAnchor(barId)
        end
        self:UpdateBar(barId)
    end
end

function module:DestroyBar(barId)
    if not bars[barId] then
        return
    end
    local frame = bars[barId]
    if self.Anchoring and self.Anchoring.UnregisterBar then
        self.Anchoring:UnregisterBar(barId, frame)
    end
    if self.Bar and frame.Destroy then
        frame:Destroy()
    end
    bars[barId] = nil
end

function module:ClearAllBars()
    for barId, _ in pairs(bars) do
        self:DestroyBar(barId)
    end
    bars = {}
    activeBarIds = {}
end

function module:IsResourceBarType(barId)
    return self.Data and self.Data.SEGMENTED_TYPES and self.Data.SEGMENTED_TYPES[barId] ~= nil
end

function module:IsSpecialResourceType(barId)
    if barId == CONSTANTS.BAR_ID_ALTERNATE_POWER then return false end
    return self.Data and self.Data.SPECIAL_RESOURCES and self.Data.SPECIAL_RESOURCES[barId] ~= nil
end

function module:GetBarType(barId)
    if barId == CONSTANTS.BAR_ID_HEALTH or barId == CONSTANTS.BAR_ID_PRIMARY_POWER then
        return CONSTANTS.BAR_TYPE_POWER
    end
    local resource = self.Data.SEGMENTED_TYPES[barId] or self.Data.SPECIAL_RESOURCES[barId]
    if not resource then
        return nil
    end
    if resource.displayType == CONSTANTS.DISPLAY_TYPE_BAR then
        return CONSTANTS.BAR_TYPE_POWER
    end
    return CONSTANTS.BAR_TYPE_SEGMENTED
end

function module:GetDefaultPowerTypeColor(powerType)
    if self.Data and self.Data.POWER_TYPES and self.Data.POWER_TYPES.PRIMARY_POWER and self.Data.POWER_TYPES.PRIMARY_POWER.powerTypes then
        local c = self.Data.POWER_TYPES.PRIMARY_POWER.powerTypes[powerType]
        if c and c.color then return c.color end
    end
    if PowerBarColor and powerType and PowerBarColor[powerType] then
        local c = PowerBarColor[powerType]
        return { r = c.r or 1, g = c.g or 1, b = c.b or 1 }
    end
    return { r = 1, g = 1, b = 1 }
end

function module:GetDefaultResourceColor(barId)
    if barId == CONSTANTS.BAR_ID_HEALTH then
        return { r = 1, g = 0, b = 0 }
    end
    if self.Data then
        local seg = self.Data.SEGMENTED_TYPES and self.Data.SEGMENTED_TYPES[barId]
        if seg and seg.color then return seg.color end
        local spec = self.Data.SPECIAL_RESOURCES and self.Data.SPECIAL_RESOURCES[barId]
        if spec and spec.color then return spec.color end
    end
    return { r = 1, g = 1, b = 1 }
end

local function copyTableShallow(src)
    local t = {}
    for k, v in pairs(src or {}) do
        t[k] = v
    end
    return t
end

local function applySegmentedDefaults(config)
    local def = DEFAULTS_SEGMENTED
    for k, v in pairs(def) do
        if config[k] == nil then
            if k == CONSTANTS.KEY_SEGMENT_BORDER then
                local b = def[CONSTANTS.KEY_SEGMENT_BORDER]
                config[CONSTANTS.KEY_SEGMENT_BORDER] = { enabled = b.enabled, size = b.size, color = { r = b.color.r, g = b.color.g, b = b.color.b, a = b.color.a } }
            elseif k == CONSTANTS.KEY_SEGMENT_BACKGROUND then
                local bg = def[CONSTANTS.KEY_SEGMENT_BACKGROUND]
                config[CONSTANTS.KEY_SEGMENT_BACKGROUND] = { enabled = bg.enabled, texture = bg.texture, color = { r = bg.color.r, g = bg.color.g, b = bg.color.b, a = bg.color.a } }
            else
                config[k] = v
            end
        end
    end
end

local function normalizeColorMode(mode)
    if mode == CONSTANTS.COLOR_MODE_GRADIENT then
        return CONSTANTS.COLOR_MODE_SOLID
    end
    return mode
end

local function getDefaultColorMode(barId)
    return barId == CONSTANTS.BAR_ID_STAGGER and CONSTANTS.COLOR_MODE_THRESHOLD or CONSTANTS.COLOR_MODE_RESOURCE_TYPE
end

function module:GetEffectiveResourceColor(barId, resColours)
    resColours = resColours or self:GetSetting("resourceColours", {}) or {}
    if barId == CONSTANTS.BAR_ID_PRIMARY_POWER then
        local powerType = UnitPowerType("player")
        local ptColours = resColours.powerTypes and resColours.powerTypes[powerType]
        return (type(ptColours) == "table" and (ptColours.r or ptColours.g or ptColours.b) and ptColours)
            or self:GetDefaultPowerTypeColor(powerType)
    end
    local resColor = resColours[barId] or resColours[CONSTANTS.BAR_ID_ALTERNATE_POWER]
    return (type(resColor) == "table" and (resColor.r or resColor.g or resColor.b) and resColor)
        or self:GetDefaultResourceColor(barId)
end

function module:GetBarConfig(barId)
    local db = self:GetDB()
    local barDefaults = defaults.bars[barId] or {}
    local raw = db.bars[barId] or barDefaults
    local config = copyTableShallow(raw)
    local barType = self:GetBarType(barId)

    if barType == CONSTANTS.BAR_TYPE_SEGMENTED then
        applySegmentedDefaults(config)
    end

    local colorMode = normalizeColorMode(config.colorMode or getDefaultColorMode(barId))
    config.colorMode = colorMode

    if colorMode == CONSTANTS.COLOR_MODE_CLASS_COLOR then
        local _, classFile = UnitClass("player")
        if classFile and RAID_CLASS_COLORS then
            local classColours = self:GetSetting("classColours", {}) or {}
            local cc = classColours[classFile] or (RAID_CLASS_COLORS[classFile] and { r = RAID_CLASS_COLORS[classFile].r, g = RAID_CLASS_COLORS[classFile].g, b = RAID_CLASS_COLORS[classFile].b })
            if cc then
                config.color = { r = cc.r or 1, g = cc.g or 1, b = cc.b or 1, a = (type(cc.a) == "number") and cc.a or 1 }
            end
        end
    end

    if colorMode == CONSTANTS.COLOR_MODE_RESOURCE_TYPE or (colorMode == CONSTANTS.COLOR_MODE_SOLID and (not config.color or not config.color.r)) then
        local resColours = self:GetSetting("resourceColours", {}) or {}
        local effective = self:GetEffectiveResourceColor(barId, resColours)
        if colorMode == CONSTANTS.COLOR_MODE_RESOURCE_TYPE then
            config.color = effective
        else
            config.color = (raw.color and (raw.color.r or raw.color.g or raw.color.b)) and raw.color or effective
        end
    end

    if config.color and type(config.color) == "table" then
        config.color.a = (type(config.color.a) == "number") and config.color.a or 1
    end
    if self:IsResourceBarType(barId) then
        local shared = self:GetSetting("resourceBarAnchorConfig")
        config.anchorConfig = (type(shared) == "table") and shared or nil
    elseif self:IsSpecialResourceType(barId) then
        local shared = self:GetSetting("specialResourceAnchorConfig")
        config.anchorConfig = (type(shared) == "table") and shared or nil
    end
    local barDef = defaults.bars[barId]
    if barDef then
        config.barText = (config.barText ~= nil and config.barText ~= "") and config.barText or barDef.barText
        config.barTextPoint = config.barTextPoint or barDef.barTextPoint
        config.barTextRelativePoint = config.barTextRelativePoint or barDef.barTextRelativePoint
        config.barTextOffsetX = (type(config.barTextOffsetX) == "number") and config.barTextOffsetX or barDef.barTextOffsetX
        config.barTextOffsetY = (type(config.barTextOffsetY) == "number") and config.barTextOffsetY or barDef.barTextOffsetY
        config.barTextColor = (type(config.barTextColor) == "table" and (config.barTextColor.r or config.barTextColor.g or config.barTextColor.b)) and config.barTextColor or barDef.barTextColor
        config.barTextFontSize = (type(config.barTextFontSize) == "number" and config.barTextFontSize > 0) and config.barTextFontSize or barDef.barTextFontSize
    end
    return config
end

function module:RegisterPowerEvents()
    self:RegisterEvent("UNIT_POWER_FREQUENT", "OnUnitPowerFrequent")
    self:RegisterEvent("UNIT_MAXPOWER", "OnUnitPowerFrequent")
    self:RegisterEvent("UNIT_DISPLAYPOWER", "OnUnitPowerFrequent")
    self:RegisterEvent("RUNE_POWER_UPDATE", "OnRunePowerUpdate")
    self:RegisterEvent("UNIT_POWER_POINT_CHARGE", "OnUnitPowerPointCharge")
    self:RegisterEvent("UNIT_POWER_BAR_SHOW", "OnUnitPowerBarShow")
    self:RegisterEvent("UNIT_POWER_BAR_HIDE", "OnUnitPowerBarHide")
    self:RegisterEvent("UNIT_HEALTH", "OnUnitHealth")
    self:RegisterEvent("UNIT_MAXHEALTH", "OnUnitHealth")
end

function module:OnUnitPowerFrequent(event, unit)
    if unit ~= "player" then
        return
    end
    
    self:UpdateBars({"PRIMARY_POWER", "COMBO_POINTS", "HOLY_POWER", "CHI", "SOUL_SHARDS", "ARCANE_CHARGES", "ESSENCE"})
end

function module:OnRunePowerUpdate()
    self:UpdateBars({"RUNES"})
end

function module:OnUnitPowerPointCharge(event, unit, powerType)
    if unit ~= "player" then
        return
    end
    
    if powerType == Enum.PowerType.Essence then
        self:UpdateBars({"ESSENCE"})
    end
end

function module:OnUnitPowerBarShow(event, unit)
    if unit ~= "player" then
        return
    end
    
    self:UpdateBars({"ALTERNATE_POWER"})
end

function module:OnUnitPowerBarHide(event, unit)
    if unit ~= "player" then
        return
    end
    
    self:UpdateBars({"ALTERNATE_POWER"})
end

function module:OnUnitHealth(event, unit)
    if unit ~= "player" then
        return
    end
    
    self:UpdateBars({"HEALTH", "STAGGER"})
end

function module:UpdateBars(barIds)
    if not self.Throttle then
        return
    end
    
    local interval = self:GetSetting("throttleInterval", CONSTANTS.UPDATE_THROTTLE_INTERVAL)
    
    for _, barId in ipairs(barIds) do
        if activeBarIds[barId] and bars[barId] then
            self.Throttle:ThrottleUpdate(barId, interval, function()
                self:UpdateBar(barId)
            end)
        end
    end
end

function module:UpdateBar(barId)
    if not bars[barId] then
        return
    end

    bars[barId].config = self:GetBarConfig(barId)
    local config = bars[barId].config
    if config[CONSTANTS.KEY_ENABLED] == false then
        if bars[barId].Hide then
            bars[barId]:Hide()
        end
        return
    end

    local result
    if self.Providers then
        local provider = self.Providers:GetProvider(barId)
        if provider then
            result = provider()
        end
    end

    if not result then
        if self.Text and self.Text.Apply then
            self.Text:Apply(barId, bars[barId], config, nil)
        end
        if self:GetBarType(barId) == CONSTANTS.BAR_TYPE_POWER and bars[barId].ApplyVisualConfig then
            bars[barId]:Show()
            bars[barId]:ApplyVisualConfig()
        elseif bars[barId].Hide then
            bars[barId]:Hide()
        end
        return
    end

    if bars[barId].Show then
        bars[barId]:Show()
    end

    if bars[barId].Update then
        bars[barId]:Update(result)
    end

    if self.Text and self.Text.Apply then
        self.Text:Apply(barId, bars[barId], config, result)
    end
end

function module:GetHealthBarIds()
    return { CONSTANTS.BAR_ID_HEALTH }
end

function module:GetPowerBarIds()
    return { CONSTANTS.BAR_ID_PRIMARY_POWER, CONSTANTS.BAR_ID_ALTERNATE_POWER }
end

function module:GetResourceBarIds()
    local list = {}
    if self.Data and self.Data.SEGMENTED_TYPES then
        for id in pairs(self.Data.SEGMENTED_TYPES) do
            list[#list + 1] = id
        end
    end
    if self.Data and self.Data.SPECIAL_RESOURCES then
        for id in pairs(self.Data.SPECIAL_RESOURCES) do
            if id ~= CONSTANTS.BAR_ID_ALTERNATE_POWER then
                list[#list + 1] = id
            end
        end
    end
    table.sort(list)
    return list
end

function module:GetSpecialResourceBarIds()
    local list = {}
    if self.Data and self.Data.SPECIAL_RESOURCES then
        for id in pairs(self.Data.SPECIAL_RESOURCES) do
            if id ~= CONSTANTS.BAR_ID_ALTERNATE_POWER then
                list[#list + 1] = id
            end
        end
    end
    table.sort(list)
    return list
end

function module:GetAllBarIds()
    local health = self:GetHealthBarIds()
    local power = self:GetPowerBarIds()
    local resource = self:GetResourceBarIds()
    local all = {}
    for _, id in ipairs(power) do all[#all + 1] = id end
    for _, id in ipairs(resource) do all[#all + 1] = id end
    return all
end

module.bars = bars
module.activeBarIds = activeBarIds
