local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("ResourceBars")

local Providers = {}

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
local ALTERNATE_POWER_INDEX = Enum.PowerType.Alternate

local function NormalizeDurationObject(start, duration, ready)
    return {
        start = start or 0,
        duration = duration or 0,
        ready = ready or false
    }
end

local function ProviderPrimaryHealth()
    local current = UnitHealth("player")
    local max = UnitHealthMax("player")
    if not max or max <= 0 then
        return nil
    end
    return {
        current = current,
        max = max,
    }
end

local function ProviderPrimaryPower()
    if not module.Data:IsResourceRelevant("PRIMARY_POWER", select(3, UnitClass("player")), GetSpecialization(), GetShapeshiftForm()) then
        return nil
    end
    
    local powerType = UnitPowerType("player")
    local current = UnitPower("player")
    local max = UnitPowerMax("player")
    
    if not max or max <= 0 then
        return nil
    end
    
    return {
        current = current,
        max = max,
    }
end

local function ProviderComboPoints()
    if not module.Data:IsResourceRelevant("COMBO_POINTS", select(3, UnitClass("player")), GetSpecialization(), GetShapeshiftForm()) then
        return nil
    end
    
    local current = UnitPower("player", POWER_TYPE_COMBO_POINTS)
    local max = UnitPowerMax("player", POWER_TYPE_COMBO_POINTS)
    
    if not max or max <= 0 then
        return nil
    end
    
    return {
        current = current,
        max = max,
    }
end

local function ProviderHolyPower()
    if not module.Data:IsResourceRelevant("HOLY_POWER", select(3, UnitClass("player")), GetSpecialization(), GetShapeshiftForm()) then
        return nil
    end
    
    local current = UnitPower("player", POWER_TYPE_HOLY_POWER)
    local max = UnitPowerMax("player", POWER_TYPE_HOLY_POWER)
    
    if not max or max <= 0 then
        return nil
    end
    
    return {
        current = current,
        max = max,
    }
end

local function ProviderChi()
    if not module.Data:IsResourceRelevant("CHI", select(3, UnitClass("player")), GetSpecialization(), GetShapeshiftForm()) then
        return nil
    end
    
    local current = UnitPower("player", POWER_TYPE_CHI)
    local max = UnitPowerMax("player", POWER_TYPE_CHI)
    
    if not max or max <= 0 then
        return nil
    end
    
    return {
        current = current,
        max = max,
    }
end

local function ProviderSoulShards()
    if not module.Data:IsResourceRelevant("SOUL_SHARDS", select(3, UnitClass("player")), GetSpecialization(), GetShapeshiftForm()) then
        return nil
    end

    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)
    local isDestro = (specID == 267)

    local current = UnitPower("player", POWER_TYPE_SOUL_SHARDS, isDestro)
    local max = UnitPowerMax("player", POWER_TYPE_SOUL_SHARDS, isDestro)

    if not max or max <= 0 then
        return nil
    end

    return {
        current = current,
        max = max,
    }
end

local function ProviderArcaneCharges()
    if not module.Data:IsResourceRelevant("ARCANE_CHARGES", select(3, UnitClass("player")), GetSpecialization(), GetShapeshiftForm()) then
        return nil
    end
    
    local current = UnitPower("player", POWER_TYPE_ARCANE_CHARGES)
    local max = UnitPowerMax("player", POWER_TYPE_ARCANE_CHARGES)
    
    if not max or max <= 0 then
        return nil
    end
    
    return {
        current = current,
        max = max,
    }
end

local function ProviderRunes()
    if not module.Data:IsResourceRelevant("RUNES", select(3, UnitClass("player")), GetSpecialization(), GetShapeshiftForm()) then
        return nil
    end
    
    local max = UnitPowerMax("player", POWER_TYPE_RUNES) or 6
    if not max or max <= 0 then
        return nil
    end
    
    local current = UnitPower("player", POWER_TYPE_RUNES)
    local segments = {}
    
    for i = 1, max do
        local start, duration, ready = GetRuneCooldown(i)
        local durationObj = NormalizeDurationObject(start, duration, ready)
        segments[i] = durationObj
    end
    
    return {
        current = current,
        max = max,
        segments = segments,
    }
end

