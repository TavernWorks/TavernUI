-- CDM Options Module
-- Handles all options UI building with helper functions to reduce duplication

local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("CDM", true)
local Anchor = LibStub("LibAnchorRegistry-1.0", true)

if not module then
    error("CDM_Options.lua: Failed to get CDM module")
    return
end

local VIEWER_ESSENTIAL = "EssentialCooldownViewer"
local VIEWER_UTILITY = "UtilityCooldownViewer"

local CDM = module.CDM or {}
if not module.CDM then
    module.CDM = CDM
end

local function IncrementSettingsVersion(trackerKey)
    if trackerKey then
        CDM.settingsVersion = CDM.settingsVersion or {}
        CDM.settingsVersion[trackerKey] = (CDM.settingsVersion[trackerKey] or 0) + 1
    else
        CDM.settingsVersion = CDM.settingsVersion or {}
        CDM.settingsVersion.essential = (CDM.settingsVersion.essential or 0) + 1
        CDM.settingsVersion.utility = (CDM.settingsVersion.utility or 0) + 1
    end
end

local ANCHOR_POINTS = {
    TOPLEFT = "TOPLEFT",
    TOP = "TOP",
    TOPRIGHT = "TOPRIGHT",
    LEFT = "LEFT",
    CENTER = "CENTER",
    RIGHT = "RIGHT",
    BOTTOMLEFT = "BOTTOMLEFT",
    BOTTOM = "BOTTOM",
    BOTTOMRIGHT = "BOTTOMRIGHT",
}

local function MakeRowOption(key, rowIndex, optionKey, optionType, config)
    local order = config.order
    local name = config.name
    local desc = config.desc
    local min = config.min
    local max = config.max
    local step = config.step or 1
    local defaultValue = config.default
    local getPath = config.getPath or optionKey
    local setPath = config.setPath or optionKey
    local disabled = config.disabled
    
    local option = {
        type = optionType,
        name = name,
        desc = desc,
        order = order,
    }
    
    if optionType == "range" then
        option.min = min
        option.max = max
        option.step = step
    elseif optionType == "select" then
        option.values = config.values or ANCHOR_POINTS
    elseif optionType == "color" then
        option.hasAlpha = config.hasAlpha or false
    end
    
    option.get = function()
        local db = module:GetDB()
        local section = db[key] or {}
        local rows = section.rows or {}
        local row = rows[rowIndex]
        if row then
            if optionType == "color" then
                local color = row[getPath]
                if color then
                    return color.r, color.g, color.b
                end
                return 0, 0, 0
            else
                return row[getPath] or defaultValue
            end
        end
        return defaultValue
    end
    
    option.set = function(_, value, g, b)
        local db = module:GetDB()
        if not db[key] then db[key] = {} end
        if not db[key].rows then db[key].rows = {} end
        if not db[key].rows[rowIndex] then db[key].rows[rowIndex] = {} end
        
        if optionType == "color" then
            if not db[key].rows[rowIndex][setPath] then
                db[key].rows[rowIndex][setPath] = {r = 0, g = 0, b = 0, a = 1}
            end
            db[key].rows[rowIndex][setPath].r = value
            db[key].rows[rowIndex][setPath].g = g
            db[key].rows[rowIndex][setPath].b = b
        else
            db[key].rows[rowIndex][setPath] = value
        end
        
        IncrementSettingsVersion(key)
        if module:IsEnabled() then
            module:RefreshAll()
        end
    end
    
    if disabled then
        option.disabled = function()
            local db = module:GetDB()
            local section = db[key] or {}
            local rows = section.rows or {}
            local row = rows[rowIndex]
            return disabled(row, db)
        end
    end
    
    return option
end

