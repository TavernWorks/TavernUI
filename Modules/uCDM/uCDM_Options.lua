local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local RefreshOptions

local Anchor = LibStub("LibAnchorRegistry-1.0", true)

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

local function IncrementSettingsVersion(viewerKey)
    if not viewerKey then return end
    if not module.settingsVersion then
        module.settingsVersion = {}
    end
    module.settingsVersion[viewerKey] = (module.settingsVersion[viewerKey] or 0) + 1
end

local function MakeRowOption(viewerKey, rowIndex, optionKey, optionType, config)
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
    elseif optionType == "input" then
    end

    option.get = function()
        local db = module:GetDB()
        local viewers = db.viewers or {}
        local viewer = viewers[viewerKey] or {}
        local rows = viewer.rows or {}
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
        if not db.viewers then db.viewers = {} end
        if not db.viewers[viewerKey] then db.viewers[viewerKey] = {} end
        if not db.viewers[viewerKey].rows then db.viewers[viewerKey].rows = {} end
        if not db.viewers[viewerKey].rows[rowIndex] then db.viewers[viewerKey].rows[rowIndex] = {} end

        if optionType == "color" then
            if not db.viewers[viewerKey].rows[rowIndex][setPath] then
                db.viewers[viewerKey].rows[rowIndex][setPath] = {r = 0, g = 0, b = 0, a = 1}
            end
            db.viewers[viewerKey].rows[rowIndex][setPath].r = value
            db.viewers[viewerKey].rows[rowIndex][setPath].g = g
            db.viewers[viewerKey].rows[rowIndex][setPath].b = b
        else
            db.viewers[viewerKey].rows[rowIndex][setPath] = value
        end

        IncrementSettingsVersion(viewerKey)

        if module:IsEnabled() and module.RefreshManager then
            module.RefreshManager.RefreshViewer(viewerKey)
        end
    end

    if disabled then
        option.disabled = function()
            local db = module:GetDB()
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            local rows = viewer.rows or {}
            local row = rows[rowIndex]
            return disabled(row, db)
        end
    end

    return option
end

