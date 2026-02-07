-- TavernUI visibility.lua
-- Core visibility: state cache, ShouldShow(config), callbacks on state change.
-- Used by modules (e.g. uCDM) to show/hide UI based on combat, target, group, instance, role, mount, flying, vehicle.

local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")

local Visibility = {}
local cache = {}
local callbacks = {}
local callbackIdNext = 0
local eventFrame = nil
local lastMounted, lastFlying
local pollTimer = nil
local POLL_INTERVAL = 0.5

local playerClass
local TRAVEL_FORM_SPELL_ID = 783
local MOUNT_FORM_SPELL_ID = 210053

local function IsInDruidTravelForm()
    if not playerClass then
        playerClass = select(2, UnitClass("player"))
    end
    if playerClass ~= "DRUID" then return false end
    return C_UnitAuras.GetPlayerAuraBySpellID(TRAVEL_FORM_SPELL_ID) ~= nil
        or C_UnitAuras.GetPlayerAuraBySpellID(MOUNT_FORM_SPELL_ID) ~= nil
end

local function UpdateCache()
    cache.inCombat = UnitAffectingCombat("player")
    cache.hasTarget = UnitExists("target")
    cache.targetHarm = cache.hasTarget and UnitCanAttack("player", "target")
    cache.targetHelp = cache.hasTarget and UnitCanAssist("player", "target")
    cache.targetDead = cache.hasTarget and (UnitIsDead("target") or UnitIsGhost("target"))
    cache.groupSolo = not IsInGroup()
    cache.groupParty = IsInGroup() and not IsInRaid()
    cache.groupRaid = IsInRaid()
    cache.instanceType = select(2, GetInstanceInfo()) or "none"
    cache.role = UnitGroupRolesAssigned("player") or "NONE"
    cache.mounted = IsMounted() or IsInDruidTravelForm()
    cache.flying = IsFlying()
    cache.inVehicle = UnitInVehicle("player")
end

local function NotifyCallbacks()
    for _, cb in pairs(callbacks) do
        pcall(cb)
    end
end

local function StopMountPoll()
    if pollTimer then
        pollTimer:Cancel()
        pollTimer = nil
    end
end

local function StartMountPoll()
    if not pollTimer then
        pollTimer = C_Timer.NewTicker(POLL_INTERVAL, function()
            UpdateCache()
            if not cache.mounted then
                StopMountPoll()
                lastMounted, lastFlying = cache.mounted, cache.flying
                NotifyCallbacks()
                return
            end
            if cache.mounted ~= lastMounted or cache.flying ~= lastFlying then
                lastMounted, lastFlying = cache.mounted, cache.flying
                NotifyCallbacks()
            end
        end)
    end
end

local function SyncMountPoll()
    if cache.mounted then
        StartMountPoll()
    else
        StopMountPoll()
    end
end

local function OnEvent(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        eventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
    if event == "PLAYER_TARGET_CHANGED" then
        C_Timer.After(0, function()
            UpdateCache()
            NotifyCallbacks()
        end)
        return
    end
    UpdateCache()
    lastMounted, lastFlying = cache.mounted, cache.flying
    SyncMountPoll()
    NotifyCallbacks()
end

function Visibility.ShouldShow(config)
    if not config or type(config) ~= "table" then return true end
    UpdateCache()

    if config.hideWhenInVehicle and cache.inVehicle then return false end

    if config.hideWhenMounted and cache.mounted then
        local when = config.hideWhenMountedWhen or "both"
        if when == "both" or when == "always" then return false end
        if when == "grounded" and not cache.flying then return false end
        if when == "flying" and cache.flying then return false end
    end

    local combat = config.combat
    if combat then
        local ok = (combat.showInCombat and cache.inCombat) or (combat.showOutOfCombat and not cache.inCombat)
        if not ok then return false end
    end

    local target = config.target
    if target and target.showWhenTargetExists then
        if not cache.hasTarget then return false end
    end

    local group = config.group
    if group then
        local ok = (group.showSolo and cache.groupSolo) or (group.showParty and cache.groupParty) or (group.showRaid and cache.groupRaid)
        if not ok then return false end
    end

    return true
end

function Visibility.RegisterCallback(callback)
    if type(callback) ~= "function" then return nil end
    callbackIdNext = callbackIdNext + 1
    callbacks[callbackIdNext] = callback
    return callbackIdNext
end

function Visibility.UnregisterCallback(id)
    if id then callbacks[id] = nil end
end

function Visibility.GetCache()
    UpdateCache()
    return cache
end

function Visibility.Initialize()
    if eventFrame then return end
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("COMPANION_UPDATE")
    eventFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
    eventFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    eventFrame:RegisterUnitEvent("UNIT_FLAGS", "player")
    eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
    eventFrame:SetScript("OnEvent", function(f, event, arg1)
        if event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
            if arg1 ~= "player" then return end
        end
        -- UNIT_AURA fires frequently; only check mount/flying state, skip full cache update
        if event == "UNIT_AURA" then
            local mounted = IsMounted() or IsInDruidTravelForm()
            local flying = IsFlying()
            if mounted ~= cache.mounted or flying ~= cache.flying then
                cache.mounted = mounted
                cache.flying = flying
                lastMounted, lastFlying = mounted, flying
                SyncMountPoll()
                NotifyCallbacks()
            end
            return
        end
        OnEvent(f, event)
    end)
    UpdateCache()
    lastMounted, lastFlying = cache.mounted, cache.flying
    SyncMountPoll()
end

TavernUI.Visibility = Visibility

C_Timer.After(0, function()
    if TavernUI.Visibility and TavernUI.Visibility.Initialize then
        TavernUI.Visibility.Initialize()
    end
end)
