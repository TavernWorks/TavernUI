local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local L = LibStub("AceLocale-3.0"):GetLocale("TavernUI", true)
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local DEFAULT_ICON_BORDER_COLOR = {r = 0, g = 0, b = 0, a = 1}
local DEFAULT_ROW_BORDER_COLOR = {r = 0, g = 0, b = 0, a = 1}

local DEFAULT_ICON_COUNT_ESSENTIAL = 4
local DEFAULT_ICON_COUNT_UTILITY = 6
local DEFAULT_ICON_SIZE_ESSENTIAL = 50
local DEFAULT_ICON_SIZE_UTILITY = 42
local DEFAULT_PADDING = 4
local DEFAULT_ASPECT_RATIO_CROP = 1.0
local DEFAULT_ZOOM = 0
local DEFAULT_ICON_STYLE = "square"
local DEFAULT_ICON_BORDER_SIZE = 1
local DEFAULT_ROW_BORDER_SIZE = 0
local DEFAULT_DURATION_SIZE = 18
local DEFAULT_STACK_SIZE = 16
local DEFAULT_DURATION_POINT = "CENTER"
local DEFAULT_STACK_POINT = "BOTTOMRIGHT"

local function GetViewerPath(viewerKey)
    return string.format("viewers.%s", viewerKey)
end

local function GetRowsPath(viewerKey)
    return string.format("viewers.%s.rows", viewerKey)
end

local function GetRowPath(viewerKey, rowIndex)
    return string.format("viewers.%s.rows[%d]", viewerKey, rowIndex)
end

local function GetRowOptionPath(viewerKey, rowIndex, optionKey)
    return string.format("viewers.%s.rows[%d].%s", viewerKey, rowIndex, optionKey)
end

local function GetAnchorConfigPath(viewerKey)
    return string.format("viewers.%s.anchorConfig", viewerKey)
end

local function CreateDefaultRow(viewerKey, rowNumber)
    local defaultIconCount = viewerKey == "essential" and DEFAULT_ICON_COUNT_ESSENTIAL or DEFAULT_ICON_COUNT_UTILITY
    local defaultIconSize = viewerKey == "essential" and DEFAULT_ICON_SIZE_ESSENTIAL or DEFAULT_ICON_SIZE_UTILITY
    
    return {
        name = rowNumber and string.format(L["ROW_N"], rowNumber) or L["DEFAULT"],
        iconCount = defaultIconCount,
        iconSize = defaultIconSize,
        padding = DEFAULT_PADDING,
        yOffset = 0,
        keepRowHeightWhenEmpty = true,
        aspectRatioCrop = DEFAULT_ASPECT_RATIO_CROP,
        zoom = DEFAULT_ZOOM,
        iconStyle = DEFAULT_ICON_STYLE,
        iconBorderSize = DEFAULT_ICON_BORDER_SIZE,
        iconBorderColor = DEFAULT_ICON_BORDER_COLOR,
        rowBorderSize = DEFAULT_ROW_BORDER_SIZE,
        rowBorderColor = DEFAULT_ROW_BORDER_COLOR,
        durationSize = DEFAULT_DURATION_SIZE,
        durationPoint = DEFAULT_DURATION_POINT,
        durationOffsetX = 0,
        durationOffsetY = 0,
        stackSize = DEFAULT_STACK_SIZE,
        stackPoint = DEFAULT_STACK_POINT,
        stackOffsetX = 0,
        stackOffsetY = 0,
    }
end

local function CopyRowWithColorFix(sourceRow)
    local newRow = {}
    for k, v in pairs(sourceRow) do
        if k == "iconBorderColor" or k == "rowBorderColor" then
            newRow[k] = v and {
                r = v.r or 0,
                g = v.g or (k == "iconBorderColor" and 1 or 0),
                b = v.b or 0,
                a = v.a or 1
            } or (k == "iconBorderColor" and DEFAULT_ICON_BORDER_COLOR or DEFAULT_ROW_BORDER_COLOR)
        else
            newRow[k] = v
        end
    end
    return newRow
end

local function RefreshViewerComponents(viewerKey, property)
    if not module:IsEnabled() then return end

    local layoutProperties = {
        iconCount = true,
        orientation = true,
        padding = true,
        rowSpacing = true,
        yOffset = true,
        iconSize = true,
        aspectRatioCrop = true,
        rowBorderSize = true,
        rows = true,
        keepRowHeightWhenEmpty = true,
        scale = true,
        showPreview = true,
        previewIconCount = true,
    }
    
    if layoutProperties[property] then
        if module.RefreshViewer then
            module:RefreshViewer(viewerKey)
        elseif module.LayoutEngine then
            module.LayoutEngine.RefreshViewer(viewerKey)
        end
        if viewerKey == "buff" and (property == "showPreview" or property == "previewIconCount") and module.LayoutEngine then
            C_Timer.After(0, function()
                if module:IsEnabled() then
                    module.LayoutEngine.RefreshViewer("buff")
                end
            end)
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

local function RefreshViewerAndOptions(viewerKey)
    RefreshViewerComponents(viewerKey, "rows")
    RefreshOptions(true)
end

local function CreateCustomEntry(trackingType, id, overrideViewer, configData)
    local defaultViewer = overrideViewer or module:GetSetting("defaultCustomViewer", "essential")
    if defaultViewer == "custom" then
        defaultViewer = "essential"
    end
    
    local entryID = module:GenerateItemID(trackingType, id)
    local index = module:GetNextIndex(defaultViewer)
    
    local config = {
        id = entryID,
        viewer = defaultViewer,
        enabled = true,
    }
    
    for k, v in pairs(configData) do
        config[k] = v
    end
    
    local entryConfig = {
        id = entryID,
        viewer = defaultViewer,
        index = index,
        enabled = true,
        config = config,
    }
    
    for k, v in pairs(configData) do
        entryConfig[k] = v
    end
    
    local customEntries = module:GetSetting("customEntries", {})
    table.insert(customEntries, entryConfig)
    module:SetSetting("customEntries", customEntries)
    
    local entry = module.ItemRegistry.CreateCustomItem(config)
    if entry then
        if module.LayoutEngine then
            module.LayoutEngine.RefreshViewer(defaultViewer)
        end
        RefreshOptions(true)
        return true
    end
    return false