local function ProviderEssence()
    if not module.Data:IsResourceRelevant("ESSENCE", select(3, UnitClass("player")), GetSpecialization(), GetShapeshiftForm()) then
        return nil
    end
    
    local current = UnitPower("player", POWER_TYPE_ESSENCE)
    local max = UnitPowerMax("player", POWER_TYPE_ESSENCE) or 5
    
    if not max or max <= 0 then
        return nil
    end
    
    local partialRaw = (UnitPartialPower and UnitPartialPower("player", POWER_TYPE_ESSENCE)) or 0
    local partialFill = math.max(0, math.min(1, partialRaw / 1000))
    local regenRate = (GetPowerRegenForPowerType and GetPowerRegenForPowerType(POWER_TYPE_ESSENCE)) or 0.2
    local fullDuration = (regenRate and regenRate > 0) and (1 / regenRate) or 5
    local elapsed = partialFill * fullDuration
    local startTime = (elapsed > 0 and GetTime) and (GetTime() - elapsed) or 0
    
    local segments = {}
    for i = 1, max do
        if i <= current then
            segments[i] = { ready = true }
        elseif i == current + 1 and current < max then
            segments[i] = {
                fillPercent = partialFill,
                start = startTime,
                duration = fullDuration,
                ready = (partialFill >= 1),
            }
        else
            segments[i] = { ready = false }
        end
    end
    
    return {
        current = current,
        max = max,
        segments = segments,
    }
end

local function ProviderStagger()
    if not module.Data:IsResourceRelevant("STAGGER", select(3, UnitClass("player")), GetSpecialization(), GetShapeshiftForm()) then
        return nil
    end
    if not UnitStagger or not UnitHealthMax then
        return nil
    end
    local current = UnitStagger("player")
    local max = UnitHealthMax("player")
    if not max or max <= 0 then
        return nil
    end
    if type(current) ~= "number" or current ~= current then
        current = 0
    end
    if current < 0 then current = 0 end
    if current > max then current = max end
    return {
        current = current,
        max = max,
    }
end

local function ProviderSoulFragments()
    if not module.Data:IsResourceRelevant("SOUL_FRAGMENTS", select(3, UnitClass("player")), GetSpecialization(), GetShapeshiftForm()) then
        return nil
    end
    
    local spellIds = {1225789, 1227702}
    local current = 0
    
    for _, spellId in ipairs(spellIds) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellId)
        if aura then
            current = current + (aura.applications or 1)
        end
    end
    
    local max = 5
    
    return {
        current = current,
        max = max,
        percentage = max > 0 and (current / max) or 0,
    }
end

local function ProviderAlternatePower()
    local barInfo = UnitAlternatePowerInfo("player")
    if not barInfo or not barInfo.barEnabled then
        return nil
    end
    
    local current = UnitPower("player", ALTERNATE_POWER_INDEX)
    local max = UnitPowerMax("player", ALTERNATE_POWER_INDEX)
    
    if not max or max <= 0 then
        return nil
    end
    
    return {
        current = current,
        max = max,
    }
end

local function ProviderEbonMight()
    if not module.Data:IsResourceRelevant("EBON_MIGHT", select(3, UnitClass("player")), GetSpecialization(), GetShapeshiftForm()) then
        return nil
    end
    
    if not PlayerFrame or not PlayerFrame:IsShown() then
        return nil
    end
    
    if not EvokerEbonMightBar then
        return nil
    end
    
    local current = EvokerEbonMightBar:GetValue()
    local min, max = EvokerEbonMightBar:GetMinMaxValues()
    
    if not max or max <= 0 then
        return nil
    end
    
    return {
        current = current,
        max = max,
    }
end

local function ProviderMaelstromWeapon()
    if not module.Data:IsResourceRelevant("MAELSTROM_WEAPON", select(3, UnitClass("player")), GetSpecialization(), GetShapeshiftForm()) then
        return nil
    end
    
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(344179)
    local current = aura and (aura.applications or 0) or 0
    local max = 10
    
    return {
        current = current,
        max = max,
        percentage = max > 0 and (current / max) or 0,
    }
end

Providers.registry = {
    HEALTH = ProviderPrimaryHealth,
    PRIMARY_POWER = ProviderPrimaryPower,
    COMBO_POINTS = ProviderComboPoints,
    HOLY_POWER = ProviderHolyPower,
    CHI = ProviderChi,
    SOUL_SHARDS = ProviderSoulShards,
    ARCANE_CHARGES = ProviderArcaneCharges,
    RUNES = ProviderRunes,
    ESSENCE = ProviderEssence,
    STAGGER = ProviderStagger,
    SOUL_FRAGMENTS = ProviderSoulFragments,
    ALTERNATE_POWER = ProviderAlternatePower,
    EBON_MIGHT = ProviderEbonMight,
    MAELSTROM_WEAPON = ProviderMaelstromWeapon,
}

function Providers:GetProvider(barId)
    return self.registry[barId]
end

module.Providers = Providers
