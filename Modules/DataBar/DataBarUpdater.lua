-- DataBarUpdater.lua
-- Event dispatcher + poll group manager for DataBar datatexts

local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("DataBar", true)
if not module then return end

-- Internal state
local eventFrame = nil
local eventSubscriptions = {} -- event name -> { datatextName = true }
local eventDelays = {}        -- datatextName -> delay (seconds) for event-driven updates
local pollGroups = {}         -- interval -> { ticker, datatexts = { name = true } }
local activeSlots = {}        -- datatextName -> { { barId, slotIndex }, ... }
local initCalled = {}         -- datatextName -> true (init callback already fired)

local function UpdateSlotText(barId, slotIndex, datatextName)
    local datatext = module:GetDatatext(datatextName)
    if not datatext or not datatext.update then return end

    local text = module.slotTexts[barId] and module.slotTexts[barId][slotIndex]
    if not text or not text:IsVisible() then return end

    local bar = module:GetBar(barId)
    local slot = bar and bar.slots[slotIndex]
    local value = datatext.update(slot)
    if value then
        module:UpdateSlotLabel(barId, slotIndex, text, value)
    end
    module:UpdateSlotColor(barId, slotIndex, text)
end

local function UpdateDatatextSlots(datatextName)
    local slots = activeSlots[datatextName]
    if not slots then return end
    for _, slot in ipairs(slots) do
        UpdateSlotText(slot.barId, slot.slotIndex, datatextName)
    end
end

function module:RegisterSlotUpdates(barId, slotIndex, datatextName)
    local datatext = self:GetDatatext(datatextName)
    if not datatext then return end

    if not activeSlots[datatextName] then
        activeSlots[datatextName] = {}
    end
    table.insert(activeSlots[datatextName], { barId = barId, slotIndex = slotIndex })

    -- One-time init callback (for deferred setup like TLM registration)
    if datatext.init and not initCalled[datatextName] then
        initCalled[datatextName] = true
        datatext.init()
    end

    -- Track per-datatext event delay
    if datatext.eventDelay then
        eventDelays[datatextName] = datatext.eventDelay
    end

    -- Subscribe to WoW events
    if datatext.events then
        for _, event in ipairs(datatext.events) do
            if not eventSubscriptions[event] then
                eventSubscriptions[event] = {}
                if eventFrame then
                    eventFrame:RegisterEvent(event)
                end
            end
            eventSubscriptions[event][datatextName] = true
        end
    end

    -- Subscribe to poll group
    if datatext.pollInterval then
        local interval = datatext.pollInterval
        if not pollGroups[interval] then
            pollGroups[interval] = { ticker = nil, datatexts = {} }
        end
        pollGroups[interval].datatexts[datatextName] = true
        -- Start ticker immediately if updates are already active
        if eventFrame and not pollGroups[interval].ticker then
            local group = pollGroups[interval]
            group.ticker = C_Timer.NewTicker(interval, function()
                for dt in pairs(group.datatexts) do
                    UpdateDatatextSlots(dt)
                end
            end)
        end
    end
end

function module:UnregisterSlotUpdates(barId, slotIndex)
    for datatextName, slots in pairs(activeSlots) do
        for i = #slots, 1, -1 do
            if slots[i].barId == barId and slots[i].slotIndex == slotIndex then
                table.remove(slots, i)
            end
        end
        if #slots == 0 then
            activeSlots[datatextName] = nil
            eventDelays[datatextName] = nil
            initCalled[datatextName] = nil
            for event, subs in pairs(eventSubscriptions) do
                subs[datatextName] = nil
                if not next(subs) then
                    eventSubscriptions[event] = nil
                    if eventFrame then
                        eventFrame:UnregisterEvent(event)
                    end
                end
            end
            for interval, group in pairs(pollGroups) do
                group.datatexts[datatextName] = nil
                if not next(group.datatexts) then
                    if group.ticker then
                        group.ticker:Cancel()
                        group.ticker = nil
                    end
                    pollGroups[interval] = nil
                end
            end
        end
    end
end

function module:StartUpdates()
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:SetScript("OnEvent", function(_, event)
            local subs = eventSubscriptions[event]
            if not subs then return end
            for datatextName in pairs(subs) do
                local delay = eventDelays[datatextName]
                if delay then
                    local dt = datatextName
                    C_Timer.After(delay, function()
                        UpdateDatatextSlots(dt)
                    end)
                else
                    UpdateDatatextSlots(datatextName)
                end
            end
        end)
    end

    for event in pairs(eventSubscriptions) do
        eventFrame:RegisterEvent(event)
    end

    for interval, group in pairs(pollGroups) do
        if not group.ticker then
            group.ticker = C_Timer.NewTicker(interval, function()
                for datatextName in pairs(group.datatexts) do
                    UpdateDatatextSlots(datatextName)
                end
            end)
        end
    end
end

function module:StopUpdates()
    if eventFrame then
        eventFrame:UnregisterAllEvents()
    end

    for _, group in pairs(pollGroups) do
        if group.ticker then
            group.ticker:Cancel()
            group.ticker = nil
        end
    end
end

function module:RefreshAllSlots()
    for datatextName, slots in pairs(activeSlots) do
        for _, slot in ipairs(slots) do
            UpdateSlotText(slot.barId, slot.slotIndex, datatextName)
        end
    end
end

function module:RefreshDatatext(datatextName)
    UpdateDatatextSlots(datatextName)
end
