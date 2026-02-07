local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:NewModule("Visibility", "AceEvent-3.0")

local defaults = {
    visibility = {
        combat = { showInCombat = true, showOutOfCombat = true },
        target = { showWhenTargetExists = false },
        group = { showSolo = true, showParty = true, showRaid = true },
        hideWhenInVehicle = false,
        hideWhenMounted = false,
        hideWhenMountedWhen = "both",
        hiddenOpacity = 0,
        visibleOnHover = false,
    },
}

TavernUI:RegisterModuleDefaults("Visibility", defaults, true)

local cache = {}
local callbacks = {}
local callbackIdNext = 0
local eventFrame = nil
local lastMounted, lastFlying
local pollTimer = nil
local POLL_INTERVAL = 0.5
local COMBAT_DISMOUNT_CATCHUP_DELAY = 0.2

local FLIGHT_FORM_ID = 29
local SWIFT_FLIGHT_FORM_ID = 27
local TRAVEL_FORM_ID = 3

local function IsDruidFlyingForm()
    if not GetShapeshiftFormID then return false end
    local formId = GetShapeshiftFormID()
    return formId == FLIGHT_FORM_ID or formId == SWIFT_FLIGHT_FORM_ID
end

local function IsDruidTravelForm()
    if not GetShapeshiftFormID then return false end
    return GetShapeshiftFormID() == TRAVEL_FORM_ID
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
    local druidFlying = IsDruidFlyingForm()
    local druidTravel = IsDruidTravelForm()
    cache.mounted = IsMounted() or druidFlying or druidTravel
    cache.flying = IsFlying() or druidFlying
    cache.inVehicle = UnitInVehicle("player")
end

local function NotifyCallbacks()
    for _, cb in pairs(callbacks) do
        pcall(cb)
    end
    TavernUI:SendMessage("TavernUI_VisibilityStateChanged")
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

local function ApplyCacheAndNotify()
    UpdateCache()
    lastMounted, lastFlying = cache.mounted, cache.flying
    SyncMountPoll()
    NotifyCallbacks()
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
    if event == "PLAYER_REGEN_DISABLED" then
        C_Timer.After(0, function()
            ApplyCacheAndNotify()
        end)
        C_Timer.After(COMBAT_DISMOUNT_CATCHUP_DELAY, function()
            UpdateCache()
            if lastMounted ~= cache.mounted or lastFlying ~= cache.flying then
                lastMounted, lastFlying = cache.mounted, cache.flying
                SyncMountPoll()
                NotifyCallbacks()
            end
        end)
        return
    end
    if event == "PLAYER_MOUNT_DISPLAY_CHANGED" or event == "UPDATE_SHAPESHIFT_FORMS"
        or event == "COMPANION_UPDATE" then
        C_Timer.After(0, function()
            ApplyCacheAndNotify()
        end)
        return
    end
    ApplyCacheAndNotify()
end

local function CopyVisibilityTable(vis)
    if type(vis) ~= "table" then return nil end
    local copy = {}
    for k, v in pairs(vis) do
        if type(v) == "table" then
            local inner = {}
            for k2, v2 in pairs(v) do inner[k2] = v2 end
            copy[k] = inner
        else
            copy[k] = v
        end
    end
    return copy
end

function module:ShouldShow(config)
    local cfg = config
    if not cfg or type(cfg) ~= "table" then
        cfg = self:GetSetting("visibility")
    end
    if not cfg or type(cfg) ~= "table" then return true end
    UpdateCache()

    if cfg.hideWhenInVehicle and cache.inVehicle then return false end

    if cfg.hideWhenMounted and cache.mounted then
        local when = cfg.hideWhenMountedWhen or "both"
        if when == "both" or when == "always" then return false end
        if when == "grounded" and not cache.flying then return false end
        if when == "flying" and cache.flying then return false end
    end

    local combat = cfg.combat
    if combat then
        local ok = (combat.showInCombat and cache.inCombat) or (combat.showOutOfCombat and not cache.inCombat)
        if not ok then return false end
    end

    local target = cfg.target
    if target and target.showWhenTargetExists then
        if not cache.hasTarget then return false end
    end

    local group = cfg.group
    if group then
        local ok = (group.showSolo and cache.groupSolo) or (group.showParty and cache.groupParty) or (group.showRaid and cache.groupRaid)
        if not ok then return false end
    end

    return true
end

function module:RegisterCallback(callback)
    if type(callback) ~= "function" then return nil end
    callbackIdNext = callbackIdNext + 1
    callbacks[callbackIdNext] = callback
    return callbackIdNext
end

function module:UnregisterCallback(id)
    if id then callbacks[id] = nil end
end

function module:NotifyStateChange()
    NotifyCallbacks()
end

function module:GetCache()
    UpdateCache()
    return cache
end

function module:GetVisibilityConfig()
    return self:GetSetting("visibility")
end

function module:GetHiddenOpacity(config)
    local cfg = config or self:GetSetting("visibility")
    if not cfg or type(cfg) ~= "table" then return 0 end
    local pct = cfg.hiddenOpacity
    if type(pct) ~= "number" or pct <= 0 then return 0 end
    return math.min(1, math.max(0, pct / 100))
end

function module:GetVisibleOnHover(config)
    local cfg = config or self:GetSetting("visibility")
    return cfg and type(cfg) == "table" and cfg.visibleOnHover == true
end

function module:Initialize()
    if eventFrame then return end
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("COMPANION_UPDATE")
    eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    eventFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
    eventFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
    eventFrame:RegisterUnitEvent("UNIT_FLAGS", "player")
    eventFrame:SetScript("OnEvent", function(f, event, arg1)
        if event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
            if arg1 ~= "player" then return end
        end
        OnEvent(f, event)
    end)
    UpdateCache()
    lastMounted, lastFlying = cache.mounted, cache.flying
    SyncMountPoll()
    TavernUI:SendMessage("TavernUI_VisibilityStateChanged")
end

function module:OnInitialize()
    if self.Options and self.Options.Initialize then
        self.Options:Initialize()
    end
end

function module:OnEnable()
    C_Timer.After(0, function()
        if not module:GetSetting("_migratedFromUCDM") then
            local ucdmProfile = TavernUI.db and TavernUI.db.profile and TavernUI.db.profile.uCDM
            if ucdmProfile and ucdmProfile.general and type(ucdmProfile.general.visibility) == "table" then
                local copy = CopyVisibilityTable(ucdmProfile.general.visibility)
                if copy then
                    module:SetSetting("visibility", copy)
                end
                module:SetSetting("_migratedFromUCDM", true)
            end
        end
        if module.Initialize then module:Initialize() end
    end)
end

TavernUI.CopyVisibilityTable = CopyVisibilityTable
TavernUI.Visibility = module
