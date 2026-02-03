local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local Helpers = module.CooldownTrackerHelpers

local CooldownTracker = {}

-- Normalize frame element access (Blizzard uses inconsistent casing)
local function GetIcon(frame)
    return frame and (frame.Icon or frame.icon)
end

local function GetCooldown(frame)
    return frame and (frame.Cooldown or frame.cooldown)
end

local function GetCount(frame)
    return frame and (frame.Count or frame.count)
end

CooldownTracker._hasChargesCache = {}

-- Curve-based cooldown detection for Midnight compatibility
local CooldownCurves = {
    initialized = false,
    Binary = nil,
}

local function SetupCooldownCurves()
    if CooldownCurves.initialized then return true end
    if not C_CurveUtil or not C_CurveUtil.CreateCurve then
        return false
    end

    CooldownCurves.Binary = C_CurveUtil.CreateCurve()
    CooldownCurves.Binary:AddPoint(0.0, 0)
    CooldownCurves.Binary:AddPoint(0.001, 1)
    CooldownCurves.Binary:AddPoint(1.0, 1)

    CooldownCurves.initialized = true
    return true
end

-- Evaluate remaining percent using curves - returns a value usable by SetDesaturation
local function EvaluateCooldownDesaturation(durationObj)
    if not durationObj or not SetupCooldownCurves() then return 0 end
    local ok, val = pcall(durationObj.EvaluateRemainingPercent, durationObj, CooldownCurves.Binary)
    if not ok then return 0 end
    return val  -- Can be a secret value - that's fine for SetDesaturation
end

local function ApplySwipeStyle(cooldown)
    if not cooldown then return end
    if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
    if cooldown.SetDrawBling then cooldown:SetDrawBling(false) end
    if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture("Interface\\Buttons\\WHITE8X8") end
    if cooldown.SetSwipeColor then cooldown:SetSwipeColor(0, 0, 0, 0.8) end
end

CooldownTracker.ApplySwipeStyle = ApplySwipeStyle

function CooldownTracker.UpdateTrinket(slotID)
    local itemID = GetInventoryItemID("player", slotID)
    if not itemID then return nil end
    return CooldownTracker.UpdateItem(itemID)
end

function CooldownTracker.UpdateItem(itemID)
    if not itemID then return nil end
    local startTime, duration = C_Container.GetItemCooldown(itemID)
    local _, spellID = GetItemSpell(itemID)
    local itemCount = C_Item.GetItemCount(itemID, false, false) or 0
    local itemCharges = Helpers.GetItemCharges(itemID)

    local buffStacks, buffRemaining, spellCharges = Helpers.GetItemBuffInfo(spellID, CooldownTracker._hasChargesCache)
    local stackDisplay = Helpers.GetStackDisplay(itemCount, itemCharges, spellCharges, buffStacks)
    local durationObj = Helpers.CreateCooldownDuration(startTime, duration)

    return {
        stackDisplay = stackDisplay,
        desaturation = EvaluateCooldownDesaturation(durationObj),
        duration = durationObj,
        buffRemaining = buffRemaining,
    }
end

function CooldownTracker.UpdateSpell(spellID, auraSpellID)
    -- Use GetSpellCooldownDuration directly - returns a duration object
    -- The curve evaluation handles determining if there's an active cooldown
    local durationObj = C_Spell.GetSpellCooldownDuration(spellID)

    -- auraSpellID allows tracking a different spell ID for the target debuff
    -- (useful when cast spell ID differs from debuff spell ID)
    local stacks, charges, hasCharges, chargeDuration, buffRemaining, targetDebuffRemaining =
        Helpers.GetSpellStackAndChargeInfo(spellID, CooldownTracker._hasChargesCache, auraSpellID)
    local stackDisplay = Helpers.GetStackDisplay(nil, nil, nil, stacks, hasCharges, charges)
    local isUsable, noMana = Helpers.GetSpellUsability(spellID)

    -- Determine the primary duration object for desaturation
    -- Priority: target debuff > player buff > charge > cooldown
    local primaryDuration = targetDebuffRemaining or buffRemaining or chargeDuration or durationObj

    return {
        stackDisplay = stackDisplay,
        desaturation = EvaluateCooldownDesaturation(primaryDuration),
        duration = durationObj,
        buffRemaining = buffRemaining,
        chargeDuration = chargeDuration,
        targetDebuffRemaining = targetDebuffRemaining,
        isUsable = isUsable,
        noMana = noMana
    }
end

function CooldownTracker.UpdateActionSlot(slot)
    if not slot or slot < 1 or slot > 120 then return nil end
    local actionType, id = GetActionInfo(slot)
    if actionType == "spell" and id then
        return CooldownTracker.UpdateSpell(id)
    elseif actionType == "item" and id then
        return CooldownTracker.UpdateItem(id)
    end
    local startTime, duration, enable = GetActionCooldown(slot)
    local durationObj
    local ok = pcall(function()
        if type(startTime) ~= "number" or type(duration) ~= "number" or duration <= 0 then
            return
        end
        durationObj = Helpers.CreateCooldownDuration(startTime, duration)
    end)
    if not ok or not durationObj then
        return { duration = nil, desaturation = 0, stackDisplay = nil }
    end
    return {
        duration = durationObj,
        desaturation = EvaluateCooldownDesaturation(durationObj),
        stackDisplay = nil,
    }
