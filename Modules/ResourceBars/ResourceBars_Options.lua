local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("TavernUI", true)
local module = TavernUI:GetModule("ResourceBars")

if not module then return end

local Anchor = LibStub("LibAnchorRegistry-1.0", true)

local Options = {}

local function GetBarDisplayName(barId)
    return L[barId] or (barId:gsub("_", " "):gsub("^%l", string.upper))
end

local function GetBarPath(barId, key)
    return string.format("bars.%s.%s", barId, key)
end

local CONSTANTS = module.CONSTANTS
local function GetBarColorModeDefault(barId)
    if barId == CONSTANTS.BAR_ID_STAGGER then return CONSTANTS.COLOR_MODE_THRESHOLD end
    return CONSTANTS.COLOR_MODE_RESOURCE_TYPE
end

local function GetBarSetting(barId, key, defaultValue)
    return module:GetSetting(GetBarPath(barId, key), defaultValue)
end

local function GetEffectiveConfig(barId)
    return module:GetBarConfig(barId)
end

local function SetBarSetting(barId, key, value)
    module:SetSetting(GetBarPath(barId, key), value)
    if key == "enabled" then
        module:RebuildActiveBars()
    elseif module.bars and module.bars[barId] then
        module:UpdateBar(barId)
    end
end

local ANCHOR_POINTS = {
    TOPLEFT = "ANCHOR_TOPLEFT", TOP = "ANCHOR_TOP", TOPRIGHT = "ANCHOR_TOPRIGHT",
    LEFT = "ANCHOR_LEFT", CENTER = "ANCHOR_CENTER", RIGHT = "ANCHOR_RIGHT",
    BOTTOMLEFT = "ANCHOR_BOTTOMLEFT", BOTTOM = "ANCHOR_BOTTOM", BOTTOMRIGHT = "ANCHOR_BOTTOMRIGHT",
}
local RESOURCE_BAR_ANCHOR_NAME = "TavernUI.ResourceBars.ResourceBar"
local SPECIAL_RESOURCE_ANCHOR_NAME = "TavernUI.ResourceBars.SpecialResource"

local function GetAnchorConfig(barId)
    if module:IsResourceBarType(barId) then
        return module:GetSetting("resourceBarAnchorConfig", {}) or {}
    end
    if module:IsSpecialResourceType(barId) then
        return module:GetSetting("specialResourceAnchorConfig", {}) or {}
    end
    return GetBarSetting(barId, "anchorConfig", {}) or {}
end

local function MergeAnchorConfig(barId, overrides)
    local c = GetAnchorConfig(barId)
    if type(c) ~= "table" then c = {} end
    return {
        target = (overrides.target ~= nil) and overrides.target or c.target,
        point = overrides.point or c.point or "CENTER",
        relativePoint = overrides.relativePoint or c.relativePoint or "CENTER",
        offsetX = (overrides.offsetX ~= nil) and overrides.offsetX or (type(c.offsetX) == "number" and c.offsetX or 0),
        offsetY = (overrides.offsetY ~= nil) and overrides.offsetY or (type(c.offsetY) == "number" and c.offsetY or 0),
    }
end

local function SetAnchorConfig(barId, anchorConfig)
    if module.Anchoring and anchorConfig and anchorConfig.target and anchorConfig.target ~= "" then
        if module:IsResourceBarType(barId) then
            for _, rid in ipairs(module:GetResourceBarIds()) do
                module.Anchoring:ClearLayoutPositionForBar(rid)
            end
        elseif module:IsSpecialResourceType(barId) then
            for _, rid in ipairs(module:GetSpecialResourceBarIds()) do
                module.Anchoring:ClearLayoutPositionForBar(rid)
            end
        else
            module.Anchoring:ClearLayoutPositionForBar(barId)
        end
    end
    if module:IsResourceBarType(barId) then
        module:SetSetting("resourceBarAnchorConfig", anchorConfig)
        if not anchorConfig or not anchorConfig.target then
            module:SetSetting("resourceBarAnchorCategory", nil)
        end
        for _, rid in ipairs(module:GetResourceBarIds()) do
            if module.bars and module.bars[rid] then
                module:UpdateBar(rid)
                if module.Anchoring then module.Anchoring:ApplyAnchor(rid) end
            end
        end
    elseif module:IsSpecialResourceType(barId) then
        module:SetSetting("specialResourceAnchorConfig", anchorConfig)
        if not anchorConfig or not anchorConfig.target then
            module:SetSetting("specialResourceAnchorCategory", nil)
        end
        for _, rid in ipairs(module:GetSpecialResourceBarIds()) do
            if module.bars and module.bars[rid] then
                module:UpdateBar(rid)
                if module.Anchoring then module.Anchoring:ApplyAnchor(rid) end
            end
        end
    else
        SetBarSetting(barId, "anchorConfig", anchorConfig)
        if not anchorConfig or not anchorConfig.target then
            SetBarSetting(barId, "anchorCategory", nil)
        end
    end
    if module.Anchoring then
        module.Anchoring:ApplyAnchor(barId)
    end
end

local function GetAnchorNameToExclude(barId)
    if module:IsSpecialResourceType(barId) then return SPECIAL_RESOURCE_ANCHOR_NAME end
    if module:IsResourceBarType(barId) then return RESOURCE_BAR_ANCHOR_NAME end
    return "TavernUI.ResourceBars." .. barId
end

local function GetCategoryForAnchor(anchorName)
    if not Anchor or not anchorName then return nil end
    local frame, metadata = Anchor:Get(anchorName)
    if metadata and metadata.category then
        return metadata.category
    end
    return nil
end

local function GetAnchorCategory(barId)
    local stored
    if module:IsResourceBarType(barId) then
        stored = module:GetSetting("resourceBarAnchorCategory")
    elseif module:IsSpecialResourceType(barId) then
        stored = module:GetSetting("specialResourceAnchorCategory")
    else
        stored = GetBarSetting(barId, "anchorCategory")
    end
    if stored and stored ~= "None" then return stored end
    local anchorConfig = GetAnchorConfig(barId)
    if anchorConfig.target and anchorConfig.target ~= "UIParent" then
        local derived = GetCategoryForAnchor(anchorConfig.target)
        if derived then return derived end
    end
    return "None"
end

local function SetAnchorCategory(barId, value)
    local setCategoryPath
    if module:IsResourceBarType(barId) then
        setCategoryPath = "resourceBarAnchorCategory"
    elseif module:IsSpecialResourceType(barId) then
        setCategoryPath = "specialResourceAnchorCategory"
    else
        setCategoryPath = GetBarPath(barId, "anchorCategory")
    end
    if value == "None" or not value then
        module:SetSetting(setCategoryPath, nil)
        SetAnchorConfig(barId, nil)
    else
        module:SetSetting(setCategoryPath, value)
        local cur = GetAnchorConfig(barId)
            if cur and cur.target then
            local currentCategory = GetCategoryForAnchor(cur.target)
            if currentCategory ~= value then
                SetAnchorConfig(barId, MergeAnchorConfig(barId, { target = nil }))
            end
        end
    end
    AceConfigRegistry:NotifyChange("TavernUI")
