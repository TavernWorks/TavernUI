-- TavernUI DataBar Module

local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:NewModule("DataBar", "AceEvent-3.0")

local LibDogTag = LibStub("LibDogTag-3.0", true)
local LibSharedMedia = LibStub("LibSharedMedia-3.0", true)
local Anchor = LibStub("LibAnchorRegistry-1.0", true)
local LibEditMode = LibStub("LibEditMode-1.0", true)

local defaults = {
    bars = {},
    nextBarId = 1,
}

local defaultBarSettings = {
    width = 200,
    height = 40,
    background = {type = "solid", color = {r = 0.067, g = 0.067, b = 0.067}},
    borders = {
        top = {enabled = true, color = {r = 1, g = 1, b = 1}, width = 1},
        bottom = {enabled = true, color = {r = 1, g = 1, b = 1}, width = 1},
        left = {enabled = true, color = {r = 1, g = 1, b = 1}, width = 1},
        right = {enabled = true, color = {r = 1, g = 1, b = 1}, width = 1},
    },
    textColor = {r = 1, g = 1, b = 1},
    font = nil,
    fontSize = 12,
    growthDirection = "horizontal",
    spacing = 4,
    anchorConfig = nil,
}

TavernUI:RegisterModuleDefaults("DataBar", defaults, false)

-- Datatext Registry System
local datatextRegistry = {}

local function registerDatatext(name, tag, namespace, iconDefaults)
    datatextRegistry[name] = {
        name = name,
        tag = tag,
        namespace = namespace,
        iconDefaults = iconDefaults,
    }
end

function module:RegisterDatatext(name, tag, namespace, iconDefaults)
    registerDatatext(name, tag, namespace, iconDefaults)
end

function module:GetDatatext(name)
    return datatextRegistry[name]
end

function module:GetAllDatatexts()
    return datatextRegistry
end

local function initializeDatatexts()
    -- Simple tag names - namespace is passed to AddFontString separately
    registerDatatext("Gold", "[Gold]", "TavernUI", {enabled = true, source = "preset", texture = "gold", position = "left", textPosition = "right", size = nil, alpha = 1, zoom = 1})
    registerDatatext("Experience", "[XP]", "TavernUI", nil)
    registerDatatext("Experience: Rested", "[RestedXP]", "TavernUI", {enabled = true, source = "preset", texture = "rested", position = "center", textPosition = "over", size = nil, alpha = 1, zoom = 1})
    registerDatatext("Experience: Percent", "[XPPercent]", "TavernUI", nil)
    registerDatatext("Time: Local", "[LocalTime]", "TavernUI", {enabled = true, source = "preset", texture = "time", position = "left", textPosition = "right", size = nil, alpha = 1, zoom = 1})
    registerDatatext("Time: Local (12h)", "[LocalTime12]", "TavernUI", {enabled = true, source = "preset", texture = "time", position = "left", textPosition = "right", size = nil, alpha = 1, zoom = 1})
    registerDatatext("Time: Server", "[ServerTime]", "TavernUI", {enabled = true, source = "preset", texture = "time", position = "left", textPosition = "right", size = nil, alpha = 1, zoom = 1})
    registerDatatext("FPS", "[FPS]", "TavernUI", {enabled = true, source = "preset", texture = "fps", position = "left", textPosition = "right", size = nil, alpha = 1, zoom = 1})
    registerDatatext("Latency", "[Latency]", "TavernUI", {enabled = true, source = "preset", texture = "latency", position = "left", textPosition = "right", size = nil, alpha = 1, zoom = 1})
    registerDatatext("Durability", "[Durability]", "TavernUI", {enabled = true, source = "preset", texture = "durability", position = "left", textPosition = "right", size = nil, alpha = 1, zoom = 1})
    registerDatatext("Friends Online", "[FriendsOnline]", "TavernUI", {enabled = true, source = "preset", texture = "friends", position = "left", textPosition = "right", size = nil, alpha = 1, zoom = 1})
    registerDatatext("Guild Online", "[GuildOnline]", "TavernUI", {enabled = true, source = "preset", texture = "guild", position = "left", textPosition = "right", size = nil, alpha = 1, zoom = 1})
    registerDatatext("Memory Usage", "[MemoryUsage]", "TavernUI", {enabled = true, source = "preset", texture = "memory", position = "left", textPosition = "right", size = nil, alpha = 1, zoom = 1})
    registerDatatext("Reputation", "[Reputation]", "TavernUI", {enabled = true, source = "preset", texture = "reputation", position = "left", textPosition = "right", size = nil, alpha = 1, zoom = 1})
end

local presetValues = {}
local addSlotPresetValues = {}

local function buildPresetValues()
    presetValues = {[""] = "Custom"}
    addSlotPresetValues = {}
    for name in pairs(datatextRegistry) do
        presetValues[name] = name
        addSlotPresetValues[name] = name
    end
end

function module:OnInitialize()
    self.frames = {}
    self.barFrames = {}
    self.slotFrames = {}
    self.slotIcons = {}
    self.slotTexts = {}
    self.anchorHandles = {}
    self.anchorNames = {}
    self.slotAnchorHandles = {}
    self.editModeCallbacks = {}
    self.optionsBuilt = false
    self.tagsRegistered = false
    self.playerName = nil
    self.playerFullName = nil
    self.playerGUID = nil
    
    self:RegisterMessage("TavernUI_ProfileChanged", "OnProfileChanged")
    self:RegisterMessage("TavernUI_CoreEnabled", "OnCoreEnabled")
    
    initializeDatatexts()
    buildPresetValues()
    
    if LibDogTag then
        self:RegisterCustomTags()
        self.tagsRegistered = true
    else
        self:Debug("LibDogTag-3.0 not found, tags will not be registered")
    end
    
    self:InitializeIconPresets()
    self:RegisterOptions()
    
    self:Debug("DataBar initialized")
end

function module:RegisterFrame(name, frame)
    self.frames[name] = frame
end

function module:GetFrame(name)
    return self.frames[name]
end

function module:OnEnable()
    local db = self:GetDB()
    
    if not LibDogTag then
        self:Debug("LibDogTag-3.0 not found, DataBar cannot function")
        return
    end
    
    if not self.tagsRegistered then
        self:RegisterCustomTags()
        self.tagsRegistered = true
    end
    
    if not self.updateFrame then
        local frame = CreateFrame("Frame")
        frame:Show()
        frame.elapsed = 0
        frame:SetScript("OnUpdate", function(frame, delta)
            frame.elapsed = frame.elapsed + delta
            if frame.elapsed >= 0.75 then
                frame.elapsed = 0
                if LibDogTag then
                    self:Debug("Firing TavernUI_DataBar_Update event")
                    LibDogTag:FireEvent("TavernUI_DataBar_Update")
                    for barId, slotTexts in pairs(self.slotTexts) do
                        if slotTexts then
                            for slotIndex, text in pairs(slotTexts) do
                                if text and text:IsVisible() then
                                    LibDogTag:UpdateFontString(text)
                                end
                            end
                        end
                    end
                end
            end
        end)
        self.updateFrame = frame
        self:Debug("Created update frame for periodic tag updates")
    else
        self.updateFrame:Show()
    end
    
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    local playerName = UnitName("player")
    local playerRealm = GetRealmName()
    if playerName then
        self.playerName = playerName
        self.playerFullName = playerName .. "-" .. (playerRealm or "")
    end
    
    for barId, bar in pairs(db.bars) do
        if bar.enabled then
            self:CreateBarFrame(barId, bar)
        end
    end
    
    if LibDogTag then
        LibDogTag:FireEvent("TavernUI_DataBar_Update")
    end
    
    self:Debug("DataBar enabled")
end

function module:OnDisable()
    for barId in pairs(self.barFrames) do
        self:DestroyBar(barId)
    end
    
    if self.updateFrame then
        self.updateFrame:SetScript("OnUpdate", nil)
        self.updateFrame = nil
    end
    
    self:UnregisterAllEvents()
    self:Debug("DataBar disabled")
end

function module:OnProfileChanged()
    self:Debug("Profile changed, recreating bars")
    
    for barId in pairs(self.barFrames) do
        self:DestroyBar(barId)
    end
    
    if self:IsEnabled() then
        local db = self:GetDB()
        for barId, bar in pairs(db.bars) do
            if bar.enabled then
                self:CreateBarFrame(barId, bar)
            end
        end
    end
end

-- Icon Presets