local function BuildRowOptions(key, rowIndex, orderBase)
    local args = {}
    local order = orderBase or 1
    
    args.iconCount = MakeRowOption(key, rowIndex, "iconCount", "range", {
        order = order, name = "Icon Count", desc = "Number of icons in this row",
        min = 1, max = 12, step = 1, default = key == "essential" and 4 or 6
    })
    order = order + 1
    
    args.iconSize = MakeRowOption(key, rowIndex, "iconSize", "range", {
        order = order, name = "Icon Size", desc = "Size of icons in this row",
        min = 20, max = 100, step = 1, default = key == "essential" and 50 or 42
    })
    order = order + 1
    
    args.padding = MakeRowOption(key, rowIndex, "padding", "range", {
        order = order, name = "Padding", desc = "Spacing between icons (negative for overlap)",
        min = -20, max = 20, step = 1, default = -8
    })
    order = order + 1
    
    args.yOffset = MakeRowOption(key, rowIndex, "yOffset", "range", {
        order = order, name = "Y Offset", desc = "Vertical offset for this row",
        min = -50, max = 50, step = 1, default = 0
    })
    order = order + 1
    
    args.stylingHeader = {type = "header", name = "Icon Styling", order = order}
    order = order + 1
    
    args.aspectRatioCrop = MakeRowOption(key, rowIndex, "aspectRatioCrop", "range", {
        order = order, name = "Aspect Ratio Crop", desc = "Icon aspect ratio (1.0 = square, higher = wider/flatter)",
        min = 1.0, max = 2.0, step = 0.01, default = 1.0
    })
    order = order + 1
    
    args.zoom = MakeRowOption(key, rowIndex, "zoom", "range", {
        order = order, name = "Zoom", desc = "Zoom level for icon texture (0 = default, higher = zoomed in)",
        min = 0, max = 0.2, step = 0.01, default = 0
    })
    order = order + 1
    
    args.iconBorderHeader = {type = "header", name = "Icon Border", order = order}
    order = order + 1
    
    args.iconBorderSize = MakeRowOption(key, rowIndex, "iconBorderSize", "range", {
        order = order, name = "Icon Border Size", desc = "Size of border around each icon (0 = no border)",
        min = 0, max = 5, step = 1, default = 0
    })
    order = order + 1
    
    args.iconBorderColor = MakeRowOption(key, rowIndex, "iconBorderColor", "color", {
        order = order, name = "Icon Border Color", desc = "Color of the border around each icon",
        default = {r = 0, g = 0, b = 0, a = 1},
        disabled = function(row) return (row and row.iconBorderSize or 0) == 0 end
    })
    order = order + 1
    
    args.rowBorderHeader = {type = "header", name = "Row Border", order = order}
    order = order + 1
    
    args.rowBorderSize = MakeRowOption(key, rowIndex, "rowBorderSize", "range", {
        order = order, name = "Row Border Size", desc = "Size of border around the entire row (0 = no border)",
        min = 0, max = 5, step = 1, default = 0
    })
    order = order + 1
    
    args.rowBorderColor = MakeRowOption(key, rowIndex, "rowBorderColor", "color", {
        order = order, name = "Row Border Color", desc = "Color of the border around the entire row",
        default = {r = 0, g = 0, b = 0, a = 1},
        disabled = function(row) return (row and row.rowBorderSize or 0) == 0 end
    })
    order = order + 1
    
    args.textHeader = {type = "header", name = "Text Settings", order = order}
    order = order + 1
    
    args.durationSize = MakeRowOption(key, rowIndex, "durationSize", "range", {
        order = order, name = "Duration Text Size", desc = "Font size for cooldown duration text (0 = hide)",
        min = 0, max = 96, step = 1, default = 18
    })
    order = order + 1
    
    args.durationPoint = MakeRowOption(key, rowIndex, "durationPoint", "select", {
        order = order, name = "Duration Text Position", desc = "Anchor point for duration text on icon",
        values = ANCHOR_POINTS, default = "CENTER",
        disabled = function(row) return (row and row.durationSize or 18) == 0 end
    })
    order = order + 1
    
    args.durationOffsetX = MakeRowOption(key, rowIndex, "durationOffsetX", "range", {
        order = order, name = "Duration Text Offset X", desc = "Horizontal offset for duration text",
        min = -50, max = 50, step = 1, default = 0,
        disabled = function(row) return (row and row.durationSize or 18) == 0 end
    })
    order = order + 1
    
    args.durationOffsetY = MakeRowOption(key, rowIndex, "durationOffsetY", "range", {
        order = order, name = "Duration Text Offset Y", desc = "Vertical offset for duration text",
        min = -50, max = 50, step = 1, default = 0,
        disabled = function(row) return (row and row.durationSize or 18) == 0 end
    })
    order = order + 1
    
    args.stackSize = MakeRowOption(key, rowIndex, "stackSize", "range", {
        order = order, name = "Stack Text Size", desc = "Font size for stack count text (0 = hide)",
        min = 0, max = 96, step = 1, default = 16
    })
    order = order + 1
    
    args.stackPoint = MakeRowOption(key, rowIndex, "stackPoint", "select", {
        order = order, name = "Stack Text Position", desc = "Anchor point for stack text on icon",
        values = ANCHOR_POINTS, default = "BOTTOMRIGHT",
        disabled = function(row) return (row and row.stackSize or 16) == 0 end
    })
    order = order + 1
    
    args.stackOffsetX = MakeRowOption(key, rowIndex, "stackOffsetX", "range", {
        order = order, name = "Stack Text Offset X", desc = "Horizontal offset for stack text",
        min = -50, max = 50, step = 1, default = 0,
        disabled = function(row) return (row and row.stackSize or 16) == 0 end
    })
    order = order + 1
    
    args.stackOffsetY = MakeRowOption(key, rowIndex, "stackOffsetY", "range", {
        order = order, name = "Stack Text Offset Y", desc = "Vertical offset for stack text",
        min = -50, max = 50, step = 1, default = 0,
        disabled = function(row) return (row and row.stackSize or 16) == 0 end
    })
    order = order + 1
    
    args.actionsHeader = {type = "header", name = "Actions", order = order}
    order = order + 1
    
    args.removeRow = {
        type = "execute",
        name = "Remove Row",
        desc = "Remove this row",
        order = order,
        func = function()
            local db = module:GetDB()
            if db[key] and db[key].rows then
                table.remove(db[key].rows, rowIndex)
                IncrementSettingsVersion(key)
                if module:IsEnabled() then
                    module:RefreshAll()
                end
                module:RefreshOptions(true)
            end
        end,
    }
    
    return args
