local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")

local Data = {}

local RB = TavernUI:GetModule("ResourceBars", true)
local DISPLAY_BAR = (RB and RB.CONSTANTS and RB.CONSTANTS.DISPLAY_TYPE_BAR) or "bar"
local DISPLAY_SEGMENTED = (RB and RB.CONSTANTS and RB.CONSTANTS.DISPLAY_TYPE_SEGMENTED) or "segmented"

local CLASS_WARRIOR = 1
local CLASS_PALADIN = 2
local CLASS_HUNTER = 3
local CLASS_ROGUE = 4
local CLASS_PRIEST = 5
local CLASS_DEATHKNIGHT = 6
local CLASS_SHAMAN = 7
local CLASS_MAGE = 8
local CLASS_WARLOCK = 9
local CLASS_MONK = 10
local CLASS_DRUID = 11
local CLASS_DEMONHUNTER = 12
local CLASS_EVOKER = 13

local POWER_TYPE_MANA = Enum.PowerType.Mana
local POWER_TYPE_RAGE = Enum.PowerType.Rage
local POWER_TYPE_FOCUS = Enum.PowerType.Focus
local POWER_TYPE_ENERGY = Enum.PowerType.Energy
local POWER_TYPE_COMBO_POINTS = Enum.PowerType.ComboPoints
local POWER_TYPE_RUNES = Enum.PowerType.Runes
local POWER_TYPE_RUNIC_POWER = Enum.PowerType.RunicPower
local POWER_TYPE_SOUL_SHARDS = Enum.PowerType.SoulShards
local POWER_TYPE_LUNAR_POWER = Enum.PowerType.LunarPower
local POWER_TYPE_HOLY_POWER = Enum.PowerType.HolyPower
local POWER_TYPE_MAELSTROM = Enum.PowerType.Maelstrom
local POWER_TYPE_CHI = Enum.PowerType.Chi
local POWER_TYPE_INSANITY = Enum.PowerType.Insanity
local POWER_TYPE_ARCANE_CHARGES = Enum.PowerType.ArcaneCharges
local POWER_TYPE_FURY = Enum.PowerType.Fury
local POWER_TYPE_PAIN = Enum.PowerType.Pain
local POWER_TYPE_ESSENCE = Enum.PowerType.Essence

Data.POWER_TYPES = {
    PRIMARY_POWER = {
        id = "PRIMARY_POWER",
        name = "Primary Power",
        powerTypes = {
            [POWER_TYPE_MANA] = { name = "Mana", color = {r = 0.0, g = 0.5, b = 1.0} },
            [POWER_TYPE_RAGE] = { name = "Rage", color = {r = 1.0, g = 0.0, b = 0.0} },
            [POWER_TYPE_FOCUS] = { name = "Focus", color = {r = 1.0, g = 0.5, b = 0.25} },
            [POWER_TYPE_ENERGY] = { name = "Energy", color = {r = 1.0, g = 1.0, b = 0.0} },
            [POWER_TYPE_RUNIC_POWER] = { name = "Runic Power", color = {r = 0.0, g = 0.82, b = 1.0} },
            [POWER_TYPE_LUNAR_POWER] = { name = "Astral Power", color = {r = 0.3, g = 0.52, b = 0.9} },
            [POWER_TYPE_MAELSTROM] = { name = "Maelstrom", color = {r = 0.0, g = 0.78, b = 1.0} },
            [POWER_TYPE_INSANITY] = { name = "Insanity", color = {r = 0.4, g = 0.0, b = 0.8} },
            [POWER_TYPE_FURY] = { name = "Fury", color = {r = 0.78, g = 0.26, b = 0.99} },
            [POWER_TYPE_PAIN] = { name = "Pain", color = {r = 1.0, g = 0.61, b = 0.0} },
        }
    }
}