function module:InitializeIconPresets()
    self.iconPresets = {
        gold = "Interface\\Icons\\INV_Misc_Coin_01",
        rested = "Interface\\Icons\\Spell_Shadow_Twilight",
        experience = "Interface\\Icons\\XP_Icon",
        reputation = "Interface\\Icons\\INV_BannerPVP_02",
        time = "Interface\\Icons\\INV_Misc_PocketWatch_01",
        fps = "Interface\\Icons\\Spell_Nature_TimeStop",
        latency = "Interface\\Icons\\Spell_ChargeNegative",
        durability = "Interface\\Icons\\Trade_BlackSmithing",
        friends = "Interface\\Icons\\INV_Letter_20",
        guild = "Interface\\Icons\\INV_BannerPVP_01",
        memory = "Interface\\Icons\\INV_Misc_EngGizmos_19",
    }
end

function module:GetIconPresetTexture(presetName)
    return self.iconPresets[presetName] or "Interface\\BUTTONS\\WHITE8X8"
end

-- Custom LibDogTag Tags

function module:RegisterCustomTags()
    if not LibDogTag then
        return
    end
    
    local namespace = "TavernUI"
    local m = self
    
    -- Simple tags without arguments - these are most reliable
    local simpleTags = {
        {
            name = "Gold",
            code = function()
                return GetCoinTextureString(GetMoney())
            end,
            ret = "string",
            events = "PLAYER_MONEY",
            doc = "Returns the player's gold",
            example = '[Gold] => "1g 23s 45c"',
            category = "TavernUI",
        },
        {
            name = "XP",
            code = function()
                return m:FormatNumber(UnitXP("player"))
            end,
            ret = "string",
            events = "PLAYER_XP_UPDATE",
            doc = "Returns current experience",
            example = '[XP] => "12345"',
            category = "TavernUI",
        },
        {
            name = "XPPercent",
            code = function()
                local current, max = UnitXP("player"), UnitXPMax("player")
                return max > 0 and (math.floor((current / max) * 100) .. "%") or "0%"
            end,
            ret = "string",
            events = "PLAYER_XP_UPDATE",
            doc = "Returns experience as percentage",
            example = '[XPPercent] => "45%"',
            category = "TavernUI",
        },
        {
            name = "RestedXP",
            code = function()
                local rested = GetXPExhaustion()
                return rested and ("|cff00ff00+" .. m:FormatNumber(rested) .. "|r") or ""
            end,
            ret = "string",
            events = "PLAYER_XP_UPDATE;UPDATE_EXHAUSTION",
            doc = "Returns rested XP bonus",
            example = '[RestedXP] => "+1234"',
            category = "TavernUI",
        },
        {
            name = "Reputation",
            code = function()
                local name, standing, minRep, maxRep, value = GetWatchedFactionInfo()
                if name then
                    return name .. ": " .. math.floor(((value - minRep) / (maxRep - minRep)) * 100) .. "%"
                end
                return ""
            end,
            ret = "string",
            events = "UPDATE_FACTION;QUEST_LOG_UPDATE",
            doc = "Returns currently watched faction progress",
            example = '[Reputation] => "Stormwind: 75%"',
            category = "TavernUI",
        },
        {
            name = "LocalTime",
            code = function()
                local dateTime = C_DateAndTime.GetCurrentCalendarTime()
                return string.format("%02d:%02d", dateTime.hour, dateTime.minute)
            end,
            ret = "string",
            events = "TavernUI_DataBar_Update",
            doc = "Returns local time in 24-hour format",
            example = '[LocalTime] => "14:30"',
            category = "TavernUI",
        },
        {
            name = "LocalTime12",
            code = function()
                local dateTime = C_DateAndTime.GetCurrentCalendarTime()
                local hour = dateTime.hour
                local minute = dateTime.minute
                
                local ampm = "AM"
                if hour >= 12 then
                    ampm = "PM"
                end
                if hour == 0 then
                    hour = 12
                elseif hour > 12 then
                    hour = hour - 12
                end
                return string.format("%d:%02d %s", hour, minute, ampm)
            end,
            ret = "string",
            events = "TavernUI_DataBar_Update",
            doc = "Returns local time in 12-hour format with AM/PM",
            example = '[LocalTime12] => "2:30 PM"',
            category = "TavernUI",
        },
        {
            name = "ServerTime",
            code = function()
                local hour, minute = GetGameTime()
                return string.format("%02d:%02d", hour, minute)
            end,
            ret = "string",
            events = "TavernUI_DataBar_Update",
            doc = "Returns server time",
            example = '[ServerTime] => "14:30"',
            category = "TavernUI",
        },
        {
            name = "FPS",
            code = function()
                return math.floor(GetFramerate()) .. " FPS"
            end,
            ret = "string",
            events = "TavernUI_DataBar_Update",
            doc = "Returns current framerate",
            example = '[FPS] => "60 FPS"',
            category = "TavernUI",
        },
        {
            name = "Latency",
            code = function()
                local _, world = GetNetStats()
                return world .. " ms"
            end,
            ret = "string",
            events = "TavernUI_DataBar_Update",
            doc = "Returns world latency",
            example = '[Latency] => "45 ms"',
            category = "TavernUI",
        },
        {
            name = "Durability",
            code = function()
                local total, broken = 0, 0
                for i = 1, 19 do
                    local current, maximum = GetInventoryItemDurability(i)
                    if current and maximum then
                        total = total + maximum
                        broken = broken + (maximum - current)
                    end
                end
                return total > 0 and (math.floor(((total - broken) / total) * 100) .. "%") or "100%"
            end,
            ret = "string",
            events = "UPDATE_INVENTORY_DURABILITY",
            doc = "Returns overall equipment durability",
            example = '[Durability] => "87%"',
            category = "TavernUI",
        },
        {
            name = "FriendsOnline",
            code = function()
                local numFriends = C_FriendList.GetNumFriends()
                local online = 0
                for i = 1, numFriends do
                    local info = C_FriendList.GetFriendInfoByIndex(i)
                    if info and info.connected then
                        online = online + 1
                    end
                end
                return tostring(online)
            end,
            ret = "string",
            events = "FRIENDLIST_UPDATE",
            doc = "Returns online friend count",
            example = '[FriendsOnline] => "5"',
            category = "TavernUI",
        },
        {
            name = "GuildOnline",
            code = function()
                return IsInGuild() and tostring(select(2, GetNumGuildMembers())) or "0"
            end,
            ret = "string",
            events = "GUILD_ROSTER_UPDATE",
            doc = "Returns online guild member count",
            example = '[GuildOnline] => "12"',
            category = "TavernUI",
        },
        {
            name = "MemoryUsage",
            code = function()
                return m:FormatMemory(collectgarbage("count"))
            end,
            ret = "string",
            events = "TavernUI_DataBar_Update",
            doc = "Returns addon memory usage",
            example = '[MemoryUsage] => "45.2 MB"',
            category = "TavernUI",
        },
    }
    
    for _, tagData in ipairs(simpleTags) do
        local success, err = pcall(function()
            LibDogTag:AddTag(namespace, tagData.name, {
                code = tagData.code,
                ret = tagData.ret,
                events = tagData.events,
                doc = tagData.doc,
                example = tagData.example,
                category = tagData.category,
            })
        end)
        if success then
            self:Debug("Registered tag: %s", tagData.name)
        else
            self:Debug("Failed to register tag %s: %s", tagData.name, tostring(err))
        end
    end
    self:Debug("Registered %d custom tags in namespace %s", #simpleTags, namespace)
end

function module:FormatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    else
        return tostring(num)
    end
end

function module:FormatMemory(kb)
    if kb >= 1024 then
        return string.format("%.1f MB", kb / 1024)
    else
        return string.format("%.0f KB", kb)
    end
end


-- Helper Functions

local function ensureBarAnchorConfig(bar, defaults)
    if not bar.anchorConfig then
        bar.anchorConfig = defaults or {
            target = "UIParent",
            point = "CENTER",
            relativePoint = "CENTER",
            offsetX = 0,
            offsetY = 0,
        }
    end
    return bar.anchorConfig
end

local function ensureDualAnchorConfig(bar)
    if not bar.anchorConfig then
        bar.anchorConfig = {
            target = "UIParent",
            point = "LEFT",
            relativePoint = "LEFT",
            offsetX = 0,
            offsetY = 0,
            useDualAnchor = true,
            target2 = "UIParent",
            point2 = "RIGHT",
            relativePoint2 = "RIGHT",
            offsetX2 = 0,
            offsetY2 = 0,
        }
    else
        bar.anchorConfig.useDualAnchor = true
        if not bar.anchorConfig.target2 then
            bar.anchorConfig.target2 = "UIParent"
            bar.anchorConfig.point2 = "RIGHT"
            bar.anchorConfig.relativePoint2 = "RIGHT"
            bar.anchorConfig.offsetX2 = 0
            bar.anchorConfig.offsetY2 = 0
        end
    end
    return bar.anchorConfig
end

local function ensureSlotAnchorConfig(slot, barAnchorName)
    if not slot.anchorConfig then
        slot.anchorConfig = {
            target = barAnchorName,
            point = "CENTER",
            relativePoint = "CENTER",
            offsetX = 0,
            offsetY = 0,
        }
    else
        slot.anchorConfig.target = barAnchorName
    end
    return slot.anchorConfig
end

local function createAnchorOptionSetter(barId, bar, field, default)
    return function(_, value)
        ensureBarAnchorConfig(bar)
        bar.anchorConfig[field] = value
        module:UpdateBar(barId)
    end
end

local function createDualAnchorOptionSetter(barId, bar, field, default)
    return function(_, value)
        ensureDualAnchorConfig(bar)
        bar.anchorConfig[field] = value
        module:UpdateBar(barId)
    end
end

local function createSlotAnchorOptionSetter(barId, slot, barAnchorName, field, default)
    return function(_, value)
        ensureSlotAnchorConfig(slot, barAnchorName)
        slot.anchorConfig[field] = value
        module:UpdateBar(barId)
    end
end

local function createSimpleOptionSetter(barId, obj, field, updateFunc)
    return function(_, value)
        obj[field] = value
        module:UpdateBar(barId)
    end
end

local function ensureIconConfig(slot)
    if not slot.icon then
        slot.icon = {
            enabled = false,
            texture = "",
            source = "file",
            size = nil,
            position = "left",
            textPosition = "right",
            alpha = 1,
            zoom = 1,
            borders = {},
        }
    end
    return slot.icon
end

local function createOption(t)
    return t
end

-- Options UI

function module:RegisterOptions()
    if not self.optionsBuilt then
        self:BuildOptions()
        self.optionsBuilt = true
    end
end

function module:RefreshOptions(rebuild)
    if rebuild then
        self.optionsBuilt = false
        self:BuildOptions()
        self.optionsBuilt = true
    end
    LibStub("AceConfigRegistry-3.0"):NotifyChange("TavernUI")
end

function module:BuildOptions()
    local options = {
        type = "group",
        name = "DataBar",
        childGroups = "tab",
        args = {
            bars = {
                type = "group",
                name = "Bars",
                desc = "Configure your information bars",
                order = 10,
                childGroups = "select",
                args = {},
            },
        },
    }
    
    self:BuildBarListOptions(options.args.bars.args)
    
    TavernUI:RegisterModuleOptions("DataBar", options, "DataBar")
end

function module:BuildBarListOptions(args)
    local db = self:GetDB()
    
    args.addBar = {
        type = "execute",
        name = "Create New Bar",
        desc = "Create a new information bar",
        order = 1,
        func = function()
            self:CreateBar("New Bar")
            self:RefreshOptions(true)
        end,
    }
    
    local barIds = {}
    for barId in pairs(db.bars) do
        table.insert(barIds, barId)
    end
    table.sort(barIds)
    
    for i, barId in ipairs(barIds) do
        local bar = db.bars[barId]
        local barName = bar.name or ("Bar " .. barId)
        
        local barArgs = {
            type = "group",
            name = barName,
            desc = string.format("Configure %s", barName),
            order = (i + 1) * 10,
            childGroups = "tab",
            args = {},
        }
        
        local generalArgs = {
            type = "group",
            name = "General",
            order = 10,
            args = {},
        }
        
        generalArgs.args.enabled = {
            type = "toggle",
            name = "Enabled",
            desc = "Enable or disable this bar",
            order = 1,
            get = function() return bar.enabled end,
            set = function(_, value)
                bar.enabled = value
                self:UpdateBar(barId)
            end,
        }
        
        generalArgs.args.name = {
            type = "input",
            name = "Name",
            desc = "Name of this bar",
            order = 2,
            get = function() return bar.name or "" end,
            set = function(_, value)
                bar.name = value
                if Anchor and self.anchorNames[barId] then
                    Anchor:UpdateMetadata(self.anchorNames[barId], {
                        displayName = value,
                    })
                end
                self:RefreshOptions(true)
            end,
        }
        
        generalArgs.args.delete = {
            type = "execute",
            name = "Delete Bar",
            desc = "Permanently delete this bar",
            order = 3,
            confirm = true,
            func = function()
                self:DeleteBar(barId)
                self:RefreshOptions(true)
            end,
        }
        
        barArgs.args.general = generalArgs
        barArgs.args.slots = {
            type = "group",
            name = "Slots",
            desc = "Configure datatext slots for this bar",
            order = 20,
            args = {},
        }
        barArgs.args.styling = {
            type = "group",
            name = "Styling",
            desc = "Configure the appearance of this bar",
            order = 30,
            args = {},
        }
        barArgs.args.position = {
            type = "group",
            name = "Position",
            desc = "Configure the position and anchoring of this bar",
            order = 40,
            args = {},
        }
        
        self:BuildSlotOptions(barArgs.args.slots.args, barId, bar)
        self:BuildStylingOptions(barArgs.args.styling.args, barId, bar)
        self:BuildPositionOptions(barArgs.args.position.args, barId, bar)
        
        args["bar" .. barId] = barArgs
    end
end

function module:BuildSlotOptions(args, barId, bar)
    args.addSlot = {
        type = "execute",
        name = "Add Empty Slot",
        desc = "Add a new empty slot to this bar",
        order = 1,
        func = function()
            self:AddSlot(barId, nil, "", "Base")
            self:RefreshOptions(true)
        end,
    }
    
    args.addSlotPreset = {
        type = "select",
        name = "Add Slot from Preset",
        desc = "Add a new slot using a preset datatext",
        order = 2,
        values = addSlotPresetValues,
        get = function() return "" end,
        set = function(_, value)
            if value == "" then return end
            local datatext = datatextRegistry[value]
            if datatext then
                local slot = {
                    tag = datatext.tag,
                    namespace = datatext.namespace,
                    width = nil,
                    textColor = nil,
                    anchorConfig = nil,
                    icon = datatext.iconDefaults and (type(datatext.iconDefaults) == "table" and {unpack(datatext.iconDefaults)} or datatext.iconDefaults) or nil,
                }
                table.insert(bar.slots, slot)
                self:UpdateBar(barId)
                self:RefreshOptions(true)
            end
        end,
    }
    
    args.spacer1 = {
        type = "description",
        name = " ",
        order = 3,
    }
    
    for slotIndex, slot in ipairs(bar.slots) do
        local slotArgs = {
            type = "group",
            name = string.format("Slot %d", slotIndex),
            desc = string.format("Configure slot %d", slotIndex),
            order = (slotIndex + 1) * 10,
            args = {},
        }
        
        slotArgs.args.preset = {
            type = "select",
            name = "Preset",
            desc = "Select a preset datatext configuration",
            order = 1,
            values = presetValues,
            get = function()
                for name, datatext in pairs(datatextRegistry) do
                    if slot.tag == datatext.tag and slot.namespace == datatext.namespace then
                        return name
                    end
                end
                return ""
            end,
            set = function(_, value)
                if value == "" then return end
                local datatext = datatextRegistry[value]
                if datatext then
                    slot.tag = datatext.tag
                    slot.namespace = datatext.namespace
                    if datatext.iconDefaults then
                        slot.icon = type(datatext.iconDefaults) == "table" and {unpack(datatext.iconDefaults)} or datatext.iconDefaults
                    end
                    self:UpdateBar(barId)
                end
            end,
        }
        
        slotArgs.args.tag = {
            type = "input",
            name = "Tag",
            desc = "LibDogTag tag string (e.g., [Gold:Total])",
            order = 2,
            get = function() return slot.tag or "" end,
            set = function(_, value)
                slot.tag = value
                self:UpdateBar(barId)
            end,
        }
        
        slotArgs.args.namespace = {
            type = "select",
            name = "Namespace",
            desc = "Tag namespace",
            order = 3,
            values = {Base = "Base", TavernUI = "TavernUI"},
            get = function() return slot.namespace or "Base" end,
            set = function(_, value)
                slot.namespace = value
                self:UpdateBar(barId)
            end,
        }
        
        slotArgs.args.width = {
            type = "input",
            name = "Width",
            desc = "Slot width (leave empty for auto)",
            order = 4,
            get = function() return slot.width and tostring(slot.width) or "" end,
            set = function(_, value)
                if value == "" or value == "nil" then
                    slot.width = nil
                else
                    slot.width = tonumber(value)
                end
                self:UpdateBar(barId)
            end,
        }
        
        slotArgs.args.textColor = {
            type = "color",
            name = "Text Color",
            desc = "Override text color for this slot",
            order = 5,
            hasAlpha = false,
            get = function()
                if slot.textColor then
                    return slot.textColor.r, slot.textColor.g, slot.textColor.b
                end
                return 1, 1, 1
            end,
            set = function(_, r, g, b)
                slot.textColor = {r = r, g = g, b = b}
                self:UpdateBar(barId)
            end,
        }
        
        slotArgs.args.spacer1 = {
            type = "description",
            name = " ",
            order = 10,
        }
        
        slotArgs.args.iconHeader = {
            type = "header",
            name = "Icon Settings",
            order = 11,
        }
        
        self:BuildIconOptions(slotArgs.args, barId, slotIndex, slot, bar, 12)
        self:BuildSlotPositionOptions(slotArgs.args, barId, slotIndex, slot, bar)
        
        slotArgs.args.spacer2 = {
            type = "description",
            name = " ",
            order = 90,
        }
        
        slotArgs.args.remove = {
            type = "execute",
            name = "Remove Slot",
            desc = "Remove this slot from the bar",
            order = 100,
            confirm = true,
            func = function()
                self:RemoveSlot(barId, slotIndex)
                self:RefreshOptions(true)
            end,
        }
        
        args["slot" .. slotIndex] = slotArgs
    end
end

function module:BuildIconOptions(args, barId, slotIndex, slot, bar, startOrder)
    startOrder = startOrder or 10
    local icon = ensureIconConfig(slot)
    
    local iconFieldMap = {
        iconEnabled = "enabled",
        iconSource = "source",
        iconTexture = "texture",
        iconPosition = "position",
        textPosition = "textPosition",
        iconAlpha = "alpha",
        iconZoom = "zoom",
    }
    
    local iconOptions = {
        {key = "iconEnabled", type = "toggle", name = "Enable Icon", desc = "Show an icon for this slot", get = function() return icon.enabled end},
        {key = "iconSource", type = "select", name = "Icon Source", desc = "Where to get the icon texture from", values = {file = "File Path", libsharedmedia = "LibSharedMedia", preset = "Preset", wow = "WoW Texture"}, get = function() return icon.source or "file" end},
        {key = "iconTexture", type = "input", name = "Icon Texture", desc = "Texture path or preset name", get = function() return icon.texture or "" end},
        {key = "iconPosition", type = "select", name = "Icon Position", desc = "Where to position the icon relative to the text", values = {left = "Left", right = "Right", center = "Center", background = "Background"}, get = function() return icon.position or "left" end},
        {key = "textPosition", type = "select", name = "Text Position", desc = "Where to position the text relative to the icon", values = {over = "Over", left = "Left", right = "Right", below = "Below"}, get = function() return icon.textPosition or "right" end},
        {key = "iconAlpha", type = "range", name = "Icon Alpha", desc = "Icon transparency", min = 0, max = 1, step = 0.1, get = function() return icon.alpha or 1 end},
        {key = "iconZoom", type = "range", name = "Icon Zoom", desc = "Icon zoom level", min = 0.1, max = 2.0, step = 0.1, get = function() return icon.zoom or 1 end},
    }
    
    for i, opt in ipairs(iconOptions) do
        local optDef = {type = opt.type, name = opt.name, desc = opt.desc, order = startOrder + i - 1,
            get = opt.get, set = createSimpleOptionSetter(barId, icon, iconFieldMap[opt.key])}
        if opt.values then optDef.values = opt.values end
        if opt.min then optDef.min, optDef.max, optDef.step = opt.min, opt.max, opt.step end
        args[opt.key] = optDef
    end
    
    args.iconSize = {type = "input", name = "Icon Size", desc = "Icon size in pixels (leave empty to use bar height)", order = startOrder + 3,
        get = function() return icon.size and tostring(icon.size) or "" end,
        set = function(_, value)
            icon.size = (value == "" or value == "nil") and nil or tonumber(value)
            self:UpdateBar(barId)
        end}
end

function module:BuildStylingOptions(args, barId, bar)
    local function addHeader(name, order)
        args[name .. "Header"] = {type = "header", name = name, order = order}
    end
    
    local function addRange(key, name, desc, order, min, max, step)
        args[key] = {type = "range", name = name, desc = desc, order = order, min = min, max = max, step = step,
            get = function() return bar[key] end, set = createSimpleOptionSetter(barId, bar, key)}
    end
    
    local function addColor(key, name, desc, order, getColor, setColor)
        args[key] = {type = "color", name = name, desc = desc, order = order, hasAlpha = false,
            get = getColor, set = setColor}
    end
    
    addHeader("Size", 10)
    addRange("width", "Width", "Bar width in pixels", 11, 50, 1000, 1)
    addRange("height", "Height", "Bar height in pixels", 12, 20, 200, 1)
    
    addHeader("Background", 20)
    args.backgroundType = {type = "select", name = "Background Type", desc = "Type of background to display", order = 21,
        values = {solid = "Solid Color", texture = "Texture"},
        get = function() return bar.background.type or "solid" end,
        set = createSimpleOptionSetter(barId, bar.background, "type")}
    addColor("backgroundColor", "Background Color", "Background color", 22,
        function() local c = bar.background.color; return c.r, c.g, c.b end,
        function(_, r, g, b) bar.background.color = {r = r, g = g, b = b}; self:UpdateBar(barId) end)
    
    addHeader("Text", 30)
    addRange("fontSize", "Font Size", "Font size for datatext", 31, 8, 32, 1)
    addColor("textColor", "Text Color", "Default text color for datatexts", 32,
        function() local c = bar.textColor; return c.r, c.g, c.b end,
        function(_, r, g, b) bar.textColor = {r = r, g = g, b = b}; self:UpdateBar(barId) end)
    
    addHeader("Layout", 40)
    args.growthDirection = {type = "select", name = "Growth Direction", desc = "Direction slots grow in", order = 41,
        values = {horizontal = "Horizontal", vertical = "Vertical"},
        get = function() return bar.growthDirection end,
        set = createSimpleOptionSetter(barId, bar, "growthDirection")}
    addRange("spacing", "Spacing", "Spacing between slots", 42, 0, 50, 1)
end

local anchorPointValues = {
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

local function addAnchorOption(args, module, barId, bar, prefix, order, field, default, isDual)
    local name = prefix .. (field:sub(1,1):upper() .. field:sub(2))
    local getter = function() return bar.anchorConfig and bar.anchorConfig[field] or default end
    local setter = isDual and createDualAnchorOptionSetter(barId, bar, field, default) or createAnchorOptionSetter(barId, bar, field, default)
    local disabled = isDual and function() return not (bar.anchorConfig and bar.anchorConfig.useDualAnchor) end or nil
    
    if field == "target" or field == "target2" then
        args[prefix .. field] = {
            type = "input",
            name = name,
            desc = "Target frame name (e.g., UIParent or registered anchor name)",
            order = order,
            disabled = disabled,
            get = getter,
            set = function(_, value)
                if isDual then
                    ensureDualAnchorConfig(bar)
                else
                    ensureBarAnchorConfig(bar, {target = value, point = "CENTER", relativePoint = "CENTER", offsetX = 0, offsetY = 0})
                end
                bar.anchorConfig[field] = value
                module:UpdateBar(barId)
            end,
        }
    elseif field == "point" or field == "point2" or field:find("Point") then
        local descText = "Point on the bar to anchor"
        if field == "relativePoint" or field == "relativePoint2" then
            descText = "Point on the target to anchor to"
        end
        args[prefix .. field] = {
            type = "select",
            name = name,
            desc = descText,
            order = order,
            disabled = disabled,
            values = anchorPointValues,
            get = getter,
            set = setter,
        }
    else
        args[prefix .. field] = {
            type = "range",
            name = name,
            desc = (field:find("X") and "Horizontal" or "Vertical") .. " offset",
            order = order,
            min = -500,
            max = 500,
            step = 1,
            disabled = disabled,
            get = getter,
            set = setter,
        }
    end
end

function module:BuildPositionOptions(args, barId, bar)
    if not Anchor then
        args.noAnchor = {type = "description", name = "LibAnchorRegistry not available", order = 1}
        return
    end
    
    args.useDualAnchor = {
        type = "toggle",
        name = "Use Dual Anchor",
        desc = "Enable dual anchor mode to stretch the bar between two points",
        order = 1,
        get = function() return bar.anchorConfig and bar.anchorConfig.useDualAnchor or false end,
        set = function(_, value)
            if value then ensureDualAnchorConfig(bar) else
                if bar.anchorConfig then bar.anchorConfig.useDualAnchor = false end
            end
            self:UpdateBar(barId)
        end,
    }
    
    args.anchorHeader = {type = "header", name = "First Anchor Point", order = 10}
    addAnchorOption(args, self, barId, bar, "anchor", 11, "target", "UIParent", false)
    addAnchorOption(args, self, barId, bar, "anchor", 12, "point", "CENTER", false)
    addAnchorOption(args, self, barId, bar, "relative", 13, "relativePoint", "CENTER", false)
    addAnchorOption(args, self, barId, bar, "", 14, "offsetX", 0, false)
    addAnchorOption(args, self, barId, bar, "", 15, "offsetY", 0, false)
    
    args.dualAnchorHeader = {type = "header", name = "Second Anchor Point", order = 20, disabled = function() return not (bar.anchorConfig and bar.anchorConfig.useDualAnchor) end}
    addAnchorOption(args, self, barId, bar, "anchor", 21, "target2", "UIParent", true)
    addAnchorOption(args, self, barId, bar, "anchor", 22, "point2", "RIGHT", true)
    addAnchorOption(args, self, barId, bar, "relative", 23, "relativePoint2", "RIGHT", true)
    addAnchorOption(args, self, barId, bar, "", 24, "offsetX2", 0, true)
    addAnchorOption(args, self, barId, bar, "", 25, "offsetY2", 0, true)
    
    args.clearAnchor = {
        type = "execute",
        name = "Clear Anchor",
        desc = "Remove all anchor configuration",
        order = 100,
        func = function() bar.anchorConfig = nil; self:UpdateBar(barId) end,
    }
end

function module:BuildSlotPositionOptions(args, barId, slotIndex, slot, bar)
    if not Anchor then
        args.noAnchor = {
            type = "description",
            name = "LibAnchorRegistry not available",
            order = 1,
        }
        return
    end
    
    local barAnchorName = self.anchorNames[barId] or ("TavernUI.DataBar" .. barId)
    
    args.anchorPoint = {
        type = "select",
        name = "Anchor Point",
        desc = "Point on the slot to anchor",
        order = 1,
        values = anchorPointValues,
        get = function() return slot.anchorConfig and slot.anchorConfig.point or "CENTER" end,
        set = createSlotAnchorOptionSetter(barId, slot, barAnchorName, "point", "CENTER"),
    }
    
    args.relativePoint = {
        type = "select",
        name = "Relative Point",
        desc = "Point on the bar to anchor to",
        order = 2,
        values = anchorPointValues,
        get = function() return slot.anchorConfig and slot.anchorConfig.relativePoint or "CENTER" end,
        set = createSlotAnchorOptionSetter(barId, slot, barAnchorName, "relativePoint", "CENTER"),
    }
    
    args.offsetX = {
        type = "range",
        name = "Offset X",
        desc = "Horizontal offset",
        order = 3,
        min = -500,
        max = 500,
        step = 1,
        get = function() return slot.anchorConfig and slot.anchorConfig.offsetX or 0 end,
        set = createSlotAnchorOptionSetter(barId, slot, barAnchorName, "offsetX", 0),
    }
    
    args.offsetY = {
        type = "range",
        name = "Offset Y",
        desc = "Vertical offset",
        order = 4,
        min = -500,
        max = 500,
        step = 1,
        get = function() return slot.anchorConfig and slot.anchorConfig.offsetY or 0 end,
        set = createSlotAnchorOptionSetter(barId, slot, barAnchorName, "offsetY", 0),
    }
    
    args.clearAnchor = {
        type = "execute",
        name = "Clear Anchor",
        desc = "Remove anchor configuration and use auto layout",
        order = 5,
        func = function()
            slot.anchorConfig = nil
            self:UpdateBar(barId)
        end,
    }
end

function module:OnCoreEnabled()
    self:Debug("Core enabled notification received")
end

function module:PLAYER_ENTERING_WORLD()
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    
    local playerName = UnitName("player")
    local playerRealm = GetRealmName()
    if playerName then
        self.playerName = playerName
        self.playerFullName = playerName .. "-" .. (playerRealm or "")
        self.playerGUID = UnitGUID("player")
    end
    
    local db = self:GetDB()
    for barId, bar in pairs(db.bars) do
        if bar.enabled and self.barFrames[barId] then
            self:UpdateBar(barId)
        end
    end
    
    if LibDogTag then
        LibDogTag:FireEvent("TavernUI_DataBar_Update")
    end
end

-- Bar Management

function module:CreateBar(name)
    local db = self:GetDB()
    local barId = db.nextBarId
    db.nextBarId = db.nextBarId + 1
    
    local bar = {
        id = barId,
        name = name or ("Bar " .. barId),
        enabled = true,
        slots = {},
    }
    
    for k, v in pairs(defaultBarSettings) do
        bar[k] = v
    end
    
    db.bars[barId] = bar
    
    if self:IsEnabled() then
        self:CreateBarFrame(barId, bar)
    end
    
    return barId
end

function module:DeleteBar(barId)
    self:DestroyBar(barId)
    
    local db = self:GetDB()
    db.bars[barId] = nil
end

function module:GetBar(barId)
    local db = self:GetDB()
    return db.bars[barId]
end

function module:GetAllBars()
    local db = self:GetDB()
    return db.bars
end

function module:CreateBarFrame(barId, bar)
    if self.barFrames[barId] then
        return
    end
    
    local frame = CreateFrame("Frame", "TavernUI_DataBar_" .. barId, UIParent)
    frame:SetSize(bar.width, bar.height)
    
    self.barFrames[barId] = frame
    self:RegisterFrame("bar" .. barId, frame)
    self.slotFrames[barId] = {}
    self.slotIcons[barId] = {}
    self.slotTexts[barId] = {}
    self.slotAnchorHandles[barId] = {}
    
    if Anchor then
        local anchorName = "TavernUI.DataBar" .. barId
        Anchor:Register(anchorName, frame, {
            displayName = bar.name,
            category = "bars",
        })
        self.anchorNames[barId] = anchorName
        
        if bar.anchorConfig and bar.anchorConfig.target then
            local target = bar.anchorConfig.target
            
            if target == "UIParent" or target == "" then
                local point = bar.anchorConfig.point or "CENTER"
                local relativePoint = bar.anchorConfig.relativePoint or "CENTER"
                local offsetX = bar.anchorConfig.offsetX or 0
                local offsetY = bar.anchorConfig.offsetY or 0
                frame:SetPoint(point, UIParent, relativePoint, offsetX, offsetY)
            else
                local config = {
                    target = target,
                    point = bar.anchorConfig.point or "CENTER",
                    relativePoint = bar.anchorConfig.relativePoint or "CENTER",
                    offsetX = bar.anchorConfig.offsetX or 0,
                    offsetY = bar.anchorConfig.offsetY or 0,
                    fallback = "UIParent",
                    fallbackPoint = "CENTER",
                }
                local handle = Anchor:AnchorTo(frame, config)
                self.anchorHandles[barId] = handle
                
                Anchor:Subscribe(anchorName, function(event)
                    if event == "MOVED" and handle then
                        local savedConfig = handle:GetConfig()
                        if savedConfig then
                            bar.anchorConfig = savedConfig
                        end
                    end
                end)
            end
        else
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    
    self:UpdateBarStyling(barId, bar)
    self:UpdateBarSlots(barId, bar)
    
    if LibEditMode then
        local editModeName = "TavernUI_DataBar_" .. barId
        LibEditMode:RegisterFrame(editModeName, frame, {
            name = bar.name,
            category = "TavernUI",
            anchorPoint = "CENTER",
            onEditModeExit = function()
                local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
                if relativeTo == UIParent then
                    if not bar.anchorConfig then
                        bar.anchorConfig = {
                            target = "UIParent",
                            point = point,
                            relativePoint = relativePoint,
                            offsetX = xOfs,
                            offsetY = yOfs,
                        }
                    else
                        bar.anchorConfig.target = "UIParent"
                        bar.anchorConfig.point = point
                        bar.anchorConfig.relativePoint = relativePoint
                        bar.anchorConfig.offsetX = xOfs
                        bar.anchorConfig.offsetY = yOfs
                    end
                    self:UpdateBar(barId)
                end
            end,
        })
        self.editModeCallbacks[barId] = editModeName
    end
end

function module:DestroyBar(barId)
    if not self.barFrames[barId] then
        return
    end
    
    if self.anchorHandles[barId] then
        self.anchorHandles[barId]:Release()
        self.anchorHandles[barId] = nil
    end
    
    if Anchor and self.anchorNames[barId] then
        Anchor:Unregister(self.anchorNames[barId])
        self.anchorNames[barId] = nil
    end
    
    if LibEditMode and self.editModeCallbacks[barId] then
        LibEditMode:UnregisterFrame(self.editModeCallbacks[barId])
        self.editModeCallbacks[barId] = nil
    end
    
    for slotIndex, slotFrame in pairs(self.slotFrames[barId] or {}) do
        if slotFrame then
            slotFrame:Hide()
            slotFrame:SetParent(nil)
        end
    end
    
    if self.barFrames[barId] then
        self.barFrames[barId]:Hide()
        self.barFrames[barId]:SetParent(nil)
    end
    
    self.barFrames[barId] = nil
    self.slotFrames[barId] = nil
    self.slotIcons[barId] = nil
    self.slotTexts[barId] = nil
    self.slotAnchorHandles[barId] = nil
end

function module:UpdateBar(barId)
    local bar = self:GetBar(barId)
    if not bar then
        return
    end
    
    if not self.barFrames[barId] then
        if bar.enabled then
            self:CreateBarFrame(barId, bar)
        end
        return
    end
    
    local frame = self.barFrames[barId]
    
    if bar.enabled then
        self:Debug("UpdateBar: Showing bar %d with %d slots", barId, #bar.slots)
        frame:Show()
        frame:SetSize(bar.width, bar.height)
        self:UpdateBarPosition(barId, bar)
        self:UpdateBarStyling(barId, bar)
        self:UpdateBarSlots(barId, bar)
    else
        self:Debug("UpdateBar: Hiding bar %d", barId)
        frame:Hide()
    end
end

function module:UpdateBarPosition(barId, bar)
    local frame = self.barFrames[barId]
    if not frame then
        return
    end
    
    if not bar then
        bar = self:GetBar(barId)
    end
    
    if not bar then
        return
    end
    
    if LibEditMode and LibEditMode:IsEditModeActive() then
        return
    end
    
    if self.anchorHandles[barId] then
        self.anchorHandles[barId]:Release()
        self.anchorHandles[barId] = nil
    end
    
    if bar.anchorConfig and bar.anchorConfig.target then
        local target = bar.anchorConfig.target
        
        if bar.anchorConfig.useDualAnchor and bar.anchorConfig.target2 then
            local target2 = bar.anchorConfig.target2
            
            if (target == "UIParent" or target == "") and (target2 == "UIParent" or target2 == "") then
                frame:ClearAllPoints()
                local point1 = bar.anchorConfig.point or "LEFT"
                local relativePoint1 = bar.anchorConfig.relativePoint or "LEFT"
                local offsetX1 = bar.anchorConfig.offsetX or 0
                local offsetY1 = bar.anchorConfig.offsetY or 0
                local point2 = bar.anchorConfig.point2 or "RIGHT"
                local relativePoint2 = bar.anchorConfig.relativePoint2 or "RIGHT"
                local offsetX2 = bar.anchorConfig.offsetX2 or 0
                local offsetY2 = bar.anchorConfig.offsetY2 or 0
                
                frame:SetPoint(point1, UIParent, relativePoint1, offsetX1, offsetY1)
                frame:SetPoint(point2, UIParent, relativePoint2, offsetX2, offsetY2)
            elseif Anchor then
                local config = {
                    target = target,
                    point = bar.anchorConfig.point or "LEFT",
                    relativePoint = bar.anchorConfig.relativePoint or "LEFT",
                    offsetX = bar.anchorConfig.offsetX or 0,
                    offsetY = bar.anchorConfig.offsetY or 0,
                    target2 = target2,
                    point2 = bar.anchorConfig.point2 or "RIGHT",
                    relativePoint2 = bar.anchorConfig.relativePoint2 or "RIGHT",
                    offsetX2 = bar.anchorConfig.offsetX2 or 0,
                    offsetY2 = bar.anchorConfig.offsetY2 or 0,
                }
                
                local handle = Anchor:AnchorDual(frame, config)
                self.anchorHandles[barId] = handle
            else
                frame:ClearAllPoints()
                frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            end
        elseif target == "UIParent" or target == "" then
            frame:ClearAllPoints()
            local point = bar.anchorConfig.point or "CENTER"
            local relativePoint = bar.anchorConfig.relativePoint or "CENTER"
            local offsetX = bar.anchorConfig.offsetX or 0
            local offsetY = bar.anchorConfig.offsetY or 0
            frame:SetPoint(point, UIParent, relativePoint, offsetX, offsetY)
        elseif Anchor then
            local config = {
                target = target,
                point = bar.anchorConfig.point or "CENTER",
                relativePoint = bar.anchorConfig.relativePoint or "CENTER",
                offsetX = bar.anchorConfig.offsetX or 0,
                offsetY = bar.anchorConfig.offsetY or 0,
                fallback = "UIParent",
                fallbackPoint = "CENTER",
            }
            local handle = Anchor:AnchorTo(frame, config)
            self.anchorHandles[barId] = handle
        else
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    else
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function module:UpdateBarStyling(barId, bar)
    local frame = self.barFrames[barId]
    if not frame then
        return
    end
    
    if not bar then
        bar = self:GetBar(barId)
    end
    
    if not bar then
        return
    end
    
    if bar.background.type == "solid" then
        if not frame.bg then
            frame.bg = frame:CreateTexture(nil, "BACKGROUND")
        end
        frame.bg:SetAllPoints(frame)
        local c = bar.background.color
        frame.bg:SetColorTexture(c.r, c.g, c.b, 1)
    elseif bar.background.type == "texture" and LibSharedMedia then
        if not frame.bg then
            frame.bg = frame:CreateTexture(nil, "BACKGROUND")
        end
        frame.bg:SetAllPoints(frame)
        local texture = LibSharedMedia:Fetch("statusbar", bar.background.texture)
        if texture then
            frame.bg:SetTexture(texture)
        else
            local c = bar.background.color or {r = 0.067, g = 0.067, b = 0.067}
            frame.bg:SetColorTexture(c.r, c.g, c.b, 1)
        end
    end
    
    if not frame.borders then
        frame.borders = {}
    end
    
    local borderConfigs = {
        top = {points = {{"TOPLEFT", frame, "TOPLEFT"}, {"TOPRIGHT", frame, "TOPRIGHT"}}, setSize = function(b, w) b:SetHeight(w) end},
        bottom = {points = {{"BOTTOMLEFT", frame, "BOTTOMLEFT"}, {"BOTTOMRIGHT", frame, "BOTTOMRIGHT"}}, setSize = function(b, w) b:SetHeight(w) end},
        left = {points = {{"TOPLEFT", frame, "TOPLEFT"}, {"BOTTOMLEFT", frame, "BOTTOMLEFT"}}, setSize = function(b, w) b:SetWidth(w) end},
        right = {points = {{"TOPRIGHT", frame, "TOPRIGHT"}, {"BOTTOMRIGHT", frame, "BOTTOMRIGHT"}}, setSize = function(b, w) b:SetWidth(w) end},
    }
    
    for side, config in pairs(bar.borders) do
        if config.enabled then
            if not frame.borders[side] then
                frame.borders[side] = frame:CreateTexture(nil, "BORDER")
            end
            local border = frame.borders[side]
            local c = config.color
            border:SetColorTexture(c.r, c.g, c.b, 1)
            
            local borderConfig = borderConfigs[side]
            if borderConfig then
                for _, pointData in ipairs(borderConfig.points) do
                    border:SetPoint(pointData[1], pointData[2], pointData[3], 0, 0)
                end
                borderConfig.setSize(border, config.width)
            end
            border:Show()
        elseif frame.borders[side] then
            frame.borders[side]:Hide()
        end
    end
end

-- Slot Management

function module:AddSlot(barId, slotIndex, tag, namespace)
    local bar = self:GetBar(barId)
    if not bar then
        return
    end
    
    slotIndex = slotIndex or (#bar.slots + 1)
    
    local slot = {
        tag = tag or "",
        namespace = namespace or "Base",
        width = nil,
        textColor = nil,
        anchorConfig = nil,
        icon = nil,
    }
    
    table.insert(bar.slots, slotIndex, slot)
    
    if self:IsEnabled() then
        if not self.barFrames[barId] and bar.enabled then
            self:CreateBarFrame(barId, bar)
        end
        self:UpdateBar(barId)
    end
end

function module:RemoveSlot(barId, slotIndex)
    local bar = self:GetBar(barId)
    if not bar or not bar.slots[slotIndex] then
        return
    end
    
    table.remove(bar.slots, slotIndex)
    
    if self.slotFrames[barId] and self.slotFrames[barId][slotIndex] then
        local slotFrame = self.slotFrames[barId][slotIndex]
        slotFrame:Hide()
        slotFrame:SetParent(nil)
        self.slotFrames[barId][slotIndex] = nil
        self.slotIcons[barId][slotIndex] = nil
        self.slotTexts[barId][slotIndex] = nil
    end
    
    if self:IsEnabled() then
        self:UpdateBar(barId)
    end
end

function module:MoveSlot(barId, fromIndex, toIndex)
    local bar = self:GetBar(barId)
    if not bar or not bar.slots[fromIndex] then
        return
    end
    
    local slot = table.remove(bar.slots, fromIndex)
    table.insert(bar.slots, toIndex, slot)
    
    if self:IsEnabled() then
        self:UpdateBar(barId)
    end
end

function module:UpdateSlot(barId, slotIndex, config)
    local bar = self:GetBar(barId)
    if not bar or not bar.slots[slotIndex] then
        return
    end
    
    for k, v in pairs(config) do
        bar.slots[slotIndex][k] = v
    end
    
    if self:IsEnabled() then
        self:UpdateBar(barId)
    end
end

function module:UpdateBarSlots(barId, bar)
    if not bar then
        bar = self:GetBar(barId)
    end
    
    if not bar then
        self:Debug("UpdateBarSlots: No bar found for barId %d", barId)
        return
    end
    
    local frame = self.barFrames[barId]
    if not frame then
        self:Debug("UpdateBarSlots: No bar frame found for barId %d", barId)
        return
    end
    
    local numSlots = #bar.slots
    self:Debug("UpdateBarSlots: Updating %d slots for barId %d", numSlots, barId)
    
    for slotIndex, slot in ipairs(bar.slots) do
        self:Debug("UpdateBarSlots: Creating slot %d with tag=%s, namespace=%s", slotIndex, slot.tag or "nil", slot.namespace or "nil")
        self:CreateSlot(barId, slotIndex, slot, bar)
    end
    
    if self.slotFrames[barId] then
        for slotIndex = numSlots + 1, #self.slotFrames[barId] do
            if self.slotFrames[barId][slotIndex] then
                self.slotFrames[barId][slotIndex]:Hide()
            end
        end
    end
    
    self:LayoutSlots(barId, bar)
end

function module:CreateSlot(barId, slotIndex, slot, bar)
    if not self.barFrames[barId] then
        self:Debug("CreateSlot: No bar frame for barId %d", barId)
        return
    end
    
    if not self.slotFrames[barId] then
        self.slotFrames[barId] = {}
    end
    
    if not self.slotTexts[barId] then
        self.slotTexts[barId] = {}
    end
    
    local slotFrame = self.slotFrames[barId][slotIndex]
    if not slotFrame then
        slotFrame = CreateFrame("Frame", nil, self.barFrames[barId])
        self.slotFrames[barId][slotIndex] = slotFrame
        self:Debug("CreateSlot: Created new slotFrame for barId %d, slotIndex %d", barId, slotIndex)
    end
    
    local text = self.slotTexts[barId][slotIndex]
    if not text then
        text = slotFrame:CreateFontString(nil, "OVERLAY")
        self.slotTexts[barId][slotIndex] = text
        text:SetParent(slotFrame)
        self:Debug("CreateSlot: Created new FontString for barId %d, slotIndex %d", barId, slotIndex)
    end
    
    slotFrame:SetHeight(bar.height or 40)
    
    local font = bar.font
    if font and LibSharedMedia then
        font = LibSharedMedia:Fetch("font", font) or font
    end
    text:SetFont(font or "Fonts\\FRIZQT__.TTF", bar.fontSize or 12)
    
    local textColor = slot.textColor or bar.textColor
    text:SetTextColor(textColor.r, textColor.g, textColor.b, 1)
    
    if not LibDogTag then
        self:Debug("CreateSlot: LibDogTag not available, using plain text")
        text:SetText(slot.tag or "")
        text:Show()
        slotFrame:Show()
        slotFrame:SetParent(self.barFrames[barId])
        return
    end
    
    local tag = slot.tag or ""
    self:Debug("CreateSlot: barId %d, slotIndex %d, tag=%s, namespace=%s", barId, slotIndex, tag, slot.namespace or "Base")
    
    if tag == "" then
        text:SetText("")
        text:Show()
        slotFrame:Show()
        slotFrame:SetParent(self.barFrames[barId])
        return
    end
    
    local namespace = slot.namespace or "Base"
    local nsList = namespace
    if namespace == "TavernUI" then
        nsList = "TavernUI;Base"
    end
    
    local tagToUse = tag
    
    self:Debug("CreateSlot: Adding LibDogTag with tag=%s, nsList=%s", tagToUse, nsList)
    
    local success, err = pcall(function()
        LibDogTag:AddFontString(text, slotFrame, tagToUse, nsList)
    end)
    
    if not success then
        self:Debug("CreateSlot: Failed to add LibDogTag for slot %d in bar %d: %s", slotIndex, barId, tostring(err))
        text:SetText(tag)
    else
        self:Debug("CreateSlot: Successfully added LibDogTag, updating FontString")
        LibDogTag:UpdateFontString(text)
        local actualText = text:GetText() or ""
        self:Debug("CreateSlot: FontString text after update: %s", actualText)
        text:Show()
        slotFrame:Show()
    end
    
    if slot.icon and slot.icon.enabled then
        self:CreateSlotIcon(barId, slotIndex, slot, bar)
    else
        if self.slotIcons[barId] and self.slotIcons[barId][slotIndex] then
            self.slotIcons[barId][slotIndex]:Hide()
        end
        text:ClearAllPoints()
        text:SetPoint("LEFT", slotFrame, "LEFT", 4, 0)
        text:SetJustifyH("LEFT")
        text:SetJustifyV("MIDDLE")
    end
    
    slotFrame:Show()
    slotFrame:SetParent(self.barFrames[barId])
    
    self:Debug("CreateSlot: Final state - text visible: %s, slotFrame visible: %s, text text: %s", 
        tostring(text:IsVisible()), tostring(slotFrame:IsVisible()), tostring(text:GetText() or ""))
end

function module:CreateSlotIcon(barId, slotIndex, slot, bar)
    if not self.slotIcons[barId] then
        self.slotIcons[barId] = {}
    end
    
    local slotFrame = self.slotFrames[barId][slotIndex]
    if not slotFrame then
        return
    end
    
    if not self.slotIcons[barId][slotIndex] then
        local icon = slotFrame:CreateTexture(nil, "ARTWORK")
        self.slotIcons[barId][slotIndex] = icon
        icon:SetParent(slotFrame)
    end
    
    local icon = self.slotIcons[barId][slotIndex]
    local iconConfig = slot.icon
    
    local texture = self:GetIconTexture(iconConfig)
    icon:SetTexture(texture)
    
    local iconSize = iconConfig.size or bar.height
    icon:SetSize(iconSize, iconSize)
    
    icon:SetAlpha(iconConfig.alpha or 1)
    
    if iconConfig.zoom and iconConfig.zoom ~= 1.0 then
        self:ApplyIconZoom(icon, iconConfig.zoom)
    else
        icon:SetTexCoord(0, 1, 0, 1)
    end
    
    self:UpdateIconBorders(barId, slotIndex, icon, iconConfig)
    self:PositionIcon(barId, slotIndex, slot, bar)
    
    icon:Show()
end

function module:GetIconTexture(iconConfig)
    if iconConfig.source == "file" then
        return iconConfig.texture or "Interface\\BUTTONS\\WHITE8X8"
    elseif iconConfig.source == "libsharedmedia" and LibSharedMedia then
        return LibSharedMedia:Fetch("icon", iconConfig.texture) or "Interface\\BUTTONS\\WHITE8X8"
    elseif iconConfig.source == "preset" then
        return self:GetIconPresetTexture(iconConfig.texture) or "Interface\\BUTTONS\\WHITE8X8"
    elseif iconConfig.source == "wow" then
        return iconConfig.texture or "Interface\\BUTTONS\\WHITE8X8"
    else
        return "Interface\\BUTTONS\\WHITE8X8"
    end
end

function module:ApplyIconZoom(icon, zoom)
    if zoom >= 1.0 then
        local left = (zoom - 1) / (2 * zoom)
        local right = (zoom + 1) / (2 * zoom)
        left = math.max(0, math.min(1, left))
        right = math.max(0, math.min(1, right))
        icon:SetTexCoord(left, right, left, right)
    else
        icon:SetTexCoord(0, 1, 0, 1)
    end
end

function module:UpdateIconBorders(barId, slotIndex, icon, iconConfig)
    if not iconConfig.borders then
        return
    end
    
    local slotFrame = self.slotFrames[barId][slotIndex]
    if not slotFrame then
        return
    end
    
    if not slotFrame.iconBorders then
        slotFrame.iconBorders = {}
    end
    
    local borderConfigs = {
        top = {points = {{"TOPLEFT", icon, "TOPLEFT"}, {"TOPRIGHT", icon, "TOPRIGHT"}}, setSize = function(b, w) b:SetHeight(w) end},
        bottom = {points = {{"BOTTOMLEFT", icon, "BOTTOMLEFT"}, {"BOTTOMRIGHT", icon, "BOTTOMRIGHT"}}, setSize = function(b, w) b:SetHeight(w) end},
        left = {points = {{"TOPLEFT", icon, "TOPLEFT"}, {"BOTTOMLEFT", icon, "BOTTOMLEFT"}}, setSize = function(b, w) b:SetWidth(w) end},
        right = {points = {{"TOPRIGHT", icon, "TOPRIGHT"}, {"BOTTOMRIGHT", icon, "BOTTOMRIGHT"}}, setSize = function(b, w) b:SetWidth(w) end},
    }
    
    for side, config in pairs(iconConfig.borders) do
        if config.enabled then
            if not slotFrame.iconBorders[side] then
                slotFrame.iconBorders[side] = slotFrame:CreateTexture(nil, "BORDER")
            end
            local border = slotFrame.iconBorders[side]
            local c = config.color
            border:SetColorTexture(c.r, c.g, c.b, 1)
            
            local borderConfig = borderConfigs[side]
            if borderConfig then
                for _, pointData in ipairs(borderConfig.points) do
                    border:SetPoint(pointData[1], pointData[2], pointData[3], 0, 0)
                end
                borderConfig.setSize(border, config.width)
            end
            border:Show()
        elseif slotFrame.iconBorders[side] then
            slotFrame.iconBorders[side]:Hide()
        end
    end
end

function module:PositionIcon(barId, slotIndex, slot, bar)
    local slotFrame = self.slotFrames[barId][slotIndex]
    local icon = self.slotIcons[barId][slotIndex]
    local text = self.slotTexts[barId][slotIndex]
    
    if not slotFrame or not text then
        return
    end
    
    if not icon then
        text:ClearAllPoints()
        text:SetPoint("LEFT", slotFrame, "LEFT", 4, 0)
        text:SetJustifyH("LEFT")
        text:SetJustifyV("MIDDLE")
        return
    end
    
    local iconConfig = slot.icon
    local position = iconConfig.position or "left"
    local textPosition = iconConfig.textPosition or "right"
    
    local iconPositions = {
        left = {point = "LEFT", relativeTo = slotFrame, relativePoint = "LEFT", x = 0, y = 0},
        right = {point = "RIGHT", relativeTo = slotFrame, relativePoint = "RIGHT", x = 0, y = 0},
        center = {point = "CENTER", relativeTo = slotFrame, relativePoint = "CENTER", x = 0, y = 0},
        background = {point = "ALL", relativeTo = slotFrame},
    }
    
    local textPositions = {
        left = {point = "RIGHT", relativeTo = icon, relativePoint = "LEFT", x = -4, y = 0, second = {point = "LEFT", relativeTo = slotFrame, relativePoint = "LEFT", x = 0, y = 0}},
        right = {point = "LEFT", relativeTo = icon, relativePoint = "RIGHT", x = 4, y = 0, second = {point = "RIGHT", relativeTo = slotFrame, relativePoint = "RIGHT", x = 0, y = 0}},
        over = {point = "CENTER", relativeTo = icon, relativePoint = "CENTER", x = 0, y = 0},
        below = {point = "TOP", relativeTo = icon, relativePoint = "BOTTOM", x = 0, y = -4},
    }
    
    if position == "background" then
        icon:SetAllPoints(slotFrame)
        text:SetPoint("CENTER", slotFrame, "CENTER", 0, 0)
    else
        local iconPos = iconPositions[position]
        if iconPos then
            icon:SetPoint(iconPos.point, iconPos.relativeTo, iconPos.relativePoint, iconPos.x, iconPos.y)
        end
        
        local textPos = textPositions[textPosition]
        if textPos then
            text:SetPoint(textPos.point, textPos.relativeTo, textPos.relativePoint, textPos.x, textPos.y)
            if textPos.second then
                text:SetPoint(textPos.second.point, textPos.second.relativeTo, textPos.second.relativePoint, textPos.second.x, textPos.second.y)
            end
        end
    end
    
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
end

function module:LayoutSlots(barId, bar)
    local frame = self.barFrames[barId]
    if not frame then
        self:Debug("LayoutSlots: No bar frame for barId %d", barId)
        return
    end
    
    if not frame:IsVisible() then
        self:Debug("LayoutSlots: Bar frame %d is not visible", barId)
    end
    
    local growthDirection = bar.growthDirection or "horizontal"
    local spacing = bar.spacing or 4
    
    self:Debug("LayoutSlots: Laying out %d slots for barId %d, growthDirection=%s", #bar.slots, barId, growthDirection)
    
    for slotIndex, slot in ipairs(bar.slots) do
        local slotFrame = self.slotFrames[barId][slotIndex]
        if not slotFrame then
            break
        end
        
        slotFrame:ClearAllPoints()
        
        if slot.anchorConfig and Anchor then
            local barAnchorName = self.anchorNames[barId]
            if not barAnchorName then
                barAnchorName = "TavernUI.DataBar" .. barId
            end
            
            if not Anchor:Exists(barAnchorName) then
                self:Debug("LayoutSlots: Bar anchor %s does not exist, using default layout for slot %d", barAnchorName, slotIndex)
                slot.anchorConfig = nil
            else
                if not self.slotAnchorHandles[barId] then
                    self.slotAnchorHandles[barId] = {}
                end
                
                if self.slotAnchorHandles[barId][slotIndex] then
                    self.slotAnchorHandles[barId][slotIndex]:Release()
                    self.slotAnchorHandles[barId][slotIndex] = nil
                end
                
                local anchorConfig = {
                    target = barAnchorName,
                    point = slot.anchorConfig.point or "CENTER",
                    relativePoint = slot.anchorConfig.relativePoint or "CENTER",
                    offsetX = slot.anchorConfig.offsetX or 0,
                    offsetY = slot.anchorConfig.offsetY or 0,
                }
                
                local success, handle = pcall(function()
                    return Anchor:AnchorTo(slotFrame, anchorConfig)
                end)
                
                if success and handle then
                    self.slotAnchorHandles[barId][slotIndex] = handle
                    self:Debug("LayoutSlots: Successfully anchored slot %d to %s", slotIndex, barAnchorName)
                else
                    self:Debug("LayoutSlots: Failed to anchor slot %d, using default layout", slotIndex)
                    slot.anchorConfig = nil
                end
            end
        end
        
        if not slot.anchorConfig then
            if growthDirection == "horizontal" then
                if slotIndex == 1 then
                    slotFrame:SetPoint("LEFT", frame, "LEFT", 0, 0)
                    self:Debug("LayoutSlots: Slot %d anchored to LEFT of bar", slotIndex)
                else
                    local prevSlot = self.slotFrames[barId][slotIndex - 1]
                    if prevSlot then
                        slotFrame:SetPoint("LEFT", prevSlot, "RIGHT", spacing, 0)
                        self:Debug("LayoutSlots: Slot %d anchored to RIGHT of slot %d", slotIndex, slotIndex - 1)
                    end
                end
            else
                if slotIndex == 1 then
                    slotFrame:SetPoint("TOP", frame, "TOP", 0, 0)
                    self:Debug("LayoutSlots: Slot %d anchored to TOP of bar", slotIndex)
                else
                    local prevSlot = self.slotFrames[barId][slotIndex - 1]
                    if prevSlot then
                        slotFrame:SetPoint("TOP", prevSlot, "BOTTOM", 0, -spacing)
                        self:Debug("LayoutSlots: Slot %d anchored to BOTTOM of slot %d", slotIndex, slotIndex - 1)
                    end
                end
            end
        end
        
        if slot.width then
            slotFrame:SetWidth(slot.width)
        else
            slotFrame:SetWidth(1)
            slotFrame:SetScript("OnUpdate", function(frame)
                frame:SetScript("OnUpdate", nil)
                local text = module.slotTexts[barId][slotIndex]
                if text then
                    local textWidth = text:GetStringWidth() or 0
                    local icon = module.slotIcons[barId] and module.slotIcons[barId][slotIndex]
                    if icon and icon:IsShown() then
                        textWidth = textWidth + icon:GetWidth() + 4
                    end
                    frame:SetWidth(math.max(1, textWidth + 8))
                end
            end)
        end
        
        slotFrame:Show()
    end
end