end

local function BuildAnchorOptions(key, orderBase, config)
    local args = {}
    local order = orderBase or 1
    local ApplyAnchorFunc = config.applyAnchorFunc
    local viewerName = config.viewerName or key
    
    args.anchoringHeader = {type = "header", name = "Anchoring", order = order}
    order = order + 1
    
    if config.hasAnchorBelow then
        args.anchorBelowEssential = {
            type = "toggle",
            name = "Anchor to Essential",
            desc = "Anchor Utility viewer to Essential viewer (disables custom anchor)",
            order = order,
            get = function()
                local db = module:GetDB()
                return (db[key] and db[key].anchorBelowEssential) ~= false
            end,
            set = function(_, value)
                local db = module:GetDB()
                if not db[key] then db[key] = {} end
                db[key].anchorBelowEssential = value
                if value then
                    db[key].anchorConfig = nil
                    if not db[key].anchorPoint then db[key].anchorPoint = "TOP" end
                    if not db[key].anchorRelativePoint then db[key].anchorRelativePoint = "BOTTOM" end
                    if not db[key].anchorGap then db[key].anchorGap = 5 end
                end
                IncrementSettingsVersion(key)
                if module:IsEnabled() then
                    ApplyAnchorFunc()
                    module:RefreshAll()
                end
            end,
        }
        order = order + 1
        
        args.anchorPoint = {
            type = "select",
            name = "Source Point",
            desc = "Anchor point on " .. viewerName .. " viewer",
            order = order,
            values = ANCHOR_POINTS,
            disabled = function()
                local db = module:GetDB()
                return not (db[key] and db[key].anchorBelowEssential ~= false)
            end,
            get = function()
                local db = module:GetDB()
                return (db[key] and db[key].anchorPoint) or "TOP"
            end,
            set = function(_, value)
                local db = module:GetDB()
                if not db[key] then db[key] = {} end
                db[key].anchorPoint = value
                IncrementSettingsVersion(key)
                if module:IsEnabled() then
                    ApplyAnchorFunc()
                    module:RefreshAll()
                end
            end,
        }
        order = order + 1
        
        args.anchorRelativePoint = {
            type = "select",
            name = "Target Point",
            desc = "Anchor point on Essential viewer",
            order = order,
            values = ANCHOR_POINTS,
            disabled = function()
                local db = module:GetDB()
                return not (db[key] and db[key].anchorBelowEssential ~= false)
            end,
            get = function()
                local db = module:GetDB()
                return (db[key] and db[key].anchorRelativePoint) or "BOTTOM"
            end,
            set = function(_, value)
                local db = module:GetDB()
                if not db[key] then db[key] = {} end
                db[key].anchorRelativePoint = value
                IncrementSettingsVersion(key)
                if module:IsEnabled() then
                    ApplyAnchorFunc()
                    module:RefreshAll()
                end
            end,
        }
        order = order + 1
        
        args.anchorOffsetX = {
            type = "range",
            name = "Offset X",
            desc = "Horizontal offset from Essential viewer",
            order = order,
            min = -50,
            max = 50,
            step = 1,
            disabled = function()
                local db = module:GetDB()
                return not (db[key] and db[key].anchorBelowEssential ~= false)
            end,
            get = function()
                local db = module:GetDB()
                return (db[key] and db[key].anchorOffsetX) or 0
            end,
            set = function(_, value)
                local db = module:GetDB()
                if not db[key] then db[key] = {} end
                db[key].anchorOffsetX = value
                IncrementSettingsVersion(key)
                if module:IsEnabled() then
                    ApplyAnchorFunc()
                    module:RefreshAll()
                end
            end,
        }
        order = order + 1
        
        args.anchorGap = {
            type = "range",
            name = "Offset Y",
            desc = "Vertical offset from Essential viewer (negative for overlap)",
            order = order,
            min = -50,
            max = 50,
            step = 1,
            disabled = function()
                local db = module:GetDB()
                return not (db[key] and db[key].anchorBelowEssential ~= false)
            end,
            get = function()
                local db = module:GetDB()
                return (db[key] and db[key].anchorGap) or 5
            end,
            set = function(_, value)
                local db = module:GetDB()
                if not db[key] then db[key] = {} end
                db[key].anchorGap = value
                IncrementSettingsVersion(key)
                if module:IsEnabled() then
                    ApplyAnchorFunc()
                    module:RefreshAll()
                end
            end,
        }
        order = order + 1
    end
    
    args.useCustomAnchor = {
        type = "toggle",
        name = "Use Custom Anchor",
        desc = config.customAnchorDesc or "Override Blizzard positioning with custom anchor",
        order = order,
        get = function()
            local db = module:GetDB()
            return db[key] and db[key].anchorConfig and db[key].anchorConfig.target ~= nil
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db[key] then db[key] = {} end
            if value then
                if config.hasAnchorBelow then
                    db[key].anchorBelowEssential = false
                end
                if not db[key].anchorConfig then
                    db[key].anchorConfig = {
                        target = "UIParent",
                        point = "CENTER",
                        relativePoint = "CENTER",
                        offsetX = 0,
                        offsetY = 0,
                    }
                end
            else
                db[key].anchorConfig = nil
            end
            IncrementSettingsVersion(key)
            if module:IsEnabled() then
                ApplyAnchorFunc()
                module:RefreshAll()
            end
        end,
    }
    order = order + 1
    
    args.anchorTarget = {
        type = "select",
        name = "Anchor Target",
        desc = "Frame to anchor to",
        order = order,
        disabled = function()
            local db = module:GetDB()
            return not (db[key] and db[key].anchorConfig and db[key].anchorConfig.target ~= nil)
        end,
        values = function()
            local values = {
                UIParent = "UIParent (Blizzard Edit Mode)",
            }
            
            if Anchor then
                local dropdownData = Anchor:GetDropdownData()
                for _, item in ipairs(dropdownData) do
                    values[item.value] = item.text
                end
            end
            
            return values
        end,
        get = function()
            local db = module:GetDB()
            return (db[key] and db[key].anchorConfig and db[key].anchorConfig.target) or "UIParent"
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db[key] then db[key] = {} end
            if not db[key].anchorConfig then
                db[key].anchorConfig = {}
            end
            db[key].anchorConfig.target = value or "UIParent"
            IncrementSettingsVersion(key)
            if module:IsEnabled() then
                ApplyAnchorFunc()
                module:RefreshAll()
            end
        end,
    }
    order = order + 1
    
    args.anchorPoint = {
        type = "select",
        name = "Point",
        desc = "Anchor point on " .. viewerName .. " viewer",
        order = order,
        values = ANCHOR_POINTS,
        disabled = function()
            local db = module:GetDB()
            return not (db[key] and db[key].anchorConfig and db[key].anchorConfig.target ~= nil)
        end,
        get = function()
            local db = module:GetDB()
            return (db[key] and db[key].anchorConfig and db[key].anchorConfig.point) or "CENTER"
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db[key] then db[key] = {} end
            if not db[key].anchorConfig then
                db[key].anchorConfig = {}
            end
            db[key].anchorConfig.point = value
            IncrementSettingsVersion(key)
            if module:IsEnabled() then
                ApplyAnchorFunc()
                module:RefreshAll()
            end
        end,
    }
    order = order + 1
    
    args.anchorRelativePoint = {
        type = "select",
        name = "Relative Point",
        desc = "Anchor point on target frame",
        order = order,
        values = ANCHOR_POINTS,
        disabled = function()
            local db = module:GetDB()
            return not (db[key] and db[key].anchorConfig and db[key].anchorConfig.target ~= nil)
        end,
        get = function()
            local db = module:GetDB()
            return (db[key] and db[key].anchorConfig and db[key].anchorConfig.relativePoint) or "CENTER"
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db[key] then db[key] = {} end
            if not db[key].anchorConfig then
                db[key].anchorConfig = {}
            end
            db[key].anchorConfig.relativePoint = value
            IncrementSettingsVersion(key)
            if module:IsEnabled() then
                ApplyAnchorFunc()
                module:RefreshAll()
            end
        end,
    }
    order = order + 1
    
    args.anchorOffsetX = {
        type = "range",
        name = "Offset X",
        desc = "Horizontal offset",
        order = order,
        min = -500,
        max = 500,
        step = 1,
        disabled = function()
            local db = module:GetDB()
            return not (db[key] and db[key].anchorConfig and db[key].anchorConfig.target ~= nil)
        end,
        get = function()
            local db = module:GetDB()
            return (db[key] and db[key].anchorConfig and db[key].anchorConfig.offsetX) or 0
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db[key] then db[key] = {} end
            if not db[key].anchorConfig then
                db[key].anchorConfig = {}
            end
            db[key].anchorConfig.offsetX = value
            IncrementSettingsVersion(key)
            if module:IsEnabled() then
                ApplyAnchorFunc()
                module:RefreshAll()
            end
        end,
    }
    order = order + 1
    
    args.anchorOffsetY = {
        type = "range",
        name = "Offset Y",
        desc = "Vertical offset",
        order = order,
        min = -500,
        max = 500,
        step = 1,
        disabled = function()
            local db = module:GetDB()
            return not (db[key] and db[key].anchorConfig and db[key].anchorConfig.target ~= nil)
        end,
        get = function()
            local db = module:GetDB()
            return (db[key] and db[key].anchorConfig and db[key].anchorConfig.offsetY) or 0
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db[key] then db[key] = {} end
            if not db[key].anchorConfig then
                db[key].anchorConfig = {}
            end
            db[key].anchorConfig.offsetY = value
            IncrementSettingsVersion(key)
            if module:IsEnabled() then
                ApplyAnchorFunc()
                module:RefreshAll()
            end
        end,
    }
    
    return args
