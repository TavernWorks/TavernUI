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

        if key == "buff" and setPath == "iconCount" then
            local db = module:GetDB()
            local settings = db[key] or {}
            local activeRows = {}
            for _, row in ipairs(settings.rows or {}) do
                if row.iconCount and row.iconCount > 0 then
                    table.insert(activeRows, row)
                end
            end
            local newCapacity = 0
            for _, row in ipairs(activeRows) do
                newCapacity = newCapacity + (row.iconCount or 0)
            end
            
            if module.ValidateSlotAssignments then
                local cleaned, removedCount = module.ValidateSlotAssignments("buff", newCapacity)
                if cleaned and removedCount > 0 then
                    if DEFAULT_CHAT_FRAME then
                        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00CDM:|r " .. removedCount .. " slot assignment(s) were removed due to capacity reduction")
                    end
                end
                if module.CDM then
                    module.CDM.lastCapacity = module.CDM.lastCapacity or {}
                    module.CDM.lastCapacity["buff"] = newCapacity
                end
            end
        end
        
        IncrementSettingsVersion(key)
        
        if module:IsEnabled() and not (module.CDM and module.CDM.refreshing) then
            C_Timer.After(0.15, function()
                if module:IsEnabled() and not (module.CDM and module.CDM.refreshing) then
                    module:RefreshAll()
                end
            end)
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
    local viewerName = config.viewerName or key

    local viewerConfig = {
        essential = {
            anchorName = "TavernUI.CDM.Essential",
            applyFunc = module.ApplyEssentialAnchor,
        },
        utility = {
            anchorName = "TavernUI.CDM.Utility",
            applyFunc = module.ApplyUtilityAnchor,
        },
        buff = {
            anchorName = "TavernUI.CDM.Buff",
            applyFunc = module.ApplyBuffAnchor,
        },
    }
    
    local viewerInfo = viewerConfig[key] or {}
    local excludeAnchor = viewerInfo.anchorName

    local function GetApplyAnchorFunc()
        return viewerInfo.applyFunc
    end

    args.anchoringHeader = {type = "header", name = "Anchoring", order = order}
    order = order + 1

    local function GetAvailableCategories()
        local categories = {}
        if not Anchor then return categories end

        local allAnchors = Anchor:GetAll()

        for anchorName, anchorData in pairs(allAnchors) do
            if anchorName ~= excludeAnchor and anchorData.metadata then
                local category = anchorData.metadata.category or "misc"
                if not categories[category] then
                    categories[category] = true
                end
            end
        end

        local categoryOrder = {
            actionbars = 1,
            bars = 2,
            cooldowns = 3,
            cdm = 4,
            unitframes = 5,
            TavernUI = 6,
            blizzard = 7,
            misc = 8,
        }

        local categoryList = {}
        for cat in pairs(categories) do
            table.insert(categoryList, cat)
        end

        table.sort(categoryList, function(a, b)
            local orderA = categoryOrder[a] or 99
            local orderB = categoryOrder[b] or 99
            if orderA == orderB then
                return a < b
            end
            return orderA < orderB
        end)

        return categoryList
    end

    local function GetCategoryForAnchor(anchorName)
        if not Anchor or not anchorName then return nil end
        local frame, metadata = Anchor:Get(anchorName)
        if metadata and metadata.category then
            return metadata.category
        end
        return "misc"
    end

    args.anchorCategory = {
        type = "select",
        name = "Category",
        desc = "Category of anchor target",
        order = order,
        values = function()
            local values = {
                None = "None (No Anchoring)",
            }

            local categoryDisplayNames = {
                actionbars = "Action Bars",
                bars = "Bars",
                cooldowns = "Cooldowns",
                cdm = "CDM",
                unitframes = "Unit Frames",
                TavernUI = "TavernUI",
                blizzard = "Blizzard",
                misc = "Misc",
            }

            local categories = GetAvailableCategories()
            for _, cat in ipairs(categories) do
                local displayName = categoryDisplayNames[cat] or cat:gsub("^%l", string.upper)
                values[cat] = displayName
            end

            return values
        end,
        get = function()
            local db = module:GetDB()
            if db[key] and db[key].anchorConfig and db[key].anchorConfig.target and db[key].anchorConfig.target ~= "UIParent" then
                local category = GetCategoryForAnchor(db[key].anchorConfig.target)
                if category then
                    if not db[key].anchorCategory then
                        db[key].anchorCategory = category
                    end
                    return category
                end
                return "misc"
            end
            return db[key] and db[key].anchorCategory or "None"
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db[key] then db[key] = {} end
            if not db[key].anchorConfig then
                db[key].anchorConfig = {
                    target = nil,
                    point = "CENTER",
                    relativePoint = "CENTER",
                    offsetX = 0,
                    offsetY = 0,
                }
            end

            local needsRelease = false
            if value == "None" or not value then
                if db[key].anchorConfig and db[key].anchorConfig.target then
                    needsRelease = true
                end
                if db[key].anchorConfig then
                    db[key].anchorConfig.target = nil
                end
                db[key].anchorCategory = nil
            else
                db[key].anchorCategory = value
                if db[key].anchorConfig and db[key].anchorConfig.target then
                    local currentCategory = GetCategoryForAnchor(db[key].anchorConfig.target)
                    if currentCategory ~= value then
                        db[key].anchorConfig.target = nil
                        needsRelease = true
                    end
                end
            end

            IncrementSettingsVersion(key)

            -- Release anchor if we cleared the target
            if needsRelease and module:IsEnabled() then
                local applyFunc = GetApplyAnchorFunc()
                if applyFunc then applyFunc() end
            end

            LibStub("AceConfigRegistry-3.0"):NotifyChange("TavernUI")
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
            if not db[key] then return true end

            local category = db[key].anchorCategory
            if not category or category == "None" then
                if db[key].anchorConfig and db[key].anchorConfig.target and db[key].anchorConfig.target ~= "UIParent" then
                    category = GetCategoryForAnchor(db[key].anchorConfig.target)
                    if category then
                        db[key].anchorCategory = category
                        return false
                    end
                end
                return true
            end
            return false
        end,
        values = function()
            local values = {}

            if Anchor then
                local db = module:GetDB()
                local selectedCategory = db[key] and db[key].anchorCategory

                if not selectedCategory or selectedCategory == "None" then
                    if db[key] and db[key].anchorConfig and db[key].anchorConfig.target and db[key].anchorConfig.target ~= "UIParent" then
                        selectedCategory = GetCategoryForAnchor(db[key].anchorConfig.target)
                        if selectedCategory then
                            db[key].anchorCategory = selectedCategory
                        end
                    end
                end

                if selectedCategory and selectedCategory ~= "None" then
                    local anchorsByCategory = Anchor:GetByCategory(selectedCategory)

                    for anchorName, anchorData in pairs(anchorsByCategory) do
                        if anchorName ~= excludeAnchor then
                            local displayName = anchorData.metadata and anchorData.metadata.displayName or anchorName
                            values[anchorName] = displayName
                        end
                    end
                end
            end

            return values
        end,
        get = function()
            local db = module:GetDB()
            if db[key] and db[key].anchorConfig and db[key].anchorConfig.target and db[key].anchorConfig.target ~= "UIParent" then
                return db[key].anchorConfig.target
            end
            return nil
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db[key] then db[key] = {} end

            if not value then
                if db[key].anchorConfig then
                    db[key].anchorConfig.target = nil
                end
            else
                if not db[key].anchorConfig then
                    db[key].anchorConfig = {
                        target = value,
                        point = "CENTER",
                        relativePoint = "CENTER",
                        offsetX = 0,
                        offsetY = 0,
                    }
                else
                    db[key].anchorConfig.target = value
                end

                local category = GetCategoryForAnchor(value)
                if category then
                    db[key].anchorCategory = category
                end
            end

            IncrementSettingsVersion(key)
            if module:IsEnabled() then
                local applyFunc = GetApplyAnchorFunc()
                if applyFunc then applyFunc() end
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
                local applyFunc = GetApplyAnchorFunc()
                if applyFunc then applyFunc() end
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
                local applyFunc = GetApplyAnchorFunc()
                if applyFunc then applyFunc() end
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
                local applyFunc = GetApplyAnchorFunc()
                if applyFunc then applyFunc() end
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
                local applyFunc = GetApplyAnchorFunc()
                if applyFunc then applyFunc() end
                module:RefreshAll()
            end
        end,
    }

    return args