end

local CATEGORY_DISPLAY_NAMES = {
    screen = "SCREEN",
    actionbars = "ACTION_BARS",
    bars = "BARS",
    resourcebars = "RESOURCE_BARS",
    castbars = "CASTBARS",
    cooldowns = "COOLDOWNS",
    cdm = "CDM",
    ucdm = "UCDM_CATEGORY",
    unitframes = "UNIT_FRAMES",
    TavernUI = "TAVERN_UI_CATEGORY",
    blizzard = "BLIZZARD",
    misc = "MISC",
}
local CATEGORY_ORDER = {
    screen = 0, actionbars = 1, bars = 2, resourcebars = 3, castbars = 4, cooldowns = 5, cdm = 6, ucdm = 7,
    unitframes = 8, TavernUI = 9, blizzard = 10, misc = 11,
}

local function GetAvailableCategories(barId)
    local categories = {}
    local exclude = GetAnchorNameToExclude(barId)
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

local function RefreshBar(barId)
    if module.bars and module.bars[barId] then
        module:UpdateBar(barId)
    end
    if module.Anchoring then
        module.Anchoring:ApplyAnchor(barId)
    end
end

local function RefreshAllBars()
    for _, barId in ipairs(module:GetAllBarIds()) do
        RefreshBar(barId)
    end
end

local CLASS_FILES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER" }

local function CreateArrayColorConfigUI(barId, configKey, entryType, minEntries, maxEntries)
    local args = {}
    local order = 1
    
    local function GetArray()
        local array = GetBarSetting(barId, configKey, {})
        if type(array) ~= "table" then
            array = {}
        end
        return array
    end
    
    local function SetArray(array)
        table.sort(array, function(a, b)
            local keyA = entryType == "threshold" and a.threshold or a.position
            local keyB = entryType == "threshold" and b.threshold or b.position
            return keyA < keyB
        end)
        SetBarSetting(barId, configKey, array)
        RefreshBar(barId)
    end

    local rebuildEntriesAndNotify
    local function AddEntry()
        local array = GetArray()
        local newEntry = {}
        if entryType == "threshold" then
            newEntry.threshold = #array > 0 and (array[#array].threshold + 0.1) or 0.5
            newEntry.color = {r = 1, g = 1, b = 1}
        else
            newEntry.position = #array > 0 and (array[#array].position + 0.1) or 0.5
            newEntry.color = {r = 1, g = 1, b = 1}
        end
        table.insert(array, newEntry)
        SetArray(array)
        if rebuildEntriesAndNotify then rebuildEntriesAndNotify() end
    end

    local function RemoveEntry(index)
        local array = GetArray()
        if #array > minEntries then
            table.remove(array, index)
            SetArray(array)
            if rebuildEntriesAndNotify then rebuildEntriesAndNotify() end
        end
    end
    
    local addEntryDesc = L["ADD_NEW_THRESHOLD_ENTRY"]
    args.add = {
        type = "execute",
        name = L["ADD_ENTRY"],
        desc = addEntryDesc,
        order = order,
        func = function()
            local array = GetArray()
            if maxEntries and #array >= maxEntries then
                return
            end
            AddEntry()
        end,
        disabled = function()
            local array = GetArray()
            return maxEntries and #array >= maxEntries
        end,
    }
    order = order + 1
    
    args.entries = {
        type = "group",
        name = L["ENTRIES"],
        inline = true,
        order = order,
        args = {},
    }
    order = order + 1
    
    local function BuildEntryOptions()
        local array = GetArray()
        local entryArgs = args.entries.args
        
        for k in pairs(entryArgs) do
            entryArgs[k] = nil
        end
        
        for i = 1, #array do
            local entry = array[i]
            local entryKey = "entry" .. i
            
            entryArgs[entryKey] = {
                type = "group",
                name = string.format(L["ENTRY_N"], i),
                inline = true,
                order = i,
                args = {},
            }
            
            local entryOrder = 1
            
            if entryType == "threshold" then
                entryArgs[entryKey].args.threshold = {
                    type = "range",
                    name = L["THRESHOLD"],
                    desc = L["THRESHOLD_VALUE_DESC"],
                    order = entryOrder,
                    min = 0,
                    max = 1,
                    step = 0.01,
                    get = function()
                        return entry.threshold or 0.5
                    end,
                    set = function(_, value)
                        entry.threshold = value
                        SetArray(array)
                    end,
                }
                entryOrder = entryOrder + 1
            else
                entryArgs[entryKey].args.position = {
                    type = "range",
                    name = L["POSITION"],
                    desc = L["POSITION_VALUE_DESC"],
                    order = entryOrder,
                    min = 0,
                    max = 1,
                    step = 0.01,
                    get = function()
                        return entry.position or 0.5
                    end,
                    set = function(_, value)
                        entry.position = value
                        SetArray(array)
                    end,
                }
                entryOrder = entryOrder + 1
            end
            
            entryArgs[entryKey].args.color = {
                type = "color",
                name = L["COLOR"],
                desc = L["COLOR_FOR_ENTRY_DESC"],
                order = entryOrder,
                hasAlpha = false,
                get = function()
                    local color = entry.color or {r = 1, g = 1, b = 1}
                    return color.r or 1, color.g or 1, color.b or 1
                end,
                set = function(_, r, g, b)
                    entry.color = {r = r, g = g, b = b}
                    SetArray(array)
                end,
            }
            entryOrder = entryOrder + 1
            
            entryArgs[entryKey].args.remove = {
                type = "execute",
                name = L["REMOVE"],
                desc = L["REMOVE_ENTRY_DESC"],
                order = entryOrder,
                func = function()
                    RemoveEntry(i)
                end,
                disabled = function()
                    return #array <= minEntries
                end,
            }
        end
    end

    rebuildEntriesAndNotify = function()
        BuildEntryOptions()
        AceConfigRegistry:NotifyChange("TavernUI")
    end

    BuildEntryOptions()

    return args, BuildEntryOptions
end