end

local function BuildViewerOptions(key, viewerName, orderBase)
    local args = {}
    local order = orderBase or 1
    local ApplyAnchorFunc = key == "essential" and module.ApplyEssentialAnchor or module.ApplyUtilityAnchor
    local defaultIconCount = key == "essential" and 4 or 6
    local defaultIconSize = key == "essential" and 50 or 42
    
    args.enabled = {
        type = "toggle",
        name = "Enabled",
        desc = "Enable " .. viewerName .. " cooldown viewer",
        order = order,
        get = function()
            local db = module:GetDB()
            return (db[key] and db[key].enabled) ~= false
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db[key] then db[key] = {} end
            db[key].enabled = value
            IncrementSettingsVersion(key)
            if module:IsEnabled() then
                module:RefreshAll()
            end
        end,
    }
    order = order + 1
    
    local anchorOrder = key == "essential" and 5 or 10
    local anchorOptions = BuildAnchorOptions(key, anchorOrder, {
        applyAnchorFunc = ApplyAnchorFunc,
        viewerName = viewerName,
        hasAnchorBelow = key == "utility",
        customAnchorDesc = key == "utility" and "Override positioning with custom anchor (disables anchor below Essential)" or "Override Blizzard positioning with custom anchor",
    })
    
    for k, v in pairs(anchorOptions) do
        args[k] = v
        if v.order then
            order = math.max(order, v.order + 1)
        end
    end
    
    args.rowsHeader = {type = "header", name = "Rows Configuration", order = order}
    order = order + 1
    
    args.addRow = {
        type = "execute",
        name = "Add Row",
        desc = "Add a new row to the " .. viewerName .. " viewer",
        order = order,
        func = function()
            local db = module:GetDB()
            if not db[key] then db[key] = {} end
            if not db[key].rows then
                db[key].rows = {}
            end
            table.insert(db[key].rows, {
                iconCount = defaultIconCount,
                iconSize = defaultIconSize,
                padding = -8,
                yOffset = 0,
                aspectRatioCrop = 1.0,
                zoom = 0,
                iconBorderSize = 0,
                iconBorderColor = {r = 0, g = 0, b = 0, a = 1},
                rowBorderSize = 0,
                rowBorderColor = {r = 0, g = 0, b = 0, a = 1},
                durationSize = 18,
                durationPoint = "CENTER",
                durationOffsetX = 0,
                durationOffsetY = 0,
                stackSize = 16,
                stackPoint = "BOTTOMRIGHT",
                stackOffsetX = 0,
                stackOffsetY = 0,
            })
            IncrementSettingsVersion(key)
            if module:IsEnabled() then
                module:RefreshAll()
            end
            module:RefreshOptions(true)
        end,
    }
    order = order + 1
    
    local db = module:GetDB()
    local section = db[key] or {}
    if section.rows then
        for i, row in ipairs(section.rows) do
            local rowKey = "row" .. i
            local rowOrderBase = key == "essential" and 20 or 30
            args[rowKey] = {
                type = "group",
                name = "Row " .. i,
                order = rowOrderBase + i,
                inline = true,
                args = BuildRowOptions(key, i, 1),
            }
        end
    end
    
    return args