end

local function BuildViewerOptions(key, viewerName, orderBase)
    local args = {}
    local order = orderBase or 1
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

    args.keybindHeader = {type = "header", name = "Keybind Display", order = order}
    order = order + 1

    args.showKeybinds = {
        type = "toggle",
        name = "Show Keybinds",
        desc = "Display action bar keybinds on cooldown icons",
        order = order,
        get = function()
            local db = module:GetDB()
            return (db[key] and db[key].showKeybinds) == true
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db[key] then db[key] = {} end
            db[key].showKeybinds = value
            IncrementSettingsVersion(key)
            if module:IsEnabled() then
                if module.UpdateAllKeybinds then
                    module.UpdateAllKeybinds()
                end
                module:RefreshAll()
            end
        end,
    }
    order = order + 1

    args.keybindSize = {
        type = "range",
        name = "Keybind Text Size",
        desc = "Font size for keybind text",
        order = order,
        min = 6,
        max = 24,
        step = 1,
        disabled = function()
            local db = module:GetDB()
            return not (db[key] and db[key].showKeybinds)
        end,
        get = function()
            local db = module:GetDB()
            return (db[key] and db[key].keybindSize) or 10
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db[key] then db[key] = {} end
            db[key].keybindSize = value
            IncrementSettingsVersion(key)
            if module:IsEnabled() then
                if module.UpdateAllKeybinds then
                    module.UpdateAllKeybinds()
                end
                module:RefreshAll()
            end
        end,
    }
    order = order + 1

    args.keybindPoint = {
        type = "select",
        name = "Keybind Position",
        desc = "Anchor point for keybind text on icon",
        order = order,
        values = ANCHOR_POINTS,
        disabled = function()
            local db = module:GetDB()
            return not (db[key] and db[key].showKeybinds)
        end,
        get = function()
            local db = module:GetDB()
            return (db[key] and db[key].keybindPoint) or "TOPLEFT"
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db[key] then db[key] = {} end
            db[key].keybindPoint = value
            IncrementSettingsVersion(key)
            if module:IsEnabled() then
                if module.UpdateAllKeybinds then
                    module.UpdateAllKeybinds()
                end
                module:RefreshAll()
            end
        end,
    }
    order = order + 1

    args.keybindOffsetX = {
        type = "range",
        name = "Keybind Offset X",
        desc = "Horizontal offset for keybind text",
        order = order,
        min = -50,
        max = 50,
        step = 1,
        disabled = function()
            local db = module:GetDB()
            return not (db[key] and db[key].showKeybinds)
        end,
        get = function()
            local db = module:GetDB()
            return (db[key] and db[key].keybindOffsetX) or 2
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db[key] then db[key] = {} end
            db[key].keybindOffsetX = value
            IncrementSettingsVersion(key)
            if module:IsEnabled() then
                if module.UpdateAllKeybinds then
                    module.UpdateAllKeybinds()
                end
                module:RefreshAll()
            end
        end,
    }
    order = order + 1

    args.keybindOffsetY = {
        type = "range",
        name = "Keybind Offset Y",
        desc = "Vertical offset for keybind text",
        order = order,
        min = -50,
        max = 50,
        step = 1,
        disabled = function()
            local db = module:GetDB()
            return not (db[key] and db[key].showKeybinds)
        end,
        get = function()
            local db = module:GetDB()
            return (db[key] and db[key].keybindOffsetY) or -2
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db[key] then db[key] = {} end
            db[key].keybindOffsetY = value
            IncrementSettingsVersion(key)
            if module:IsEnabled() then
                if module.UpdateAllKeybinds then
                    module.UpdateAllKeybinds()
                end
                module:RefreshAll()
            end
        end,
    }
    order = order + 1

    args.keybindColor = {
        type = "color",
        name = "Keybind Text Color",
        desc = "Color of the keybind text",
        order = order,
        hasAlpha = true,
        disabled = function()
            local db = module:GetDB()
            return not (db[key] and db[key].showKeybinds)
        end,
        get = function()
            local db = module:GetDB()
            local color = (db[key] and db[key].keybindColor) or {r = 1, g = 1, b = 1, a = 1}
            return color.r, color.g, color.b, color.a
        end,
        set = function(_, r, g, b, a)
            local db = module:GetDB()
            if not db[key] then db[key] = {} end
            if not db[key].keybindColor then
                db[key].keybindColor = {r = 1, g = 1, b = 1, a = 1}
            end
            db[key].keybindColor.r = r
            db[key].keybindColor.g = g
            db[key].keybindColor.b = b
            db[key].keybindColor.a = a or 1
            IncrementSettingsVersion(key)
            if module:IsEnabled() then
                if module.UpdateAllKeybinds then
                    module.UpdateAllKeybinds()
                end
                module:RefreshAll()
            end
        end,
    }
    order = order + 1

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
            local rowOrderBase = key == "essential" and 20 or (key == "utility" and 30) or 40
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
            buff = {
                type = "group",
                name = "Buff Cooldowns",
                order = 30,
                args = {},
            },
        },
    }

    options.args.essential.args = BuildViewerOptions("essential", "Essential", 1)
    options.args.utility.args = BuildViewerOptions("utility", "Utility", 1)
    options.args.buff.args = BuildViewerOptions("buff", "Buff", 1)

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