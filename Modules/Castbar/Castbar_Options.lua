local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("TavernUI", true)
local module = TavernUI:GetModule("Castbar")

if not module then return end

local Anchor = LibStub("LibAnchorRegistry-1.0", true)
local CONSTANTS = module.CONSTANTS

local Options = {}

local function GetUnitSetting(unitKey, key, default)
    return module:GetSetting("units." .. unitKey .. "." .. key, default)
end

local function SetUnitSetting(unitKey, key, value)
    module:SetSetting("units." .. unitKey .. "." .. key, value)
end

local function RefreshUnit(unitKey)
    module:RefreshCastbar(unitKey)
end

local function SetPreviewMode(unitKey, value)
    SetUnitSetting(unitKey, CONSTANTS.KEY_PREVIEW_MODE, value)
    local bar = module:GetCastbar(unitKey)
    if not bar or not module.Cast then return end
    if value then
        module.Cast:EnablePreview(bar)
    else
        module.Cast:DisablePreview(bar)
    end
end

local function SetUnitEnabled(unitKey, value)
    SetUnitSetting(unitKey, CONSTANTS.KEY_ENABLED, value)
    if value then
        local bar = module:GetCastbar(unitKey)
        if not bar then
            bar = module:CreateCastbar(unitKey)
            if module.Cast then
                module.Cast:SetupEvents(bar, unitKey)
            end
        end
        if module.Anchoring then
            module.Anchoring:RegisterBar(unitKey, bar.frame)
            module.Anchoring:ApplyAnchor(unitKey)
        end
        module.HideBlizzardCastbar(unitKey)
    else
        local bar = module:GetCastbar(unitKey)
        if bar and module.Anchoring then
            module.Anchoring:UnregisterBar(unitKey, bar.frame)
        end
        module:DestroyCastbar(unitKey)
        module.ShowBlizzardCastbar(unitKey)
    end
end

local ANCHOR_POINTS = {
    TOPLEFT = "ANCHOR_TOPLEFT", TOP = "ANCHOR_TOP", TOPRIGHT = "ANCHOR_TOPRIGHT",
    LEFT = "ANCHOR_LEFT", CENTER = "ANCHOR_CENTER", RIGHT = "ANCHOR_RIGHT",
    BOTTOMLEFT = "ANCHOR_BOTTOMLEFT", BOTTOM = "ANCHOR_BOTTOM", BOTTOMRIGHT = "ANCHOR_BOTTOMRIGHT",
}

local CATEGORY_DISPLAY_NAMES = {
    screen = "SCREEN", actionbars = "ACTION_BARS", bars = "BARS",
    resourcebars = "RESOURCE_BARS", castbars = "CASTBARS",
    cooldowns = "COOLDOWNS", cdm = "CDM", ucdm = "UCDM_CATEGORY",
    unitframes = "UNIT_FRAMES", TavernUI = "TAVERN_UI_CATEGORY",
    blizzard = "BLIZZARD", misc = "MISC",
}

local CATEGORY_ORDER = {
    screen = 0, actionbars = 1, bars = 2, resourcebars = 3, castbars = 4,
    cooldowns = 5, cdm = 6, ucdm = 7, unitframes = 8,
    TavernUI = 9, blizzard = 10, misc = 11,
}

local ANCHOR_NAMES = module.ANCHOR_NAMES or {
    player = "TavernUI.Castbar.player",
    target = "TavernUI.Castbar.target",
    focus  = "TavernUI.Castbar.focus",
}

local ICON_ANCHOR_VALUES = {
    LEFT = L["ANCHOR_LEFT"],
    RIGHT = L["ANCHOR_RIGHT"],
}

local TEXT_ANCHOR_VALUES = {
    LEFT = L["ANCHOR_LEFT"],
    CENTER = L["ANCHOR_CENTER"],
    RIGHT = L["ANCHOR_RIGHT"],
}

local UNIT_DISPLAY_NAMES = {
    player = L["PLAYER"],
    target = L["TARGET"],
    focus  = L["FOCUS"],
}

local function GetAnchorConfig(unitKey)
    return GetUnitSetting(unitKey, CONSTANTS.KEY_ANCHOR_CONFIG, {}) or {}
end

local function MergeAnchorConfig(unitKey, overrides)
    local c = GetAnchorConfig(unitKey)
    if type(c) ~= "table" then c = {} end
    return {
        target = (overrides.target ~= nil) and overrides.target or c.target,
        point = overrides.point or c.point or "CENTER",
        relativePoint = overrides.relativePoint or c.relativePoint or "CENTER",
        offsetX = (overrides.offsetX ~= nil) and overrides.offsetX or (type(c.offsetX) == "number" and c.offsetX or 0),
        offsetY = (overrides.offsetY ~= nil) and overrides.offsetY or (type(c.offsetY) == "number" and c.offsetY or 0),
    }
