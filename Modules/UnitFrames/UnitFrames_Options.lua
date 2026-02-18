local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("UnitFrames")
if not module then return end

local Anchor = LibStub("LibAnchorRegistry-1.0", true)

local UNIT_CONFIG = module.UNIT_CONFIG

local function RefreshCastbarModule(unitType)
    local frame = module.frames and module.frames[unitType]
    -- If UF has the frame and Castbar module is NOT owning it, refresh directly
    if frame and frame.TUI_Castbar and frame.TUI_CastbarOwner ~= "CB" then
        if module.CastbarShared then
            module.CastbarShared:RefreshCastbar(frame.TUI_Castbar, unitType)
        end
        return
    end
    -- Otherwise (Castbar module owns it, or castbar_only frame), route to Castbar module
    local cbModule = TavernUI:GetModule("Castbar", true)
    if cbModule and cbModule.RefreshCastbar then
        cbModule:RefreshCastbar(unitType)
    end
end

local ANCHOR_POINTS = {
    TOPLEFT = "Top Left", TOP = "Top", TOPRIGHT = "Top Right",
    LEFT = "Left", CENTER = "Center", RIGHT = "Right",
    BOTTOMLEFT = "Bottom Left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom Right",
}

local AURA_ANCHOR_POINTS = {
    TOPLEFT = "Top Left",
    TOPRIGHT = "Top Right",
    BOTTOMLEFT = "Bottom Left",
    BOTTOMRIGHT = "Bottom Right",
}

local GROWTH_X = { RIGHT = "Right", LEFT = "Left" }
local GROWTH_Y = { UP = "Up", DOWN = "Down" }

local CATEGORY_DISPLAY_NAMES = {
    screen = "Screen", actionbars = "Action Bars", bars = "Bars",
    resourcebars = "Resource Bars", castbars = "Castbars",
    cooldowns = "Cooldowns", cdm = "CDM", ucdm = "uCDM",
    unitframes = "Unit Frames", TavernUI = "TavernUI",
    blizzard = "Blizzard", misc = "Misc",
}

local function UnitPath(unitType, key)
    return "units." .. unitType .. "." .. key
end

local function GetUnitSetting(unitType, key, default)
    return module:GetSetting(UnitPath(unitType, key), default)
end

local function SetUnitSetting(unitType, key, value)
    module:SetSetting(UnitPath(unitType, key), value)
end

local function BuildAuraGroup(unitType, auraType, headerName, orderBase, defaultAnchorPoint)
    local dbKey = auraType:lower() .. "s"
    defaultAnchorPoint = defaultAnchorPoint or "TOPLEFT"
    return {
        [dbKey .. "Header"] = {
            type = "header",
            name = headerName,
            order = orderBase,
        },
        [dbKey .. "Enabled"] = {
            type = "toggle",
            name = "Enable " .. headerName,
            order = orderBase + 1,
            get = function() return GetUnitSetting(unitType, dbKey .. ".enabled", false) end,
            set = function(_, value)
                SetUnitSetting(unitType, dbKey .. ".enabled", value)
                module:RefreshUnitType(unitType)
            end,
        },
        [dbKey .. "Num"] = {
            type = "range",
            name = "Max " .. headerName,
            order = orderBase + 2,
            min = 0, max = 40, step = 1,
            hidden = function() return not GetUnitSetting(unitType, dbKey .. ".enabled", false) end,
            get = function() return GetUnitSetting(unitType, dbKey .. ".num", 0) end,
            set = function(_, value)
                SetUnitSetting(unitType, dbKey .. ".num", value)
                module:RefreshUnitType(unitType)
            end,
        },
        [dbKey .. "AnchorPoint"] = {
            type = "select",
            name = "Anchor Point",
            desc = "Where " .. auraType:lower() .. "s attach to the frame.",
            order = orderBase + 3,
            values = AURA_ANCHOR_POINTS,
            hidden = function() return not GetUnitSetting(unitType, dbKey .. ".enabled", false) end,
            get = function() return GetUnitSetting(unitType, dbKey .. ".anchorPoint", defaultAnchorPoint) end,
            set = function(_, value)
                SetUnitSetting(unitType, dbKey .. ".anchorPoint", value)
                module:RefreshUnitType(unitType)
            end,
        },
        [dbKey .. "GrowthX"] = {
            type = "select",
            name = "Growth X",
            order = orderBase + 4,
            values = GROWTH_X,
            hidden = function() return not GetUnitSetting(unitType, dbKey .. ".enabled", false) end,
            get = function() return GetUnitSetting(unitType, dbKey .. ".growthX", "RIGHT") end,
            set = function(_, value)
                SetUnitSetting(unitType, dbKey .. ".growthX", value)
                module:RefreshUnitType(unitType)
            end,
        },
        [dbKey .. "GrowthY"] = {
            type = "select",
            name = "Growth Y",
            order = orderBase + 5,
            values = GROWTH_Y,
            hidden = function() return not GetUnitSetting(unitType, dbKey .. ".enabled", false) end,
            get = function() return GetUnitSetting(unitType, dbKey .. ".growthY", "UP") end,
            set = function(_, value)
                SetUnitSetting(unitType, dbKey .. ".growthY", value)
                module:RefreshUnitType(unitType)
            end,
        },
        [dbKey .. "Size"] = {
            type = "range",
            name = "Icon Size",
            order = orderBase + 6,
            min = 12, max = 48, step = 1,
            hidden = function() return not GetUnitSetting(unitType, dbKey .. ".enabled", false) end,
            get = function() return GetUnitSetting(unitType, dbKey .. ".size", 24) end,
            set = function(_, value)
                SetUnitSetting(unitType, dbKey .. ".size", value)
                module:RefreshUnitType(unitType)
            end,
        },
        [dbKey .. "Spacing"] = {
            type = "range",
            name = "Spacing",
            order = orderBase + 7,
            min = 0, max = 10, step = 1,
            hidden = function() return not GetUnitSetting(unitType, dbKey .. ".enabled", false) end,
            get = function() return GetUnitSetting(unitType, dbKey .. ".spacing", 2) end,
            set = function(_, value)
                SetUnitSetting(unitType, dbKey .. ".spacing", value)
                module:RefreshUnitType(unitType)
            end,
        },
        [dbKey .. "OnlyShowPlayer"] = {
            type = "toggle",
            name = "Only Show Mine",
            desc = "Only show " .. auraType:lower() .. "s cast by you.",
            order = orderBase + 8,
            hidden = function() return not GetUnitSetting(unitType, dbKey .. ".enabled", false) end,
            get = function() return GetUnitSetting(unitType, dbKey .. ".onlyShowPlayer", false) end,
            set = function(_, value)
                SetUnitSetting(unitType, dbKey .. ".onlyShowPlayer", value)
                module:RefreshUnitType(unitType)
            end,
        },
    }
