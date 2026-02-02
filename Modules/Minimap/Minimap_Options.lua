local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("Minimap", true)

if not module then return end

local ANCHOR_POSITIONS = {
    TOPLEFT = "Top Left",
    TOP = "Top",
    TOPRIGHT = "Top Right",
    LEFT = "Left",
    CENTER = "Center",
    RIGHT = "Right",
    BOTTOMLEFT = "Bottom Left",
    BOTTOM = "Bottom",
    BOTTOMRIGHT = "Bottom Right",
}

local function GetFontValues()
    return TavernUI:GetLSMMediaDropdownValues("font", "", "Default")
end

local STRATA_VALUES = {
    BACKGROUND = "Background",
    LOW = "Low",
    MEDIUM = "Medium",
    HIGH = "High",
    DIALOG = "Dialog",
}

--------------------------------------------------------------------------------
-- Tab 1: General
--------------------------------------------------------------------------------

local function BuildGeneralTab()
    local args = {}
    local order = 1

    args.shapeHeader = {type = "header", name = "Shape & Size", order = order}
    order = order + 1

    args.shape = {
        type = "select",
        name = "Shape",
        desc = "Minimap shape",
        order = order,
        values = {SQUARE = "Square", ROUND = "Round"},
        get = function() return module:GetSetting("shape", "SQUARE") end,
        set = function(_, value)
            module:SetSetting("shape", value)
            module:SetShape()
            if module.Elements then module.Elements.RefreshAll() end
        end,
    }
    order = order + 1

    args.size = {
        type = "range",
        name = "Size",
        desc = "Minimap size in pixels",
        order = order,
        min = 120, max = 380, step = 1,
        get = function() return module:GetSetting("size", 180) end,
        set = function(_, value)
            module:SetSetting("size", value, {type = "number", min = 120, max = 380})
            module:UpdateSize()
            module:UpdateBackdrop()
            if module.Elements then module.Elements.RefreshAll() end
        end,
    }
    order = order + 1

    args.lock = {
        type = "toggle",
        name = "Lock Position",
        desc = "Prevent minimap from being dragged",
        order = order,
        get = function() return module:GetSetting("lock", false) end,
        set = function(_, value)
            module:SetSetting("lock", value)
            module:UpdateLock()
        end,
    }
    order = order + 1

    args.borderHeader = {type = "header", name = "Border", order = order}
    order = order + 1

    args.borderSize = {
        type = "range",
        name = "Border Size",
        desc = "Border thickness in pixels (0 = no border)",
        order = order,
        min = 0, max = 10, step = 1,
        get = function() return module:GetSetting("borderSize", 3) end,
        set = function(_, value)
            module:SetSetting("borderSize", value, {type = "number", min = 0, max = 10})
            module:UpdateBackdrop()
        end,
    }
    order = order + 1

    args.borderColor = {
        type = "color",
        name = "Border Color",
        desc = "Color of the minimap border",
        order = order,
        hasAlpha = true,
        disabled = function()
            return module:GetSetting("borderSize", 3) == 0 or module:GetSetting("useClassColorBorder", false)
        end,
        get = function()
            local c = module:GetSetting("borderColor", {r=0, g=0, b=0, a=1})
            return c.r or 0, c.g or 0, c.b or 0, c.a or 1
        end,
        set = function(_, r, g, b, a)
            module:SetSetting("borderColor", {r=r, g=g, b=b, a=a})
            module:UpdateBackdrop()
        end,
    }
    order = order + 1

    args.useClassColorBorder = {
        type = "toggle",
        name = "Class Color Border",
        desc = "Use your class color for the border",
        order = order,
        disabled = function() return module:GetSetting("borderSize", 3) == 0 end,
        get = function() return module:GetSetting("useClassColorBorder", false) end,
        set = function(_, value)
            module:SetSetting("useClassColorBorder", value)
            module:UpdateBackdrop()
        end,
    }
    order = order + 1

    args.zoomHeader = {type = "header", name = "Zoom", order = order}
    order = order + 1

    args.mouseWheelZoom = {
        type = "toggle",
        name = "Mouse Wheel Zoom",
        desc = "Enable zooming with the mouse wheel",
        order = order,
        get = function() return module:GetSetting("mouseWheelZoom", true) end,
        set = function(_, value)
            module:SetSetting("mouseWheelZoom", value)
            module:SetupMouseWheelZoom()
        end,
    }
    order = order + 1

    args.autoZoomOut = {
        type = "toggle",
        name = "Auto Zoom Out",
        desc = "Automatically zoom out after 15 seconds",
        order = order,
        get = function() return module:GetSetting("autoZoomOut", true) end,
        set = function(_, value)
            module:SetSetting("autoZoomOut", value)
            module:SetupAutoZoom()
        end,
    }
    order = order + 1

    args.displayHeader = {type = "header", name = "Display", order = order}
    order = order + 1

    args.strata = {
        type = "select",
        name = "Frame Strata",
        desc = "Rendering layer for the minimap",
        order = order,
        values = STRATA_VALUES,
        get = function() return module:GetSetting("strata", "BACKGROUND") end,
        set = function(_, value)
            module:SetSetting("strata", value)
            module:UpdateStrata()
        end,
    }
    order = order + 1

    args.lineBreak1 = {
        type = "description", name = " ", order = order, width = "full",
        disabled = true
    }
    order = order + 1

    args.opacity = {
        type = "range",
        name = "Opacity",
        desc = "Base minimap opacity",
        order = order,
        min = 0.1, max = 1.0, step = 0.05, isPercent = true,
        get = function() return module:GetSetting("opacity", 1.0) end,
        set = function(_, value)
            module:SetSetting("opacity", value, {type = "number", min = 0.1, max = 1.0})
            module:ApplyOpacity()
        end,
    }
    order = order + 1

    args.opacityMoving = {
        type = "range",
        name = "Opacity When Moving",
        desc = "Minimap opacity while the player is moving",
        order = order,
        min = 0.0, max = 1.0, step = 0.05, isPercent = true,
        get = function() return module:GetSetting("opacityMoving", 1.0) end,
        set = function(_, value)
            module:SetSetting("opacityMoving", value, {type = "number", min = 0.0, max = 1.0})
            module:ApplyOpacity()
        end,
    }
    order = order + 1

    args.opacityMounted = {
        type = "range",
        name = "Opacity When Mounted",
        desc = "Minimap opacity while mounted (overrides moving opacity)",
        order = order,
        min = 0.0, max = 1.0, step = 0.05, isPercent = true,
        get = function() return module:GetSetting("opacityMounted", 1.0) end,
        set = function(_, value)
            module:SetSetting("opacityMounted", value, {type = "number", min = 0.0, max = 1.0})
            module:ApplyOpacity()
        end,
    }
    order = order + 1

    return args