end

local function SetAnchorConfigAndApply(unitKey, anchorConfig)
    if module.Anchoring and anchorConfig and anchorConfig.target and anchorConfig.target ~= "" then
        module.Anchoring:ClearLayoutPositionForBar(unitKey)
    end
    SetUnitSetting(unitKey, CONSTANTS.KEY_ANCHOR_CONFIG, anchorConfig)
    if not anchorConfig or not anchorConfig.target then
        SetUnitSetting(unitKey, "anchorCategory", nil)
    end
    if module.Anchoring then
        module.Anchoring:ApplyAnchor(unitKey)
    end
end

local function GetCategoryForAnchor(anchorName)
    if not Anchor or not anchorName then return nil end
    local frame, metadata = Anchor:Get(anchorName)
    if metadata and metadata.category then
        return metadata.category
    end
    return nil
end

local function GetAnchorCategory(unitKey)
    local stored = GetUnitSetting(unitKey, "anchorCategory")
    if stored and stored ~= "None" then return stored end
    local anchorConfig = GetAnchorConfig(unitKey)
    if anchorConfig.target and anchorConfig.target ~= "UIParent" then
        local derived = GetCategoryForAnchor(anchorConfig.target)
        if derived then return derived end
    end
    return "None"
end

local function SetAnchorCategory(unitKey, value)
    if value == "None" or not value then
        SetUnitSetting(unitKey, "anchorCategory", nil)
        SetAnchorConfigAndApply(unitKey, nil)
    else
        SetUnitSetting(unitKey, "anchorCategory", value)
        local cur = GetAnchorConfig(unitKey)
        if cur and cur.target then
            local currentCategory = GetCategoryForAnchor(cur.target)
            if currentCategory ~= value then
                SetAnchorConfigAndApply(unitKey, MergeAnchorConfig(unitKey, { target = nil }))
            end
        end
    end
    AceConfigRegistry:NotifyChange("TavernUI")
end