Data.SEGMENTED_TYPES = {
    COMBO_POINTS = {
        id = "COMBO_POINTS",
        name = "Combo Points",
        powerType = POWER_TYPE_COMBO_POINTS,
        color = {r = 1.0, g = 0.96, b = 0.41},
        maxDefault = 5,
        fractional = false,
        classes = {CLASS_ROGUE, CLASS_DRUID},
    },
    HOLY_POWER = {
        id = "HOLY_POWER",
        name = "Holy Power",
        powerType = POWER_TYPE_HOLY_POWER,
        color = {r = 0.9, g = 0.9, b = 0.6},
        maxDefault = 5,
        fractional = false,
        classes = {CLASS_PALADIN},
    },
    CHI = {
        id = "CHI",
        name = "Chi",
        powerType = POWER_TYPE_CHI,
        color = {r = 0.71, g = 0.92, b = 0.87},
        maxDefault = 6,
        fractional = false,
        classes = {CLASS_MONK},
        specs = {3},
    },
    SOUL_SHARDS = {
        id = "SOUL_SHARDS",
        name = "Soul Shards",
        powerType = POWER_TYPE_SOUL_SHARDS,
        color = {r = 0.58, g = 0.51, b = 0.79},
        maxDefault = 5,
        fractional = true,
        classes = {CLASS_WARLOCK},
    },
    ARCANE_CHARGES = {
        id = "ARCANE_CHARGES",
        name = "Arcane Charges",
        powerType = POWER_TYPE_ARCANE_CHARGES,
        color = {r = 0.1, g = 0.8, b = 1.0},
        maxDefault = 4,
        fractional = false,
        classes = {CLASS_MAGE},
    },
    RUNES = {
        id = "RUNES",
        name = "Runes",
        powerType = POWER_TYPE_RUNES,
        color = {r = 0.0, g = 0.82, b = 1.0},
        maxDefault = 6,
        fractional = false,
        hasDurationObjects = true,
        classes = {CLASS_DEATHKNIGHT},
    },
    ESSENCE = {
        id = "ESSENCE",
        name = "Essence",
        powerType = POWER_TYPE_ESSENCE,
        color = {r = 0.2, g = 0.8, b = 0.9},
        maxDefault = 5,
        fractional = false,
        hasDurationObjects = true,
        classes = {CLASS_EVOKER},
    },
}

Data.SPECIAL_RESOURCES = {
    STAGGER = {
        id = "STAGGER",
        name = "Stagger",
        displayType = DISPLAY_BAR,
        classes = {CLASS_MONK},
        specs = {1},
        color = {r = 1.0, g = 0.0, b = 0.0},
    },
    SOUL_FRAGMENTS = {
        id = "SOUL_FRAGMENTS",
        name = "Soul Fragments",
        displayType = DISPLAY_SEGMENTED,
        classes = {CLASS_DEMONHUNTER},
        specs = {2},
        maxDefault = 5,
        color = {r = 0.58, g = 0.51, b = 0.79},
        spellIds = {1225789, 1227702},
    },
    ALTERNATE_POWER = {
        id = "ALTERNATE_POWER",
        name = "Alternate Power",
        displayType = DISPLAY_BAR,
        classes = {},
        color = {r = 0.5, g = 0.5, b = 1.0},
    },
    EBON_MIGHT = {
        id = "EBON_MIGHT",
        name = "Ebon Might",
        displayType = DISPLAY_BAR,
        classes = {CLASS_EVOKER},
        specs = {3},
        color = {r = 0.2, g = 0.4, b = 0.6},
        requiresBlizzardFrame = true,
    },
    MAELSTROM_WEAPON = {
        id = "MAELSTROM_WEAPON",
        name = "Maelstrom Weapon",
        displayType = DISPLAY_SEGMENTED,
        classes = {CLASS_SHAMAN},
        specs = {2},
        maxDefault = 10,
        color = {r = 0.0, g = 0.78, b = 1.0},
        spellId = 344179,
    },
}

function Data:IsResourceRelevant(resourceId, class, spec, form)
    if resourceId == "PRIMARY_POWER" then
        return true
    end
    
    if resourceId == "ALTERNATE_POWER" then
        return false
    end
    
    local resource = self.SEGMENTED_TYPES[resourceId] or self.SPECIAL_RESOURCES[resourceId]
    if not resource then
        return false
    end
    
    if resource.classes and #resource.classes > 0 then
        local classMatches = false
        for _, resourceClass in ipairs(resource.classes) do
            if resourceClass == class then
                classMatches = true
                break
            end
        end
        if not classMatches then
            return false
        end
    end
    
    if resource.specs and #resource.specs > 0 then
        local specMatches = false
        for _, resourceSpec in ipairs(resource.specs) do
            if resourceSpec == spec then
                specMatches = true
                break
            end
        end
        if not specMatches then
            return false
        end
    end
    
    if resourceId == "COMBO_POINTS" and class == CLASS_DRUID then
        if form and form ~= 3 then
            return false
        end
    end
    
    return true
end

function Data:GetActiveBarsForClass(class, spec, form)
    local activeBars = {}
    
    activeBars["HEALTH"] = true
    activeBars["PRIMARY_POWER"] = true
    
    for id, resource in pairs(self.SEGMENTED_TYPES) do
        if self:IsResourceRelevant(id, class, spec, form) then
            activeBars[id] = true
        end
    end
    
    for id, resource in pairs(self.SPECIAL_RESOURCES) do
        if id == "ALTERNATE_POWER" then
        elseif self:IsResourceRelevant(id, class, spec, form) then
            activeBars[id] = true
        end
    end
    
    return activeBars
end

local module = TavernUI:GetModule("ResourceBars", true)
if module then
    module.Data = Data
end