end

function CooldownTracker.UpdateOverride(entry)
    if not entry or not entry.frame then return nil end
    local startTime, duration = nil, nil
    if entry.viewerKey and entry.layoutIndex then
        startTime, duration = module:GetSlotCooldownOverride(entry.viewerKey, entry.layoutIndex)
    end
    if not startTime or not duration then return nil end
    local durationObj = Helpers.CreateCooldownDuration(startTime, duration)
    local desaturation = EvaluateCooldownDesaturation(durationObj)
    local data = {
        duration = durationObj,
        desaturation = desaturation,
        stackDisplay = nil,
    }
    local frame = entry.frame
    local cooldown = GetCooldown(frame)
    if cooldown and durationObj then
        cooldown:SetCooldownFromDurationObject(durationObj, true)
        cooldown:Show()
    end
    local icon = GetIcon(frame)
    if icon then
        icon:SetDesaturation(desaturation)
        icon:SetVertexColor(1.0, 1.0, 1.0)
    end
    local countText = GetCount(frame)
    if countText then countText:Hide() end
    return data
end

-- Try to get cooldown from SpellScanner if available (provides more accurate tracking)
local function TryGetScannerCooldown(entry)
    local scanner = TavernUI.SpellScanner or TavernUI:GetModule("SpellScanner", true)
    if not scanner then return nil end

    local startTime, duration

    -- Try direct spell lookup
    if entry.spellID and scanner.GetSpellActiveCooldown then
        startTime, duration = scanner:GetSpellActiveCooldown(entry.spellID)
    end

    -- Try action slot lookup
    if not startTime and entry.actionSlotID then
        local slot = tonumber(entry.actionSlotID)
        if slot and slot >= 1 and slot <= 120 then
            local atype, id = GetActionInfo(slot)
            if id then
                if (atype == "spell" or atype == "macro") and scanner.GetSpellActiveCooldown then
                    startTime, duration = scanner:GetSpellActiveCooldown(id)
                elseif atype == "item" and scanner.GetItemActiveCooldown then
                    startTime, duration = scanner:GetItemActiveCooldown(id)
                end
            end
        end
    end

    -- Try item lookup
    if not startTime and entry.itemID and scanner.GetItemActiveCooldown then
        startTime, duration = scanner:GetItemActiveCooldown(entry.itemID)
    end

    if startTime and duration then
        local durationObj = Helpers.CreateCooldownDuration(startTime, duration)
        if durationObj then
            return {
                buffRemaining = durationObj,
                desaturation = EvaluateCooldownDesaturation(durationObj),
                stackDisplay = nil
            }
        end
    end

    return nil
end

function CooldownTracker.GetEntryData(entry)
    -- Try SpellScanner first for more accurate cooldown tracking
    if entry.spellID or entry.actionSlotID or entry.itemID then
        local scannerData = TryGetScannerCooldown(entry)
        if scannerData then return scannerData end
    end

    if entry.spellID then
        -- Pass auraSpellID if provided (for spells where cast ID ≠ debuff ID)
        return CooldownTracker.UpdateSpell(entry.spellID, entry.auraSpellID)
    elseif entry.itemID then
        return CooldownTracker.UpdateItem(entry.itemID)
    elseif entry.slotID then
        return CooldownTracker.UpdateTrinket(entry.slotID)
    elseif entry.actionSlotID then
        return CooldownTracker.UpdateActionSlot(entry.actionSlotID)
    end
    return nil
end

function CooldownTracker.UpdateEntry(entry)
    if not entry or not entry.frame then return nil end

    local data = CooldownTracker.UpdateOverride(entry)
    if data then return data end

    data = CooldownTracker.GetEntryData(entry)
    if not data then return nil end

    local frame = entry.frame
    local cooldown = GetCooldown(frame)

    -- Determine which duration object to use
    -- Priority: target debuff > player buff > charge > cooldown
    local durationObj = data.targetDebuffRemaining or data.buffRemaining or data.chargeDuration or data.duration
    local desaturation = data.desaturation or 0

    if cooldown then
        if durationObj then
            -- Use reverse animation for countdowns (debuffs, buffs, cooldowns)
            local useReverse = data.targetDebuffRemaining ~= nil or data.buffRemaining ~= nil or data.duration ~= nil
            cooldown:SetCooldownFromDurationObject(durationObj, useReverse)
            cooldown:Show()
        else
            cooldown:Clear()
        end
    end

    local icon = GetIcon(frame)
    if icon then
        -- Always apply desaturation from curve (0 = available, 1 = on cooldown)
        -- The curve value handles the correct state
        icon:SetDesaturation(desaturation)

        -- Apply vertex color based on usability
        if data.isUsable == false then
            icon:SetVertexColor(data.noMana and 0.5 or 0.4, data.noMana and 0.5 or 0.4, data.noMana and 1.0 or 0.4)
        else
            icon:SetVertexColor(1.0, 1.0, 1.0)
        end
    end

    local countText = GetCount(frame)
    if countText then
        if data.stackDisplay then
            countText:SetText(data.stackDisplay)
            countText:Show()
        else
            countText:Hide()
        end
    end

    return data
end

function CooldownTracker.Initialize()
    SetupCooldownCurves()
end

module.CooldownTracker = CooldownTracker