local function BuildRowOptions(viewerKey, rowIndex, orderBase)
    local args = {}
    local order = orderBase or 1

    args.rowName = MakeRowOption(viewerKey, rowIndex, "name", "input", {
        order = order, name = "Row Name", desc = "Optional name for this row",
        default = ""
    })
    order = order + 1

    args.iconCount = MakeRowOption(viewerKey, rowIndex, "iconCount", "range", {
        order = order, name = "Icon Count", desc = "Number of icons in this row",
        min = 1, max = 12, step = 1, default = viewerKey == "essential" and 4 or 6
    })
    order = order + 1

    args.iconSize = MakeRowOption(viewerKey, rowIndex, "iconSize", "range", {
        order = order, name = "Icon Size", desc = "Size of icons in this row",
        min = 20, max = 100, step = 1, default = viewerKey == "essential" and 50 or 42
    })
    order = order + 1

    args.padding = MakeRowOption(viewerKey, rowIndex, "padding", "range", {
        order = order, name = "Padding", desc = "Spacing between icons (negative for overlap)",
        min = -20, max = 20, step = 1, default = -8
    })
    order = order + 1

    args.yOffset = MakeRowOption(viewerKey, rowIndex, "yOffset", "range", {
        order = order, name = "Y Offset", desc = "Vertical offset for this row",
        min = -50, max = 50, step = 1, default = 0
    })
    order = order + 1

    args.stylingHeader = {type = "header", name = "Icon Styling", order = order}
    order = order + 1

    args.aspectRatioCrop = MakeRowOption(viewerKey, rowIndex, "aspectRatioCrop", "range", {
        order = order, name = "Aspect Ratio Crop", desc = "Icon aspect ratio (1.0 = square, higher = wider/flatter)",
        min = 1.0, max = 2.0, step = 0.01, default = 1.0
    })
    order = order + 1

    args.zoom = MakeRowOption(viewerKey, rowIndex, "zoom", "range", {
        order = order, name = "Zoom", desc = "Zoom level for icon texture (0 = default, higher = zoomed in)",
        min = 0, max = 0.2, step = 0.01, default = 0
    })
    order = order + 1

    args.iconBorderHeader = {type = "header", name = "Icon Border", order = order}
    order = order + 1

    args.iconBorderSize = MakeRowOption(viewerKey, rowIndex, "iconBorderSize", "range", {
        order = order, name = "Icon Border Size", desc = "Size of border around each icon (0 = no border)",
        min = 0, max = 5, step = 1, default = 0
    })
    order = order + 1

    args.iconBorderColor = MakeRowOption(viewerKey, rowIndex, "iconBorderColor", "color", {
        order = order, name = "Icon Border Color", desc = "Color of the border around each icon",
        default = {r = 0, g = 0, b = 0, a = 1},
        disabled = function(row) return (row and row.iconBorderSize or 0) == 0 end
    })
    order = order + 1

    args.rowBorderHeader = {type = "header", name = "Row Border", order = order}
    order = order + 1

    args.rowBorderSize = MakeRowOption(viewerKey, rowIndex, "rowBorderSize", "range", {
        order = order, name = "Row Border Size", desc = "Size of border around the entire row (0 = no border)",
        min = 0, max = 5, step = 1, default = 0
    })
    order = order + 1

    args.rowBorderColor = MakeRowOption(viewerKey, rowIndex, "rowBorderColor", "color", {
        order = order, name = "Row Border Color", desc = "Color of the border around the entire row",
        default = {r = 0, g = 0, b = 0, a = 1},
        disabled = function(row) return (row and row.rowBorderSize or 0) == 0 end
    })
    order = order + 1

    args.textHeader = {type = "header", name = "Text Settings", order = order}
    order = order + 1

    args.durationSize = MakeRowOption(viewerKey, rowIndex, "durationSize", "range", {
        order = order, name = "Duration Text Size", desc = "Font size for cooldown duration text (0 = hide)",
        min = 0, max = 96, step = 1, default = 18
    })
    order = order + 1

    args.durationPoint = MakeRowOption(viewerKey, rowIndex, "durationPoint", "select", {
        order = order, name = "Duration Text Position", desc = "Anchor point for duration text on icon",
        values = ANCHOR_POINTS, default = "CENTER",
        disabled = function(row) return (row and row.durationSize or 18) == 0 end
    })
    order = order + 1

    args.durationOffsetX = MakeRowOption(viewerKey, rowIndex, "durationOffsetX", "range", {
        order = order, name = "Duration Text Offset X", desc = "Horizontal offset for duration text",
        min = -50, max = 50, step = 1, default = 0,
        disabled = function(row) return (row and row.durationSize or 18) == 0 end
    })
    order = order + 1

    args.durationOffsetY = MakeRowOption(viewerKey, rowIndex, "durationOffsetY", "range", {
        order = order, name = "Duration Text Offset Y", desc = "Vertical offset for duration text",
        min = -50, max = 50, step = 1, default = 0,
        disabled = function(row) return (row and row.durationSize or 18) == 0 end
    })
    order = order + 1

    args.stackSize = MakeRowOption(viewerKey, rowIndex, "stackSize", "range", {
        order = order, name = "Stack Text Size", desc = "Font size for stack count text (0 = hide)",
        min = 0, max = 96, step = 1, default = 16
    })
    order = order + 1

    args.stackPoint = MakeRowOption(viewerKey, rowIndex, "stackPoint", "select", {
        order = order, name = "Stack Text Position", desc = "Anchor point for stack text on icon",
        values = ANCHOR_POINTS, default = "BOTTOMRIGHT",
        disabled = function(row) return (row and row.stackSize or 16) == 0 end
    })
    order = order + 1

    args.stackOffsetX = MakeRowOption(viewerKey, rowIndex, "stackOffsetX", "range", {
        order = order, name = "Stack Text Offset X", desc = "Horizontal offset for stack text",
        min = -50, max = 50, step = 1, default = 0,
        disabled = function(row) return (row and row.stackSize or 16) == 0 end
    })
    order = order + 1

    args.stackOffsetY = MakeRowOption(viewerKey, rowIndex, "stackOffsetY", "range", {
        order = order, name = "Stack Text Offset Y", desc = "Vertical offset for stack text",
        min = -50, max = 50, step = 1, default = 0,
        disabled = function(row) return (row and row.stackSize or 16) == 0 end
    })
    order = order + 1

    args.actionsHeader = {type = "header", name = "Actions", order = order}
    order = order + 1

    args.moveUp = {
        type = "execute",
        name = "Move Up",
        desc = "Move this row up",
        order = order,
        disabled = function()
            return rowIndex == 1
        end,
        func = function()
            local db = module:GetDB()
            if db.viewers and db.viewers[viewerKey] and db.viewers[viewerKey].rows and rowIndex > 1 then
                local rows = db.viewers[viewerKey].rows
                rows[rowIndex], rows[rowIndex - 1] = rows[rowIndex - 1], rows[rowIndex]
                IncrementSettingsVersion(viewerKey)
                if module:IsEnabled() and module.RefreshManager then
                    module.RefreshManager.RefreshViewer(viewerKey)
                end
                RefreshOptions(true)
                if module:IsEnabled() and module.RefreshManager then
                    C_Timer.After(0.15, function()
                        module.RefreshManager.RefreshViewer(viewerKey)
                    end)
                end
            end
        end,
    }
    order = order + 1

    args.moveDown = {
        type = "execute",
        name = "Move Down",
        desc = "Move this row down",
        order = order,
        disabled = function()
            local db = module:GetDB()
            if not db.viewers or not db.viewers[viewerKey] or not db.viewers[viewerKey].rows then return true end
            return rowIndex >= #db.viewers[viewerKey].rows
        end,
        func = function()
            local db = module:GetDB()
            if db.viewers and db.viewers[viewerKey] and db.viewers[viewerKey].rows and rowIndex < #db.viewers[viewerKey].rows then
                local rows = db.viewers[viewerKey].rows
                rows[rowIndex], rows[rowIndex + 1] = rows[rowIndex + 1], rows[rowIndex]
                IncrementSettingsVersion(viewerKey)
                if module:IsEnabled() and module.RefreshManager then
                    module.RefreshManager.RefreshViewer(viewerKey)
                end
                RefreshOptions(true)
                if module:IsEnabled() and module.RefreshManager then
                    C_Timer.After(0.15, function()
                        module.RefreshManager.RefreshViewer(viewerKey)
                    end)
                end
            end
        end,
    }
    order = order + 1

    args.removeRow = {
        type = "execute",
        name = "Remove Row",
        desc = "Remove this row",
        order = order,
        func = function()
            local db = module:GetDB()
            if db.viewers and db.viewers[viewerKey] and db.viewers[viewerKey].rows then
                table.remove(db.viewers[viewerKey].rows, rowIndex)
                IncrementSettingsVersion(viewerKey)
                if module:IsEnabled() and module.RefreshManager then
                    module.RefreshManager.RefreshViewer(viewerKey)
                end
                RefreshOptions(true)
                if module:IsEnabled() and module.RefreshManager then
                    C_Timer.After(0.15, function()
                        module.RefreshManager.RefreshViewer(viewerKey)
                    end)
                end
            end
        end,
    }

    return args