end

local TAG_HINT = "See the Tag Reference tab for all available tags."

local function BuildTagReference()
    return {
        type = "group",
        name = "Tag Reference",
        order = 100,
        args = {
            intro = {
                type = "description",
                name = "Tags are placeholders you can use in Name, Health, Power, and Info Bar tag strings. "
                    .. "Combine multiple tags to build custom displays.\n\n"
                    .. "Example:  |cff88bbdd[TUI:classcolor][TUI:name]|r|r  shows a class-colored name.\n",
                order = 0,
                fontSize = "medium",
            },
            identityHeader = {
                type = "header",
                name = "Identity",
                order = 10,
            },
            identityTags = {
                type = "description",
                name = "|cffffd200[TUI:name]|r  Full unit name\n"
                    .. "|cffffd200[TUI:name:short]|r  Name truncated to 10 characters\n"
                    .. "|cffffd200[TUI:name:vshort]|r  Name truncated to 5 characters\n"
                    .. "|cffffd200[TUI:race]|r  Unit race (Human, Orc, etc.)\n"
                    .. "|cffffd200[TUI:class]|r  Unit class (Warrior, Mage, etc.)\n"
                    .. "|cffffd200[TUI:level]|r  Unit level\n"
                    .. "|cffffd200[TUI:smartlevel]|r  Level with classification suffix (62+, 60r, Boss)\n"
                    .. "|cffffd200[TUI:classification]|r  Boss, Elite, Rare, Rare Elite, or blank\n"
                    .. "|cffffd200[TUI:group]|r  Raid group number (1-8)\n",
                order = 11,
                fontSize = "medium",
            },
            healthHeader = {
                type = "header",
                name = "Health",
                order = 20,
            },
            healthTags = {
                type = "description",
                name = "|cffffd200[TUI:curhp]|r  Current health (raw number)\n"
                    .. "|cffffd200[TUI:curhp:short]|r  Current health (abbreviated: 1.2m, 45.3k)\n"
                    .. "|cffffd200[TUI:maxhp]|r  Maximum health (raw number)\n"
                    .. "|cffffd200[TUI:maxhp:short]|r  Maximum health (abbreviated)\n"
                    .. "|cffffd200[TUI:perhp]|r  Health percentage (0-100)\n"
                    .. "|cffffd200[TUI:deficit:hp]|r  Health deficit (-45.3k) or blank at full\n",
                order = 21,
                fontSize = "medium",
            },
            powerHeader = {
                type = "header",
                name = "Power",
                order = 30,
            },
            powerTags = {
                type = "description",
                name = "|cffffd200[TUI:curpp]|r  Current power (raw number)\n"
                    .. "|cffffd200[TUI:curpp:short]|r  Current power (abbreviated)\n"
                    .. "|cffffd200[TUI:maxpp]|r  Maximum power (raw number)\n"
                    .. "|cffffd200[TUI:perpp]|r  Power percentage (0-100)\n"
                    .. "|cffffd200[TUI:curmana]|r  Current mana (abbreviated, always mana regardless of form)\n",
                order = 31,
                fontSize = "medium",
            },
            statusHeader = {
                type = "header",
                name = "Status",
                order = 40,
            },
            statusTags = {
                type = "description",
                name = "|cffffd200[TUI:dead]|r  Dead or Ghost, blank if alive\n"
                    .. "|cffffd200[TUI:offline]|r  Offline, blank if connected\n"
                    .. "|cffffd200[TUI:status]|r  Combined: Offline, Ghost, Dead, or zzz (resting)\n"
                    .. "|cffffd200[TUI:afk]|r  AFK, blank if not\n"
                    .. "|cffffd200[TUI:resting]|r  zzz when in a rest area, blank otherwise\n",
                order = 41,
                fontSize = "medium",
            },
            colorHeader = {
                type = "header",
                name = "Color",
                order = 50,
            },
            colorTags = {
                type = "description",
                name = "Color tags output |cff hex codes. Place before text and add |r after to end the color.\n\n"
                    .. "|cffffd200[TUI:classcolor]|r  Class color (Warrior brown, Mage blue, etc.)\n"
                    .. "|cffffd200[TUI:diffcolor]|r  Difficulty color based on level difference\n",
                order = 51,
                fontSize = "medium",
            },
            classHeader = {
                type = "header",
                name = "Class Resources",
                order = 60,
            },
            classTags = {
                type = "description",
                name = "|cffffd200[TUI:cpoints]|r  Combo points (blank if zero)\n",
                order = 61,
                fontSize = "medium",
            },
            examplesHeader = {
                type = "header",
                name = "Examples",
                order = 70,
            },
            examples = {
                type = "description",
                name = "|cff88bbddClass-colored name:|r\n"
                    .. "  [TUI:classcolor][TUI:name]|r\n\n"
                    .. "|cff88bbddShort health with percentage:|r\n"
                    .. "  [TUI:curhp:short] ([TUI:perhp]%)\n\n"
                    .. "|cff88bbddLevel and classification:|r\n"
                    .. "  [TUI:diffcolor][TUI:smartlevel]|r [TUI:classification]\n\n"
                    .. "|cff88bbddFull info bar:|r\n"
                    .. "  [TUI:classcolor][TUI:level] [TUI:name] [TUI:race]|r\n",
                order = 71,
                fontSize = "medium",
            },
        },
    }