end

function module:RegisterOptions()
    if not self.optionsBuilt then
        self:BuildOptions()
        self.optionsBuilt = true
    end
end

function module:BuildOptions()
    local options = {
        type = "group",
        name = "CDM",
        childGroups = "tab",
        args = {
            essential = {
                type = "group",
                name = "Essential Cooldowns",
                order = 10,
                args = {},
            },
            utility = {
                type = "group",
                name = "Utility Cooldowns",
                order = 20,
                args = {},
            },
        },
    }
    
    options.args.essential.args = BuildViewerOptions("essential", "Essential", 1)
    options.args.utility.args = BuildViewerOptions("utility", "Utility", 1)
    
    TavernUI:RegisterModuleOptions("CDM", options, "CDM")
end

function module:RefreshOptions(rebuild)
    if rebuild then
        self.optionsBuilt = false
        self:BuildOptions()
        self.optionsBuilt = true
    end
    LibStub("AceConfigRegistry-3.0"):NotifyChange("TavernUI")
end

local function BuildOptionsWhenReady()
    if TavernUI and TavernUI.db and TavernUI.RegisterModuleOptions then
        module:RegisterOptions()
    end
end

module:RegisterMessage("TavernUI_CoreEnabled", BuildOptionsWhenReady)

if TavernUI and TavernUI.db and TavernUI.RegisterModuleOptions then
    BuildOptionsWhenReady()
end

