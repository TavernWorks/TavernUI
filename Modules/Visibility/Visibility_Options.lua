local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local L = LibStub("AceLocale-3.0"):GetLocale("TavernUI", true)
local module = TavernUI:GetModule("Visibility", true)

if not module then return end

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local VISIBILITY_OPTION_SCHEMA = {
    { key = "visibilityDesc", type = "description", nameKey = "VISIBILITY_DESC", order = 1 },
    { key = "visibilityCombatHeader", type = "header", nameKey = "VISIBILITY_COMBAT", order = 2 },
    { key = "showInCombat", type = "toggle", path = "visibility.combat.showInCombat", nameKey = "SHOW_IN_COMBAT", order = 3 },
    { key = "showOutOfCombat", type = "toggle", path = "visibility.combat.showOutOfCombat", nameKey = "SHOW_OUT_OF_COMBAT", order = 4 },
    { key = "visibilityTargetHeader", type = "header", nameKey = "VISIBILITY_TARGET", order = 5 },
    { key = "showWhenTargetExists", type = "toggle", path = "visibility.target.showWhenTargetExists", nameKey = "SHOW_WHEN_TARGET_EXISTS", order = 6 },
    { key = "visibilityGroupHeader", type = "header", nameKey = "VISIBILITY_GROUP", order = 11 },
    { key = "showSolo", type = "toggle", path = "visibility.group.showSolo", nameKey = "SHOW_WHEN_SOLO", order = 12 },
    { key = "showParty", type = "toggle", path = "visibility.group.showParty", nameKey = "SHOW_WHEN_IN_PARTY", order = 13 },
    { key = "showRaid", type = "toggle", path = "visibility.group.showRaid", nameKey = "SHOW_WHEN_IN_RAID", order = 14 },
    { key = "visibilityHideHeader", type = "header", nameKey = "VISIBILITY_HIDE_WHEN", order = 15 },
    { key = "hideWhenInVehicle", type = "toggle", path = "visibility.hideWhenInVehicle", nameKey = "HIDE_WHEN_IN_VEHICLE", order = 16 },
    { key = "hideWhenMounted", type = "toggle", path = "visibility.hideWhenMounted", nameKey = "HIDE_WHEN_MOUNTED", order = 17 },
    { key = "hideWhenMountedWhen", type = "select", path = "visibility.hideWhenMountedWhen", nameKey = "HIDE_WHEN_MOUNTED_WHEN", descKey = "HIDE_WHEN_MOUNTED_WHEN_DESC", order = 18, default = "both", values = { both = "VISIBILITY_WHEN_BOTH", grounded = "VISIBILITY_WHEN_GROUNDED", flying = "VISIBILITY_WHEN_FLYING" } },
    { key = "visibilityWhenHiddenHeader", type = "header", nameKey = "VISIBILITY_WHEN_HIDDEN", order = 19 },
    { key = "hiddenOpacity", type = "range", path = "visibility.hiddenOpacity", nameKey = "VISIBILITY_HIDDEN_OPACITY", descKey = "VISIBILITY_HIDDEN_OPACITY_DESC", order = 20, min = 0, max = 100, step = 5, default = 0 },
    { key = "visibleOnHover", type = "toggle", path = "visibility.visibleOnHover", nameKey = "VISIBILITY_VISIBLE_ON_HOVER", descKey = "VISIBILITY_VISIBLE_ON_HOVER_DESC", order = 21, default = false },
}

local function MakeVisibilityOption(entry)
    if entry.type == "description" then
        return { type = "description", name = L[entry.nameKey], order = entry.order, fontSize = "small" }
    end
    if entry.type == "header" then
        return { type = "header", name = L[entry.nameKey], order = entry.order }
    end
    local path = entry.path
    local defaultVal = entry.default
    local opt = {
        type = entry.type,
        name = L[entry.nameKey],
        order = entry.order,
        get = function() return module:GetSetting(path, defaultVal) end,
        set = function(_, value)
            module:SetSetting(path, value)
            if module:IsEnabled() and module.NotifyStateChange then module:NotifyStateChange() end
        end,
    }
    if entry.descKey then opt.desc = L[entry.descKey] end
    if entry.type == "select" and entry.values then
        local resolved = {}
        for k, v in pairs(entry.values) do
            resolved[k] = type(v) == "string" and L[v] or v
        end
        opt.values = resolved
    end
    if entry.type == "range" then
        opt.min = entry.min
        opt.max = entry.max
        opt.step = entry.step
    end
    return opt
end

local function BuildVisibilityOptions()
    local result = {}
    for _, entry in ipairs(VISIBILITY_OPTION_SCHEMA) do
        result[entry.key] = MakeVisibilityOption(entry)
    end
    return result
end

local Options = {}

function Options:Initialize()
    local args = BuildVisibilityOptions()
    AceConfig:RegisterOptionsTable("TavernUI.Visibility", {
        type = "group",
        name = L["VISIBILITY"],
        args = args,
    })
    AceConfigDialog:AddToBlizOptions("TavernUI.Visibility", L["VISIBILITY"], "TavernUI")
    TavernUI:RegisterModuleOptions("Visibility", {
        type = "group",
        name = L["VISIBILITY"],
        args = args,
    }, L["VISIBILITY"])
end

module.Options = Options