end

--------------------------------------------------------------------------------
-- Tab 2: Elements
--------------------------------------------------------------------------------

local function BuildElementsTab()
    local args = {}
    local order = 1

    -- Zone Text subgroup
    args.zoneTextGroup = {
        type = "group",
        name = "Zone Text",
        order = order,
        inline = true,
        args = {},
    }
    order = order + 1

    local zo = 1
    args.zoneTextGroup.args.showZoneText = {
        type = "toggle",
        name = "Show Zone Text",
        desc = "Display the zone name on the minimap",
        order = zo, width = "full",
        get = function() return module:GetSetting("showZoneText", true) end,
        set = function(_, value)
            module:SetSetting("showZoneText", value)
            if module.Elements then module.Elements.UpdateZoneText() end
        end,
    }
    zo = zo + 1

    args.zoneTextGroup.args.position = {
        type = "select",
        name = "Position",
        desc = "Anchor position on the minimap",
        order = zo,
        values = ANCHOR_POSITIONS,
        disabled = function() return not module:GetSetting("showZoneText", true) end,
        get = function() return module:GetSetting("zoneText.position", "TOP") end,
        set = function(_, value)
            module:SetSetting("zoneText.position", value)
            if module.Elements then module.Elements.UpdateZoneText() end
        end,
    }
    zo = zo + 1

    args.zoneTextGroup.args.offsetX = {
        type = "range",
        name = "Offset X",
        order = zo, min = -100, max = 100, step = 1,
        disabled = function() return not module:GetSetting("showZoneText", true) end,
        get = function() return module:GetSetting("zoneText.offsetX", 0) end,
        set = function(_, value)
            module:SetSetting("zoneText.offsetX", value, {type = "number", min = -100, max = 100})
            if module.Elements then module.Elements.UpdateZoneText() end
        end,
    }
    zo = zo + 1

    args.zoneTextGroup.args.offsetY = {
        type = "range",
        name = "Offset Y",
        order = zo, min = -100, max = 100, step = 1,
        disabled = function() return not module:GetSetting("showZoneText", true) end,
        get = function() return module:GetSetting("zoneText.offsetY", -2) end,
        set = function(_, value)
            module:SetSetting("zoneText.offsetY", value, {type = "number", min = -100, max = 100})
            if module.Elements then module.Elements.UpdateZoneText() end
        end,
    }
    zo = zo + 1

    args.zoneTextGroup.args.lineBreak1 = {
        type = "description", name = " ", order = zo, width = "full",
        disabled = true
    }
    zo = zo + 1

    args.zoneTextGroup.args.font = {
        type = "select",

        name = "Font",
        desc = "Font face for zone text",
        order = zo,
        values = GetFontValues,
        disabled = function() return not module:GetSetting("showZoneText", true) end,
        get = function() return module:GetSetting("zoneText.font", "") end,
        set = function(_, value)
            module:SetSetting("zoneText.font", value)
            if module.Elements then module.Elements.UpdateZoneText() end
        end,
    }
    zo = zo + 1

    args.zoneTextGroup.args.fontSize = {
        type = "range",
        name = "Font Size",
        order = zo, min = 8, max = 24, step = 1,
        disabled = function() return not module:GetSetting("showZoneText", true) end,
        get = function() return module:GetSetting("zoneText.fontSize", 12) end,
        set = function(_, value)
            module:SetSetting("zoneText.fontSize", value, {type = "number", min = 8, max = 24})
            if module.Elements then module.Elements.UpdateZoneText() end
        end,
    }
    zo = zo + 1

    args.zoneTextGroup.args.allCaps = {
        type = "toggle",
        name = "All Caps",
        desc = "Display zone text in uppercase",
        order = zo,
        disabled = function() return not module:GetSetting("showZoneText", true) end,
        get = function() return module:GetSetting("zoneText.allCaps", true) end,
        set = function(_, value)
            module:SetSetting("zoneText.allCaps", value)
            if module.Elements then module.Elements.UpdateZoneText() end
        end,
    }
    zo = zo + 1

    args.zoneTextGroup.args.lineBreak2 = {
        type = "description", name = " ", order = zo, width = "full",
        disabled = true
    }
    zo = zo + 1

    args.zoneTextGroup.args.fadeOut = {
        type = "toggle",
        name = "Fade When Not Hovering",
        desc = "Hide zone text when the mouse is not over the minimap",
        order = zo,
        disabled = function() return not module:GetSetting("showZoneText", true) end,
        get = function() return module:GetSetting("zoneText.fadeOut", false) end,
        set = function(_, value)
            module:SetSetting("zoneText.fadeOut", value)
            if module.Elements then module.Elements.UpdateZoneText() end
        end,
    }
    zo = zo + 1

    args.zoneTextGroup.args.lineBreak3 = {
        type = "description", name = " ", order = zo, width = "full",
        disabled = true
    }
    zo = zo + 1

    args.zoneTextGroup.args.useClassColor = {
        type = "toggle",
        name = "Use Class Color",
        desc = "Override PvP zone colors with your class color",
        order = zo,
        disabled = function() return not module:GetSetting("showZoneText", true) end,
        get = function() return module:GetSetting("zoneText.useClassColor", false) end,
        set = function(_, value)
            module:SetSetting("zoneText.useClassColor", value)
            if module.Elements then module.Elements.UpdateZoneText() end
        end,
    }
    zo = zo + 1

    args.zoneTextGroup.args.lineBreak4 = {
        type = "description", name = " ", order = zo, width = "full",
        disabled = true
    }
    zo = zo + 1

    local zoneColors = {
        {key = "colorSanctuary", name = "Sanctuary", default = {r=0.41, g=0.80, b=0.94, a=1}},
        {key = "colorArena",     name = "Arena/Combat", default = {r=1.00, g=0.10, b=0.10, a=1}},
        {key = "colorFriendly",  name = "Friendly", default = {r=0.10, g=1.00, b=0.10, a=1}},
        {key = "colorHostile",   name = "Hostile", default = {r=1.00, g=0.10, b=0.10, a=1}},
        {key = "colorContested", name = "Contested", default = {r=1.00, g=0.70, b=0.00, a=1}},
        {key = "colorNormal",    name = "Normal", default = {r=1.00, g=0.82, b=0.00, a=1}},
    }

    for _, zc in ipairs(zoneColors) do
        args.zoneTextGroup.args[zc.key] = {
            type = "color",
            name = zc.name,
            order = zo,
            hasAlpha = false,
            disabled = function()
                return not module:GetSetting("showZoneText", true)
                    or module:GetSetting("zoneText.useClassColor", false)
            end,
            get = function()
                local c = module:GetSetting("zoneText." .. zc.key, zc.default)
                return c.r or 1, c.g or 1, c.b or 1
            end,
            set = function(_, r, g, b)
                module:SetSetting("zoneText." .. zc.key, {r=r, g=g, b=b, a=1})
                if module.Elements then module.Elements.UpdateZoneText() end
            end,
        }
        zo = zo + 1
    end

    -- Coordinates subgroup
    args.coordsGroup = {
        type = "group",
        name = "Coordinates",
        order = order,
        inline = true,
        args = {},
    }
    order = order + 1

    local co = 1
    args.coordsGroup.args.showCoords = {
        type = "toggle",
        name = "Show Coordinates",
        desc = "Display player coordinates on the minimap",
        order = co, width = "full",
        get = function() return module:GetSetting("showCoords", true) end,
        set = function(_, value)
            module:SetSetting("showCoords", value)
            if module.Elements then module.Elements.UpdateCoords() end
        end,
    }
    co = co + 1

    args.coordsGroup.args.position = {
        type = "select",
        name = "Position",
        desc = "Anchor position on the minimap",
        order = co,
        values = ANCHOR_POSITIONS,
        disabled = function() return not module:GetSetting("showCoords", true) end,
        get = function() return module:GetSetting("coords.position", "TOPRIGHT") end,
        set = function(_, value)
            module:SetSetting("coords.position", value)
            if module.Elements then module.Elements.UpdateCoords() end
        end,
    }
    co = co + 1

    args.coordsGroup.args.offsetX = {
        type = "range",
        name = "Offset X",
        order = co, min = -100, max = 100, step = 1,
        disabled = function() return not module:GetSetting("showCoords", true) end,
        get = function() return module:GetSetting("coords.offsetX", -2) end,
        set = function(_, value)
            module:SetSetting("coords.offsetX", value, {type = "number", min = -100, max = 100})
            if module.Elements then module.Elements.UpdateCoords() end
        end,
    }
    co = co + 1

    args.coordsGroup.args.offsetY = {
        type = "range",
        name = "Offset Y",
        order = co, min = -100, max = 100, step = 1,
        disabled = function() return not module:GetSetting("showCoords", true) end,
        get = function() return module:GetSetting("coords.offsetY", -2) end,
        set = function(_, value)
            module:SetSetting("coords.offsetY", value, {type = "number", min = -100, max = 100})
            if module.Elements then module.Elements.UpdateCoords() end
        end,
    }
    co = co + 1

    args.coordsGroup.args.lineBreak1 = {
        type = "description", name = " ", order = co, width = "full",
        disabled = true
    }
    co = co + 1

    args.coordsGroup.args.font = {
        type = "select",

        name = "Font",
        desc = "Font face for coordinates",
        order = co,
        values = GetFontValues,
        disabled = function() return not module:GetSetting("showCoords", true) end,
        get = function() return module:GetSetting("coords.font", "") end,
        set = function(_, value)
            module:SetSetting("coords.font", value)
            if module.Elements then module.Elements.UpdateCoords() end
        end,
    }
    co = co + 1

    args.coordsGroup.args.fontSize = {
        type = "range",
        name = "Font Size",
        order = co, min = 8, max = 24, step = 1,
        disabled = function() return not module:GetSetting("showCoords", true) end,
        get = function() return module:GetSetting("coords.fontSize", 12) end,
        set = function(_, value)
            module:SetSetting("coords.fontSize", value, {type = "number", min = 8, max = 24})
            if module.Elements then module.Elements.UpdateCoords() end
        end,
    }
    co = co + 1

    args.coordsGroup.args.precision = {
        type = "select",
        name = "Precision",
        desc = "Decimal precision for coordinates",
        order = co,
        disabled = function() return not module:GetSetting("showCoords", true) end,
        values = {
            ["%.0f, %.0f"] = "No decimals",
            ["%.1f, %.1f"] = "1 decimal",
            ["%.2f, %.2f"] = "2 decimals",
        },
        get = function() return module:GetSetting("coords.precision", "%.1f, %.1f") end,
        set = function(_, value)
            module:SetSetting("coords.precision", value)
            if module.Elements then module.Elements.UpdateCoords() end
        end,
    }
    co = co + 1

    args.coordsGroup.args.lineBreak2 = {
        type = "description", name = " ", order = co, width = "full",
        disabled = true
    }
    co = co + 1

    args.coordsGroup.args.updateInterval = {
        type = "range",
        name = "Update Interval",
        desc = "How often coordinates update (in seconds)",
        order = co, min = 0.1, max = 5, step = 0.1,
        disabled = function() return not module:GetSetting("showCoords", true) end,
        get = function() return module:GetSetting("coords.updateInterval", 1) end,
        set = function(_, value)
            module:SetSetting("coords.updateInterval", value, {type = "number", min = 0.1, max = 5})
            module:RestartTickers()
        end,
    }
    co = co + 1

    args.coordsGroup.args.lineBreak3 = {
        type = "description", name = " ", order = co, width = "full",
        disabled = true
    }
    co = co + 1

    args.coordsGroup.args.fadeOut = {
        type = "toggle",
        name = "Fade When Not Hovering",
        desc = "Hide coordinates when the mouse is not over the minimap",
        order = co,
        disabled = function() return not module:GetSetting("showCoords", true) end,
        get = function() return module:GetSetting("coords.fadeOut", false) end,
        set = function(_, value)
            module:SetSetting("coords.fadeOut", value)
            if module.Elements then module.Elements.UpdateCoords() end
        end,
    }
    co = co + 1

    args.coordsGroup.args.lineBreak4 = {
        type = "description", name = " ", order = co, width = "full",
        disabled = true
    }
    co = co + 1

    args.coordsGroup.args.useClassColor = {
        type = "toggle",
        name = "Use Class Color",
        order = co,
        disabled = function() return not module:GetSetting("showCoords", true) end,
        get = function() return module:GetSetting("coords.useClassColor", false) end,
        set = function(_, value)
            module:SetSetting("coords.useClassColor", value)
            if module.Elements then module.Elements.UpdateCoords() end
        end,
    }
    co = co + 1

    args.coordsGroup.args.lineBreak5 = {
        type = "description", name = " ", order = co, width = "full",
        disabled = true
    }
    co = co + 1

    args.coordsGroup.args.color = {
        type = "color",
        name = "Text Color",
        order = co,
        hasAlpha = true,
        disabled = function()
            return not module:GetSetting("showCoords", true)
                or module:GetSetting("coords.useClassColor", false)
        end,
        get = function()
            local c = module:GetSetting("coords.color", {r=1, g=1, b=1, a=1})
            return c.r or 1, c.g or 1, c.b or 1, c.a or 1
        end,
        set = function(_, r, g, b, a)
            module:SetSetting("coords.color", {r=r, g=g, b=b, a=a})
            if module.Elements then module.Elements.UpdateCoords() end
        end,
    }
    co = co + 1

    -- Clock subgroup
    args.clockGroup = {
        type = "group",
        name = "Clock",
        order = order,
        inline = true,
        args = {},
    }
    order = order + 1

    local clo = 1
    args.clockGroup.args.showClock = {
        type = "toggle",
        name = "Show Clock",
        desc = "Display a clock on the minimap",
        order = clo, width = "full",
        get = function() return module:GetSetting("showClock", true) end,
        set = function(_, value)
            module:SetSetting("showClock", value)
            if module.Elements then module.Elements.UpdateClock() end
        end,
    }
    clo = clo + 1

    args.clockGroup.args.position = {
        type = "select",
        name = "Position",
        desc = "Anchor position on the minimap",
        order = clo,
        values = ANCHOR_POSITIONS,
        disabled = function() return not module:GetSetting("showClock", true) end,
        get = function() return module:GetSetting("clock.position", "TOPLEFT") end,
        set = function(_, value)
            module:SetSetting("clock.position", value)
            if module.Elements then module.Elements.UpdateClock() end
        end,
    }
    clo = clo + 1

    args.clockGroup.args.offsetX = {
        type = "range",
        name = "Offset X",
        order = clo, min = -100, max = 100, step = 1,
        disabled = function() return not module:GetSetting("showClock", true) end,
        get = function() return module:GetSetting("clock.offsetX", 2) end,
        set = function(_, value)
            module:SetSetting("clock.offsetX", value, {type = "number", min = -100, max = 100})
            if module.Elements then module.Elements.UpdateClock() end
        end,
    }
    clo = clo + 1

    args.clockGroup.args.offsetY = {
        type = "range",
        name = "Offset Y",
        order = clo, min = -100, max = 100, step = 1,
        disabled = function() return not module:GetSetting("showClock", true) end,
        get = function() return module:GetSetting("clock.offsetY", -2) end,
        set = function(_, value)
            module:SetSetting("clock.offsetY", value, {type = "number", min = -100, max = 100})
            if module.Elements then module.Elements.UpdateClock() end
        end,
    }
    clo = clo + 1

    args.clockGroup.args.lineBreak1 = {
        type = "description", name = " ", order = clo, width = "full",
        disabled = true
    }
    clo = clo + 1

    args.clockGroup.args.font = {
        type = "select",

        name = "Font",
        desc = "Font face for the clock",
        order = clo,
        values = GetFontValues,
        disabled = function() return not module:GetSetting("showClock", true) end,
        get = function() return module:GetSetting("clock.font", "") end,
        set = function(_, value)
            module:SetSetting("clock.font", value)
            if module.Elements then module.Elements.UpdateClock() end
        end,
    }
    clo = clo + 1

    args.clockGroup.args.fontSize = {
        type = "range",
        name = "Font Size",
        order = clo, min = 8, max = 24, step = 1,
        disabled = function() return not module:GetSetting("showClock", true) end,
        get = function() return module:GetSetting("clock.fontSize", 12) end,
        set = function(_, value)
            module:SetSetting("clock.fontSize", value, {type = "number", min = 8, max = 24})
            if module.Elements then module.Elements.UpdateClock() end
        end,
    }
    clo = clo + 1

    args.clockGroup.args.lineBreak2 = {
        type = "description", name = " ", order = clo, width = "full",
        disabled = true
    }
    clo = clo + 1

    args.clockGroup.args.timeSource = {
        type = "select",
        name = "Time Source",
        desc = "Use local system time or server time",
        order = clo,
        disabled = function() return not module:GetSetting("showClock", true) end,
        values = {["local"] = "Local Time", server = "Server Time"},
        get = function() return module:GetSetting("clock.timeSource", "local") end,
        set = function(_, value)
            module:SetSetting("clock.timeSource", value)
            if module.Elements then module.Elements.UpdateClock() end
        end,
    }
    clo = clo + 1

    args.clockGroup.args.use24Hour = {
        type = "toggle",
        name = "24-Hour Format",
        desc = "Use 24-hour time format",
        order = clo,
        disabled = function() return not module:GetSetting("showClock", true) end,
        get = function() return module:GetSetting("clock.use24Hour", true) end,
        set = function(_, value)
            module:SetSetting("clock.use24Hour", value)
            if module.Elements then module.Elements.UpdateClock() end
        end,
    }
    clo = clo + 1

    args.clockGroup.args.lineBreak3 = {
        type = "description", name = " ", order = clo, width = "full",
        disabled = true
    }
    clo = clo + 1

    args.clockGroup.args.fadeOut = {
        type = "toggle",
        name = "Fade When Not Hovering",
        desc = "Hide clock when the mouse is not over the minimap",
        order = clo,
        disabled = function() return not module:GetSetting("showClock", true) end,
        get = function() return module:GetSetting("clock.fadeOut", false) end,
        set = function(_, value)
            module:SetSetting("clock.fadeOut", value)
            if module.Elements then module.Elements.UpdateClock() end
        end,
    }
    clo = clo + 1

    args.clockGroup.args.lineBreak4 = {
        type = "description", name = " ", order = clo, width = "full",
        disabled = true
    }
    clo = clo + 1

    args.clockGroup.args.useClassColor = {
        type = "toggle",
        name = "Use Class Color",
        order = clo,
        disabled = function() return not module:GetSetting("showClock", true) end,
        get = function() return module:GetSetting("clock.useClassColor", false) end,
        set = function(_, value)
            module:SetSetting("clock.useClassColor", value)
            if module.Elements then module.Elements.UpdateClock() end
        end,
    }
    clo = clo + 1

    args.clockGroup.args.lineBreak5 = {
        type = "description", name = " ", order = clo, width = "full",
        disabled = true
    }
    clo = clo + 1

    args.clockGroup.args.color = {
        type = "color",
        name = "Text Color",
        order = clo,
        hasAlpha = true,
        disabled = function()
            return not module:GetSetting("showClock", true)
                or module:GetSetting("clock.useClassColor", false)
        end,
        get = function()
            local c = module:GetSetting("clock.color", {r=1, g=1, b=1, a=1})
            return c.r or 1, c.g or 1, c.b or 1, c.a or 1
        end,
        set = function(_, r, g, b, a)
            module:SetSetting("clock.color", {r=r, g=g, b=b, a=a})
            if module.Elements then module.Elements.UpdateClock() end
        end,
    }
    clo = clo + 1

    return args
