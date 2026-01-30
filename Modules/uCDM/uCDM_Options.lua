local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local RefreshOptions

local function RefreshViewerComponents(viewerKey, property)
    if not module:IsEnabled() then return end

    local layoutProperties = {
        iconCount = true,
        padding = true,
        yOffset = true,
        iconSize = true,
        aspectRatioCrop = true,
        rowBorderSize = true,
        rows = true,
        keepRowHeightWhenEmpty = true,
    }
    
    if layoutProperties[property] then
        if module.RefreshViewer then
            module:RefreshViewer(viewerKey)
        elseif module.LayoutEngine then
            module.LayoutEngine.RefreshViewer(viewerKey)
            if module.LayoutEngine then
                module.LayoutEngine.RefreshViewer(viewerKey)
            end
        end
    elseif property == "anchorConfig" or property == "anchorCategory" or 
           property:match("^anchorConfig%.") then
        if module.Anchoring then
            module.Anchoring.RefreshViewer(viewerKey)
        end
    elseif property == "showKeybinds" or property == "keybindSize" or 
           property == "keybindColor" or property == "keybindPoint" or
           property == "keybindOffsetX" or property == "keybindOffsetY" then
        if module.Keybinds then
            module.Keybinds.RefreshViewer(viewerKey)
        end
    else
        if module.LayoutEngine then
            module.LayoutEngine.RefreshViewer(viewerKey)
        end
    end