end

local function BuildAnchorOptions(viewerKey, orderBase)
    local args = {}
    local order = orderBase or 1

    if not Anchor then
        return args
    end

    local anchorNames = {
        essential = "TavernUI.uCDM.essential",
        utility = "TavernUI.uCDM.utility",
        buff = "TavernUI.uCDM.buff",
        custom = "TavernUI.uCDM.custom",
    }
    local excludeAnchor = anchorNames[viewerKey]

    local function GetCategoryForAnchor(anchorName)
        if not Anchor or not anchorName then return nil end
        local frame, metadata = Anchor:Get(anchorName)
        if metadata and metadata.category then
            return metadata.category
        end
        return "misc"
    end

    local function GetAvailableCategories()
        local categories = {}
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
            ucdm = 5,
            unitframes = 6,
            TavernUI = 7,
            blizzard = 8,
            misc = 9,
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

    args.anchoringHeader = {type = "header", name = "Anchoring", order = order}
    order = order + 1

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
                ucdm = "uCDM",
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
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            if viewer.anchorConfig and viewer.anchorConfig.target and viewer.anchorConfig.target ~= "UIParent" then
                local category = GetCategoryForAnchor(viewer.anchorConfig.target)
                if category then
                    if not viewer.anchorCategory then
                        viewer.anchorCategory = category
                    end
                    return category
                end
                return "misc"
            end
            return viewer.anchorCategory or "None"
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db.viewers then db.viewers = {} end
            if not db.viewers[viewerKey] then db.viewers[viewerKey] = {} end
            if not db.viewers[viewerKey].anchorConfig then
                db.viewers[viewerKey].anchorConfig = {
                    target = nil,
                    point = "CENTER",
                    relativePoint = "CENTER",
                    offsetX = 0,
                    offsetY = 0,
                }
            end

            if value == "None" or not value then
                if db.viewers[viewerKey].anchorConfig then
                    db.viewers[viewerKey].anchorConfig.target = nil
                end
                db.viewers[viewerKey].anchorCategory = nil
            else
                db.viewers[viewerKey].anchorCategory = value
                if db.viewers[viewerKey].anchorConfig and db.viewers[viewerKey].anchorConfig.target then
                    local currentCategory = GetCategoryForAnchor(db.viewers[viewerKey].anchorConfig.target)
                    if currentCategory ~= value then
                        db.viewers[viewerKey].anchorConfig.target = nil
                    end
                end
            end

            IncrementSettingsVersion(viewerKey)

            if module:IsEnabled() and module.Anchoring then
                module.Anchoring.ApplyAnchorsAfterLayout(viewerKey)
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
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            local category = viewer.anchorCategory
            if not category or category == "None" then
                if viewer.anchorConfig and viewer.anchorConfig.target and viewer.anchorConfig.target ~= "UIParent" then
                    category = GetCategoryForAnchor(viewer.anchorConfig.target)
                    if category then
                        viewer.anchorCategory = category
                        return false
                    end
                end
                return true
            end
            return false
        end,
        values = function()
            local values = {}
            local db = module:GetDB()
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            local selectedCategory = viewer.anchorCategory

            if selectedCategory and selectedCategory ~= "None" then
                local anchorsByCategory = Anchor:GetByCategory(selectedCategory)

                for anchorName, anchorData in pairs(anchorsByCategory) do
                    if anchorName ~= excludeAnchor then
                        local displayName = anchorData.metadata and anchorData.metadata.displayName or anchorName
                        values[anchorName] = displayName
                    end
                end
            end

            return values
        end,
        get = function()
            local db = module:GetDB()
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            if viewer.anchorConfig and viewer.anchorConfig.target and viewer.anchorConfig.target ~= "UIParent" then
                return viewer.anchorConfig.target
            end
            return nil
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db.viewers then db.viewers = {} end
            if not db.viewers[viewerKey] then db.viewers[viewerKey] = {} end

            if not value then
                if db.viewers[viewerKey].anchorConfig then
                    db.viewers[viewerKey].anchorConfig.target = nil
                end
            else
                if not db.viewers[viewerKey].anchorConfig then
                    db.viewers[viewerKey].anchorConfig = {
                        target = value,
                        point = "CENTER",
                        relativePoint = "CENTER",
                        offsetX = 0,
                        offsetY = 0,
                    }
                else
                    db.viewers[viewerKey].anchorConfig.target = value
                end

                local category = GetCategoryForAnchor(value)
                if category then
                    db.viewers[viewerKey].anchorCategory = category
                end
            end

            IncrementSettingsVersion(viewerKey)
            if module:IsEnabled() and module.Anchoring then
                module.Anchoring.ApplyAnchorsAfterLayout(viewerKey)
            end
        end,
    }
    order = order + 1

    args.anchorPoint = {
        type = "select",
        name = "Point",
        desc = "Anchor point on viewer",
        order = order,
        values = ANCHOR_POINTS,
        disabled = function()
            local db = module:GetDB()
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            return not (viewer.anchorConfig and viewer.anchorConfig.target ~= nil)
        end,
        get = function()
            local db = module:GetDB()
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            return (viewer.anchorConfig and viewer.anchorConfig.point) or "CENTER"
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db.viewers then db.viewers = {} end
            if not db.viewers[viewerKey] then db.viewers[viewerKey] = {} end
            if not db.viewers[viewerKey].anchorConfig then
                db.viewers[viewerKey].anchorConfig = {}
            end
            db.viewers[viewerKey].anchorConfig.point = value
            IncrementSettingsVersion(viewerKey)
            if module:IsEnabled() and module.Anchoring then
                module.Anchoring.ApplyAnchorsAfterLayout(viewerKey)
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
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            return not (viewer.anchorConfig and viewer.anchorConfig.target ~= nil)
        end,
        get = function()
            local db = module:GetDB()
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            return (viewer.anchorConfig and viewer.anchorConfig.relativePoint) or "CENTER"
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db.viewers then db.viewers = {} end
            if not db.viewers[viewerKey] then db.viewers[viewerKey] = {} end
            if not db.viewers[viewerKey].anchorConfig then
                db.viewers[viewerKey].anchorConfig = {}
            end
            db.viewers[viewerKey].anchorConfig.relativePoint = value
            IncrementSettingsVersion(viewerKey)
            if module:IsEnabled() and module.Anchoring then
                module.Anchoring.ApplyAnchorsAfterLayout(viewerKey)
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
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            return not (viewer.anchorConfig and viewer.anchorConfig.target ~= nil)
        end,
        get = function()
            local db = module:GetDB()
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            return (viewer.anchorConfig and viewer.anchorConfig.offsetX) or 0
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db.viewers then db.viewers = {} end
            if not db.viewers[viewerKey] then db.viewers[viewerKey] = {} end
            if not db.viewers[viewerKey].anchorConfig then
                db.viewers[viewerKey].anchorConfig = {}
            end
            db.viewers[viewerKey].anchorConfig.offsetX = value
            IncrementSettingsVersion(viewerKey)
            if module:IsEnabled() and module.Anchoring then
                module.Anchoring.ApplyAnchorsAfterLayout(viewerKey)
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
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            return not (viewer.anchorConfig and viewer.anchorConfig.target ~= nil)
        end,
        get = function()
            local db = module:GetDB()
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            return (viewer.anchorConfig and viewer.anchorConfig.offsetY) or 0
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db.viewers then db.viewers = {} end
            if not db.viewers[viewerKey] then db.viewers[viewerKey] = {} end
            if not db.viewers[viewerKey].anchorConfig then
                db.viewers[viewerKey].anchorConfig = {}
            end
            db.viewers[viewerKey].anchorConfig.offsetY = value
            IncrementSettingsVersion(viewerKey)
            if module:IsEnabled() and module.Anchoring then
                module.Anchoring.ApplyAnchorsAfterLayout(viewerKey)
            end
        end,
    }

    return args