end

--------------------------------------------------------------------------------
-- Tab 3: Buttons
--------------------------------------------------------------------------------

local BUTTON_DEFS = {
    {key = "zoom",             name = "Zoom Buttons",       defaultShow = false, defaultPoint = "BOTTOMRIGHT"},
    {key = "mail",             name = "Mail Indicator",      defaultShow = true,  defaultPoint = "BOTTOMLEFT"},
    {key = "craftingOrder",    name = "Crafting Orders",     defaultShow = true,  defaultPoint = "BOTTOMRIGHT"},
    {key = "addonCompartment", name = "Addon Compartment",   defaultShow = false, defaultPoint = "TOPRIGHT"},
    {key = "difficulty",       name = "Instance Difficulty",  defaultShow = true,  defaultPoint = "TOPLEFT"},
    {key = "missions",         name = "Missions Button",     defaultShow = false, defaultPoint = "TOPLEFT"},
    {key = "calendar",         name = "Calendar",            defaultShow = false, defaultPoint = "TOPRIGHT"},
    {key = "tracking",         name = "Tracking Button",     defaultShow = true,  defaultPoint = "TOPLEFT"},
}

local function BuildButtonsTab()
    local args = {}
    local order = 1

    args.buttonsHeader = {type = "header", name = "Built-in Buttons", order = order}
    order = order + 1

    for _, btn in ipairs(BUTTON_DEFS) do
        local path = "buttons." .. btn.key
        local subArgs = {}
        local so = 1

        subArgs.show = {
            type = "toggle",
            name = "Show",
            desc = "Show or hide this button",
            order = so, width = "full",
            get = function() return module:GetSetting(path .. ".show", btn.defaultShow) end,
            set = function(_, value)
                module:SetSetting(path .. ".show", value)
                if module.Elements then module.Elements.UpdateButtons() end
            end,
        }
        so = so + 1

        subArgs.scale = {
            type = "range",
            name = "Scale",
            desc = "Button size multiplier",
            order = so, min = 0.3, max = 3.0, step = 0.05,
            disabled = function() return not module:GetSetting(path .. ".show", btn.defaultShow) end,
            get = function() return module:GetSetting(path .. ".scale", 1.0) end,
            set = function(_, value)
                module:SetSetting(path .. ".scale", value, {type = "number", min = 0.3, max = 3.0})
                if module.Elements then module.Elements.UpdateButtons() end
            end,
        }
        so = so + 1

        subArgs.strata = {
            type = "select",
            name = "Frame Strata",
            desc = "Rendering layer for this button",
            order = so,
            values = STRATA_VALUES,
            disabled = function() return not module:GetSetting(path .. ".show", btn.defaultShow) end,
            get = function() return module:GetSetting(path .. ".strata", "MEDIUM") end,
            set = function(_, value)
                module:SetSetting(path .. ".strata", value)
                if module.Elements then module.Elements.UpdateButtons() end
            end,
        }
        so = so + 1

        subArgs.point = {
            type = "select",
            name = "Anchor Point",
            desc = "Where to anchor this button on the minimap",
            order = so,
            values = ANCHOR_POSITIONS,
            disabled = function() return not module:GetSetting(path .. ".show", btn.defaultShow) end,
            get = function() return module:GetSetting(path .. ".point", btn.defaultPoint) end,
            set = function(_, value)
                module:SetSetting(path .. ".point", value)
                if module.Elements then module.Elements.UpdateButtons() end
            end,
        }
        so = so + 1

        subArgs.offsetX = {
            type = "range",
            name = "Offset X",
            order = so, min = -200, max = 200, step = 1,
            disabled = function() return not module:GetSetting(path .. ".show", btn.defaultShow) end,
            get = function() return module:GetSetting(path .. ".offsetX", 0) end,
            set = function(_, value)
                module:SetSetting(path .. ".offsetX", value, {type = "number", min = -200, max = 200})
                if module.Elements then module.Elements.UpdateButtons() end
            end,
        }
        so = so + 1

        subArgs.offsetY = {
            type = "range",
            name = "Offset Y",
            order = so, min = -200, max = 200, step = 1,
            disabled = function() return not module:GetSetting(path .. ".show", btn.defaultShow) end,
            get = function() return module:GetSetting(path .. ".offsetY", 0) end,
            set = function(_, value)
                module:SetSetting(path .. ".offsetY", value, {type = "number", min = -200, max = 200})
                if module.Elements then module.Elements.UpdateButtons() end
            end,
        }
        so = so + 1

        subArgs.fadeOut = {
            type = "toggle",
            name = "Fade When Not Hovering",
            desc = "Hide this button when the mouse is not over the minimap",
            order = so,
            disabled = function() return not module:GetSetting(path .. ".show", btn.defaultShow) end,
            get = function() return module:GetSetting(path .. ".fadeOut", false) end,
            set = function(_, value)
                module:SetSetting(path .. ".fadeOut", value)
                if module.Elements then module.Elements.UpdateButtons() end
            end,
        }
        so = so + 1

        args[btn.key] = {
            type = "group",
            name = btn.name,
            order = order,
            inline = true,
            args = subArgs,
        }
        order = order + 1
    end

    args.addonHeader = {type = "header", name = "Addon Buttons", order = order}
    order = order + 1

    args.hideAddonButtons = {
        type = "toggle",
        name = "Hide Addon Buttons",
        desc = "Show LibDBIcon buttons only on minimap hover",
        order = order,
        get = function() return module:GetSetting("hideAddonButtons", false) end,
        set = function(_, value)
            module:SetSetting("hideAddonButtons", value)
            if module.Elements then module.Elements.UpdateAddonButtons() end
        end,
    }
    order = order + 1

    args.dungeonEyeHeader = {type = "header", name = "Dungeon Eye", order = order}
    order = order + 1

    args.dungeonEyeEnabled = {
        type = "toggle",
        name = "Enable Dungeon Eye",
        desc = "Show the queue status button near the minimap",
        order = order,
        get = function() return module:GetSetting("dungeonEye.enabled", true) end,
        set = function(_, value)
            module:SetSetting("dungeonEye.enabled", value)
            if module.Elements then module.Elements.UpdateDungeonEye() end
        end,
    }
    order = order + 1

    args.dungeonEyeCorner = {
        type = "select",
        name = "Anchor Point",
        desc = "Where to anchor the dungeon eye on the minimap",
        order = order,
        values = ANCHOR_POSITIONS,
        disabled = function() return not module:GetSetting("dungeonEye.enabled", true) end,
        get = function() return module:GetSetting("dungeonEye.corner", "BOTTOMRIGHT") end,
        set = function(_, value)
            module:SetSetting("dungeonEye.corner", value)
            if module.Elements then module.Elements.UpdateDungeonEye() end
        end,
    }
    order = order + 1

    args.dungeonEyeScale = {
        type = "range",
        name = "Scale",
        order = order, min = 0.3, max = 2.0, step = 0.05,
        disabled = function() return not module:GetSetting("dungeonEye.enabled", true) end,
        get = function() return module:GetSetting("dungeonEye.scale", 0.8) end,
        set = function(_, value)
            module:SetSetting("dungeonEye.scale", value, {type = "number", min = 0.3, max = 2.0})
            if module.Elements then module.Elements.UpdateDungeonEye() end
        end,
    }
    order = order + 1

    args.dungeonEyeOffsetX = {
        type = "range",
        name = "Offset X",
        order = order, min = -100, max = 100, step = 1,
        disabled = function() return not module:GetSetting("dungeonEye.enabled", true) end,
        get = function() return module:GetSetting("dungeonEye.offsetX", 0) end,
        set = function(_, value)
            module:SetSetting("dungeonEye.offsetX", value, {type = "number", min = -100, max = 100})
            if module.Elements then module.Elements.UpdateDungeonEye() end
        end,
    }
    order = order + 1

    args.dungeonEyeOffsetY = {
        type = "range",
        name = "Offset Y",
        order = order, min = -100, max = 100, step = 1,
        disabled = function() return not module:GetSetting("dungeonEye.enabled", true) end,
        get = function() return module:GetSetting("dungeonEye.offsetY", 0) end,
        set = function(_, value)
            module:SetSetting("dungeonEye.offsetY", value, {type = "number", min = -100, max = 100})
            if module.Elements then module.Elements.UpdateDungeonEye() end
        end,
    }
    order = order + 1

    return args
