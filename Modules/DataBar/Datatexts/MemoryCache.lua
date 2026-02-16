local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local HOVER_COOLDOWN = 10

local cache = {
    addons = {},
    total = 0,
    lastRefresh = 0,
    pending = false,
    pollingActive = false,
}

DataBar.memoryCache = cache

local function CollectMemoryData()
    local count = 0
    local total = 0
    for i = 1, C_AddOns.GetNumAddOns() do
        local mem = GetAddOnMemoryUsage(i)
        if mem > 0 then
            count = count + 1
            total = total + mem
            local entry = cache.addons[count]
            if entry then
                entry.name = C_AddOns.GetAddOnInfo(i)
                entry.mem = mem
            else
                cache.addons[count] = { name = C_AddOns.GetAddOnInfo(i), mem = mem }
            end
        end
    end
    for i = count + 1, #cache.addons do
        cache.addons[i] = nil
    end
    table.sort(cache.addons, function(a, b) return a.mem > b.mem end)
    cache.total = total
    cache.pending = false
end

function DataBar:RefreshMemoryCache()
    if cache.pending then return end
    cache.pending = true
    cache.lastRefresh = GetTime()
    UpdateAddOnMemoryUsage()
    C_Timer.After(0, CollectMemoryData)
end

function DataBar:RefreshMemoryCacheOnHover()
    if cache.pollingActive then return end
    if GetTime() - cache.lastRefresh < HOVER_COOLDOWN then return end
    self:RefreshMemoryCache()
end

function DataBar:CheckMemoryPoll(slot)
    local interval = tonumber(slot and slot.memoryPollInterval or "0") or 0
    if interval > 0 then
        cache.pollingActive = true
        local now = GetTime()
        if now - cache.lastRefresh >= interval then
            self:RefreshMemoryCache()
        end
    else
        cache.pollingActive = false
    end
end