local function GetAvailableCategories(unitKey)
    local categories = {}
    local exclude = ANCHOR_NAMES[unitKey]
    if Anchor then
        local allAnchors = Anchor:GetAll()
        for anchorName, anchorData in pairs(allAnchors) do
            if anchorName ~= exclude and anchorData.metadata then
                local cat = anchorData.metadata.category or "misc"
                if not categories[cat] then categories[cat] = true end
            end
        end
    end
    local list = {}
    for cat in pairs(categories) do
        list[#list + 1] = cat
    end
    table.sort(list, function(a, b)
        local oa, ob = CATEGORY_ORDER[a] or 99, CATEGORY_ORDER[b] or 99
        if oa ~= ob then return oa < ob end
        return a < b
    end)
    return list
end

local function CopyCastbarSettings(sourceUnit, targetUnit)
    local source = module:GetUnitSettings(sourceUnit)
    if not source then return end

    local skipKeys = { anchorConfig = true, previewMode = true }
    for key, value in pairs(source) do
        if not skipKeys[key] then
            if type(value) == "table" then
                local copy = {}
                for k, v in pairs(value) do
                    if type(v) == "table" then
                        local inner = {}
                        for ik, iv in pairs(v) do inner[ik] = iv end
                        copy[k] = inner
                    else
                        copy[k] = v
                    end
                end
                SetUnitSetting(targetUnit, key, copy)
            else
                SetUnitSetting(targetUnit, key, value)
            end
        end
    end
    RefreshUnit(targetUnit)
end

local function BuildUnitOptions(unitKey)
    local args = {}
    local order = 1
    local isPlayer = (unitKey == CONSTANTS.UNIT_PLAYER)

    args.enabled = {
        type = "toggle",
        name = L["ENABLED"],
        desc = L["ENABLE_CASTBAR_DESC"],
        order = order,
        get = function()
            return GetUnitSetting(unitKey, CONSTANTS.KEY_ENABLED) ~= false
        end,
        set = function(_, value)
            SetUnitEnabled(unitKey, value)
        end,
    }
    order = order + 1

    args.copyFrom = {
        type = "select",
        name = L["COPY_FROM"],
        desc = L["COPY_FROM_DESC"],
        order = order,
        values = function()
            local v = {}
            for _, uKey in ipairs({ "player", "target", "focus" }) do
                if uKey ~= unitKey then
                    v[uKey] = UNIT_DISPLAY_NAMES[uKey]
                end
            end
            return v
        end,
        get = function() return nil end,
        set = function(_, sourceUnit)
            CopyCastbarSettings(sourceUnit, unitKey)
            AceConfigRegistry:NotifyChange("TavernUI")
        end,
        confirm = function(_, sourceUnit)
            return string.format("Copy all settings from %s to %s?", UNIT_DISPLAY_NAMES[sourceUnit], UNIT_DISPLAY_NAMES[unitKey])
        end,
    }
    order = order + 1

    args.sizeHeader = { type = "header", name = L["SIZE"], order = order }
    order = order + 1

    args.width = {
        type = "range",
        name = L["WIDTH"],
        desc = L["BAR_WIDTH_DESC"],
        order = order,
        min = 50, max = 500, step = 1,
        get = function()
            return GetUnitSetting(unitKey, CONSTANTS.KEY_WIDTH, 250)
        end,
        set = function(_, value)
            SetUnitSetting(unitKey, CONSTANTS.KEY_WIDTH, value)
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    args.height = {
        type = "range",
        name = L["HEIGHT"],
        desc = L["BAR_HEIGHT_DESC"],
        order = order,
        min = 5, max = 100, step = 1,
        get = function()
            return GetUnitSetting(unitKey, CONSTANTS.KEY_HEIGHT, 25)
        end,
        set = function(_, value)
            SetUnitSetting(unitKey, CONSTANTS.KEY_HEIGHT, value)
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    args.barHeader = { type = "header", name = L["BAR"], order = order }
    order = order + 1

    args.barTexture = {
        type = "select",
        name = L["TEXTURE"],
        desc = L["BAR_FILL_TEXTURE_DESC"],
        order = order,
        values = function()
            return TavernUI:GetLSMMediaDropdownValues("statusbar", "", L["DEFAULT"])
        end,
        get = function()
            local v = GetUnitSetting(unitKey, CONSTANTS.KEY_BAR_TEXTURE)
            return (v and v ~= "") and v or ""
        end,
        set = function(_, value)
            SetUnitSetting(unitKey, CONSTANTS.KEY_BAR_TEXTURE, (value and value ~= "") and value or nil)
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    args.barColor = {
        type = "color",
        name = L["BAR_COLOR"],
        desc = L["BAR_COLOR_DESC"],
        order = order,
        hasAlpha = true,
        get = function()
            local c = GetUnitSetting(unitKey, CONSTANTS.KEY_BAR_COLOR, {})
            return c.r or 1, c.g or 0.7, c.b or 0, (type(c.a) == "number") and c.a or 1
        end,
        set = function(_, r, g, b, a)
            SetUnitSetting(unitKey, CONSTANTS.KEY_BAR_COLOR, { r = r, g = g, b = b, a = (a ~= nil) and a or 1 })
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    args.useClassColor = {
        type = "toggle",
        name = L["USE_CLASS_COLOUR"],
        desc = L["USE_CLASS_COLOUR_DESC"],
        order = order,
        get = function()
            return GetUnitSetting(unitKey, CONSTANTS.KEY_USE_CLASS_COLOR, false)
        end,
        set = function(_, value)
            SetUnitSetting(unitKey, CONSTANTS.KEY_USE_CLASS_COLOR, value)
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    args.bgColor = {
        type = "color",
        name = L["BACKGROUND_COLOR"],
        desc = L["BACKGROUND_COLOR_DESC"],
        order = order,
        hasAlpha = true,
        get = function()
            local c = GetUnitSetting(unitKey, CONSTANTS.KEY_BG_COLOR, {})
            return c.r or 0.149, c.g or 0.149, c.b or 0.149, (type(c.a) == "number") and c.a or 1
        end,
        set = function(_, r, g, b, a)
            SetUnitSetting(unitKey, CONSTANTS.KEY_BG_COLOR, { r = r, g = g, b = b, a = (a ~= nil) and a or 1 })
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    args.borderSize = {
        type = "range",
        name = L["BORDER_SIZE"],
        desc = L["BORDER_THICKNESS"],
        order = order,
        min = 0, max = 8, step = 1,
        get = function()
            return GetUnitSetting(unitKey, CONSTANTS.KEY_BORDER_SIZE, 1)
        end,
        set = function(_, value)
            SetUnitSetting(unitKey, CONSTANTS.KEY_BORDER_SIZE, value)
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    args.borderColor = {
        type = "color",
        name = L["BORDER_COLOR"],
        desc = L["BORDER_COLOR_ALPHA_DESC"],
        order = order,
        hasAlpha = true,
        get = function()
            local c = GetUnitSetting(unitKey, CONSTANTS.KEY_BORDER_COLOR, {})
            return c.r or 0, c.g or 0, c.b or 0, (type(c.a) == "number") and c.a or 1
        end,
        set = function(_, r, g, b, a)
            SetUnitSetting(unitKey, CONSTANTS.KEY_BORDER_COLOR, { r = r, g = g, b = b, a = (a ~= nil) and a or 1 })
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    args.notInterruptibleColor = {
        type = "color",
        name = L["NOT_INTERRUPTIBLE_COLOR"],
        desc = L["NOT_INTERRUPTIBLE_COLOR_DESC"],
        order = order,
        hasAlpha = true,
        get = function()
            local c = GetUnitSetting(unitKey, CONSTANTS.KEY_NOT_INTERRUPTIBLE_COLOR, {})
            return c.r or 0.7, c.g or 0.2, c.b or 0.2, (type(c.a) == "number") and c.a or 1
        end,
        set = function(_, r, g, b, a)
            SetUnitSetting(unitKey, CONSTANTS.KEY_NOT_INTERRUPTIBLE_COLOR, { r = r, g = g, b = b, a = (a ~= nil) and a or 1 })
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    args.channelFillForward = {
        type = "toggle",
        name = L["CHANNEL_FILL_FORWARD"],
        desc = L["CHANNEL_FILL_FORWARD_DESC"],
        order = order,
        get = function()
            return GetUnitSetting(unitKey, CONSTANTS.KEY_CHANNEL_FILL_FORWARD, false)
        end,
        set = function(_, value)
            SetUnitSetting(unitKey, CONSTANTS.KEY_CHANNEL_FILL_FORWARD, value)
        end,
    }
    order = order + 1

    args.iconHeader = { type = "header", name = L["ICON"], order = order }
    order = order + 1

    args.showIcon = {
        type = "toggle",
        name = L["SHOW_ICON"],
        desc = L["SHOW_ICON_DESC"],
        order = order,
        get = function()
            return GetUnitSetting(unitKey, CONSTANTS.KEY_SHOW_ICON) ~= false
        end,
        set = function(_, value)
            SetUnitSetting(unitKey, CONSTANTS.KEY_SHOW_ICON, value)
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    args.iconSize = {
        type = "range",
        name = L["ICON_SIZE"],
        desc = L["SIZE_OF_ICONS_DESC"],
        order = order,
        min = 10, max = 80, step = 1,
        get = function()
            return GetUnitSetting(unitKey, CONSTANTS.KEY_ICON_SIZE, 25)
        end,
        set = function(_, value)
            SetUnitSetting(unitKey, CONSTANTS.KEY_ICON_SIZE, value)
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    args.iconScale = {
        type = "range",
        name = L["ICON_SCALE"],
        desc = L["ICON_SCALE_DESC"],
        order = order,
        min = 0.5, max = 2.0, step = 0.05,
        get = function()
            return GetUnitSetting(unitKey, CONSTANTS.KEY_ICON_SCALE, 1.0)
        end,
        set = function(_, value)
            SetUnitSetting(unitKey, CONSTANTS.KEY_ICON_SCALE, value)
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    args.iconAnchor = {
        type = "select",
        name = L["ICON_ANCHOR"],
        desc = L["ICON_ANCHOR_DESC"],
        order = order,
        values = ICON_ANCHOR_VALUES,
        get = function()
            return GetUnitSetting(unitKey, CONSTANTS.KEY_ICON_ANCHOR, "LEFT")
        end,
        set = function(_, value)
            SetUnitSetting(unitKey, CONSTANTS.KEY_ICON_ANCHOR, value)
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    args.iconSpacing = {
        type = "range",
        name = L["ICON_SPACING"],
        desc = L["ICON_SPACING_DESC"],
        order = order,
        min = -10, max = 20, step = 1,
        get = function()
            return GetUnitSetting(unitKey, CONSTANTS.KEY_ICON_SPACING, 0)
        end,
        set = function(_, value)
            SetUnitSetting(unitKey, CONSTANTS.KEY_ICON_SPACING, value)
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    args.iconBorderSize = {
        type = "range",
        name = L["ICON_BORDER_SIZE"],
        desc = L["SIZE_OF_ICON_BORDER_DESC"],
        order = order,
        min = 0, max = 8, step = 1,
        get = function()
            return GetUnitSetting(unitKey, CONSTANTS.KEY_ICON_BORDER_SIZE, 2)
        end,
        set = function(_, value)
            SetUnitSetting(unitKey, CONSTANTS.KEY_ICON_BORDER_SIZE, value)
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    args.iconBorderColor = {
        type = "color",
        name = L["ICON_BORDER_COLOR"],
        desc = L["COLOR_OF_ICON_BORDER_DESC"],
        order = order,
        hasAlpha = true,
        get = function()
            local c = GetUnitSetting(unitKey, CONSTANTS.KEY_ICON_BORDER_COLOR, {})
            return c.r or 0, c.g or 0, c.b or 0, (type(c.a) == "number") and c.a or 1
        end,
        set = function(_, r, g, b, a)
            SetUnitSetting(unitKey, CONSTANTS.KEY_ICON_BORDER_COLOR, { r = r, g = g, b = b, a = (a ~= nil) and a or 1 })
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    args.textHeader = { type = "header", name = L["TEXT"], order = order }
    order = order + 1

    args.fontSize = {
        type = "range",
        name = L["FONT_SIZE"],
        desc = L["FONT_SIZE_DESC"],
        order = order,
        min = 8, max = 24, step = 1,
        get = function()
            return GetUnitSetting(unitKey, CONSTANTS.KEY_FONT_SIZE, 12)
        end,
        set = function(_, value)
            SetUnitSetting(unitKey, CONSTANTS.KEY_FONT_SIZE, value)
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    args.maxTextLength = {
        type = "range",
        name = L["MAX_TEXT_LENGTH"],
        desc = L["MAX_TEXT_LENGTH_DESC"],
        order = order,
        min = 0, max = 40, step = 1,
        get = function()
            return GetUnitSetting(unitKey, CONSTANTS.KEY_MAX_TEXT_LENGTH, 0)
        end,
        set = function(_, value)
            SetUnitSetting(unitKey, CONSTANTS.KEY_MAX_TEXT_LENGTH, value)
        end,
    }
    order = order + 1

    args.showSpellText = {
        type = "toggle",
        name = L["SHOW_SPELL_TEXT"],
        desc = L["SHOW_SPELL_TEXT_DESC"],
        order = order,
        get = function()
            return GetUnitSetting(unitKey, CONSTANTS.KEY_SHOW_SPELL_TEXT) ~= false
        end,
        set = function(_, value)
            SetUnitSetting(unitKey, CONSTANTS.KEY_SHOW_SPELL_TEXT, value)
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    args.spellTextAnchor = {
        type = "select",
        name = L["SPELL_TEXT_ANCHOR"],
        order = order,
        values = TEXT_ANCHOR_VALUES,
        get = function()
            return GetUnitSetting(unitKey, CONSTANTS.KEY_SPELL_TEXT_ANCHOR, "LEFT")
        end,
        set = function(_, value)
            SetUnitSetting(unitKey, CONSTANTS.KEY_SPELL_TEXT_ANCHOR, value)
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    args.spellTextOffsetX = {
        type = "range",
        name = L["OFFSET_X"],
        order = order,
        min = -100, max = 100, step = 1,
        get = function()
            return GetUnitSetting(unitKey, CONSTANTS.KEY_SPELL_TEXT_OFFSET_X, 4)
        end,
        set = function(_, value)
            SetUnitSetting(unitKey, CONSTANTS.KEY_SPELL_TEXT_OFFSET_X, value)
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    args.spellTextOffsetY = {
        type = "range",
        name = L["OFFSET_Y"],
        order = order,
        min = -100, max = 100, step = 1,
        get = function()
            return GetUnitSetting(unitKey, CONSTANTS.KEY_SPELL_TEXT_OFFSET_Y, 0)
        end,
        set = function(_, value)
            SetUnitSetting(unitKey, CONSTANTS.KEY_SPELL_TEXT_OFFSET_Y, value)
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    args.showTimeText = {
        type = "toggle",
        name = L["SHOW_TIME_TEXT"],
        desc = L["SHOW_TIME_TEXT_DESC"],
        order = order,
        get = function()
            return GetUnitSetting(unitKey, CONSTANTS.KEY_SHOW_TIME_TEXT) ~= false
        end,
        set = function(_, value)
            SetUnitSetting(unitKey, CONSTANTS.KEY_SHOW_TIME_TEXT, value)
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    args.timeTextAnchor = {
        type = "select",
        name = L["TIME_TEXT_ANCHOR"],
        order = order,
        values = TEXT_ANCHOR_VALUES,
        get = function()
            return GetUnitSetting(unitKey, CONSTANTS.KEY_TIME_TEXT_ANCHOR, "RIGHT")
        end,
        set = function(_, value)
            SetUnitSetting(unitKey, CONSTANTS.KEY_TIME_TEXT_ANCHOR, value)
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    args.timeTextOffsetX = {
        type = "range",
        name = L["OFFSET_X"],
        order = order,
        min = -100, max = 100, step = 1,
        get = function()
            return GetUnitSetting(unitKey, CONSTANTS.KEY_TIME_TEXT_OFFSET_X, -4)
        end,
        set = function(_, value)
            SetUnitSetting(unitKey, CONSTANTS.KEY_TIME_TEXT_OFFSET_X, value)
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    args.timeTextOffsetY = {
        type = "range",
        name = L["OFFSET_Y"],
        order = order,
        min = -100, max = 100, step = 1,
        get = function()
            return GetUnitSetting(unitKey, CONSTANTS.KEY_TIME_TEXT_OFFSET_Y, 0)
        end,
        set = function(_, value)
            SetUnitSetting(unitKey, CONSTANTS.KEY_TIME_TEXT_OFFSET_Y, value)
            RefreshUnit(unitKey)
        end,
    }
    order = order + 1

    if isPlayer then
        args.empoweredHeader = { type = "header", name = L["EMPOWERED_SETTINGS"], order = order }
        order = order + 1

        args.showEmpoweredLevel = {
            type = "toggle",
            name = L["SHOW_EMPOWERED_LEVEL"],
            desc = L["SHOW_EMPOWERED_LEVEL_DESC"],
            order = order,
            get = function()
                return GetUnitSetting(unitKey, CONSTANTS.KEY_SHOW_EMPOWERED_LEVEL, false)
            end,
            set = function(_, value)
                SetUnitSetting(unitKey, CONSTANTS.KEY_SHOW_EMPOWERED_LEVEL, value)
            end,
        }
        order = order + 1

        args.empoweredLevelTextAnchor = {
            type = "select",
            name = L["EMPOWERED_LEVEL_TEXT_ANCHOR"],
            order = order,
            values = TEXT_ANCHOR_VALUES,
            get = function()
                return GetUnitSetting(unitKey, CONSTANTS.KEY_EMPOWERED_LEVEL_TEXT_ANCHOR, "CENTER")
            end,
            set = function(_, value)
                SetUnitSetting(unitKey, CONSTANTS.KEY_EMPOWERED_LEVEL_TEXT_ANCHOR, value)
                RefreshUnit(unitKey)
            end,
        }
        order = order + 1

        args.empoweredLevelTextOffsetX = {
            type = "range",
            name = L["OFFSET_X"],
            order = order,
            min = -100, max = 100, step = 1,
            get = function()
                return GetUnitSetting(unitKey, CONSTANTS.KEY_EMPOWERED_LEVEL_TEXT_OFFSET_X, 0)
            end,
            set = function(_, value)
                SetUnitSetting(unitKey, CONSTANTS.KEY_EMPOWERED_LEVEL_TEXT_OFFSET_X, value)
                RefreshUnit(unitKey)
            end,
        }
        order = order + 1

        args.empoweredLevelTextOffsetY = {
            type = "range",
            name = L["OFFSET_Y"],
            order = order,
            min = -100, max = 100, step = 1,
            get = function()
                return GetUnitSetting(unitKey, CONSTANTS.KEY_EMPOWERED_LEVEL_TEXT_OFFSET_Y, 0)
            end,
            set = function(_, value)
                SetUnitSetting(unitKey, CONSTANTS.KEY_EMPOWERED_LEVEL_TEXT_OFFSET_Y, value)
                RefreshUnit(unitKey)
            end,
        }
        order = order + 1

        args.hideTimeTextOnEmpowered = {
            type = "toggle",
            name = L["HIDE_TIME_ON_EMPOWERED"],
            desc = L["HIDE_TIME_ON_EMPOWERED_DESC"],
            order = order,
            get = function()
                return GetUnitSetting(unitKey, CONSTANTS.KEY_HIDE_TIME_TEXT_ON_EMPOWERED, false)
            end,
            set = function(_, value)
                SetUnitSetting(unitKey, CONSTANTS.KEY_HIDE_TIME_TEXT_ON_EMPOWERED, value)
            end,
        }
        order = order + 1

        args.stageColorsHeader = { type = "header", name = L["STAGE_COLORS"], order = order }
        order = order + 1

        for i = 1, 5 do
            args["stageColor" .. i] = {
                type = "color",
                name = string.format(L["STAGE_N_COLOR"], i),
                desc = string.format(L["STAGE_N_COLOR_DESC"], i),
                order = order,
                hasAlpha = true,
                get = function()
                    local colors = GetUnitSetting(unitKey, CONSTANTS.KEY_EMPOWERED_STAGE_COLORS)
                    local c = colors and colors[i] or module.STAGE_COLORS[i]
                    return c[1] or 0.5, c[2] or 0.5, c[3] or 0.5, c[4] or 1
                end,
                set = function(_, r, g, b, a)
                    local colors = GetUnitSetting(unitKey, CONSTANTS.KEY_EMPOWERED_STAGE_COLORS) or {}
                    colors[i] = { r, g, b, (a ~= nil) and a or 1 }
                    SetUnitSetting(unitKey, CONSTANTS.KEY_EMPOWERED_STAGE_COLORS, colors)
                end,
            }
            order = order + 1
        end

        args.fillColorsHeader = { type = "header", name = L["FILL_COLORS"], order = order }
        order = order + 1

        for i = 1, 5 do
            args["fillColor" .. i] = {
                type = "color",
                name = string.format(L["FILL_N_COLOR"], i),
                desc = string.format(L["FILL_N_COLOR_DESC"], i),
                order = order,
                hasAlpha = true,
                get = function()
                    local colors = GetUnitSetting(unitKey, CONSTANTS.KEY_EMPOWERED_FILL_COLORS)
                    local c = colors and colors[i] or module.STAGE_FILL_COLORS[i]
                    return c[1] or 0.5, c[2] or 0.5, c[3] or 0.5, c[4] or 1
                end,
                set = function(_, r, g, b, a)
                    local colors = GetUnitSetting(unitKey, CONSTANTS.KEY_EMPOWERED_FILL_COLORS) or {}
                    colors[i] = { r, g, b, (a ~= nil) and a or 1 }
                    SetUnitSetting(unitKey, CONSTANTS.KEY_EMPOWERED_FILL_COLORS, colors)
                end,
            }
            order = order + 1
        end

        args.resetEmpoweredColors = {
            type = "execute",
            name = L["RESET_EMPOWERED_COLORS"],
            desc = L["RESET_EMPOWERED_COLORS_DESC"],
            order = order,
            func = function()
                SetUnitSetting(unitKey, CONSTANTS.KEY_EMPOWERED_STAGE_COLORS, nil)
                SetUnitSetting(unitKey, CONSTANTS.KEY_EMPOWERED_FILL_COLORS, nil)
                AceConfigRegistry:NotifyChange("TavernUI")
            end,
            confirm = true,
        }
        order = order + 1
    end

    args.previewHeader = { type = "header", name = L["PREVIEW_MODE"], order = order }
    order = order + 1

    args.previewMode = {
        type = "toggle",
        name = L["PREVIEW_MODE"],
        desc = L["PREVIEW_MODE_DESC"],
        order = order,
        get = function()
            return GetUnitSetting(unitKey, CONSTANTS.KEY_PREVIEW_MODE, false)
        end,
        set = function(_, value)
            SetPreviewMode(unitKey, value)
        end,
    }
    order = order + 1

    args.anchoringHeader = { type = "header", name = L["ANCHORING"], order = order }
    order = order + 1

    args.anchorCategory = {
        type = "select",
        name = L["CATEGORY"],
        desc = L["CATEGORY_OF_ANCHOR_DESC"],
        order = order,
        values = function()
            local values = { None = L["NONE_NO_ANCHORING"] }
            for _, cat in ipairs(GetAvailableCategories(unitKey)) do
                local lkey = CATEGORY_DISPLAY_NAMES[cat]
                values[cat] = (lkey and L[lkey]) or cat:gsub("^%l", string.upper)
            end
            return values
        end,
        get = function()
            return GetAnchorCategory(unitKey)
        end,
        set = function(_, value)
            SetAnchorCategory(unitKey, value)
            if module.Anchoring then module.Anchoring:ApplyAnchor(unitKey) end
        end,
    }
    order = order + 1

    args.anchorTarget = {
        type = "select",
        name = L["ANCHOR_TARGET"],
        desc = L["FRAME_TO_ANCHOR_DESC"],
        order = order,
        disabled = function()
            local category = GetAnchorCategory(unitKey)
            if category and category ~= "None" then return false end
            local anchorConfig = GetAnchorConfig(unitKey)
            if anchorConfig.target and anchorConfig.target ~= "UIParent" then
                local derived = GetCategoryForAnchor(anchorConfig.target)
                if derived then return false end
            end
            return true
        end,
        values = function()
            local values = {}
            local selectedCategory = GetAnchorCategory(unitKey)
            if Anchor and selectedCategory and selectedCategory ~= "None" then
                local exclude = ANCHOR_NAMES[unitKey]
                local anchorsByCategory = Anchor:GetByCategory(selectedCategory)
                for anchorName, anchorData in pairs(anchorsByCategory) do
                    if anchorName ~= exclude then
                        local displayName = anchorData.metadata and anchorData.metadata.displayName or anchorName
                        values[anchorName] = displayName
                    end
                end
            end
            return values
        end,
        get = function()
            local anchorConfig = GetAnchorConfig(unitKey)
            if anchorConfig.target and anchorConfig.target ~= "UIParent" then
                return anchorConfig.target
            end
            return nil
        end,
        set = function(_, value)
            if not value then
                SetAnchorConfigAndApply(unitKey, nil)
                SetAnchorCategory(unitKey, "None")
            else
                SetAnchorConfigAndApply(unitKey, MergeAnchorConfig(unitKey, { target = value }))
                local category = GetCategoryForAnchor(value)
                if category then
                    SetUnitSetting(unitKey, "anchorCategory", category)
                end
            end
            AceConfigRegistry:NotifyChange("TavernUI")
        end,
    }
    order = order + 1

    local function anchorPointValues()
        local v = {}
        for point, lkey in pairs(ANCHOR_POINTS) do
            v[point] = L[lkey] or point
        end
        return v
    end

    local function isAnchorDisabled()
        local anchorConfig = GetAnchorConfig(unitKey)
        return not anchorConfig or not anchorConfig.target or anchorConfig.target == "UIParent"
    end

    args.anchorPoint = {
        type = "select",
        name = L["POINT"],
        desc = L["ANCHOR_POINT_ON_VIEWER_DESC"],
        order = order,
        values = anchorPointValues,
        disabled = isAnchorDisabled,
        get = function()
            local anchorConfig = GetAnchorConfig(unitKey)
            return (anchorConfig and anchorConfig.point) or "CENTER"
        end,
        set = function(_, value)
            SetAnchorConfigAndApply(unitKey, MergeAnchorConfig(unitKey, { point = value }))
        end,
    }
    order = order + 1

    args.anchorRelativePoint = {
        type = "select",
        name = L["RELATIVE_POINT"],
        desc = L["ANCHOR_POINT_ON_TARGET_DESC"],
        order = order,
        values = anchorPointValues,
        disabled = isAnchorDisabled,
        get = function()
            local anchorConfig = GetAnchorConfig(unitKey)
            return (anchorConfig and anchorConfig.relativePoint) or "CENTER"
        end,
        set = function(_, value)
            SetAnchorConfigAndApply(unitKey, MergeAnchorConfig(unitKey, { relativePoint = value }))
        end,
    }
    order = order + 1

    args.anchorOffsetX = {
        type = "range",
        name = L["OFFSET_X"],
        desc = L["HORIZONTAL_OFFSET"],
        order = order,
        min = -500, max = 500, step = 1,
        disabled = isAnchorDisabled,
        get = function()
            local anchorConfig = GetAnchorConfig(unitKey)
            return (anchorConfig and type(anchorConfig.offsetX) == "number") and anchorConfig.offsetX or 0
        end,
        set = function(_, value)
            SetAnchorConfigAndApply(unitKey, MergeAnchorConfig(unitKey, { offsetX = value }))
        end,
    }
    order = order + 1

    args.anchorOffsetY = {
        type = "range",
        name = L["OFFSET_Y"],
        desc = L["VERTICAL_OFFSET"],
        order = order,
        min = -500, max = 500, step = 1,
        disabled = isAnchorDisabled,
        get = function()
            local anchorConfig = GetAnchorConfig(unitKey)
            return (anchorConfig and type(anchorConfig.offsetY) == "number") and anchorConfig.offsetY or 0
        end,
        set = function(_, value)
            SetAnchorConfigAndApply(unitKey, MergeAnchorConfig(unitKey, { offsetY = value }))
        end,
    }
    order = order + 1

    return args
end

function Options:Initialize()
    local args = {
        general = {
            type = "group",
            name = L["GENERAL"],
            order = 1,
            args = {
                enabled = {
                    type = "toggle",
                    name = L["ENABLED"],
                    desc = L["ENABLE_CASTBAR_MODULE_DESC"],
                    order = 1,
                    get = function()
                        return module:GetSetting("enabled", true)
                    end,
                    set = function(_, value)
                        module:SetSetting("enabled", value)
                        if value then
                            module:Enable()
                        else
                            module:Disable()
                        end
                    end,
                },
            },
        },
        player = {
            type = "group",
            name = L["PLAYER"],
            order = 2,
            args = BuildUnitOptions(CONSTANTS.UNIT_PLAYER),
        },
        target = {
            type = "group",
            name = L["TARGET"],
            order = 3,
            args = BuildUnitOptions(CONSTANTS.UNIT_TARGET),
        },
        focus = {
            type = "group",
            name = L["FOCUS"],
            order = 4,
            args = BuildUnitOptions(CONSTANTS.UNIT_FOCUS),
        },
    }

    AceConfig:RegisterOptionsTable("TavernUI.Castbar", {
        name = L["CASTBAR"],
        type = "group",
        args = args,
    })

    AceConfigDialog:AddToBlizOptions("TavernUI.Castbar", L["CASTBAR"], "TavernUI")

    TavernUI:RegisterModuleOptions("Castbar", {
        type = "group",
        name = L["CASTBAR"],
        args = args,
    }, L["CASTBAR"])
end

module.Options = Options