end

--------------------------------------------------------------------------------
-- Build & Register
--------------------------------------------------------------------------------

function module:BuildOptions()
    if not TavernUI.db or not TavernUI.db.profile then
        return
    end

    local options = {
        type = "group",
        name = "Minimap",
        childGroups = "tab",
        args = {
            general = {
                type = "group",
                name = "General",
                order = 1,
                args = BuildGeneralTab(),
            },
            elements = {
                type = "group",
                name = "Elements",
                order = 2,
                args = BuildElementsTab(),
            },
            buttons = {
                type = "group",
                name = "Buttons",
                order = 3,
                args = BuildButtonsTab(),
            },
        },
    }

    TavernUI:RegisterModuleOptions("Minimap", options, "Minimap")
end

function module:RegisterOptions()
    if not self.optionsBuilt then
        self:BuildOptions()
        self.optionsBuilt = true
    end
end

local function BuildOptionsWhenReady()
    if TavernUI and TavernUI.db and TavernUI.db.profile and TavernUI.RegisterModuleOptions then
        module:RegisterOptions()
    end
end

module:RegisterMessage("TavernUI_CoreEnabled", BuildOptionsWhenReady)

if TavernUI and TavernUI.db and TavernUI.RegisterModuleOptions then
    BuildOptionsWhenReady()
end