end

local function BuildUnitOptions(unitType, unitInfo)
    local isBossOrArena = unitType == "boss" or unitType == "arena"

    local args = {
        enabled = {
            type = "toggle",
            name = "Enabled",
            desc = "Enable this unit frame. Requires /reload to take effect.",
            order = 1,
            get = function() return GetUnitSetting(unitType, "enabled", true) end,
            set = function(_, value)
                SetUnitSetting(unitType, "enabled", value)
            end,
        },
        sizeHeader = {
            type = "header",
            name = "Size",
            order = 10,
        },
        width = {
            type = "range",
            name = "Width",
            order = 11,
            min = 60, max = 400, step = 1,
            get = function() return GetUnitSetting(unitType, "width", 200) end,
            set = function(_, value)
                SetUnitSetting(unitType, "width", value)
                module:RefreshUnitType(unitType)
            end,
        },
        height = {
            type = "range",
            name = "Height",
            order = 12,
            min = 16, max = 100, step = 1,
            get = function() return GetUnitSetting(unitType, "height", 40) end,
            set = function(_, value)
                SetUnitSetting(unitType, "height", value)
                module:RefreshUnitType(unitType)
            end,
        },
        elementsHeader = {
            type = "header",
            name = "Elements",
            order = 20,
        },
        showPower = {
            type = "toggle",
            name = "Show Power Bar",
            order = 21,
            get = function() return GetUnitSetting(unitType, "showPower", true) end,
            set = function(_, value)
                SetUnitSetting(unitType, "showPower", value)
                module:RefreshUnitType(unitType)
            end,
        },
        showPortrait = {
            type = "toggle",
            name = "Show Portrait",
            order = 23,
            hidden = function() return unitType ~= "player" and unitType ~= "target" and unitType ~= "arena" end,
            get = function() return GetUnitSetting(unitType, "showPortrait", false) end,
            set = function(_, value)
                SetUnitSetting(unitType, "showPortrait", value)
                module:RefreshUnitType(unitType)
            end,
        },
        portraitSide = {
            type = "select",
            name = "Portrait Side",
            order = 23.5,
            values = { LEFT = "Left", RIGHT = "Right" },
            hidden = function()
                return (unitType ~= "player" and unitType ~= "target" and unitType ~= "arena")
                    or not GetUnitSetting(unitType, "showPortrait", false)
            end,
            get = function() return GetUnitSetting(unitType, "portrait.side", "LEFT") end,
            set = function(_, value)
                SetUnitSetting(unitType, "portrait.side", value)
                module:RefreshUnitType(unitType)
            end,
        },
        showClassPower = {
            type = "toggle",
            name = "Show Class Power",
            desc = "Combo points, holy power, chi, etc. (player only)",
            order = 24,
            hidden = function() return unitType ~= "player" end,
            get = function() return GetUnitSetting(unitType, "showClassPower", false) end,
            set = function(_, value)
                SetUnitSetting(unitType, "showClassPower", value)
                module:RefreshUnitType(unitType)
            end,
        },
        showInfoBar = {
            type = "toggle",
            name = "Show Info Bar",
            desc = "Optional bar with custom tag text.",
            order = 25,
            get = function() return GetUnitSetting(unitType, "showInfoBar", false) end,
            set = function(_, value)
                SetUnitSetting(unitType, "showInfoBar", value)
                module:RefreshUnitType(unitType)
            end,
        },
        rangeAlpha = {
            type = "range",
            name = "Out of Range Alpha",
            desc = "Alpha when the unit is out of range. Set to 1 to disable.",
            order = 26,
            min = 0.1, max = 1, step = 0.05,
            isPercent = false,
            get = function() return GetUnitSetting(unitType, "rangeAlpha", 1) end,
            set = function(_, value)
                SetUnitSetting(unitType, "rangeAlpha", value)
                module:RefreshUnitType(unitType)
            end,
        },
        useClassColor = {
            type = "toggle",
            name = "Use Class Color",
            desc = "Color health bar by class/reaction. When off, uses Theme health color mode.",
            order = 27,
            get = function() return GetUnitSetting(unitType, "useClassColor", false) end,
            set = function(_, value)
                SetUnitSetting(unitType, "useClassColor", value)
                module:RefreshUnitType(unitType)
            end,
        },
        nameTagHeader = {
            type = "header",
            name = "Name Tag",
            order = 30,
        },
        nameTagEnabled = {
            type = "toggle",
            name = "Show Name",
            order = 31,
            get = function() return GetUnitSetting(unitType, "nameTag.enabled", true) end,
            set = function(_, value)
                SetUnitSetting(unitType, "nameTag.enabled", value)
                module:RefreshUnitType(unitType)
            end,
        },
        nameTagString = {
            type = "input",
            name = "Name Tag String",
            desc = "oUF tag string for the name. Example: [TUI:classcolor][TUI:name]|r\n" .. TAG_HINT,
            order = 32,
            width = "full",
            hidden = function() return not GetUnitSetting(unitType, "nameTag.enabled", true) end,
            get = function() return GetUnitSetting(unitType, "nameTag.tag", "[TUI:classcolor][TUI:name]|r") end,
            set = function(_, value)
                SetUnitSetting(unitType, "nameTag.tag", value)
                module:RefreshUnitType(unitType)
            end,
        },
        healthTagHeader = {
            type = "header",
            name = "Health Tag",
            order = 35,
        },
        healthTagEnabled = {
            type = "toggle",
            name = "Show Health Text",
            order = 36,
            get = function() return GetUnitSetting(unitType, "healthTag.enabled", true) end,
            set = function(_, value)
                SetUnitSetting(unitType, "healthTag.enabled", value)
                module:RefreshUnitType(unitType)
            end,
        },
        healthTagString = {
            type = "input",
            name = "Health Tag String",
            desc = "oUF tag string for health. Example: [TUI:curhp:short]/[TUI:maxhp:short]\n" .. TAG_HINT,
            order = 37,
            width = "full",
            hidden = function() return not GetUnitSetting(unitType, "healthTag.enabled", true) end,
            get = function() return GetUnitSetting(unitType, "healthTag.tag", "[TUI:curhp:short]/[TUI:maxhp:short]") end,
            set = function(_, value)
                SetUnitSetting(unitType, "healthTag.tag", value)
                module:RefreshUnitType(unitType)
            end,
        },
        powerTagHeader = {
            type = "header",
            name = "Power Tag",
            order = 40,
        },
        powerTagEnabled = {
            type = "toggle",
            name = "Show Power Text",
            order = 41,
            hidden = function() return not GetUnitSetting(unitType, "showPower", true) end,
            get = function() return GetUnitSetting(unitType, "powerTag.enabled", true) end,
            set = function(_, value)
                SetUnitSetting(unitType, "powerTag.enabled", value)
                module:RefreshUnitType(unitType)
            end,
        },
        powerTagString = {
            type = "input",
            name = "Power Tag String",
            desc = "oUF tag string for power. Example: [TUI:curpp:short]\n" .. TAG_HINT,
            order = 42,
            width = "full",
            hidden = function()
                return not GetUnitSetting(unitType, "showPower", true) or
                    not GetUnitSetting(unitType, "powerTag.enabled", true)
            end,
            get = function() return GetUnitSetting(unitType, "powerTag.tag", "[TUI:curpp:short]") end,
            set = function(_, value)
                SetUnitSetting(unitType, "powerTag.tag", value)
                module:RefreshUnitType(unitType)
            end,
        },
        barSizesHeader = {
            type = "header",
            name = "Bar Layout",
            order = 50,
        },
        barLayout = {
            type = "select",
            name = "Bar Order",
            desc = "Stacking order of bars inside the frame (top to bottom). Health fills remaining space.",
            order = 50.5,
            values = function()
                local hasPower = GetUnitSetting(unitType, "showPower", true)
                local hasInfo = GetUnitSetting(unitType, "showInfoBar", false)
                local hasClass = GetUnitSetting(unitType, "showClassPower", false)
                local filtered = {}
                for key, label in pairs(module.BAR_LAYOUTS) do
                    local needsPower = key:find("P") ~= nil
                    local needsInfo = key:find("I") ~= nil
                    local needsClass = key:find("C") ~= nil
                    if (not needsPower or hasPower)
                        and (not needsInfo or hasInfo)
                        and (not needsClass or hasClass) then
                        filtered[key] = label
                    end
                end
                if not next(filtered) then
                    filtered["HP"] = module.BAR_LAYOUTS["HP"]
                end
                return filtered
            end,
            get = function() return GetUnitSetting(unitType, "barLayout", "HP") end,
            set = function(_, value)
                SetUnitSetting(unitType, "barLayout", value)
                module:RefreshUnitType(unitType)
            end,
        },
        powerHeight = {
            type = "range",
            name = "Power Bar Height",
            order = 51,
            min = 2, max = 30, step = 1,
            hidden = function() return not GetUnitSetting(unitType, "showPower", true) end,
            get = function() return GetUnitSetting(unitType, "power.height", 8) end,
            set = function(_, value)
                SetUnitSetting(unitType, "power.height", value)
                module:RefreshUnitType(unitType)
            end,
        },
        castbarHeader = {
            type = "header",
            name = "Castbar",
            order = 52,
            hidden = function() return unitType == "targettarget" or unitType == "focustarget" end,
        },
        showCastbar = {
            type = "toggle",
            name = "Show Castbar",
            order = 52.1,
            hidden = function() return unitType == "targettarget" or unitType == "focustarget" end,
            get = function() return GetUnitSetting(unitType, "showCastbar", true) end,
            set = function(_, value)
                SetUnitSetting(unitType, "showCastbar", value)
                module:RefreshUnitType(unitType)
            end,
        },
        castbarHeight = {
            type = "range",
            name = "Height",
            order = 52.2,
            min = 8, max = 40, step = 1,
            hidden = function()
                return unitType == "targettarget" or unitType == "focustarget"
                    or not GetUnitSetting(unitType, "showCastbar", true)
            end,
            get = function() return TavernUI:GetCastbarSetting(unitType, "height", 20) end,
            set = function(_, value)
                TavernUI:SetCastbarSetting(unitType, "height", value)
                module:RefreshUnitType(unitType)
                RefreshCastbarModule(unitType)
            end,
        },
        castbarAnchor = {
            type = "select",
            name = "Position",
            desc = "Where the castbar attaches to the unit frame.",
            order = 52.3,
            values = { below = "Below Frame", above = "Above Frame" },
            hidden = function()
                return unitType == "targettarget" or unitType == "focustarget"
                    or not GetUnitSetting(unitType, "showCastbar", true)
            end,
            get = function() return TavernUI:GetCastbarSetting(unitType, "anchorPreset", "below") end,
            set = function(_, value)
                TavernUI:SetCastbarSetting(unitType, "anchorPreset", value)
                module:RefreshUnitType(unitType)
                RefreshCastbarModule(unitType)
            end,
        },
        castbarColor = {
            type = "color",
            name = "Color",
            order = 52.4,
            hasAlpha = true,
            hidden = function()
                return unitType == "targettarget" or unitType == "focustarget"
                    or not GetUnitSetting(unitType, "showCastbar", true)
            end,
            get = function()
                local c = TavernUI:GetCastbarSetting(unitType, "barColor")
                if c then return c.r or 0.82, c.g or 0.82, c.b or 0.82, c.a or 1 end
                return 0.82, 0.82, 0.82, 1
            end,
            set = function(_, r, g, b, a)
                TavernUI:SetCastbarSetting(unitType, "barColor", { r = r, g = g, b = b, a = a or 1 })
                module:RefreshUnitType(unitType)
                RefreshCastbarModule(unitType)
            end,
        },
        castbarUseClassColor = {
            type = "toggle",
            name = "Use Class Color",
            desc = "Color the castbar by the unit's class.",
            order = 52.5,
            hidden = function()
                return unitType == "targettarget" or unitType == "focustarget"
                    or not GetUnitSetting(unitType, "showCastbar", true)
            end,
            get = function() return TavernUI:GetCastbarSetting(unitType, "useClassColor", false) end,
            set = function(_, value)
                TavernUI:SetCastbarSetting(unitType, "useClassColor", value)
                module:RefreshUnitType(unitType)
                RefreshCastbarModule(unitType)
            end,
        },
        classpowerHeight = {
            type = "range",
            name = "Class Power Height",
            order = 53,
            min = 2, max = 16, step = 1,
            hidden = function() return unitType ~= "player" or not GetUnitSetting(unitType, "showClassPower", false) end,
            get = function() return GetUnitSetting(unitType, "classpower.height", 4) end,
            set = function(_, value)
                SetUnitSetting(unitType, "classpower.height", value)
                module:RefreshUnitType(unitType)
            end,
        },
        infoBarHeader = {
            type = "header",
            name = "Info Bar",
            order = 55,
            hidden = function() return not GetUnitSetting(unitType, "showInfoBar", false) end,
        },
        infoBarHeight = {
            type = "range",
            name = "Info Bar Height",
            order = 56,
            min = 4, max = 24, step = 1,
            hidden = function() return not GetUnitSetting(unitType, "showInfoBar", false) end,
            get = function() return GetUnitSetting(unitType, "infoBar.height", 8) end,
            set = function(_, value)
                SetUnitSetting(unitType, "infoBar.height", value)
                module:RefreshUnitType(unitType)
            end,
        },
        infoBarTagString = {
            type = "input",
            name = "Info Bar Tag String",
            desc = "oUF tag string for the info bar. Example: [TUI:classcolor][TUI:level] [TUI:name] [TUI:race]\n" .. TAG_HINT,
            order = 58,
            width = "full",
            hidden = function() return not GetUnitSetting(unitType, "showInfoBar", false) end,
            get = function() return GetUnitSetting(unitType, "infoBar.tagString", "") end,
            set = function(_, value)
                SetUnitSetting(unitType, "infoBar.tagString", value)
                module:RefreshUnitType(unitType)
            end,
        },
    }

    local INDICATOR_POINTS = {
        TOPLEFT = "Top Left", TOP = "Top", TOPRIGHT = "Top Right",
        LEFT = "Left", CENTER = "Center", RIGHT = "Right",
        BOTTOMLEFT = "Bottom Left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom Right",
    }

    local INDICATOR_DEFS = {
        raidTarget = { name = "Raid Target",         order = 1 },
        combat     = { name = "Combat",              order = 2 },
        resting    = { name = "Resting",             order = 3 },
        leader     = { name = "Leader / Assistant",  order = 4 },
    }

    args.indicatorsHeader = {
        type = "header",
        name = "Indicators",
        order = 59,
    }

    local supportedIndicators = module.UNIT_INDICATORS[unitType] or {}
    for _, indKey in ipairs(supportedIndicators) do
        local indDef = INDICATOR_DEFS[indKey]
        if indDef then
            local dbPath = "indicators." .. indKey
            args["ind_" .. indKey] = {
                type = "group",
                name = indDef.name,
                inline = true,
                order = 59 + indDef.order * 0.1,
                args = {
                    enabled = {
                        type = "toggle",
                        name = "Enable",
                        order = 1,
                        get = function() return GetUnitSetting(unitType, dbPath .. ".enabled") ~= false end,
                        set = function(_, value)
                            SetUnitSetting(unitType, dbPath .. ".enabled", value)
                            module:RefreshUnitType(unitType)
                        end,
                    },
                    size = {
                        type = "range",
                        name = "Size",
                        order = 2,
                        min = 8, max = 32, step = 1,
                        hidden = function() return GetUnitSetting(unitType, dbPath .. ".enabled") == false end,
                        get = function() return GetUnitSetting(unitType, dbPath .. ".size", 16) end,
                        set = function(_, value)
                            SetUnitSetting(unitType, dbPath .. ".size", value)
                            module:RefreshUnitType(unitType)
                        end,
                    },
                    point = {
                        type = "select",
                        name = "Point",
                        order = 3,
                        values = INDICATOR_POINTS,
                        hidden = function() return GetUnitSetting(unitType, dbPath .. ".enabled") == false end,
                        get = function() return GetUnitSetting(unitType, dbPath .. ".point", "CENTER") end,
                        set = function(_, value)
                            SetUnitSetting(unitType, dbPath .. ".point", value)
                            module:RefreshUnitType(unitType)
                        end,
                    },
                    relPoint = {
                        type = "select",
                        name = "Relative Point",
                        order = 4,
                        values = INDICATOR_POINTS,
                        hidden = function() return GetUnitSetting(unitType, dbPath .. ".enabled") == false end,
                        get = function() return GetUnitSetting(unitType, dbPath .. ".relPoint", "TOP") end,
                        set = function(_, value)
                            SetUnitSetting(unitType, dbPath .. ".relPoint", value)
                            module:RefreshUnitType(unitType)
                        end,
                    },
                    offX = {
                        type = "range",
                        name = "Offset X",
                        order = 5,
                        min = -50, max = 50, step = 1,
                        hidden = function() return GetUnitSetting(unitType, dbPath .. ".enabled") == false end,
                        get = function() return GetUnitSetting(unitType, dbPath .. ".offX", 0) end,
                        set = function(_, value)
                            SetUnitSetting(unitType, dbPath .. ".offX", value)
                            module:RefreshUnitType(unitType)
                        end,
                    },
                    offY = {
                        type = "range",
                        name = "Offset Y",
                        order = 6,
                        min = -50, max = 50, step = 1,
                        hidden = function() return GetUnitSetting(unitType, dbPath .. ".enabled") == false end,
                        get = function() return GetUnitSetting(unitType, dbPath .. ".offY", 0) end,
                        set = function(_, value)
                            SetUnitSetting(unitType, dbPath .. ".offY", value)
                            module:RefreshUnitType(unitType)
                        end,
                    },
                },
            }
        end
    end

    local buffArgs = BuildAuraGroup(unitType, "Buff", "Buffs", 60, "TOPLEFT")
    for k, v in pairs(buffArgs) do args[k] = v end

    local debuffArgs = BuildAuraGroup(unitType, "Debuff", "Debuffs", 70, "BOTTOMLEFT")
    for k, v in pairs(debuffArgs) do args[k] = v end

    if not isBossOrArena then
        args.anchoringHeader = {
            type = "header",
            name = "Anchoring",
            order = 80,
        }
        args.anchorCategory = {
            type = "select",
            name = "Category",
            desc = "Category of frames to anchor to.",
            order = 81,
            values = function()
                local values = { None = "None (No Anchoring)" }
                if not Anchor then return values end
                local allAnchors = Anchor:GetAll()
                local selfAnchor = "TavernUI.UF." .. unitType
                for anchorName, anchorData in pairs(allAnchors) do
                    if anchorName ~= selfAnchor and anchorData.metadata then
                        local cat = anchorData.metadata.category or "misc"
                        if not values[cat] then
                            values[cat] = CATEGORY_DISPLAY_NAMES[cat] or cat:gsub("^%l", string.upper)
                        end
                    end
                end
                return values
            end,
            get = function()
                local stored = GetUnitSetting(unitType, "anchorCategory")
                if stored and stored ~= "None" then return stored end
                local anchorConfig = GetUnitSetting(unitType, "anchorConfig", {}) or {}
                if anchorConfig.target and anchorConfig.target ~= "UIParent" and Anchor then
                    local _, metadata = Anchor:Get(anchorConfig.target)
                    if metadata and metadata.category then return metadata.category end
                end
                return "None"
            end,
            set = function(_, value)
                if value == "None" or not value then
                    SetUnitSetting(unitType, "anchorCategory", nil)
                    SetUnitSetting(unitType, "anchorConfig", {})
                    if module.Anchoring then module.Anchoring:ApplyAnchor(unitType) end
                else
                    SetUnitSetting(unitType, "anchorCategory", value)
                    local cur = GetUnitSetting(unitType, "anchorConfig", {}) or {}
                    if cur.target and Anchor then
                        local _, metadata = Anchor:Get(cur.target)
                        if metadata and metadata.category ~= value then
                            SetUnitSetting(unitType, "anchorConfig", {})
                            if module.Anchoring then module.Anchoring:ApplyAnchor(unitType) end
                        end
                    end
                end
            end,
        }
        args.anchorTarget = {
            type = "select",
            name = "Anchor Target",
            desc = "Frame to anchor this unit frame to.",
            order = 82,
            disabled = function()
                local category = GetUnitSetting(unitType, "anchorCategory")
                return not category or category == "None"
            end,
            values = function()
                local values = {}
                if not Anchor then return values end
                local selectedCategory = GetUnitSetting(unitType, "anchorCategory")
                if not selectedCategory or selectedCategory == "None" then return values end
                local selfAnchor = "TavernUI.UF." .. unitType
                local anchorsByCategory = Anchor:GetByCategory(selectedCategory)
                for anchorName, anchorData in pairs(anchorsByCategory) do
                    if anchorName ~= selfAnchor then
                        values[anchorName] = anchorData.metadata and anchorData.metadata.displayName or anchorName
                    end
                end
                return values
            end,
            get = function()
                local anchorConfig = GetUnitSetting(unitType, "anchorConfig", {}) or {}
                if anchorConfig.target and anchorConfig.target ~= "UIParent" then
                    return anchorConfig.target
                end
                return nil
            end,
            set = function(_, value)
                if not value then
                    SetUnitSetting(unitType, "anchorConfig", {})
                    SetUnitSetting(unitType, "anchorCategory", nil)
                else
                    local cur = GetUnitSetting(unitType, "anchorConfig", {}) or {}
                    SetUnitSetting(unitType, "anchorConfig", {
                        target = value,
                        point = cur.point or "CENTER",
                        relativePoint = cur.relativePoint or "CENTER",
                        offsetX = cur.offsetX or 0,
                        offsetY = cur.offsetY or 0,
                    })
                    if Anchor then
                        local _, metadata = Anchor:Get(value)
                        if metadata and metadata.category then
                            SetUnitSetting(unitType, "anchorCategory", metadata.category)
                        end
                    end
                end
                if module.Anchoring then
                    module.Anchoring:ClearLayoutPositionForFrame(unitType)
                    module.Anchoring:ApplyAnchor(unitType)
                end
            end,
        }
        args.anchorPoint = {
            type = "select",
            name = "Point",
            desc = "Anchor point on this frame.",
            order = 83,
            values = ANCHOR_POINTS,
            disabled = function()
                local anchorConfig = GetUnitSetting(unitType, "anchorConfig", {}) or {}
                return not anchorConfig.target or anchorConfig.target == "UIParent"
            end,
            get = function()
                local anchorConfig = GetUnitSetting(unitType, "anchorConfig", {}) or {}
                return anchorConfig.point or "CENTER"
            end,
            set = function(_, value)
                local cur = GetUnitSetting(unitType, "anchorConfig", {}) or {}
                cur.point = value
                SetUnitSetting(unitType, "anchorConfig", cur)
                if module.Anchoring then
                    module.Anchoring:ClearLayoutPositionForFrame(unitType)
                    module.Anchoring:ApplyAnchor(unitType)
                end
            end,
        }
        args.anchorRelativePoint = {
            type = "select",
            name = "Relative Point",
            desc = "Anchor point on the target frame.",
            order = 84,
            values = ANCHOR_POINTS,
            disabled = function()
                local anchorConfig = GetUnitSetting(unitType, "anchorConfig", {}) or {}
                return not anchorConfig.target or anchorConfig.target == "UIParent"
            end,
            get = function()
                local anchorConfig = GetUnitSetting(unitType, "anchorConfig", {}) or {}
                return anchorConfig.relativePoint or "CENTER"
            end,
            set = function(_, value)
                local cur = GetUnitSetting(unitType, "anchorConfig", {}) or {}
                cur.relativePoint = value
                SetUnitSetting(unitType, "anchorConfig", cur)
                if module.Anchoring then
                    module.Anchoring:ClearLayoutPositionForFrame(unitType)
                    module.Anchoring:ApplyAnchor(unitType)
                end
            end,
        }
        args.anchorOffsetX = {
            type = "range",
            name = "Offset X",
            desc = "Horizontal offset from the anchor point.",
            order = 85,
            min = -500, max = 500, step = 1,
            disabled = function()
                local anchorConfig = GetUnitSetting(unitType, "anchorConfig", {}) or {}
                return not anchorConfig.target or anchorConfig.target == "UIParent"
            end,
            get = function()
                local anchorConfig = GetUnitSetting(unitType, "anchorConfig", {}) or {}
                return (type(anchorConfig.offsetX) == "number") and anchorConfig.offsetX or 0
            end,
            set = function(_, value)
                local cur = GetUnitSetting(unitType, "anchorConfig", {}) or {}
                cur.offsetX = value
                SetUnitSetting(unitType, "anchorConfig", cur)
                if module.Anchoring then
                    module.Anchoring:ClearLayoutPositionForFrame(unitType)
                    module.Anchoring:ApplyAnchor(unitType)
                end
            end,
        }
        args.anchorOffsetY = {
            type = "range",
            name = "Offset Y",
            desc = "Vertical offset from the anchor point.",
            order = 86,
            min = -500, max = 500, step = 1,
            disabled = function()
                local anchorConfig = GetUnitSetting(unitType, "anchorConfig", {}) or {}
                return not anchorConfig.target or anchorConfig.target == "UIParent"
            end,
            get = function()
                local anchorConfig = GetUnitSetting(unitType, "anchorConfig", {}) or {}
                return (type(anchorConfig.offsetY) == "number") and anchorConfig.offsetY or 0
            end,
            set = function(_, value)
                local cur = GetUnitSetting(unitType, "anchorConfig", {}) or {}
                cur.offsetY = value
                SetUnitSetting(unitType, "anchorConfig", cur)
                if module.Anchoring then
                    module.Anchoring:ClearLayoutPositionForFrame(unitType)
                    module.Anchoring:ApplyAnchor(unitType)
                end
            end,
        }
    end

    return {
        type = "group",
        name = unitInfo.name,
        order = unitInfo.order,
        args = args,
    }
end

function module:RegisterOptions()
    local args = {
        testMode = {
            type = "toggle",
            name = "Show Example Frames",
            desc = "Force-show all unit frames with sample data for configuration preview.",
            order = 0,
            width = "full",
            get = function() return module.testMode or false end,
            set = function(_, value) module:ToggleTestMode() end,
        },
        theme = self:BuildThemeOptions(),
    }

    for unitType, unitInfo in pairs(UNIT_CONFIG) do
        args[unitType] = BuildUnitOptions(unitType, unitInfo)
    end

    args.tagReference = BuildTagReference()

    local options = {
        type = "group",
        name = "Unit Frames",
        childGroups = "tab",
        args = args,
    }

    TavernUI:RegisterModuleOptions("UnitFrames", options, "Unit Frames")
end