local function BuildBarOptions(barId)
    local args = {}
    local order = 1
    
    args.enabled = {
        type = "toggle",
        name = L["ENABLED"],
        desc = L["ENABLE_RESOURCE_BAR_DESC"],
        order = order,
        get = function()
            return GetEffectiveConfig(barId)[CONSTANTS.KEY_ENABLED] ~= false
        end,
        set = function(_, value)
            SetBarSetting(barId, CONSTANTS.KEY_ENABLED, value)
        end,
    }
    order = order + 1

    local function isSegmentedBar()
        return module:GetBarType(barId) == CONSTANTS.BAR_TYPE_SEGMENTED
    end
    if not isSegmentedBar() then
        args.sizeHeader = { type = "header", name = L["SIZE"], order = order }
        order = order + 1
        args.width = {
            type = "range",
            name = L["WIDTH"],
            desc = L["BAR_WIDTH_DESC"],
            order = order,
            min = 50,
            max = 500,
            step = 1,
            get = function()
                local c = GetEffectiveConfig(barId)
                return (type(c[CONSTANTS.KEY_WIDTH]) == "number") and c[CONSTANTS.KEY_WIDTH] or 200
            end,
            set = function(_, value)
                SetBarSetting(barId, CONSTANTS.KEY_WIDTH, value)
                RefreshBar(barId)
            end,
        }
        order = order + 1
        args.height = {
            type = "range",
            name = L["HEIGHT"],
            desc = L["BAR_HEIGHT_DESC"],
            order = order,
            min = 5,
            max = 100,
            step = 1,
            get = function()
                local c = GetEffectiveConfig(barId)
                return (type(c[CONSTANTS.KEY_HEIGHT]) == "number") and c[CONSTANTS.KEY_HEIGHT] or 14
            end,
            set = function(_, value)
                SetBarSetting(barId, CONSTANTS.KEY_HEIGHT, value)
                RefreshBar(barId)
            end,
        }
        order = order + 1
    end
    if isSegmentedBar() then
        args.segmentTextureHeader = { type = "header", name = L["SEGMENT_APPEARANCE"], order = order }
        order = order + 1
        args.segmentTexture = {
            type = "select",
            name = L["SEGMENT_TEXTURE"],
            desc = L["TEXTURE_FOR_SEGMENTS_STATUSBAR_DESC"],
            order = order,
            values = function() return TavernUI:GetLSMMediaDropdownValues("statusbar", "Default", L["DEFAULT"]) end,
            get = function()
                local v = GetEffectiveConfig(barId)[CONSTANTS.KEY_SEGMENT_TEXTURE]
                return (v and v ~= "") and v or "Default"
            end,
            set = function(_, value)
                SetBarSetting(barId, CONSTANTS.KEY_SEGMENT_TEXTURE, (value == "Default") and nil or value)
                RefreshBar(barId)
            end,
        }
        order = order + 1
        args.segmentSizeHeader = { type = "header", name = L["SIZE"], order = order }
        order = order + 1
        args.width = {
            type = "range",
            name = L["WIDTH"],
            desc = L["SEGMENTED_BAR_SIZE_DESC"],
            order = order,
            min = 50,
            max = 500,
            step = 1,
            get = function()
                local c = GetEffectiveConfig(barId)
                return (type(c[CONSTANTS.KEY_WIDTH]) == "number") and c[CONSTANTS.KEY_WIDTH] or 200
            end,
            set = function(_, value)
                SetBarSetting(barId, CONSTANTS.KEY_WIDTH, value)
                RefreshBar(barId)
            end,
        }
        order = order + 1
        args.height = {
            type = "range",
            name = L["HEIGHT"],
            desc = L["SEGMENTED_BAR_SIZE_DESC"],
            order = order,
            min = 5,
            max = 100,
            step = 1,
            get = function()
                local c = GetEffectiveConfig(barId)
                return (type(c[CONSTANTS.KEY_HEIGHT]) == "number") and c[CONSTANTS.KEY_HEIGHT] or 20
            end,
            set = function(_, value)
                SetBarSetting(barId, CONSTANTS.KEY_HEIGHT, value)
                RefreshBar(barId)
            end,
        }
        order = order + 1
        args.segmentSpacing = {
            type = "range",
            name = L["SEGMENT_SPACING"],
            desc = L["SEGMENT_SPACING_DESC"],
            order = order,
            min = -1,
            max = 50,
            step = 1,
            get = function()
                local v = GetEffectiveConfig(barId)[CONSTANTS.KEY_SEGMENT_SPACING]
                return (type(v) == "number" and v >= -1) and v or 2
            end,
            set = function(_, value)
                SetBarSetting(barId, CONSTANTS.KEY_SEGMENT_SPACING, (type(value) == "number" and value >= -1) and value or nil)
                RefreshBar(barId)
            end,
        }
        order = order + 1
        args.segmentBorderEnabled = {
            type = "toggle",
            name = L["SEGMENT_BORDER"],
            desc = L["SHOW_BORDER_AROUND_SEGMENT_DESC"],
            order = order,
            get = function()
                local border = GetEffectiveConfig(barId)[CONSTANTS.KEY_SEGMENT_BORDER] or {}
                return border.enabled ~= false
            end,
            set = function(_, value)
                local border = GetBarSetting(barId, CONSTANTS.KEY_SEGMENT_BORDER, {}) or {}
                border.enabled = value
                SetBarSetting(barId, CONSTANTS.KEY_SEGMENT_BORDER, border)
                RefreshBar(barId)
            end,
        }
        order = order + 1
        args.segmentBorderSize = {
            type = "range",
            name = L["BORDER_SIZE"],
            desc = L["SEGMENT_BORDER_THICKNESS_DESC"],
            order = order,
            min = 1,
            max = 8,
            step = 1,
            get = function()
                local border = GetEffectiveConfig(barId)[CONSTANTS.KEY_SEGMENT_BORDER] or {}
                return (type(border.size) == "number") and border.size or 1
            end,
            set = function(_, value)
                local border = GetBarSetting(barId, CONSTANTS.KEY_SEGMENT_BORDER, {}) or {}
                border.size = value
                SetBarSetting(barId, CONSTANTS.KEY_SEGMENT_BORDER, border)
                RefreshBar(barId)
            end,
            disabled = function()
                local border = GetBarSetting(barId, CONSTANTS.KEY_SEGMENT_BORDER, {}) or {}
                return not border.enabled
            end,
        }
        order = order + 1
        args.segmentBorderColor = {
            type = "color",
            name = L["BORDER_COLOR"],
            desc = L["SEGMENT_BORDER_COLOR_DESC"],
            order = order,
            hasAlpha = true,
            get = function()
                local c = (GetEffectiveConfig(barId)[CONSTANTS.KEY_SEGMENT_BORDER] or {}).color or {}
                return c.r or 0, c.g or 0, c.b or 0, (type(c.a) == "number") and c.a or 1
            end,
            set = function(_, r, g, b, a)
                local border = GetBarSetting(barId, CONSTANTS.KEY_SEGMENT_BORDER, {}) or {}
                border.color = { r = r, g = g, b = b, a = (a ~= nil) and a or 1 }
                SetBarSetting(barId, CONSTANTS.KEY_SEGMENT_BORDER, border)
                RefreshBar(barId)
            end,
            disabled = function()
                local border = GetEffectiveConfig(barId)[CONSTANTS.KEY_SEGMENT_BORDER] or {}
                return not (border.enabled ~= false)
            end,
        }
        order = order + 1
        args.segmentBackgroundHeader = { type = "header", name = L["SEGMENT_BACKGROUND"], order = order }
        order = order + 1
        args.segmentBackgroundEnabled = {
            type = "toggle",
            name = L["SEGMENT_BACKGROUND"],
            desc = L["SEGMENT_BACKGROUND_DESC"],
            order = order,
            get = function()
                local bg = GetEffectiveConfig(barId)[CONSTANTS.KEY_SEGMENT_BACKGROUND] or {}
                return bg.enabled ~= false
            end,
            set = function(_, value)
                local bg = GetBarSetting(barId, CONSTANTS.KEY_SEGMENT_BACKGROUND, {}) or {}
                bg.enabled = value
                SetBarSetting(barId, CONSTANTS.KEY_SEGMENT_BACKGROUND, bg)
                RefreshBar(barId)
            end,
        }
        order = order + 1
        args.segmentBackgroundTexture = {
            type = "select",
            name = L["BACKGROUND_TEXTURE"],
            desc = L["TEXTURE_FOR_SEGMENT_BACKGROUND_DESC"],
            order = order,
            values = function() return TavernUI:GetLSMMediaDropdownValues("statusbar", "Default", L["DEFAULT"]) end,
            get = function()
                local bg = GetEffectiveConfig(barId)[CONSTANTS.KEY_SEGMENT_BACKGROUND] or {}
                local v = bg.texture
                return (v and v ~= "") and v or "Default"
            end,
            set = function(_, value)
                local bg = GetBarSetting(barId, CONSTANTS.KEY_SEGMENT_BACKGROUND, {}) or {}
                bg.texture = (value == "Default") and nil or value
                SetBarSetting(barId, CONSTANTS.KEY_SEGMENT_BACKGROUND, bg)
                RefreshBar(barId)
            end,
            disabled = function()
                local bg = GetEffectiveConfig(barId)[CONSTANTS.KEY_SEGMENT_BACKGROUND] or {}
                return not (bg.enabled ~= false)
            end,
        }
        order = order + 1
        args.segmentBackgroundColor = {
            type = "color",
            name = L["BACKGROUND_COLOUR"],
            desc = L["SEGMENT_BACKGROUND_COLOUR_DESC"],
            order = order,
            hasAlpha = true,
            get = function()
                local c = (GetEffectiveConfig(barId)[CONSTANTS.KEY_SEGMENT_BACKGROUND] or {}).color or {}
                return c.r or 0, c.g or 0, c.b or 0, (type(c.a) == "number") and c.a or 0.5
            end,
            set = function(_, r, g, b, a)
                local bg = GetBarSetting(barId, CONSTANTS.KEY_SEGMENT_BACKGROUND, {}) or {}
                bg.color = { r = r, g = g, b = b, a = (a ~= nil) and a or 0.5 }
                SetBarSetting(barId, CONSTANTS.KEY_SEGMENT_BACKGROUND, bg)
                RefreshBar(barId)
            end,
            disabled = function()
                local bg = GetEffectiveConfig(barId)[CONSTANTS.KEY_SEGMENT_BACKGROUND] or {}
                return not (bg.enabled ~= false)
            end,
        }
        order = order + 1
    end

    local function isPowerBar()
        return module:GetBarType(barId) == CONSTANTS.BAR_TYPE_POWER
    end
    args.barAppearanceHeader = { type = "header", name = L["BAR"], order = order, hidden = function() return not isPowerBar() end }
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
            local v = GetEffectiveConfig(barId)[CONSTANTS.KEY_BAR_TEXTURE]
            return (v and v ~= "") and v or ""
        end,
        set = function(_, value)
            SetBarSetting(barId, CONSTANTS.KEY_BAR_TEXTURE, (value and value ~= "") and value or nil)
            RefreshBar(barId)
        end,
        hidden = function() return not isPowerBar() end,
    }
    order = order + 1
    args.barBackgroundHeader = { type = "header", name = L["Background"], order = order, hidden = function() return not isPowerBar() end }
    order = order + 1
    args.barBackgroundEnabled = {
        type = "toggle",
        name = L["Background"],
        desc = L["SHOW_BACKGROUND_BAR_DESC"],
        order = order,
        get = function()
            local bg = GetEffectiveConfig(barId)[CONSTANTS.KEY_BAR_BACKGROUND] or {}
            return bg.enabled ~= false
        end,
        set = function(_, value)
            local bg = GetBarSetting(barId, CONSTANTS.KEY_BAR_BACKGROUND, {}) or {}
            bg.enabled = value
            SetBarSetting(barId, CONSTANTS.KEY_BAR_BACKGROUND, bg)
            RefreshBar(barId)
        end,
        hidden = function() return not isPowerBar() end,
    }
    order = order + 1
    args.barBackgroundTexture = {
        type = "select",
        name = L["BACKGROUND_TEXTURE"],
        desc = L["TEXTURE_FOR_BAR_BACKGROUND_DESC"],
        order = order,
        values = function()
            return TavernUI:GetLSMMediaDropdownValues("statusbar", "", L["DEFAULT"])
        end,
        get = function()
            local bg = GetEffectiveConfig(barId)[CONSTANTS.KEY_BAR_BACKGROUND] or {}
            return (bg.texture and bg.texture ~= "") and bg.texture or ""
        end,
        set = function(_, value)
            local bg = GetBarSetting(barId, CONSTANTS.KEY_BAR_BACKGROUND, {}) or {}
            bg.texture = (value and value ~= "") and value or nil
            SetBarSetting(barId, CONSTANTS.KEY_BAR_BACKGROUND, bg)
            RefreshBar(barId)
        end,
        disabled = function()
            local bg = GetEffectiveConfig(barId)[CONSTANTS.KEY_BAR_BACKGROUND] or {}
            return not (bg.enabled ~= false)
        end,
        hidden = function() return not isPowerBar() end,
    }
    order = order + 1
    args.barBackgroundColor = {
        type = "color",
        name = L["BACKGROUND_COLOUR"],
        desc = L["BAR_BACKGROUND_COLOUR_DESC"],
        order = order,
        hasAlpha = true,
        get = function()
            local c = (GetEffectiveConfig(barId)[CONSTANTS.KEY_BAR_BACKGROUND] or {}).color or {}
            return c.r or 0, c.g or 0, c.b or 0, (type(c.a) == "number") and c.a or 0.5
        end,
        set = function(_, r, g, b, a)
            local bg = GetBarSetting(barId, CONSTANTS.KEY_BAR_BACKGROUND, {}) or {}
            bg.color = { r = r, g = g, b = b, a = (a ~= nil) and a or 0.5 }
            SetBarSetting(barId, CONSTANTS.KEY_BAR_BACKGROUND, bg)
            RefreshBar(barId)
        end,
        disabled = function()
            local bg = GetEffectiveConfig(barId)[CONSTANTS.KEY_BAR_BACKGROUND] or {}
            return not (bg.enabled ~= false)
        end,
        hidden = function() return not isPowerBar() end,
    }
    order = order + 1

    args.barBorderHeader = { type = "header", name = L["BORDER"], order = order, hidden = function() return not isPowerBar() end }
    order = order + 1
    args.barBorderEnabled = {
        type = "toggle",
        name = L["BORDER"],
        desc = L["SHOW_BORDER_AROUND_BAR_DESC"],
        order = order,
        get = function()
            local border = GetEffectiveConfig(barId)[CONSTANTS.KEY_BAR_BORDER] or {}
            return border.enabled ~= false
        end,
        set = function(_, value)
            local border = GetBarSetting(barId, CONSTANTS.KEY_BAR_BORDER, {}) or {}
            border.enabled = value
            SetBarSetting(barId, CONSTANTS.KEY_BAR_BORDER, border)
            RefreshBar(barId)
        end,
        hidden = function() return not isPowerBar() end,
    }
    order = order + 1
    args.barBorderSize = {
        type = "range",
        name = L["BORDER_SIZE"],
        desc = L["BORDER_THICKNESS"],
        order = order,
        min = 1,
        max = 8,
        step = 1,
        get = function()
            local border = GetEffectiveConfig(barId)[CONSTANTS.KEY_BAR_BORDER] or {}
            return (type(border.size) == "number") and border.size or 1
        end,
        set = function(_, value)
            local border = GetBarSetting(barId, CONSTANTS.KEY_BAR_BORDER, {}) or {}
            border.size = value
            SetBarSetting(barId, CONSTANTS.KEY_BAR_BORDER, border)
            RefreshBar(barId)
        end,
        disabled = function()
            local border = GetEffectiveConfig(barId)[CONSTANTS.KEY_BAR_BORDER] or {}
            return not (border.enabled ~= false)
        end,
        hidden = function() return not isPowerBar() end,
    }
    order = order + 1
    args.barBorderColor = {
        type = "color",
        name = L["BORDER_COLOR"],
        desc = L["BORDER_COLOR_ALPHA_DESC"],
        order = order,
        hasAlpha = true,
        get = function()
            local c = (GetEffectiveConfig(barId)[CONSTANTS.KEY_BAR_BORDER] or {}).color or {}
            return c.r or 0, c.g or 0, c.b or 0, (type(c.a) == "number") and c.a or 1
        end,
        set = function(_, r, g, b, a)
            local border = GetBarSetting(barId, CONSTANTS.KEY_BAR_BORDER, {}) or {}
            border.color = { r = r, g = g, b = b, a = (a ~= nil) and a or 1 }
            SetBarSetting(barId, CONSTANTS.KEY_BAR_BORDER, border)
            RefreshBar(barId)
        end,
        disabled = function()
            local border = GetEffectiveConfig(barId)[CONSTANTS.KEY_BAR_BORDER] or {}
            return not (border.enabled ~= false)
        end,
        hidden = function() return not isPowerBar() end,
    }
    order = order + 1

    args.barColourHeader = { type = "header", name = L["BAR_COLOUR"], order = order }
    order = order + 1
    args.colorMode = {
        type = "select",
        name = L["COLOR_MODE"],
        desc = L["COLOR_MODE_DESC"],
        order = order,
        values = {
            [CONSTANTS.COLOR_MODE_RESOURCE_TYPE] = L["RESOURCE_COLOR"],
            [CONSTANTS.COLOR_MODE_SOLID] = L["SOLID"],
            [CONSTANTS.COLOR_MODE_CLASS_COLOR] = L["CLASS_COLOR"],
            [CONSTANTS.COLOR_MODE_THRESHOLD] = L["THRESHOLD"],
        },
        get = function()
            local v = GetEffectiveConfig(barId)[CONSTANTS.KEY_COLOR_MODE]
            if v == CONSTANTS.COLOR_MODE_GRADIENT then return CONSTANTS.COLOR_MODE_SOLID end
            return v or GetBarColorModeDefault(barId)
        end,
        set = function(_, value)
            SetBarSetting(barId, CONSTANTS.KEY_COLOR_MODE, value)
            RefreshBar(barId)
            AceConfigRegistry:NotifyChange("TavernUI")
        end,
    }
    order = order + 1

    local function getEffectiveColorMode()
        local v = GetEffectiveConfig(barId)[CONSTANTS.KEY_COLOR_MODE]
        if v == CONSTANTS.COLOR_MODE_GRADIENT then return CONSTANTS.COLOR_MODE_SOLID end
        return v or GetBarColorModeDefault(barId)
    end
    local function isSolidMode()
        return getEffectiveColorMode() == CONSTANTS.COLOR_MODE_SOLID
    end
    local function isThresholdMode()
        return getEffectiveColorMode() == CONSTANTS.COLOR_MODE_THRESHOLD
    end

    args.color = {
        type = "color",
        name = L["COLOR"],
        desc = L["BAR_COLOR_SOLID_DESC"],
        order = order,
        hasAlpha = true,
        get = function()
            local color = GetEffectiveConfig(barId)[CONSTANTS.KEY_COLOR] or {}
            return color.r or 1, color.g or 1, color.b or 1, (type(color.a) == "number") and color.a or 1
        end,
        set = function(_, r, g, b, a)
            SetBarSetting(barId, CONSTANTS.KEY_COLOR, {r = r, g = g, b = b, a = (a ~= nil) and a or 1})
            RefreshBar(barId)
        end,
        hidden = function() return not isSolidMode() end,
    }
    order = order + 1

    args.thresholdHeader = { type = "header", name = L["THRESHOLD_BREAKPOINTS"], order = order, hidden = function() return not isThresholdMode() end }
    order = order + 1
    local thresholdArgs, rebuildThreshold = CreateArrayColorConfigUI(barId, CONSTANTS.KEY_BREAKPOINTS, "threshold", 2, 10)
    for key, value in pairs(thresholdArgs) do
        args["threshold_" .. key] = value
        if type(value) == "table" and value.order then
            value.order = order
            value.hidden = value.hidden or function() return not isThresholdMode() end
            order = order + 1
        end
    end

    local function isBarTextBar()
        return module.Text and module.Text:SupportsBarText(barId)
    end

    args.barTextHeader = { type = "header", name = L["BAR_TEXT"], order = order, hidden = function() return not isBarTextBar() end }
    order = order + 1
    args.barText = {
        type = "select",
        name = L["BAR_TEXT"],
        desc = L["BAR_TEXT_DESC"],
        order = order,
        values = {
            none = L["BAR_TEXT_NONE"],
            current = L["BAR_TEXT_CURRENT"],
            current_max = L["BAR_TEXT_CURRENT_MAX"],
            percent = L["BAR_TEXT_PERCENT"],
            name = L["BAR_TEXT_NAME"],
            current_percent = L["BAR_TEXT_CURRENT_PERCENT"],
            percent_current = L["BAR_TEXT_PERCENT_CURRENT"],
        },
        get = function()
            return GetBarSetting(barId, "barText", "none") or "none"
        end,
        set = function(_, value)
            SetBarSetting(barId, "barText", value)
            RefreshBar(barId)
        end,
        hidden = function() return not isBarTextBar() end,
    }
    order = order + 1
    args.barTextPoint = {
        type = "select",
        name = L["BAR_TEXT_ANCHOR"],
        desc = L["BAR_TEXT_ANCHOR_DESC"],
        order = order,
        values = {
            TOPLEFT = L["ANCHOR_TOPLEFT"], TOP = L["ANCHOR_TOP"], TOPRIGHT = L["ANCHOR_TOPRIGHT"],
            LEFT = L["ANCHOR_LEFT"], CENTER = L["ANCHOR_CENTER"], RIGHT = L["ANCHOR_RIGHT"],
            BOTTOMLEFT = L["ANCHOR_BOTTOMLEFT"], BOTTOM = L["ANCHOR_BOTTOM"], BOTTOMRIGHT = L["ANCHOR_BOTTOMRIGHT"],
        },
        get = function()
            return GetBarSetting(barId, "barTextPoint", "CENTER") or "CENTER"
        end,
        set = function(_, value)
            SetBarSetting(barId, "barTextPoint", value)
            RefreshBar(barId)
        end,
        hidden = function() return not isBarTextBar() end,
    }
    order = order + 1
    args.barTextRelativePoint = {
        type = "select",
        name = L["BAR_TEXT_RELATIVE_POINT"],
        desc = L["BAR_TEXT_RELATIVE_POINT_DESC"],
        order = order,
        values = {
            TOPLEFT = L["ANCHOR_TOPLEFT"], TOP = L["ANCHOR_TOP"], TOPRIGHT = L["ANCHOR_TOPRIGHT"],
            LEFT = L["ANCHOR_LEFT"], CENTER = L["ANCHOR_CENTER"], RIGHT = L["ANCHOR_RIGHT"],
            BOTTOMLEFT = L["ANCHOR_BOTTOMLEFT"], BOTTOM = L["ANCHOR_BOTTOM"], BOTTOMRIGHT = L["ANCHOR_BOTTOMRIGHT"],
        },
        get = function()
            return GetBarSetting(barId, "barTextRelativePoint", "CENTER") or "CENTER"
        end,
        set = function(_, value)
            SetBarSetting(barId, "barTextRelativePoint", value)
            RefreshBar(barId)
        end,
        hidden = function() return not isBarTextBar() end,
    }
    order = order + 1
    args.barTextOffsetX = {
        type = "range",
        name = L["BAR_TEXT_OFFSET_X"],
        desc = L["BAR_TEXT_OFFSET_X_DESC"],
        order = order,
        min = -100,
        max = 100,
        step = 1,
        get = function()
            return GetBarSetting(barId, "barTextOffsetX", 0) or 0
        end,
        set = function(_, value)
            SetBarSetting(barId, "barTextOffsetX", value)
            RefreshBar(barId)
        end,
        hidden = function() return not isBarTextBar() end,
    }
    order = order + 1
    args.barTextOffsetY = {
        type = "range",
        name = L["BAR_TEXT_OFFSET_Y"],
        desc = L["BAR_TEXT_OFFSET_Y_DESC"],
        order = order,
        min = -100,
        max = 100,
        step = 1,
        get = function()
            return GetBarSetting(barId, "barTextOffsetY", 0) or 0
        end,
        set = function(_, value)
            SetBarSetting(barId, "barTextOffsetY", value)
            RefreshBar(barId)
        end,
        hidden = function() return not isBarTextBar() end,
    }
    order = order + 1
    args.barTextColor = {
        type = "color",
        name = L["BAR_TEXT_COLOUR"],
        desc = L["BAR_TEXT_COLOUR_DESC"],
        order = order,
        hasAlpha = true,
        get = function()
            local c = GetBarSetting(barId, "barTextColor", {}) or {}
            return c.r or 1, c.g or 1, c.b or 1, (type(c.a) == "number") and c.a or 1
        end,
        set = function(_, r, g, b, a)
            SetBarSetting(barId, "barTextColor", { r = r, g = g, b = b, a = (a ~= nil) and a or 1 })
            RefreshBar(barId)
        end,
        hidden = function() return not isBarTextBar() end,
    }
    order = order + 1
    args.barTextFontSize = {
        type = "range",
        name = L["BAR_TEXT_FONT_SIZE"],
        desc = L["BAR_TEXT_FONT_SIZE_DESC"],
        order = order,
        min = 8,
        max = 32,
        step = 1,
        get = function()
            return GetBarSetting(barId, "barTextFontSize", 12) or 12
        end,
        set = function(_, value)
            SetBarSetting(barId, "barTextFontSize", value)
            RefreshBar(barId)
        end,
        hidden = function() return not isBarTextBar() end,
    }
    order = order + 1
    
    args.anchoringHeader = {type = "header", name = L["ANCHORING"], order = order}
    order = order + 1
    
    args.anchorCategory = {
        type = "select",
        name = L["CATEGORY"],
        desc = L["CATEGORY_OF_ANCHOR_DESC"],
        order = order,
        values = function()
            local values = { None = L["NONE_NO_ANCHORING"] }
            for _, cat in ipairs(GetAvailableCategories(barId)) do
                local lkey = CATEGORY_DISPLAY_NAMES[cat]
                values[cat] = (lkey and L[lkey]) or cat:gsub("^%l", string.upper)
            end
            return values
        end,
        get = function()
            return GetAnchorCategory(barId)
        end,
        set = function(_, value)
            SetAnchorCategory(barId, value)
            if module.Anchoring then module.Anchoring:ApplyAnchor(barId) end
        end,
    }
    order = order + 1

    args.anchorTarget = {
        type = "select",
        name = L["ANCHOR_TARGET"],
        desc = L["FRAME_TO_ANCHOR_DESC"],
        order = order,
        disabled = function()
            local category = GetAnchorCategory(barId)
            if category and category ~= "None" then return false end
            local anchorConfig = GetAnchorConfig(barId)
            if anchorConfig.target and anchorConfig.target ~= "UIParent" then
                local derived = GetCategoryForAnchor(anchorConfig.target)
                if derived then return false end
            end
            return true
        end,
        values = function()
            local values = {}
            local selectedCategory = GetAnchorCategory(barId)
            if Anchor and selectedCategory and selectedCategory ~= "None" then
                local exclude = GetAnchorNameToExclude(barId)
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
            local anchorConfig = GetAnchorConfig(barId)
            if anchorConfig.target and anchorConfig.target ~= "UIParent" then
                return anchorConfig.target
            end
            return nil
        end,
        set = function(_, value)
            local cur = GetAnchorConfig(barId)
            local anchorConfig = (cur and type(cur) == "table") and cur or {}
            if not value then
                SetAnchorConfig(barId, nil)
                SetAnchorCategory(barId, "None")
            else
                SetAnchorConfig(barId, MergeAnchorConfig(barId, { target = value }))
                local category = GetCategoryForAnchor(value)
                if category then
                    if module:IsResourceBarType(barId) then
                        module:SetSetting("resourceBarAnchorCategory", category)
                    elseif module:IsSpecialResourceType(barId) then
                        module:SetSetting("specialResourceAnchorCategory", category)
                    else
                        SetBarSetting(barId, "anchorCategory", category)
                    end
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
    args.anchorPoint = {
        type = "select",
        name = L["POINT"],
        desc = L["ANCHOR_POINT_ON_VIEWER_DESC"],
        order = order,
        values = anchorPointValues,
        disabled = function()
            local anchorConfig = GetAnchorConfig(barId)
            return not anchorConfig or not anchorConfig.target or anchorConfig.target == "UIParent"
        end,
        get = function()
            local anchorConfig = GetAnchorConfig(barId)
            return (anchorConfig and anchorConfig.point) or "CENTER"
        end,
        set = function(_, value)
            SetAnchorConfig(barId, MergeAnchorConfig(barId, { point = value }))
        end,
    }
    order = order + 1
    args.anchorRelativePoint = {
        type = "select",
        name = L["RELATIVE_POINT"],
        desc = L["ANCHOR_POINT_ON_TARGET_DESC"],
        order = order,
        values = anchorPointValues,
        disabled = function()
            local anchorConfig = GetAnchorConfig(barId)
            return not anchorConfig or not anchorConfig.target or anchorConfig.target == "UIParent"
        end,
        get = function()
            local anchorConfig = GetAnchorConfig(barId)
            return (anchorConfig and anchorConfig.relativePoint) or "CENTER"
        end,
        set = function(_, value)
            SetAnchorConfig(barId, MergeAnchorConfig(barId, { relativePoint = value }))
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
            local anchorConfig = GetAnchorConfig(barId)
            return not anchorConfig or not anchorConfig.target or anchorConfig.target == "UIParent"
        end,
        get = function()
            local anchorConfig = GetAnchorConfig(barId)
            return (anchorConfig and type(anchorConfig.offsetX) == "number") and anchorConfig.offsetX or 0
        end,
        set = function(_, value)
            SetAnchorConfig(barId, MergeAnchorConfig(barId, { offsetX = value }))
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
            local anchorConfig = GetAnchorConfig(barId)
            return not anchorConfig or not anchorConfig.target or anchorConfig.target == "UIParent"
        end,
        get = function()
            local anchorConfig = GetAnchorConfig(barId)
            return (anchorConfig and type(anchorConfig.offsetY) == "number") and anchorConfig.offsetY or 0
        end,
        set = function(_, value)
            SetAnchorConfig(barId, MergeAnchorConfig(barId, { offsetY = value }))
        end,
    }
    order = order + 1

    return args
end

local function BuildResourceColoursOptions()
    local args = {}
    local order = 1
    args.desc = {
        type = "description",
        name = L["DEFAULT_COLOUR_FOR_RESOURCE_DESC"],
        order = order,
    }
    order = order + 1
    args.healthHeader = { type = "header", name = L["HEALTH"], order = order }
    order = order + 1
    args.HEALTH = {
        type = "color",
        name = GetBarDisplayName("HEALTH"),
        desc = string.format(L["BASE_COLOUR_FOR_S"], GetBarDisplayName("HEALTH")),
        order = order,
        hasAlpha = true,
        get = function()
            local res = module:GetSetting("resourceColours", {}) or {}
            local c = res.HEALTH or module:GetDefaultResourceColor("HEALTH")
            return c.r or 1, c.g or 1, c.b or 1, (type(c.a) == "number") and c.a or 1
        end,
        set = function(_, r, g, b, a)
            local res = module:GetSetting("resourceColours", {}) or {}
            res.HEALTH = { r = r, g = g, b = b, a = (a ~= nil) and a or 1 }
            module:SetSetting("resourceColours", res)
            RefreshBar("HEALTH")
        end,
    }
    order = order + 1
    args.primaryPowerHeader = { type = "header", name = L["PRIMARY_POWER_BY_TYPE"], order = order }
    order = order + 1
    local pt = module.Data and module.Data.POWER_TYPES and module.Data.POWER_TYPES.PRIMARY_POWER and module.Data.POWER_TYPES.PRIMARY_POWER.powerTypes
    if pt then
        local powerTypeOrder = { [0]=1, [1]=2, [2]=3, [3]=4, [5]=5, [6]=6, [7]=7, [8]=8, [13]=9, [15]=10, [17]=11 }
        for powerType, info in pairs(pt) do
            local name = info.name or ("Power " .. tostring(powerType))
            args["powerType_" .. powerType] = {
                type = "color",
                name = name,
                desc = string.format(L["BASE_COLOUR_FOR_S"], name),
                order = order + (powerTypeOrder[powerType] or powerType + 20),
                hasAlpha = true,
                get = function()
                    local res = module:GetSetting("resourceColours", {}) or {}
                    local ptColours = res.powerTypes or {}
                    local c = ptColours[powerType] or module:GetDefaultPowerTypeColor(powerType)
                    return c.r or 1, c.g or 1, c.b or 1, (type(c.a) == "number") and c.a or 1
                end,
                set = function(_, r, g, b, a)
                    local res = module:GetSetting("resourceColours", {}) or {}
                    res.powerTypes = res.powerTypes or {}
                    res.powerTypes[powerType] = { r = r, g = g, b = b, a = (a ~= nil) and a or 1 }
                    module:SetSetting("resourceColours", res)
                    RefreshBar("PRIMARY_POWER")
                end,
            }
        end
        order = order + 20
    end
    args.otherResourcesHeader = { type = "header", name = L["OTHER_RESOURCES"], order = order }
    order = order + 1
    for i, barId in ipairs(module:GetResourceBarIds()) do
        args[barId] = {
            type = "color",
            name = GetBarDisplayName(barId),
            desc = string.format(L["BASE_COLOUR_FOR_S"], GetBarDisplayName(barId)),
            order = order + i,
            hasAlpha = true,
            get = function()
                local res = module:GetSetting("resourceColours", {}) or {}
                local c = res[barId] or module:GetDefaultResourceColor(barId)
                return c.r or 1, c.g or 1, c.b or 1, (type(c.a) == "number") and c.a or 1
            end,
            set = function(_, r, g, b, a)
                local res = module:GetSetting("resourceColours", {}) or {}
                res[barId] = { r = r, g = g, b = b, a = (a ~= nil) and a or 1 }
                module:SetSetting("resourceColours", res)
                RefreshAllBars()
            end,
        }
    end
    order = order + #module:GetResourceBarIds() + 1
    args.alternatePowerHeader = { type = "header", name = L["SECONDARY_POWER"], order = order }
    order = order + 1
    args.alternatePower = {
        type = "color",
        name = GetBarDisplayName("ALTERNATE_POWER"),
        desc = string.format(L["BASE_COLOUR_FOR_S"], GetBarDisplayName("ALTERNATE_POWER")),
        order = order,
        hasAlpha = true,
        get = function()
            local res = module:GetSetting("resourceColours", {}) or {}
            local c = res.ALTERNATE_POWER or module:GetDefaultResourceColor("ALTERNATE_POWER")
            return c.r or 1, c.g or 1, c.b or 1, (type(c.a) == "number") and c.a or 1
        end,
        set = function(_, r, g, b, a)
            local res = module:GetSetting("resourceColours", {}) or {}
            res.ALTERNATE_POWER = { r = r, g = g, b = b, a = (a ~= nil) and a or 1 }
            module:SetSetting("resourceColours", res)
            RefreshBar("ALTERNATE_POWER")
        end,
    }
    return args
end

local function BuildClassColoursOptions()
    local args = {}
    local order = 1
    args.desc = {
        type = "description",
        name = L["Class colours (default: Blizzard raid frame colours). Enable \"Use Class Colour\" on a bar to use your class colour."],
        order = order,
    }
    order = order + 1
    local classDisplayNames = {
        WARRIOR = L["WARRIOR"], PALADIN = L["PALADIN"], HUNTER = L["HUNTER"], ROGUE = L["ROGUE"],
        PRIEST = L["PRIEST"], DEATHKNIGHT = L["DEATH_KNIGHT"], SHAMAN = L["SHAMAN"], MAGE = L["MAGE"],
        WARLOCK = L["WARLOCK"], MONK = L["MONK"], DRUID = L["DRUID"], DEMONHUNTER = L["DEMON_HUNTER"], EVOKER = L["EVOKER"],
    }
    for i, classFile in ipairs(CLASS_FILES) do
        local displayName = classDisplayNames[classFile] or classFile
        args[classFile] = {
            type = "color",
            name = displayName,
            desc = string.format(L["COLOUR_FOR_S"], displayName),
            order = order + i,
            hasAlpha = true,
            get = function()
                local classColours = module:GetSetting("classColours", {}) or {}
                local c = classColours[classFile]
                if c and (c.r ~= nil or c.g ~= nil or c.b ~= nil) then
                    return c.r or 0, c.g or 0, c.b or 0, (type(c.a) == "number") and c.a or 1
                end
                if RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
                    local blizz = RAID_CLASS_COLORS[classFile]
                    return blizz.r, blizz.g, blizz.b, 1
                end
                return 1, 1, 1, 1
            end,
            set = function(_, r, g, b, a)
                local classColours = module:GetSetting("classColours", {}) or {}
                classColours[classFile] = { r = r, g = g, b = b, a = (a ~= nil) and a or 1 }
                module:SetSetting("classColours", classColours)
                RefreshAllBars()
            end,
        }
    end
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
                    desc = L["ENABLE_RESOURCE_BARS_MODULE_DESC"],
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
                throttleInterval = {
                    type = "range",
                    name = L["THROTTLE_INTERVAL"],
                    desc = L["THROTTLE_INTERVAL_DESC"],
                    order = 2,
                    min = 0.01,
                    max = 0.5,
                    step = 0.01,
                    get = function()
                        return module:GetSetting("throttleInterval", 0.1)
                    end,
                    set = function(_, value)
                        module:SetSetting("throttleInterval", value)
                    end,
                },
            },
        },
        health = {
            type = "group",
            name = L["Health"],
            order = 2,
            args = {},
        },
        power = {
            type = "group",
            name = L["POWER"],
            order = 3,
            args = {},
        },
        resources = {
            type = "group",
            name = L["Resources"],
            order = 4,
            args = {},
        },
        colours = {
            type = "group",
            name = L["COLOURS"],
            order = 5,
            args = {
                classColours = {
                    type = "group",
                    name = L["CLASS_COLOURS"],
                    order = 1,
                    args = BuildClassColoursOptions(),
                },
                resourceColours = {
                    type = "group",
                    name = L["RESOURCE_COLOURS"],
                    order = 2,
                    args = BuildResourceColoursOptions(),
                },
            },
        },
    }
    
    for i, barId in ipairs(module:GetHealthBarIds()) do
        args.health.args[barId] = {
            type = "group",
            name = GetBarDisplayName(barId),
            order = 10 + i,
            args = BuildBarOptions(barId),
        }
    end
    for i, barId in ipairs(module:GetPowerBarIds()) do
        args.power.args[barId] = {
            type = "group",
            name = GetBarDisplayName(barId),
            order = 10 + i,
            args = BuildBarOptions(barId),
        }
    end
    for i, barId in ipairs(module:GetResourceBarIds()) do
        args.resources.args[barId] = {
            type = "group",
            name = GetBarDisplayName(barId),
            order = 10 + i,
            args = BuildBarOptions(barId),
        }
    end
    
    AceConfig:RegisterOptionsTable("TavernUI.ResourceBars", {
        name = L["RESOURCE_BARS"],
        type = "group",
        args = args,
    })
    
    AceConfigDialog:AddToBlizOptions("TavernUI.ResourceBars", L["RESOURCE_BARS"], "TavernUI")
    
    TavernUI:RegisterModuleOptions("ResourceBars", {
        type = "group",
        name = L["RESOURCE_BARS"],
        args = args,
    }, L["RESOURCE_BARS"])
end

module.Options = Options