end

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
        local path = string.format("viewers.%s.rows[%d].%s", viewerKey, rowIndex, getPath)
        if optionType == "color" then
            local color = module:GetSetting(path, defaultValue)
            if color and type(color) == "table" then
                return color.r or 0, color.g or 0, color.b or 0
            end
            return 0, 0, 0
        elseif optionType == "toggle" then
            local value = module:GetSetting(path)
            if value == nil then
                return defaultValue ~= false
            end
            return value == true
        else
            return module:GetSetting(path, defaultValue)
        end
    end

    option.set = function(_, value, g, b)
        local path = string.format("viewers.%s.rows[%d].%s", viewerKey, rowIndex, setPath)

        if optionType == "color" then
            local color = module:GetSetting(path, {r = 0, g = 0, b = 0, a = 1})
            if type(color) ~= "table" then
                color = {r = 0, g = 0, b = 0, a = 1}
            end
            color.r = value
            color.g = g
            color.b = b
            module:SetSetting(path, color)
            RefreshViewerComponents(viewerKey, setPath)
        else
            module:SetSetting(path, value, {
                type = optionType == "range" and "number" or nil,
                min = optionType == "range" and min or nil,
                max = optionType == "range" and max or nil,
            })
            RefreshViewerComponents(viewerKey, setPath)
        end
    end

    if disabled then
        option.disabled = function()
            local path = string.format("viewers.%s.rows[%d]", viewerKey, rowIndex)
            local row = module:GetSetting(path)
            return disabled(row)
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

    args.keepRowHeightWhenEmpty = MakeRowOption(viewerKey, rowIndex, "keepRowHeightWhenEmpty", "toggle", {
        order = order, name = "Keep Row Height When Empty", desc = "Maintain row height even when no spells are visible",
        default = true
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
            local path = string.format("viewers.%s.rows", viewerKey)
            local rows = module:GetSetting(path, {})
            if type(rows) == "table" and rowIndex > 1 and rows[rowIndex] and rows[rowIndex - 1] then
                rows[rowIndex], rows[rowIndex - 1] = rows[rowIndex - 1], rows[rowIndex]
                module:SetSetting(path, rows)
                RefreshViewerComponents(viewerKey, "rows")
                RefreshOptions(true)
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
            local path = string.format("viewers.%s.rows", viewerKey)
            local rows = module:GetSetting(path, {})
            if type(rows) ~= "table" then return true end
            return rowIndex >= #rows
        end,
        func = function()
            local path = string.format("viewers.%s.rows", viewerKey)
            local rows = module:GetSetting(path, {})
            if type(rows) == "table" and rowIndex < #rows and rows[rowIndex] and rows[rowIndex + 1] then
                rows[rowIndex], rows[rowIndex + 1] = rows[rowIndex + 1], rows[rowIndex]
                module:SetSetting(path, rows)
                RefreshViewerComponents(viewerKey, "rows")
                RefreshOptions(true)
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
            local path = string.format("viewers.%s.rows", viewerKey)
            local rows = module:GetSetting(path, {})
            if type(rows) == "table" and rows[rowIndex] then
                table.remove(rows, rowIndex)
                module:SetSetting(path, rows)
                RefreshViewerComponents(viewerKey, "rows")
                RefreshOptions(true)
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
            local viewerPath = string.format("viewers.%s", viewerKey)
            local viewer = module:GetSetting(viewerPath, {})
            local anchorConfig = module:GetSetting(viewerPath .. ".anchorConfig", {})
            
            if anchorConfig.target and anchorConfig.target ~= "UIParent" then
                local category = GetCategoryForAnchor(anchorConfig.target)
                if category then
                    local anchorCategory = module:GetSetting(viewerPath .. ".anchorCategory")
                    if not anchorCategory then
                        module:SetSetting(viewerPath .. ".anchorCategory", category)
                    end
                    return category
                end
                return "misc"
            end
            return module:GetSetting(viewerPath .. ".anchorCategory", "None")
        end,
        set = function(_, value)
            local viewerPath = string.format("viewers.%s", viewerKey)
            local anchorConfigPath = viewerPath .. ".anchorConfig"
            
            local anchorConfig = module:GetSetting(anchorConfigPath, {
                target = nil,
                point = "CENTER",
                relativePoint = "CENTER",
                offsetX = 0,
                offsetY = 0,
            })
            
            if value == "None" or not value then
                anchorConfig.target = nil
                module:SetSetting(anchorConfigPath, anchorConfig)
                module:SetSetting(viewerPath .. ".anchorCategory", nil)
            else
                module:SetSetting(viewerPath .. ".anchorCategory", value)
                if anchorConfig.target then
                    local currentCategory = GetCategoryForAnchor(anchorConfig.target)
                    if currentCategory ~= value then
                        anchorConfig.target = nil
                        module:SetSetting(anchorConfigPath, anchorConfig)
                    end
                end
            end
            
            RefreshViewerComponents(viewerKey, "anchorCategory")
        end,
    }
    order = order + 1

    args.anchorTarget = {
        type = "select",
        name = "Anchor Target",
        desc = "Frame to anchor to",
        order = order,
        disabled = function()
            local viewerPath = string.format("viewers.%s", viewerKey)
            local category = module:GetSetting(viewerPath .. ".anchorCategory")
            if not category or category == "None" then
                local anchorConfig = module:GetSetting(viewerPath .. ".anchorConfig", {})
                if anchorConfig.target and anchorConfig.target ~= "UIParent" then
                    category = GetCategoryForAnchor(anchorConfig.target)
                    if category then
                        module:SetSetting(viewerPath .. ".anchorCategory", category)
                        return false
                    end
                end
                return true
            end
            return false
        end,
        values = function()
            local values = {}
            local viewerPath = string.format("viewers.%s", viewerKey)
            local selectedCategory = module:GetSetting(viewerPath .. ".anchorCategory")

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
            local anchorConfig = module:GetSetting(string.format("viewers.%s.anchorConfig", viewerKey), {})
            if anchorConfig.target and anchorConfig.target ~= "UIParent" then
                return anchorConfig.target
            end
            return nil
        end,
        set = function(_, value)
            local viewerPath = string.format("viewers.%s", viewerKey)
            local anchorConfigPath = viewerPath .. ".anchorConfig"
            
            local anchorConfig = module:GetSetting(anchorConfigPath, {
                target = nil,
                point = "CENTER",
                relativePoint = "CENTER",
                offsetX = 0,
                offsetY = 0,
            })

            if not value then
                anchorConfig.target = nil
                module:SetSetting(anchorConfigPath, anchorConfig)
            else
                anchorConfig.target = value
                module:SetSetting(anchorConfigPath, anchorConfig)

                local category = GetCategoryForAnchor(value)
                if category then
                    module:SetSetting(viewerPath .. ".anchorCategory", category)
                end
            end
            
            RefreshViewerComponents(viewerKey, "anchorConfig")
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
            local anchorConfig = module:GetSetting(string.format("viewers.%s.anchorConfig", viewerKey), {})
            return not (anchorConfig.target ~= nil)
        end,
        get = function()
            return module:GetSetting(string.format("viewers.%s.anchorConfig.point", viewerKey), "CENTER")
        end,
        set = function(_, value)
            local path = string.format("viewers.%s.anchorConfig.point", viewerKey)
            module:SetSetting(path, value)
            RefreshViewerComponents(viewerKey, "anchorConfig.point")
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
            local anchorConfig = module:GetSetting(string.format("viewers.%s.anchorConfig", viewerKey), {})
            return not (anchorConfig.target ~= nil)
        end,
        get = function()
            return module:GetSetting(string.format("viewers.%s.anchorConfig.relativePoint", viewerKey), "CENTER")
        end,
        set = function(_, value)
            local path = string.format("viewers.%s.anchorConfig.relativePoint", viewerKey)
            module:SetSetting(path, value)
            RefreshViewerComponents(viewerKey, "anchorConfig.relativePoint")
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
            local anchorConfig = module:GetSetting(string.format("viewers.%s.anchorConfig", viewerKey), {})
            return not (anchorConfig.target ~= nil)
        end,
        get = function()
            return module:GetSetting(string.format("viewers.%s.anchorConfig.offsetX", viewerKey), 0)
        end,
        set = function(_, value)
            local path = string.format("viewers.%s.anchorConfig.offsetX", viewerKey)
            module:SetSetting(path, value, {
                type = "number",
                min = -500,
                max = 500,
            })
            RefreshViewerComponents(viewerKey, "anchorConfig.offsetX")
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
            local anchorConfig = module:GetSetting(string.format("viewers.%s.anchorConfig", viewerKey), {})
            return not (anchorConfig.target ~= nil)
        end,
        get = function()
            return module:GetSetting(string.format("viewers.%s.anchorConfig.offsetY", viewerKey), 0)
        end,
        set = function(_, value)
            local path = string.format("viewers.%s.anchorConfig.offsetY", viewerKey)
            module:SetSetting(path, value, {
                type = "number",
                min = -500,
                max = 500,
            })
            RefreshViewerComponents(viewerKey, "anchorConfig.offsetY")
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
            return module:GetSetting(string.format("viewers.%s.enabled", viewerKey), true) ~= false
        end,
        set = function(_, value)
            local path = string.format("viewers.%s.enabled", viewerKey)
            module:SetSetting(path, value)
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
            return module:GetSetting(string.format("viewers.%s.rowGrowDirection", viewerKey), "down")
        end,
        set = function(_, value)
            local path = string.format("viewers.%s.rowGrowDirection", viewerKey)
            module:SetSetting(path, value)
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
            return module:GetSetting(string.format("viewers.%s.showKeybinds", viewerKey), false) == true
        end,
        set = function(_, value)
            local path = string.format("viewers.%s.showKeybinds", viewerKey)
            module:SetSetting(path, value)
            RefreshViewerComponents(viewerKey, "showKeybinds")
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
            return not module:GetSetting(string.format("viewers.%s.showKeybinds", viewerKey), false)
        end,
        get = function()
            return module:GetSetting(string.format("viewers.%s.keybindSize", viewerKey), 10)
        end,
        set = function(_, value)
            local path = string.format("viewers.%s.keybindSize", viewerKey)
            module:SetSetting(path, value, {
                type = "number",
                min = 6,
                max = 24,
            })
            RefreshViewerComponents(viewerKey, "keybindSize")
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
            return not module:GetSetting(string.format("viewers.%s.showKeybinds", viewerKey), false)
        end,
        get = function()
            return module:GetSetting(string.format("viewers.%s.keybindPoint", viewerKey), "TOPLEFT")
        end,
        set = function(_, value)
            local path = string.format("viewers.%s.keybindPoint", viewerKey)
            module:SetSetting(path, value)
            RefreshViewerComponents(viewerKey, "keybindPoint")
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
            return not module:GetSetting(string.format("viewers.%s.showKeybinds", viewerKey), false)
        end,
        get = function()
            return module:GetSetting(string.format("viewers.%s.keybindOffsetX", viewerKey), 2)
        end,
        set = function(_, value)
            local path = string.format("viewers.%s.keybindOffsetX", viewerKey)
            module:SetSetting(path, value, {
                type = "number",
                min = -50,
                max = 50,
            })
            RefreshViewerComponents(viewerKey, "keybindOffsetX")
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
            return not module:GetSetting(string.format("viewers.%s.showKeybinds", viewerKey), false)
        end,
        get = function()
            return module:GetSetting(string.format("viewers.%s.keybindOffsetY", viewerKey), -2)
        end,
        set = function(_, value)
            local path = string.format("viewers.%s.keybindOffsetY", viewerKey)
            module:SetSetting(path, value, {
                type = "number",
                min = -50,
                max = 50,
            })
            RefreshViewerComponents(viewerKey, "keybindOffsetY")
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
            return not module:GetSetting(string.format("viewers.%s.showKeybinds", viewerKey), false)
        end,
        get = function()
            local color = module:GetSetting(string.format("viewers.%s.keybindColor", viewerKey), {r = 1, g = 1, b = 1, a = 1})
            return color.r or 1, color.g or 1, color.b or 1, color.a or 1
        end,
        set = function(_, r, g, b, a)
            local path = string.format("viewers.%s.keybindColor", viewerKey)
            module:SetSetting(path, {r = r, g = g, b = b, a = a})
            RefreshViewerComponents(viewerKey, "keybindColor")
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
            local path = string.format("viewers.%s.rows", viewerKey)
            local rows = module:GetSetting(path, {})
            if type(rows) ~= "table" then
                rows = {}
            end

            local defaultIconCount = viewerKey == "essential" and 4 or 6
            local defaultIconSize = viewerKey == "essential" and 50 or 42

            table.insert(rows, {
                name = "Row " .. (#rows + 1),
                iconCount = defaultIconCount,
                iconSize = defaultIconSize,
                padding = -8,
                yOffset = 0,
                keepRowHeightWhenEmpty = true,
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

            module:SetSetting(path, rows)
            RefreshViewerComponents(viewerKey, "rows")
            RefreshOptions(true)
        end,
    }
    order = order + 1

    local path = string.format("viewers.%s.rows", viewerKey)
    local rows = module:GetSetting(path, {})
    if type(rows) ~= "table" then
        rows = {}
    end
    
    if #rows == 0 then
        local defaultIconCount = viewerKey == "essential" and 4 or 6
        local defaultIconSize = viewerKey == "essential" and 50 or 42
        table.insert(rows, {
            name = "Default",
            iconCount = defaultIconCount,
            iconSize = defaultIconSize,
            padding = -8,
            yOffset = 0,
            keepRowHeightWhenEmpty = true,
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
        module:SetSetting(path, rows)
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
        scaleHeader = {
            type = "header",
            name = "Display",
            order = 0,
        },
        scaleFactor = {
            type = "range",
            name = "Scale",
            desc = "Overall scale factor for all cooldown viewers",
            order = 1,
            min = 0.5,
            max = 2.0,
            step = 0.05,
            get = function()
                return module:GetSetting("general.scaleFactor", 1)
            end,
            set = function(_, value)
                module:SetSetting("general.scaleFactor", value, {
                    type = "number",
                    min = 0.5,
                    max = 2.0,
                })
                for _, viewerKey in ipairs(module.CONSTANTS.VIEWER_KEYS) do
                    if viewerKey ~= "custom" and module.LayoutEngine then
                        module.LayoutEngine.RefreshViewer(viewerKey)
                    end
                end
            end,
        },
        debugHeader = {
            type = "header",
            name = "Debug",
            order = 2,
        },
        debug = {
            type = "toggle",
            name = "Debug Mode",
            desc = "Enable debug messages",
            order = 3,
            get = function()
                return module:GetSetting("general.debug", false) == true
            end,
            set = function(_, value)
                module:SetSetting("general.debug", value)
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
                return module:GetSetting("general.updateRates.normal", 0.1)
            end,
            set = function(_, value)
                module:SetSetting("general.updateRates.normal", value, {
                    type = "number",
                    min = 0.05,
                    max = 1.0,
                })
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
                return module:GetSetting("general.updateRates.combat", 0.3)
            end,
            set = function(_, value)
                module:SetSetting("general.updateRates.combat", value, {
                    type = "number",
                    min = 0.1,
                    max = 2.0,
                })
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
                return module:GetSetting("general.updateRates.initial", 0.05)
            end,
            set = function(_, value)
                module:SetSetting("general.updateRates.initial", value, {
                    type = "number",
                    min = 0.01,
                    max = 0.2
                })
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
                        local defaultViewer = module:GetSetting("defaultCustomViewer", "essential")
                        local trackingType = module.CONSTANTS.TRACKING_TYPE.SPELL
                        local entryID = module:GenerateItemID(trackingType, spellID)
                        local index = module:GetNextIndex(defaultViewer)
                        
                        local config = {
                            id = entryID,
                            spellID = spellID,
                            viewer = defaultViewer,
                            enabled = true,
                        }
                        
                        local entryConfig = {
                            id = entryID,
                            spellID = spellID,
                            viewer = defaultViewer,
                            index = index,
                            enabled = true,
                            config = config,
                        }
                        
                        local customEntries = module:GetSetting("customEntries", {})
                        table.insert(customEntries, entryConfig)
                        module:SetSetting("customEntries", customEntries)
                        
                        local entry = module.ItemRegistry.CreateCustomItem(config)
                        if entry then
                            local viewerKey = defaultViewer
                            if module.LayoutEngine then
                                module.LayoutEngine.RefreshViewer(viewerKey)
                            end
                            if module.LayoutEngine then
                                module.LayoutEngine.RefreshViewer(viewerKey)
                            end
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
                        local defaultViewer = module:GetSetting("defaultCustomViewer", "essential")
                        local trackingType = module.CONSTANTS.TRACKING_TYPE.ITEM
                        local entryID = module:GenerateItemID(trackingType, itemID)
                        local index = module:GetNextIndex(defaultViewer)
                        
                        local config = {
                            id = entryID,
                            itemID = itemID,
                            viewer = defaultViewer,
                            enabled = true,
                        }
                        
                        local entryConfig = {
                            id = entryID,
                            itemID = itemID,
                            viewer = defaultViewer,
                            index = index,
                            enabled = true,
                            config = config,
                        }
                        
                        local customEntries = module:GetSetting("customEntries", {})
                        table.insert(customEntries, entryConfig)
                        module:SetSetting("customEntries", customEntries)
                        
                        local entry = module.ItemRegistry.CreateCustomItem(config)
                        if entry then
                            local viewerKey = defaultViewer
                            if module.LayoutEngine then
                                module.LayoutEngine.RefreshViewer(viewerKey)
                            end
                            if module.LayoutEngine then
                                module.LayoutEngine.RefreshViewer(viewerKey)
                            end
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
                    local defaultViewer = module:GetSetting("defaultCustomViewer", "custom")
                    if defaultViewer == "custom" then
                        defaultViewer = "essential"
                    end
                    local trackingType = module.CONSTANTS.TRACKING_TYPE.TRINKET
                    local entryID = module:GenerateItemID(trackingType, slotID)
                    local index = module:GetNextIndex(defaultViewer)
                    
                    local config = {
                        id = entryID,
                        slotID = slotID,
                        viewer = defaultViewer,
                        enabled = true,
                    }
                    
                    local entryConfig = {
                        id = entryID,
                        slotID = slotID,
                        viewer = defaultViewer,
                        index = index,
                        enabled = true,
                        config = config,
                    }
                    
                    local customEntries = module:GetSetting("customEntries", {})
                    table.insert(customEntries, entryConfig)
                    module:SetSetting("customEntries", customEntries)
                    
                    local entry = module.ItemRegistry.CreateCustomItem(config)
                    if entry then
                        local viewerKey = defaultViewer
                        if module.LayoutEngine then
                            module.LayoutEngine.RefreshViewer(viewerKey)
                        end
                        if module.LayoutEngine then
                            module.LayoutEngine.RefreshViewer(viewerKey)
                        end
                        RefreshOptions(true)
                    end
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
                return module:GetSetting("defaultCustomViewer", "essential")
            end,
            set = function(_, value)
                module:SetSetting("defaultCustomViewer", value)
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
            custom = {
                type = "group",
                name = "Custom Items",
                order = 4,
                args = {},
            },
        },
    }
    
    local customTabOptions = BuildCustomTabOptions()
    for k, v in pairs(customTabOptions) do
        options.args.custom.args[k] = v
    end
    
    for _, viewerKey in ipairs({"essential", "utility", "buff"}) do
        local viewerName = viewerKey == "essential" and "Essential" or
                          viewerKey == "utility" and "Utility" or
                          viewerKey == "buff" and "Buff"
        
        options.args[viewerKey].args = BuildViewerOptions(viewerKey, viewerName, 1)

        local customEntries = module:GetSetting("customEntries", {})
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
                                local entry = module.ItemRegistry.GetItem(entryConfig.id)
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
                                if module:IsEnabled() then
                                    local assignedViewer = entryConfig.viewer or "essential"
                                    if module.LayoutEngine then
                                        module.LayoutEngine.RefreshViewer(assignedViewer)
                                    end
                                    if assignedViewer ~= viewerKey then
                                        if module.LayoutEngine then
                                            module.LayoutEngine.RefreshViewer(viewerKey)
                                        end
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
                                local entries = module.ItemRegistry.GetItemsForViewer(assignedViewer)
                                for i, e in ipairs(entries) do
                                    if e.id == entryConfig.id then
                                        return i
                                    end
                                end
                                return entryConfig.index or 1
                            end,
                            set = function(_, value)
                                if not module.ItemRegistry.ReorderItem then
                                    return
                                end
                                
                                local assignedViewer = entryConfig.viewer or viewerKey
                                local allEntries = module.ItemRegistry.GetItemsForViewer(assignedViewer)
                                local maxIndex = #allEntries
                                
                                if value < 1 then
                                    value = 1
                                elseif value > maxIndex then
                                    value = maxIndex
                                end
                                
                                local success = module.ItemRegistry.ReorderItem(entryConfig.id, value)
                                
                                if success then
                                    local customEntries = module:GetSetting("customEntries", {})
                                    if customEntries and #customEntries > 0 then
                                        local updatedEntries = module.ItemRegistry.GetItemsForViewer(assignedViewer)
                                        for _, entry in ipairs(updatedEntries) do
                                            if entry.source == "custom" then
                                                for _, cfg in ipairs(customEntries) do
                                                    if cfg.id == entry.id then
                                                        cfg.index = entry.index
                                                        break
                                                    end
                                                end
                                            end
                                        end
                                        module:SetSetting("customEntries", customEntries)
                                    end
                                    
                                    if module:IsEnabled() and module.LayoutEngine then
                                        module.LayoutEngine.RefreshViewer(assignedViewer)
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
                                
                                local entry = module.ItemRegistry.GetItem(entryConfig.id)
                                if not entry then
                                    module:LogError("Entry not found when changing viewer")
                                    return
                                end
                                
                                local oldViewer = entryConfig.viewer or module.ItemRegistry.GetItemSource(entry) or viewerKey
                                if oldViewer == "custom" then
                                    oldViewer = "essential"
                                end
                                
                                local sources = { entry.viewerKey } or {entry.viewerKey}
                                local wasInViewer = false
                                for _, source in ipairs(sources) do
                                    if source == value then
                                        wasInViewer = true
                                        break
                                    end
                                end
                                
                                if not wasInViewer then
                                    if module.ItemRegistry.MoveItemToViewer then
                                        module.ItemRegistry.MoveItemToViewer(entryConfig.id, value)
                                    end
                                end
                                
                                entryConfig.viewer = value
                                
                                if module.LayoutEngine then
                                    if not wasInViewer then
                                        module.LayoutEngine.RefreshViewer(oldViewer)
                                    end
                                    module.LayoutEngine.RefreshViewer(value)
                                end
                                
                                RefreshOptions(true)
                            end,
                        },
                        remove = {
                            type = "execute",
                            name = "Remove",
                            order = 6,
                            func = function()
                                module.ItemRegistry.RemoveCustomItem(entryConfig.id)
                                RefreshOptions(true)
                            end,
                        },
                    },
                }
            end
        end
    end
    
    local customEntries = module:GetSetting("customEntries", {})
    for entryIndex, entryConfig in ipairs(customEntries) do
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

        local entryViewer = entryConfig.viewer or "essential"
        if entryViewer == "custom" then
            entryViewer = "essential"
        end

        options.args.custom.args["entry" .. entryIndex] = {
            type = "group",
            name = entryName .. " (" .. (entryViewer == "essential" and "Essential" or "Utility") .. ")",
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
                        local entry = module.ItemRegistry.GetItem(entryConfig.id)
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
                        if module:IsEnabled() then
                            local assignedViewer = entryConfig.viewer or "essential"
                            if module.LayoutEngine then
                                module.LayoutEngine.RefreshViewer(assignedViewer)
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
                        local assignedViewer = entryConfig.viewer or "essential"
                        local entries = module.ItemRegistry.GetItemsForViewer(assignedViewer)
                        for i, e in ipairs(entries) do
                            if e.id == entryConfig.id then
                                return i
                            end
                        end
                        return entryConfig.index or 1
                    end,
                    set = function(_, value)
                        if not module.ItemRegistry.ReorderItem then
                            return
                        end
                        
                        local assignedViewer = entryConfig.viewer or "essential"
                        local allEntries = module.ItemRegistry.GetItemsForViewer(assignedViewer)
                        local maxIndex = #allEntries
                        
                        if value < 1 then
                            value = 1
                        elseif value > maxIndex then
                            value = maxIndex
                        end
                        
                        local success = module.ItemRegistry.ReorderItem(entryConfig.id, value)
                        
                        if success then
                            local customEntries = module:GetSetting("customEntries", {})
                            if customEntries and #customEntries > 0 then
                                local updatedEntries = module.ItemRegistry.GetItemsForViewer(assignedViewer)
                                for _, entry in ipairs(updatedEntries) do
                                    if entry.source == "custom" then
                                        for _, cfg in ipairs(customEntries) do
                                            if cfg.id == entry.id then
                                                cfg.index = entry.index
                                                break
                                            end
                                        end
                                    end
                                end
                                module:SetSetting("customEntries", customEntries)
                            end
                            
                            if module:IsEnabled() and module.LayoutEngine then
                                module.LayoutEngine.RefreshViewer(assignedViewer)
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
                        
                        local entry = module.ItemRegistry.GetItem(entryConfig.id)
                        if not entry then
                            module:LogError("Entry not found when changing viewer")
                            return
                        end
                        
                        local oldViewer = entryConfig.viewer or module.ItemRegistry.GetItemSource(entry) or "essential"
                        if oldViewer == "custom" then
                            oldViewer = "essential"
                        end
                        
                        local sources = { entry.viewerKey } or {entry.viewerKey}
                        local wasInViewer = false
                        for _, source in ipairs(sources) do
                            if source == value then
                                wasInViewer = true
                                break
                            end
                        end
                        
                        if not wasInViewer then
                            if module.ItemRegistry.MoveItemToViewer then
                                module.ItemRegistry.MoveItemToViewer(entryConfig.id, value)
                            end
                        end
                        
                        entryConfig.viewer = value
                        
                        if module.LayoutEngine then
                            if not wasInViewer then
                                module.LayoutEngine.RefreshViewer(oldViewer)
                            end
                            module.LayoutEngine.RefreshViewer(value)
                        end
                        
                        RefreshOptions(true)
                    end,
                },
                remove = {
                    type = "execute",
                    name = "Remove",
                    order = 6,
                    func = function()
                        module.ItemRegistry.RemoveCustomItem(entryConfig.id)
                        RefreshOptions(true)
                    end,
                },
            },
        }
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