end

local function RefreshOptions(rebuild)
    if rebuild then
        module.optionsBuilt = false
        module:BuildOptions()
        module.optionsBuilt = true
    end
    LibStub("AceConfigRegistry-3.0"):NotifyChange("TavernUI")
end

local pickingActionSlot = false
local actionSlotPickHooksInstalled = false
local actionSlotPickedCallback = nil

local function GetActionBarButtonNames()
    local names = {}
    local prefixes = {
        "ActionButton",
        "MultiBarBottomLeftButton",
        "MultiBarBottomRightButton",
        "MultiBarRightButton",
        "MultiBarLeftButton",
    }
    for _, prefix in ipairs(prefixes) do
        for i = 1, 12 do
            names[#names + 1] = prefix .. i
        end
    end
    for i = 1, 120 do
        names[#names + 1] = "BT4Button" .. i
    end
    return names
end

local function EnsureActionSlotPickHooks()
    if actionSlotPickHooksInstalled then return end
    actionSlotPickHooksInstalled = true
    local names = GetActionBarButtonNames()
    for _, name in ipairs(names) do
        local btn = _G[name]
        if btn and btn.HookScript and not btn.__ucdmPickHooked then
            btn:HookScript("OnClick", function(clickedBtn)
                if not pickingActionSlot or not actionSlotPickedCallback then return end
                local Keybinds = module.Keybinds
                local slot = Keybinds and Keybinds.GetActionSlotFromButton and Keybinds.GetActionSlotFromButton(clickedBtn)
                if not slot or slot < 1 or slot > 120 then return end
                pickingActionSlot = false
                actionSlotPickedCallback(slot)
            end)
            btn.__ucdmPickHooked = true
        end
    end
end

local function GetViewerSelectValues()
    local values = {
        essential = L["ESSENTIAL_VIEWER"],
        utility = L["UTILITY_VIEWER"],
    }
    for _, entry in ipairs(module:GetSetting("customViewers", {})) do
        if entry and entry.id and entry.name then
            values[entry.id] = entry.name
        end
    end
    return values
end

local function GetViewerDisplayName(_, viewerKey)
    if not viewerKey or type(viewerKey) ~= "string" or viewerKey == "" then
        return L["ESSENTIAL"]
    end
    return (viewerKey == "essential" and L["ESSENTIAL"]) or (viewerKey == "utility" and L["UTILITY"]) or (viewerKey == "buff" and L["BUFF"]) or module:GetCustomViewerDisplayName(viewerKey) or viewerKey
end
module.GetViewerDisplayName = GetViewerDisplayName

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
        local path = GetRowOptionPath(viewerKey, rowIndex, getPath)
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
        local path = GetRowOptionPath(viewerKey, rowIndex, setPath)

        -- Special-case row name so the left-hand row list updates immediately.
        if optionType == "input" and optionKey == "name" then
            local str = tostring(value or "")
            local trimmed = str:match("^%s*(.-)%s*$") or str
            module:SetSetting(path, trimmed)
            RefreshOptions(true)
            return
        end

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
            local path = GetRowPath(viewerKey, rowIndex)
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
        order = order, name = L["ROW_NAME"], desc = L["OPTIONAL_ROW_NAME_DESC"],
        default = ""
    })
    order = order + 1

    args.iconCount = MakeRowOption(viewerKey, rowIndex, "iconCount", "range", {
        order = order, name = L["ICON_COUNT"], desc = L["NUMBER_OF_ICONS_DESC"],
        min = 1, max = 12, step = 1, default = viewerKey == "essential" and DEFAULT_ICON_COUNT_ESSENTIAL or DEFAULT_ICON_COUNT_UTILITY
    })
    order = order + 1

    local isCustomViewer = module.IsCustomViewerId and module:IsCustomViewerId(viewerKey)
    if isCustomViewer then
        args.orientation = MakeRowOption(viewerKey, rowIndex, "orientation", "select", {
            order = order,
            name = L["ROW_ORIENTATION"],
            desc = L["ROW_ORIENTATION_DESC"],
            values = {
                horizontal = L["HORIZONTAL"],
                vertical = L["VERTICAL"],
            },
            default = "horizontal",
        })
        order = order + 1

        args.positionAtSide = MakeRowOption(viewerKey, rowIndex, "positionAtSide", "toggle", {
            order = order,
            name = L["POSITION_AT_SIDE"],
            desc = L["POSITION_AT_SIDE_DESC"],
            default = false,
        })
        order = order + 1
    end

    args.iconSize = MakeRowOption(viewerKey, rowIndex, "iconSize", "range", {
        order = order, name = L["ICON_SIZE"], desc = L["SIZE_OF_ICONS_DESC"],
        min = 20, max = 100, step = 1, default = viewerKey == "essential" and DEFAULT_ICON_SIZE_ESSENTIAL or DEFAULT_ICON_SIZE_UTILITY
    })
    order = order + 1

    args.padding = MakeRowOption(viewerKey, rowIndex, "padding", "range", {
        order = order, name = L["PADDING"], desc = L["SPACING_BETWEEN_ICONS_DESC"],
        min = -20, max = 20, step = 1, default = DEFAULT_PADDING
    })
    order = order + 1

    args.yOffset = MakeRowOption(viewerKey, rowIndex, "yOffset", "range", {
        order = order, name = L["Y_OFFSET"], desc = L["VERTICAL_OFFSET_ROW_DESC"],
        min = -50, max = 50, step = 1, default = 0
    })
    order = order + 1

    args.keepRowHeightWhenEmpty = MakeRowOption(viewerKey, rowIndex, "keepRowHeightWhenEmpty", "toggle", {
        order = order, name = L["KEEP_ROW_HEIGHT_WHEN_EMPTY"], desc = L["KEEP_ROW_HEIGHT_WHEN_EMPTY_DESC"],
        default = true
    })
    order = order + 1

    args.stylingHeader = {type = "header", name = L["ICON_STYLING"], order = order}
    order = order + 1

    args.aspectRatioCrop = MakeRowOption(viewerKey, rowIndex, "aspectRatioCrop", "range", {
        order = order, name = L["ASPECT_RATIO_CROP"], desc = L["ASPECT_RATIO_CROP_DESC"],
        min = 1.0, max = 2.0, step = 0.01, default = DEFAULT_ASPECT_RATIO_CROP
    })
    order = order + 1

    args.zoom = MakeRowOption(viewerKey, rowIndex, "zoom", "range", {
        order = order, name = L["ZOOM"], desc = L["ZOOM_DESC"],
        min = 0, max = 0.2, step = 0.01, default = 0
    })
    order = order + 1

    args.iconStyle = MakeRowOption(viewerKey, rowIndex, "iconStyle", "select", {
        order = order,
        name = "Icon Style",
        desc = "Choose Square or Blizzard-style icons.",
        values = {
            blizzard = "Blizzard",
            square = "Square",
        },
        default = DEFAULT_ICON_STYLE,
    })
    order = order + 1

    args.iconBorderHeader = {type = "header", name = L["ICON_BORDER"], order = order}
    order = order + 1

    args.iconBorderSize = MakeRowOption(viewerKey, rowIndex, "iconBorderSize", "range", {
        order = order, name = L["ICON_BORDER_SIZE"], desc = L["SIZE_OF_ICON_BORDER_DESC"],
        min = 0, max = 5, step = 1, default = DEFAULT_ICON_BORDER_SIZE
    })
    order = order + 1

    args.iconBorderColor = MakeRowOption(viewerKey, rowIndex, "iconBorderColor", "color", {
        order = order, name = L["ICON_BORDER_COLOR"], desc = L["COLOR_OF_ICON_BORDER_DESC"],
        default = DEFAULT_ICON_BORDER_COLOR,
        disabled = function(row) return (row and row.iconBorderSize or 0) == 0 end
    })
    order = order + 1

    args.rowBorderHeader = {type = "header", name = L["ROW_BORDER"], order = order}
    order = order + 1

    args.rowBorderSize = MakeRowOption(viewerKey, rowIndex, "rowBorderSize", "range", {
        order = order, name = L["ROW_BORDER_SIZE"], desc = L["SIZE_OF_ROW_BORDER_DESC"],
        min = 0, max = 5, step = 1, default = 0
    })
    order = order + 1

    args.rowBorderColor = MakeRowOption(viewerKey, rowIndex, "rowBorderColor", "color", {
        order = order, name = L["ROW_BORDER_COLOR"], desc = L["COLOR_OF_ROW_BORDER_DESC"],
        default = {r = 0, g = 0, b = 0, a = 1},
        disabled = function(row) return (row and row.rowBorderSize or 0) == 0 end
    })
    order = order + 1

    args.textHeader = {type = "header", name = L["TEXT_SETTINGS"], order = order}
    order = order + 1

    args.durationSize = MakeRowOption(viewerKey, rowIndex, "durationSize", "range", {
        order = order, name = L["DURATION_TEXT_SIZE"], desc = L["DURATION_TEXT_SIZE_DESC"],
        min = 0, max = 96, step = 1, default = DEFAULT_DURATION_SIZE
    })
    order = order + 1

    args.durationPoint = MakeRowOption(viewerKey, rowIndex, "durationPoint", "select", {
        order = order, name = L["DURATION_TEXT_POSITION"], desc = L["ANCHOR_POINT_DURATION_DESC"],
        values = ANCHOR_POINTS, default = DEFAULT_DURATION_POINT,
        disabled = function(row) return (row and row.durationSize or DEFAULT_DURATION_SIZE) == 0 end
    })
    order = order + 1

    args.durationOffsetX = MakeRowOption(viewerKey, rowIndex, "durationOffsetX", "range", {
        order = order, name = L["DURATION_TEXT_OFFSET_X"], desc = L["HORIZONTAL_OFFSET_DURATION_DESC"],
        min = -50, max = 50, step = 1, default = 0,
        disabled = function(row) return (row and row.durationSize or DEFAULT_DURATION_SIZE) == 0 end
    })
    order = order + 1

    args.durationOffsetY = MakeRowOption(viewerKey, rowIndex, "durationOffsetY", "range", {
        order = order, name = L["DURATION_TEXT_OFFSET_Y"], desc = L["VERTICAL_OFFSET_DURATION_DESC"],
        min = -50, max = 50, step = 1, default = 0,
        disabled = function(row) return (row and row.durationSize or DEFAULT_DURATION_SIZE) == 0 end
    })
    order = order + 1

    args.stackSize = MakeRowOption(viewerKey, rowIndex, "stackSize", "range", {
        order = order, name = L["STACK_TEXT_SIZE"], desc = L["STACK_TEXT_SIZE_DESC"],
        min = 0, max = 96, step = 1, default = DEFAULT_STACK_SIZE
    })
    order = order + 1

    args.stackPoint = MakeRowOption(viewerKey, rowIndex, "stackPoint", "select", {
        order = order, name = L["STACK_TEXT_POSITION"], desc = L["ANCHOR_POINT_STACK_DESC"],
        values = ANCHOR_POINTS, default = DEFAULT_STACK_POINT,
        disabled = function(row) return (row and row.stackSize or DEFAULT_STACK_SIZE) == 0 end
    })
    order = order + 1

    args.stackOffsetX = MakeRowOption(viewerKey, rowIndex, "stackOffsetX", "range", {
        order = order, name = L["STACK_TEXT_OFFSET_X"], desc = L["HORIZONTAL_OFFSET_STACK_DESC"],
        min = -50, max = 50, step = 1, default = 0,
        disabled = function(row) return (row and row.stackSize or DEFAULT_STACK_SIZE) == 0 end
    })
    order = order + 1

    args.stackOffsetY = MakeRowOption(viewerKey, rowIndex, "stackOffsetY", "range", {
        order = order, name = L["STACK_TEXT_OFFSET_Y"], desc = L["VERTICAL_OFFSET_STACK_DESC"],
        min = -50, max = 50, step = 1, default = 0,
        disabled = function(row) return (row and row.stackSize or DEFAULT_STACK_SIZE) == 0 end
    })
    order = order + 1

    args.actionsHeader = {type = "header", name = L["ACTIONS"], order = order}
    order = order + 1

    args.moveUp = {
        type = "execute",
        name = L["MOVE_UP"],
        desc = L["MOVE_ROW_UP_DESC"],
        order = order,
        disabled = function()
            return rowIndex == 1
        end,
        func = function()
            local path = GetRowsPath(viewerKey)
            local rows = module:GetSetting(path, {})
            if type(rows) == "table" and rowIndex > 1 and rows[rowIndex] and rows[rowIndex - 1] then
                rows[rowIndex], rows[rowIndex - 1] = rows[rowIndex - 1], rows[rowIndex]
                module:SetSetting(path, rows)
                RefreshViewerAndOptions(viewerKey)
            end
        end,
    }
    order = order + 1

    args.moveDown = {
        type = "execute",
        name = L["MOVE_DOWN"],
        desc = L["MOVE_ROW_DOWN_DESC"],
        order = order,
        disabled = function()
            local path = GetRowsPath(viewerKey)
            local rows = module:GetSetting(path, {})
            if type(rows) ~= "table" then return true end
            return rowIndex >= #rows
        end,
        func = function()
            local path = GetRowsPath(viewerKey)
            local rows = module:GetSetting(path, {})
            if type(rows) == "table" and rowIndex < #rows and rows[rowIndex] and rows[rowIndex + 1] then
                rows[rowIndex], rows[rowIndex + 1] = rows[rowIndex + 1], rows[rowIndex]
                module:SetSetting(path, rows)
                RefreshViewerAndOptions(viewerKey)
            end
        end,
    }
    order = order + 1

    args.removeRow = {
        type = "execute",
        name = L["REMOVE_ROW"],
        desc = L["REMOVE_ROW_DESC"],
        order = order,
        func = function()
            local path = GetRowsPath(viewerKey)
            local rows = module:GetSetting(path, {})
            if type(rows) == "table" and rows[rowIndex] then
                table.remove(rows, rowIndex)
                module:SetSetting(path, rows)
                RefreshViewerAndOptions(viewerKey)
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

    args.anchoringHeader = {type = "header", name = L["Anchoring"], order = order}
    order = order + 1

    args.anchorCategory = {
        type = "select",
        name = L["CATEGORY"],
        desc = L["CATEGORY_OF_ANCHOR_DESC"],
        order = order,
        values = function()
            local values = {
                None = L["NONE_NO_ANCHORING"],
            }

            local categoryDisplayNames = {
                screen = L["SCREEN"],
                actionbars = L["ACTION_BARS"],
                bars = L["BARS"],
                cooldowns = L["COOLDOWNS"],
                cdm = L["CDM"],
                ucdm = L["UCDM_CATEGORY"],
                unitframes = L["UNIT_FRAMES"],
                TavernUI = L["TAVERN_UI_CATEGORY"],
                blizzard = L["BLIZZARD"],
                misc = L["MISC"],
            }

            local categories = GetAvailableCategories()
            for _, cat in ipairs(categories) do
                local displayName = categoryDisplayNames[cat] or cat:gsub("^%l", string.upper)
                values[cat] = displayName
            end

            return values
        end,
        get = function()
            local viewerPath = GetViewerPath(viewerKey)
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
            local viewerPath = GetViewerPath(viewerKey)
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
        name = L["ANCHOR_TARGET"],
        desc = L["FRAME_TO_ANCHOR_DESC"],
        order = order,
        disabled = function()
            local viewerPath = GetViewerPath(viewerKey)
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
            local viewerPath = GetViewerPath(viewerKey)
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
            local anchorConfig = module:GetSetting(GetAnchorConfigPath(viewerKey), {})
            if anchorConfig.target and anchorConfig.target ~= "UIParent" then
                return anchorConfig.target
            end
            return nil
        end,
        set = function(_, value)
            local viewerPath = GetViewerPath(viewerKey)
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
        name = L["POINT"],
        desc = L["ANCHOR_POINT_ON_VIEWER_DESC"],
        order = order,
        values = ANCHOR_POINTS,
        disabled = function()
            local anchorConfig = module:GetSetting(GetAnchorConfigPath(viewerKey), {})
            return not (anchorConfig.target ~= nil)
        end,
        get = function()
            return module:GetSetting(GetAnchorConfigPath(viewerKey) .. ".point", "CENTER")
        end,
        set = function(_, value)
            local path = GetAnchorConfigPath(viewerKey) .. ".point"
            module:SetSetting(path, value)
            RefreshViewerComponents(viewerKey, "anchorConfig.point")
        end,
    }
    order = order + 1

    args.anchorRelativePoint = {
        type = "select",
        name = L["RELATIVE_POINT"],
        desc = L["ANCHOR_POINT_ON_TARGET_DESC"],
        order = order,
        values = ANCHOR_POINTS,
        disabled = function()
            local anchorConfig = module:GetSetting(GetAnchorConfigPath(viewerKey), {})
            return not (anchorConfig.target ~= nil)
        end,
        get = function()
            return module:GetSetting(GetAnchorConfigPath(viewerKey) .. ".relativePoint", "CENTER")
        end,
        set = function(_, value)
            local path = GetAnchorConfigPath(viewerKey) .. ".relativePoint"
            module:SetSetting(path, value)
            RefreshViewerComponents(viewerKey, "anchorConfig.relativePoint")
        end,
    }
    order = order + 1

    args.anchorOffsetX = {
        type = "range",
        name = L["OFFSET_X"],
        desc = L["HORIZONTAL_OFFSET"],
        order = order,
        min = -500,
        max = 500,
        step = 1,
        disabled = function()
            local anchorConfig = module:GetSetting(GetAnchorConfigPath(viewerKey), {})
            return not (anchorConfig.target ~= nil)
        end,
        get = function()
            return module:GetSetting(GetAnchorConfigPath(viewerKey) .. ".offsetX", 0)
        end,
        set = function(_, value)
            local path = GetAnchorConfigPath(viewerKey) .. ".offsetX"
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
        name = L["OFFSET_Y"],
        desc = L["VERTICAL_OFFSET"],
        order = order,
        min = -500,
        max = 500,
        step = 1,
        disabled = function()
            local anchorConfig = module:GetSetting(GetAnchorConfigPath(viewerKey), {})
            return not (anchorConfig.target ~= nil)
        end,
        get = function()
            return module:GetSetting(GetAnchorConfigPath(viewerKey) .. ".offsetY", 0)
        end,
        set = function(_, value)
            local path = GetAnchorConfigPath(viewerKey) .. ".offsetY"
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

    if viewerKey == "buff" then
        args.note = {
            type = "description",
            name = L["BUFF_VIEWER_BLIZZARD_ONLY_DESC"],
            order = 0,
        }
    end

    args.enabled = {
        type = "toggle",
        name = L["ENABLED"],
        desc = string.format(L["ENABLE_S_COOLDOWN_VIEWER"], viewerName),
        order = order,
        get = function()
            return module:GetSetting(GetViewerPath(viewerKey) .. ".enabled", true) ~= false
        end,
        set = function(_, value)
            local path = GetViewerPath(viewerKey) .. ".enabled"
            module:SetSetting(path, value)
        end,
    }
    order = order + 1

    args.rowGrowDirection = {
        type = "select",
        name = L["ROW_GROWTH_DIRECTION"],
        desc = L["ROW_GROWTH_DIRECTION_DESC"],
        order = order,
        values = {
            down = L["DOWN"],
            up = L["UP"],
        },
        get = function()
            return module:GetSetting(GetViewerPath(viewerKey) .. ".rowGrowDirection", "down")
        end,
        set = function(_, value)
            local path = GetViewerPath(viewerKey) .. ".rowGrowDirection"
            module:SetSetting(path, value)
        end,
    }
    order = order + 1

    args.rowSpacing = {
        type = "range",
        name = L["ROW_SPACING"],
        desc = L["ROW_SPACING_DESC"],
        order = order,
        min = -20,
        max = 30,
        step = 1,
        get = function()
            return module:GetSetting(string.format("viewers.%s.rowSpacing", viewerKey), 5)
        end,
        set = function(_, value)
            local path = string.format("viewers.%s.rowSpacing", viewerKey)
            module:SetSetting(path, value, { type = "number", min = -20, max = 30 })
            RefreshViewerComponents(viewerKey, "rowSpacing")
        end,
    }
    order = order + 1

    if viewerKey == "buff" then
        args.previewHeader = { type = "header", name = L["PREVIEW"], order = order }
        order = order + 1
        args.showPreview = {
            type = "toggle",
            name = L["SHOW_PREVIEW"],
            desc = L["SHOW_PREVIEW_DESC"],
            order = order,
            get = function()
                return module:GetSetting("viewers.buff.showPreview", false) == true
            end,
            set = function(_, value)
                module:SetSetting("viewers.buff.showPreview", value)
                RefreshViewerComponents("buff", "showPreview")
            end,
        }
        order = order + 1
        args.previewIconCount = {
            type = "range",
            name = L["PREVIEW_ICON_COUNT"],
            desc = L["PREVIEW_ICON_COUNT_DESC"],
            order = order,
            min = 1,
            max = 12,
            step = 1,
            disabled = function()
                return not module:GetSetting("viewers.buff.showPreview", false)
            end,
            get = function()
                return module:GetSetting("viewers.buff.previewIconCount", 6)
            end,
            set = function(_, value)
                module:SetSetting("viewers.buff.previewIconCount", value, {
                    type = "number",
                    min = 1,
                    max = 12,
                })
                RefreshViewerComponents("buff", "previewIconCount")
            end,
        }
        order = order + 1
    end

    args.scale = {
        type = "range",
        name = L["SCALE"],
        desc = L["VIEWER_SCALE_DESC"] or "Scale the entire viewer and its contents",
        order = order,
        min = 0.5,
        max = 2.0,
        step = 0.05,
        isPercent = true,
        get = function()
            return module:GetSetting(string.format("viewers.%s.scale", viewerKey), 1.0)
        end,
        set = function(_, value)
            local path = string.format("viewers.%s.scale", viewerKey)
            module:SetSetting(path, value, { type = "number", min = 0.5, max = 2.0 })
            RefreshViewerComponents(viewerKey, "scale")
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

    args.keybindHeader = {type = "header", name = L["KEYBIND_DISPLAY"], order = order}
    order = order + 1

    args.showKeybinds = {
        type = "toggle",
        name = L["SHOW_KEYBINDS"],
        desc = L["SHOW_KEYBINDS_DESC"],
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
        name = L["KEYBIND_TEXT_SIZE"],
        desc = L["KEYBIND_TEXT_SIZE_DESC"],
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
        name = L["KEYBIND_POSITION"],
        desc = L["ANCHOR_POINT_KEYBIND_DESC"],
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
        name = L["KEYBIND_OFFSET_X"],
        desc = L["HORIZONTAL_OFFSET_KEYBIND_DESC"],
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
        name = L["KEYBIND_OFFSET_Y"],
        desc = L["VERTICAL_OFFSET_KEYBIND_DESC"],
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
        name = L["KEYBIND_TEXT_COLOR"],
        desc = L["COLOR_OF_KEYBIND_DESC"],
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

    args.rowsHeader = {type = "header", name = L["Rows"], order = order}
    order = order + 1

    args.addRow = {
        type = "execute",
        name = L["ADD_ROW"],
        desc = L["ADD_NEW_ROW_DESC"],
        order = order,
        func = function()
            local path = GetRowsPath(viewerKey)
            local rows = module:GetSetting(path, {})
            if type(rows) ~= "table" then
                rows = {}
            end

            local newRow
            local previousRow = #rows > 0 and rows[#rows] or nil

            if previousRow then
                newRow = CopyRowWithColorFix(previousRow)
                newRow.name = string.format(L["ROW_N"], #rows + 1)
            else
                newRow = CreateDefaultRow(viewerKey, #rows + 1)
            end

            table.insert(rows, newRow)
            module:SetSetting(path, rows)
            RefreshViewerAndOptions(viewerKey)
        end,
    }
    order = order + 1

    local path = GetRowsPath(viewerKey)
    local rows = module:GetSetting(path, {})
    if type(rows) ~= "table" then
        rows = {}
    end
    
    if #rows == 0 then
        table.insert(rows, CreateDefaultRow(viewerKey))
        module:SetSetting(path, rows)
    end

    for rowIndex, row in ipairs(rows) do
        local storedName = row.name
        local trimmed = type(storedName) == "string" and storedName:match("^%s*(.-)%s*$") or storedName
        local rowName = (trimmed and trimmed ~= "")
            and trimmed
            or "[empty]"
        args["row" .. rowIndex] = {
            type = "group",
            name = rowName,
            order = 100 + rowIndex,
            args = BuildRowOptions(viewerKey, rowIndex, 1),
        }
    end

    return args
end

local function BuildOverlaysOptions()
    return {
        pandemicHeader = {
            type = "header",
            name = L["PANDEMIC"] or "Pandemic",
            order = 0,
        },
        pandemicEnabled = {
            type = "toggle",
            name = L["SHOW_PANDEMIC"] or "Show Pandemic",
            desc = L["SHOW_PANDEMIC_DESC"] or "Show border color when aura is in pandemic window",
            order = 1,
            get = function()
                return module:GetSetting("overlays.pandemic.enabled", true) ~= false
            end,
            set = function(_, value)
                module:SetSetting("overlays.pandemic.enabled", value)
            end,
        },
        pandemicBorderColor = {
            type = "color",
            name = L["PANDEMIC_BORDER_COLOR"] or "Border Color",
            desc = L["PANDEMIC_BORDER_COLOR_DESC"] or "Border color when aura is in pandemic window",
            order = 2,
            hasAlpha = false,
            get = function()
                local color = module:GetSetting("overlays.pandemic.borderColor", {r = 1, g = 0, b = 0, a = 1})
                if color and type(color) == "table" then
                    return color.r or 1, color.g or 0, color.b or 0
                end
                return 1, 0, 0
            end,
            set = function(_, r, g, b)
                local color = module:GetSetting("overlays.pandemic.borderColor", {r = 1, g = 0, b = 0, a = 1})
                if type(color) ~= "table" then
                    color = {r = 1, g = 0, b = 0, a = 1}
                end
                color.r = r
                color.g = g
                color.b = b
                module:SetSetting("overlays.pandemic.borderColor", color)
            end,
        },
        pandemicBorderWidth = {
            type = "range",
            name = L["PANDEMIC_BORDER_WIDTH"] or "Border Width",
            desc = L["PANDEMIC_BORDER_WIDTH_DESC"] or "Border width in pixels when aura is in pandemic window",
            order = 3,
            min = 1,
            max = 10,
            step = 1,
            get = function()
                return module:GetSetting("overlays.pandemic.borderWidth", 2)
            end,
            set = function(_, value)
                module:SetSetting("overlays.pandemic.borderWidth", value, {
                    type = "number",
                    min = 1,
                    max = 10,
                })
            end,
        },
    }
end

local function BuildGeneralOptions()
    return {
        debugHeader = {
            type = "header",
            name = L["DEBUG"],
            order = 0,
        },
        debug = {
            type = "toggle",
            name = L["DEBUG_MODE"],
            desc = L["ENABLE_DEBUG_MESSAGES"],
            order = 1,
            get = function()
                return module:GetSetting("general.debug", false) == true
            end,
            set = function(_, value)
                module:SetSetting("general.debug", value)
            end,
        },
        updateRatesHeader = {
            type = "header",
            name = L["UPDATE_RATES"],
            order = 10,
        },
        updateRateNormal = {
            type = "range",
            name = L["NORMAL_UPDATE_RATE"],
            desc = L["NORMAL_UPDATE_RATE_DESC"],
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
            name = L["COMBAT_UPDATE_RATE"],
            desc = L["COMBAT_UPDATE_RATE_DESC"],
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
            name = L["INITIAL_UPDATE_RATE"],
            desc = L["INITIAL_UPDATE_RATE_DESC"],
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

local function GetActionSlotSelectValues()
    local values = {}
    for slot = 1, 120 do
        local bar = math.ceil(slot / 12)
        local slotInBar = ((slot - 1) % 12) + 1
        values[slot] = string.format(L["ACTION_BAR_SLOT_FORMAT"], bar, slotInBar)
    end
    return values
end

local function GetActionSlotDisplayName(actionSlotID)
    if not actionSlotID or actionSlotID < 1 or actionSlotID > 120 then
        return string.format(L["ACTION_SLOT_N"], actionSlotID or 0)
    end
    local bar = math.ceil(actionSlotID / 12)
    local slotInBar = ((actionSlotID - 1) % 12) + 1
    local actionType, id, subType = GetActionInfo(actionSlotID)
    local displayName
    if actionType == "spell" and id then
        local ok, spellInfo = pcall(C_Spell.GetSpellInfo, id)
        if ok and spellInfo and spellInfo.name then
            displayName = spellInfo.name
        end
    elseif actionType == "item" and id then
        local ok, itemInfo = pcall(C_Item.GetItemInfoByID, id)
        if ok and itemInfo and itemInfo.itemName then
            displayName = itemInfo.itemName
        end
    elseif actionType == "macro" and id then
        local name = GetMacroInfo(id)
        if name and name ~= "" then
            displayName = name
        end
    end
    if displayName and displayName ~= "" then
        return string.format(L["ACTION_BAR_SLOT_WITH_NAME"], bar, slotInBar, displayName)
    end
    return string.format(L["ACTION_BAR_N_SLOT_M"], bar, slotInBar)
end

local function BuildCustomTabOptions()
    local actionSlotValues = GetActionSlotSelectValues()
    return {
        addSpell = {
            type = "input",
            name = L["ADD_SPELL"],
            desc = L["ENTER_SPELL_ID_DESC"],
            order = 1,
            get = function() return "" end,
            set = function(_, value)
                local spellID = tonumber(value)
                if spellID then
                    local ok, spellInfo = pcall(C_Spell.GetSpellInfo, spellID)
                    if ok and spellInfo then
                        if not CreateCustomEntry(module.CONSTANTS.TRACKING_TYPE.SPELL, spellID, nil, {spellID = spellID}) then
                            module:LogError("Failed to create spell entry")
                        end
                    else
                        module:LogError("Invalid spellID: spell not found")
                    end
                end
            end,
        },
        addItem = {
            type = "input",
            name = L["ADD_ITEM"],
            desc = L["ENTER_ITEM_ID_DESC"],
            order = 2,
            get = function() return "" end,
            set = function(_, value)
                local itemID = tonumber(value)
                if itemID then
                    local ok, itemInfo = pcall(C_Item.GetItemInfoByID, itemID)
                    if ok and itemInfo then
                        if not CreateCustomEntry(module.CONSTANTS.TRACKING_TYPE.ITEM, itemID, nil, {itemID = itemID}) then
                            module:LogError("Failed to create item entry")
                        end
                    else
                        module:LogError("Invalid itemID: item not found")
                    end
                end
            end,
        },
        addTrinket = {
            type = "select",
            name = L["ADD_TRINKET"],
            desc = L["SELECT_TRINKET_SLOT_DESC"],
            order = 3,
            values = {
                [13] = L["TRINKET_1"],
                [14] = L["TRINKET_2"],
            },
            get = function() return nil end,
            set = function(_, value)
                local slotID = value
                local itemID = GetInventoryItemID("player", slotID)
                if itemID then
                    if not CreateCustomEntry(module.CONSTANTS.TRACKING_TYPE.TRINKET, slotID, "custom", {slotID = slotID}) then
                        module:LogError("Failed to create trinket entry")
                    end
                else
                    module:LogError("No item equipped in slot " .. slotID)
                end
            end,
        },
        addMacro = {
            type = "select",
            name = L["ADD_MACRO"],
            desc = L["ADD_MACRO_DESC"],
            order = 4,
            values = actionSlotValues,
            get = function() return nil end,
            set = function(_, value)
                local actionSlotID = value
                if not actionSlotID or actionSlotID < 1 or actionSlotID > 120 then return end
                if not CreateCustomEntry(module.CONSTANTS.TRACKING_TYPE.ACTION, actionSlotID, nil, {actionSlotID = actionSlotID}) then
                    module:LogError("Failed to create action slot entry")
                end
            end,
        },
        pickMacro = {
            type = "execute",
            name = L["PICK_ACTION_SLOT"],
            desc = L["PICK_ACTION_SLOT_DESC"],
            order = 4.5,
            func = function()
                actionSlotPickedCallback = function(slot)
                    if CreateCustomEntry(module.CONSTANTS.TRACKING_TYPE.ACTION, slot, nil, {actionSlotID = slot}) then
                        if module and module.Print then
                            module:Print(string.format(L["ACTION_SLOT_ADDED"], slot))
                        end
                    end
                end
                pickingActionSlot = true
                EnsureActionSlotPickHooks()
                if module and module.Print then
                    module:Print(L["PICK_ACTION_SLOT_PROMPT"])
                end
            end,
        },
        viewerAssignment = {
            type = "select",
            name = L["DEFAULT_VIEWER"],
            desc = L["DEFAULT_VIEWER_DESC"],
            order = 5,
            values = GetViewerSelectValues,
            get = function()
                return module:GetSetting("defaultCustomViewer", "essential")
            end,
            set = function(_, value)
                module:SetSetting("defaultCustomViewer", value)
            end,
        },
        entriesHeader = {
            type = "header",
            name = L["CUSTOM_ENTRIES"],
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
        name = L["UCDM"],
        childGroups = "tab",
        args = {
            general = {
                type = "group",
                name = L["GENERAL"],
                order = 0,
                args = BuildGeneralOptions(),
            },
            essential = {
                type = "group",
                name = L["ESSENTIAL_COOLDOWNS"],
                order = 1,
                args = {},
            },
            utility = {
                type = "group",
                name = L["UTILITY_COOLDOWNS"],
                order = 2,
                args = {},
            },
            buff = {
                type = "group",
                name = L["BUFF_COOLDOWNS"],
                order = 3,
                args = {},
            },
            custom = {
                type = "group",
                name = L["CUSTOM_ITEMS"],
                order = 4,
                args = {},
            },
            myViewers = {
                type = "group",
                name = L["MY_VIEWERS"],
                order = 5,
                args = {},
            },
            overlays = {
                type = "group",
                name = L["OVERLAYS"] or "Overlays",
                order = 6,
                args = BuildOverlaysOptions(),
            },
        },
    }

    options.args.myViewers.args.desc = {
        type = "description",
        name = L["MY_VIEWERS_DESC"],
        order = 0,
        fontSize = "small",
    }
    options.args.myViewers.args.addViewer = {
        type = "execute",
        name = L["ADD_VIEWER"],
        order = 1,
        func = function()
            local id = "custom_" .. tostring(GetTime()):gsub("%.", "")
            module:CreateCustomViewerFrame(id, "New Viewer")
            if module:IsEnabled() and module.RefreshViewer then
                module:RefreshViewer(id)
            end
            if module.Anchoring and module.Anchoring.RegisterAnchors then
                module.Anchoring.RegisterAnchors()
            end
            RefreshOptions(true)
        end,
    }

    local customViewersList = module:GetSetting("customViewers", {})
    for idx, entry in ipairs(customViewersList) do
        if entry and entry.id then
            local viewerKey = entry.id
            local displayName = entry.name or viewerKey
            local groupKey = "viewer_" .. viewerKey:gsub("[^%w]", "_")
            options.args.myViewers.args[groupKey] = {
                type = "group",
                name = displayName,
                order = 10 + idx,
                args = {},
            }
            local viewerArgs = options.args.myViewers.args[groupKey].args
            viewerArgs.name = {
                type = "input",
                name = L["VIEWER_NAME"],
                order = 1,
                get = function()
                    return module:GetCustomViewerDisplayName(viewerKey) or ""
                end,
                set = function(_, value)
                    if value and value:match("%S") then
                        local trimmed = value:match("^%s*(.-)%s*$") or value
                        module:SetCustomViewerName(viewerKey, trimmed)
                        RefreshOptions(true)
                    end
                end,
            }
            viewerArgs.remove = {
                type = "execute",
                name = L["REMOVE_VIEWER"],
                order = 2,
                confirm = true,
                confirmText = L["REMOVE_VIEWER"],
                func = function()
                    module:RemoveCustomViewer(viewerKey)
                    RefreshOptions(true)
                end,
            }
            local layoutOpts = BuildViewerOptions(viewerKey, displayName, 10)
            for k, v in pairs(layoutOpts) do
                if k ~= "note" then
                    viewerArgs[k] = v
                end
            end
            local anchorOpts = BuildAnchorOptions(viewerKey, 50)
            for k, v in pairs(anchorOpts) do
                viewerArgs[k] = v
            end
        end
    end
    
    local customTabOptions = BuildCustomTabOptions()
    for k, v in pairs(customTabOptions) do
        options.args.custom.args[k] = v
    end
    
    for _, viewerKey in ipairs({"essential", "utility", "buff"}) do
        local viewerName = viewerKey == "essential" and L["ESSENTIAL"] or
            viewerKey == "utility" and L["UTILITY"] or
            viewerKey == "buff" and L["BUFF"]
        options.args[viewerKey].args = BuildViewerOptions(viewerKey, viewerName, 1)
    end

    local customEntries = module:GetSetting("customEntries", {})
    local entriesByViewer = {}
    for entryIndex, entryConfig in ipairs(customEntries) do
        local entryViewer = entryConfig.viewer or "essential"
        if entryViewer == "custom" then
            entryViewer = "essential"
            entryConfig.viewer = "essential"
        end
        if entryViewer ~= "buff" then
            if not entriesByViewer[entryViewer] then
                entriesByViewer[entryViewer] = {}
            end
            table.insert(entriesByViewer[entryViewer], { entryConfig = entryConfig, entryIndex = entryIndex })
        end
    end

    local viewerOrder = {}
    for _, vk in ipairs(module.CONSTANTS.VIEWER_KEYS) do
        if vk and (vk == "essential" or vk == "utility" or (vk ~= "buff" and vk ~= "custom" and entriesByViewer[vk])) then
            table.insert(viewerOrder, vk)
        end
    end
    for _, entry in ipairs(module:GetSetting("customViewers", {})) do
        if entry and entry.id and entry.id ~= "" and entriesByViewer[entry.id] then
            local found
            for _, vk in ipairs(viewerOrder) do
                if vk == entry.id then found = true break end
            end
            if not found then
                table.insert(viewerOrder, entry.id)
            end
        end
    end

    local viewerGroupOrder = 100
    for _, viewerKey in ipairs(viewerOrder) do
        if not viewerKey then
            -- skip nil; should never happen if viewerOrder is built correctly
        else
        local entries = entriesByViewer[viewerKey] or {}
        local viewerLabel = GetViewerDisplayName(nil, viewerKey)
        local groupKey = "viewerGroup_" .. viewerKey:gsub("[^%w]", "_")
        options.args.custom.args[groupKey] = {
            type = "group",
            name = viewerLabel,
            order = viewerGroupOrder,
            args = {},
        }
        viewerGroupOrder = viewerGroupOrder + 1

        for _, rec in ipairs(entries) do
            local entryConfig = rec.entryConfig
            local entryIndex = rec.entryIndex
            local entryName = string.format(L["ENTRY_N"], entryIndex)
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
                entryName = entryConfig.slotID == 13 and L["TRINKET_1"] or L["TRINKET_2"]
            elseif entryConfig.actionSlotID then
                entryName = GetActionSlotDisplayName(entryConfig.actionSlotID)
            end
            if not entryName or entryName == "" then
                entryName = string.format(L["ENTRY_N"], entryIndex) or ("Entry " .. tostring(entryIndex))
            end

            local entryKey = "entry_" .. (entryConfig.id or entryIndex or "unknown")
            options.args.custom.args[groupKey].args[entryKey] = {
                type = "group",
                name = entryName,
                order = 200 + entryIndex,
                args = {
                enabled = {
                    type = "toggle",
                    name = L["ENABLED"],
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
                            if module.RefreshViewer then
                                module:RefreshViewer(assignedViewer)
                            elseif module.LayoutEngine then
                                module.LayoutEngine.RefreshViewer(assignedViewer)
                            end
                        end
                    end,
                },
                index = {
                    type = "range",
                    name = L["Index"],
                    desc = L["DISPLAY_ORDER_DESC"],
                    order = 2,
                    min = 1,
                    max = 50,
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
                        name = L["VIEWER"],
                        desc = L["ASSIGN_ENTRY_TO_VIEWER_DESC"],
                        order = 5,
                        values = GetViewerSelectValues,
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
                        
                        if module.RefreshViewer then
                            if not wasInViewer then
                                module:RefreshViewer(oldViewer)
                            end
                            module:RefreshViewer(value)
                        elseif module.LayoutEngine then
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
                    name = L["REMOVE"],
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

    TavernUI:RegisterModuleOptions("uCDM", options, L["UCDM"])
end

function module:RegisterOptions()
    if not self.optionsBuilt then
        self:BuildOptions()
        self.optionsBuilt = true
    end
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