end

local function BuildViewerOptions(viewerKey, viewerName, orderBase)
    local args = {}
    local order = orderBase or 1

    args.enabled = {
        type = "toggle",
        name = "Enabled",
        desc = "Enable " .. viewerName .. " cooldown viewer",
        order = order,
        get = function()
            local db = module:GetDB()
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            return viewer.enabled ~= false
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db.viewers then db.viewers = {} end
            if not db.viewers[viewerKey] then db.viewers[viewerKey] = {} end
            db.viewers[viewerKey].enabled = value
            
            local viewer = module.LayoutEngine.GetViewerFrame(viewerKey)
            if viewer then
                if value then
                    viewer:Show()
                else
                    viewer:Hide()
                end
            end
            
            IncrementSettingsVersion(viewerKey)
            if module:IsEnabled() and module.RefreshManager then
                if value then
                    module.RefreshManager.RefreshViewer(viewerKey)
                else
                    if viewer then
                        viewer:Hide()
                    end
                end
            end
        end,
    }
    order = order + 1

    args.rowGrowDirection = {
        type = "select",
        name = "Row Growth Direction",
        desc = "Direction rows grow (Up = bottom to top, Down = top to bottom)",
        order = order,
        values = {
            down = "Down",
            up = "Up",
        },
        get = function()
            local db = module:GetDB()
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            return viewer.rowGrowDirection or "down"
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db.viewers then db.viewers = {} end
            if not db.viewers[viewerKey] then db.viewers[viewerKey] = {} end
            db.viewers[viewerKey].rowGrowDirection = value
            IncrementSettingsVersion(viewerKey)
            if module:IsEnabled() and module.RefreshManager then
                module.RefreshManager.RefreshViewer(viewerKey)
            end
        end,
    }
    order = order + 1

    local anchorOrder = viewerKey == "essential" and 5 or 10
    local anchorOptions = BuildAnchorOptions(viewerKey, anchorOrder)

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
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            return viewer.showKeybinds == true
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db.viewers then db.viewers = {} end
            if not db.viewers[viewerKey] then db.viewers[viewerKey] = {} end
            db.viewers[viewerKey].showKeybinds = value
            IncrementSettingsVersion(viewerKey)
            if module:IsEnabled() and module.RefreshManager then
                module.RefreshManager.RefreshKeybinds(viewerKey)
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
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            return not viewer.showKeybinds
        end,
        get = function()
            local db = module:GetDB()
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            return viewer.keybindSize or 10
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db.viewers then db.viewers = {} end
            if not db.viewers[viewerKey] then db.viewers[viewerKey] = {} end
            db.viewers[viewerKey].keybindSize = value
            IncrementSettingsVersion(viewerKey)
            if module:IsEnabled() and module.RefreshManager then
                module.RefreshManager.RefreshKeybinds(viewerKey)
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
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            return not viewer.showKeybinds
        end,
        get = function()
            local db = module:GetDB()
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            return viewer.keybindPoint or "TOPLEFT"
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db.viewers then db.viewers = {} end
            if not db.viewers[viewerKey] then db.viewers[viewerKey] = {} end
            db.viewers[viewerKey].keybindPoint = value
            IncrementSettingsVersion(viewerKey)
            if module:IsEnabled() and module.RefreshManager then
                module.RefreshManager.RefreshKeybinds(viewerKey)
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
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            return not viewer.showKeybinds
        end,
        get = function()
            local db = module:GetDB()
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            return viewer.keybindOffsetX or 2
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db.viewers then db.viewers = {} end
            if not db.viewers[viewerKey] then db.viewers[viewerKey] = {} end
            db.viewers[viewerKey].keybindOffsetX = value
            IncrementSettingsVersion(viewerKey)
            if module:IsEnabled() and module.RefreshManager then
                module.RefreshManager.RefreshKeybinds(viewerKey)
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
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            return not viewer.showKeybinds
        end,
        get = function()
            local db = module:GetDB()
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            return viewer.keybindOffsetY or -2
        end,
        set = function(_, value)
            local db = module:GetDB()
            if not db.viewers then db.viewers = {} end
            if not db.viewers[viewerKey] then db.viewers[viewerKey] = {} end
            db.viewers[viewerKey].keybindOffsetY = value
            IncrementSettingsVersion(viewerKey)
            if module:IsEnabled() and module.RefreshManager then
                module.RefreshManager.RefreshKeybinds(viewerKey)
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
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            return not viewer.showKeybinds
        end,
        get = function()
            local db = module:GetDB()
            local viewers = db.viewers or {}
            local viewer = viewers[viewerKey] or {}
            local color = viewer.keybindColor or {r = 1, g = 1, b = 1, a = 1}
            return color.r, color.g, color.b, color.a
        end,
        set = function(_, r, g, b, a)
            local db = module:GetDB()
            if not db.viewers then db.viewers = {} end
            if not db.viewers[viewerKey] then db.viewers[viewerKey] = {} end
            db.viewers[viewerKey].keybindColor = {r = r, g = g, b = b, a = a}
            IncrementSettingsVersion(viewerKey)
            if module:IsEnabled() and module.RefreshManager then
                module.RefreshManager.RefreshKeybinds(viewerKey)
            end
        end,
    }
    order = order + 1

    args.rowsHeader = {type = "header", name = "Rows", order = order}
    order = order + 1

    args.addRow = {
        type = "execute",
        name = "Add Row",
        desc = "Add a new row",
        order = order,
        func = function()
            local db = module:GetDB()
            if not db.viewers then db.viewers = {} end
            if not db.viewers[viewerKey] then db.viewers[viewerKey] = {} end
            if not db.viewers[viewerKey].rows then db.viewers[viewerKey].rows = {} end

            local defaultIconCount = viewerKey == "essential" and 4 or 6
            local defaultIconSize = viewerKey == "essential" and 50 or 42

            table.insert(db.viewers[viewerKey].rows, {
                name = "Row " .. (#db.viewers[viewerKey].rows + 1),
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

            IncrementSettingsVersion(viewerKey)
            if module:IsEnabled() and module.RefreshManager then
                module.RefreshManager.RefreshViewer(viewerKey)
            end
            RefreshOptions(true)
            if module:IsEnabled() and module.RefreshManager then
                C_Timer.After(0.15, function()
                    module.RefreshManager.RefreshViewer(viewerKey)
                end)
            end
        end,
    }
    order = order + 1

    local db = module:GetDB()
    local viewers = db.viewers or {}
    local viewer = viewers[viewerKey] or {}
    local rows = viewer.rows or {}
    
    if #rows == 0 then
        local defaultIconCount = viewerKey == "essential" and 4 or 6
        local defaultIconSize = viewerKey == "essential" and 50 or 42
        table.insert(rows, {
            name = "Default",
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
        if not db.viewers then db.viewers = {} end
        if not db.viewers[viewerKey] then db.viewers[viewerKey] = {} end
        db.viewers[viewerKey].rows = rows
    end

    for rowIndex, row in ipairs(rows) do
        local rowName = row.name or ("Row " .. rowIndex)
        args["row" .. rowIndex] = {
            type = "group",
            name = rowName,
            order = 100 + rowIndex,
            args = BuildRowOptions(viewerKey, rowIndex, 1),
        }
    end

    return args
end

local function BuildGeneralOptions()
    return {
        debugHeader = {
            type = "header",
            name = "Debug",
            order = 1,
        },
        debug = {
            type = "toggle",
            name = "Debug Mode",
            desc = "Enable debug messages",
            order = 2,
            get = function()
                local db = module:GetDB()
                return db.general and db.general.debug == true
            end,
            set = function(_, value)
                local db = module:GetDB()
                if not db.general then db.general = {} end
                db.general.debug = value
            end,
        },
        updateRatesHeader = {
            type = "header",
            name = "Update Rates",
            order = 10,
        },
        updateRateNormal = {
            type = "range",
            name = "Normal Update Rate",
            desc = "Update interval in seconds when out of combat (lower = more frequent updates)",
            order = 11,
            min = 0.05,
            max = 1.0,
            step = 0.05,
            get = function()
                local db = module:GetDB()
                return (db.general and db.general.updateRates and db.general.updateRates.normal) or 0.1
            end,
            set = function(_, value)
                local db = module:GetDB()
                if not db.general then db.general = {} end
                if not db.general.updateRates then db.general.updateRates = {} end
                db.general.updateRates.normal = value
                if module:IsEnabled() then
                    module:StopUpdateLoop()
                    module:StartUpdateLoop()
                end
            end,
        },
        updateRateCombat = {
            type = "range",
            name = "Combat Update Rate",
            desc = "Update interval in seconds when in combat (higher = better performance)",
            order = 12,
            min = 0.1,
            max = 2.0,
            step = 0.1,
            get = function()
                local db = module:GetDB()
                return (db.general and db.general.updateRates and db.general.updateRates.combat) or 0.3
            end,
            set = function(_, value)
                local db = module:GetDB()
                if not db.general then db.general = {} end
                if not db.general.updateRates then db.general.updateRates = {} end
                db.general.updateRates.combat = value
                if module:IsEnabled() then
                    module:StopUpdateLoop()
                    module:StartUpdateLoop()
                end
            end,
        },
        updateRateInitial = {
            type = "range",
            name = "Initial Update Rate",
            desc = "Update interval in seconds during first 5 seconds after load (lower = faster initial styling)",
            order = 13,
            min = 0.01,
            max = 0.2,
            step = 0.01,
            get = function()
                local db = module:GetDB()
                return (db.general and db.general.updateRates and db.general.updateRates.initial) or 0.05
            end,
            set = function(_, value)
                local db = module:GetDB()
                if not db.general then db.general = {} end
                if not db.general.updateRates then db.general.updateRates = {} end
                db.general.updateRates.initial = value
            end,
        },
    }
end

local function BuildCustomTabOptions()
    return {
        addSpell = {
            type = "input",
            name = "Add Spell",
            desc = "Enter spell ID to track",
            order = 1,
            get = function() return "" end,
            set = function(_, value)
                local spellID = tonumber(value)
                if spellID then
                    local ok, spellInfo = pcall(C_Spell.GetSpellInfo, spellID)
                    if ok and spellInfo then
                        local db = module:GetDB()
                        local defaultViewer = db.defaultCustomViewer or "essential"
                        local config = {
                            spellID = spellID,
                            viewer = defaultViewer,
                            enabled = true,
                        }
                        local entry = module.CustomProvider.CreateEntry(config)
                        if entry then
                            module:LogInfo("Added spell: " .. spellInfo.name)
                            RefreshOptions(true)
                        end
                    else
                        module:LogError("Invalid spellID: spell not found")
                    end
                end
            end,
        },
        addItem = {
            type = "input",
            name = "Add Item",
            desc = "Enter item ID to track",
            order = 2,
            get = function() return "" end,
            set = function(_, value)
                local itemID = tonumber(value)
                if itemID then
                    local ok, itemInfo = pcall(C_Item.GetItemInfoByID, itemID)
                    if ok and itemInfo then
                        local db = module:GetDB()
                        local defaultViewer = db.defaultCustomViewer or "essential"
                        local config = {
                            itemID = itemID,
                            viewer = defaultViewer,
                            enabled = true,
                        }
                        local entry = module.CustomProvider.CreateEntry(config)
                        if entry then
                            module:LogInfo("Added item: " .. itemInfo.itemName)
                            RefreshOptions(true)
                        end
                    else
                        module:LogError("Invalid itemID: item not found")
                    end
                end
            end,
        },
        addTrinket = {
            type = "select",
            name = "Add Trinket",
            desc = "Select trinket slot to track",
            order = 3,
            values = {
                [13] = "Trinket 1",
                [14] = "Trinket 2",
            },
            get = function() return nil end,
            set = function(_, value)
                local slotID = value
                local itemID = GetInventoryItemID("player", slotID)
                if itemID then
                    local db = module:GetDB()
                    local defaultViewer = db.defaultCustomViewer or "custom"
                    local config = {
                        slotID = slotID,
                        viewer = defaultViewer,
                        enabled = true,
                    }
                    module.CustomProvider.CreateEntry(config)
                    module:LogInfo("Added trinket from slot " .. slotID)
                    RefreshOptions(true)
                else
                    module:LogError("No item equipped in slot " .. slotID)
                end
            end,
        },
        viewerAssignment = {
            type = "select",
            name = "Default Viewer",
            desc = "Default viewer for new custom entries",
            order = 4,
            values = {
                essential = "Essential Viewer",
                utility = "Utility Viewer",
            },
            get = function()
                local db = module:GetDB()
                return db.defaultCustomViewer or "essential"
            end,
            set = function(_, value)
                local db = module:GetDB()
                db.defaultCustomViewer = value
            end,
        },
        entriesHeader = {
            type = "header",
            name = "Custom Entries",
            order = 10,
        },
    }
end

function module:BuildOptions()
    if not TavernUI.db or not TavernUI.db.profile then
        return
    end
    
    local options = {
        type = "group",
        name = "uCDM",
        childGroups = "tab",
        args = {
            general = {
                type = "group",
                name = "General",
                order = 0,
                args = BuildGeneralOptions(),
            },
            essential = {
                type = "group",
                name = "Essential Cooldowns",
                order = 1,
                args = {},
            },
            utility = {
                type = "group",
                name = "Utility Cooldowns",
                order = 2,
                args = {},
            },
            buff = {
                type = "group",
                name = "Buff Cooldowns",
                order = 3,
                args = {
                    note = {
                        type = "description",
                        name = "Buff viewer contains Blizzard entries only. No custom entries can be added.",
                        order = 1,
                    },
                },
            },
        },
    }
    
    local db = module:GetDB()
    
    local customTabOptions = BuildCustomTabOptions()
    for k, v in pairs(customTabOptions) do
        options.args.essential.args[k] = v
    end
    
    for _, viewerKey in ipairs({"essential", "utility", "buff"}) do
        local viewerName = viewerKey == "essential" and "Essential" or
                          viewerKey == "utility" and "Utility" or
                          viewerKey == "buff" and "Buff"
        
        options.args[viewerKey].args = BuildViewerOptions(viewerKey, viewerName, 1)

        local customEntries = db.customEntries or {}
        for entryIndex, entryConfig in ipairs(customEntries) do
            local entryViewer = entryConfig.viewer or "essential"
            if entryViewer == "custom" then
                entryViewer = "essential"
                entryConfig.viewer = "essential"
            end
            if entryViewer == viewerKey then
                local entryName = "Entry " .. entryIndex
                if entryConfig.spellID then
                    local ok, spellInfo = pcall(C_Spell.GetSpellInfo, entryConfig.spellID)
                    if ok and spellInfo then
                        entryName = spellInfo.name
                    end
                elseif entryConfig.itemID then
                    local ok, itemInfo = pcall(C_Item.GetItemInfoByID, entryConfig.itemID)
                    if ok and itemInfo then
                        entryName = itemInfo.itemName
                    end
                elseif entryConfig.slotID then
                    entryName = "Trinket " .. (entryConfig.slotID == 13 and "1" or "2")
                end

                options.args[viewerKey].args["entry" .. entryIndex] = {
                    type = "group",
                    name = entryName,
                    order = 200 + entryIndex,
                    args = {
                        enabled = {
                            type = "toggle",
                            name = "Enabled",
                            order = 1,
                            get = function()
                                return entryConfig.enabled ~= false
                            end,
                            set = function(_, value)
                                entryConfig.enabled = value
                                local entry = module.EntrySystem.GetEntry(entryConfig.id)
                                if entry then
                                    entry.enabled = value
                                    if entry.frame then
                                        if value then
                                            entry.frame:Show()
                                        else
                                            entry.frame:Hide()
                                        end
                                    end
                                end
                                if module:IsEnabled() and module.RefreshManager then
                                    local assignedViewer = entryConfig.viewer or "essential"
                                    module.RefreshManager.RefreshViewer(assignedViewer)
                                    if assignedViewer ~= viewerKey then
                                        module.RefreshManager.RefreshViewer(viewerKey)
                                    end
                                end
                            end,
                        },
                        index = {
                            type = "range",
                            name = "Index",
                            desc = "Display order (lower = earlier)",
                            order = 2,
                            min = 1,
                            max = 13,
                            step = 1,
                            get = function()
                                local assignedViewer = entryConfig.viewer or viewerKey
                                local entries = module.EntrySystem.GetMergedEntriesForViewer(assignedViewer)
                                for i, e in ipairs(entries) do
                                    if e.id == entryConfig.id then
                                        return i
                                    end
                                end
                                return entryConfig.index or 1
                            end,
                            set = function(_, value)
                                if not module.EntrySystem.ReorderEntry then
                                    return
                                end
                                
                                local assignedViewer = entryConfig.viewer or viewerKey
                                local allEntries = module.EntrySystem.GetMergedEntriesForViewer(assignedViewer)
                                local maxIndex = #allEntries
                                
                                if value < 1 then
                                    value = 1
                                elseif value > maxIndex then
                                    value = maxIndex
                                end
                                
                                local success = module.EntrySystem.ReorderEntry(entryConfig.id, value)
                                
                                if success then
                                    local db = module:GetDB()
                                    if db and db.customEntries then
                                        local updatedEntries = module.EntrySystem.GetMergedEntriesForViewer(assignedViewer)
                                        for _, entry in ipairs(updatedEntries) do
                                            if entry.type == "custom" then
                                                for _, cfg in ipairs(db.customEntries) do
                                                    if cfg.id == entry.id then
                                                        cfg.index = entry.index
                                                        break
                                                    end
                                                end
                                            end
                                        end
                                    end
                                    
                                    if module:IsEnabled() and module.RefreshManager then
                                        module.RefreshManager.RefreshViewer(assignedViewer)
                                    end
                                end
                            end,
                            },
                            viewer = {
                            type = "select",
                            name = "Viewer",
                            desc = "Assign entry to viewer",
                            order = 5,
                            values = {
                                essential = "Essential Viewer",
                                utility = "Utility Viewer",
                            },
                            get = function()
                                local viewer = entryConfig.viewer or "essential"
                                if viewer == "custom" then
                                    viewer = "essential"
                                    entryConfig.viewer = "essential"
                                end
                                return viewer
                            end,
                            set = function(_, value)
                                if value == "buff" then
                                    module:LogError("Cannot assign custom entries to buff viewer")
                                    return
                                end
                                
                                local entry = module.EntrySystem.GetEntry(entryConfig.id)
                                if not entry then
                                    module:LogError("Entry not found when changing viewer")
                                    return
                                end
                                
                                local oldViewer = entryConfig.viewer or entry.source or viewerKey
                                if oldViewer == "custom" then
                                    oldViewer = "essential"
                                end
                                entryConfig.viewer = value
                                
                                if entry.source ~= value and module.EntrySystem.MoveEntryToViewer then
                                    module.EntrySystem.MoveEntryToViewer(entryConfig.id, value)
                                end
                                
                                if module.RefreshManager then
                                    module.RefreshManager.RefreshViewer(oldViewer)
                                    module.RefreshManager.RefreshViewer(value)
                                end
                                
                                RefreshOptions(true)
                            end,
                        },
                        remove = {
                            type = "execute",
                            name = "Remove",
                            order = 6,
                            func = function()
                                module.CustomProvider.RemoveEntry(entryConfig.id)
                                RefreshOptions(true)
                            end,
                        },
                    },
                }
            end
        end
    end
    
    TavernUI:RegisterModuleOptions("uCDM", options, "uCDM")
end

function module:RegisterOptions()
    if not self.optionsBuilt then
        self:BuildOptions()
        self.optionsBuilt = true
    end
end

RefreshOptions = function(rebuild)
    if rebuild then
        module.optionsBuilt = false
        module:BuildOptions()
        module.optionsBuilt = true
    end
    LibStub("AceConfigRegistry-3.0"):NotifyChange("TavernUI")
end

module.RefreshOptions = RefreshOptions

local function BuildOptionsWhenReady()
    if TavernUI and TavernUI.db and TavernUI.RegisterModuleOptions then
        module:RegisterOptions()
    end
end

module:RegisterMessage("TavernUI_CoreEnabled", BuildOptionsWhenReady)

if TavernUI and TavernUI.db and TavernUI.RegisterModuleOptions then
    BuildOptionsWhenReady()
end
