local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local EntrySystem = {}

local TRACKING_TYPE = {
    TRINKET = 1,
    ITEM = 2,
    SPELL = 3,
}

EntrySystem.TRACKING_TYPE = TRACKING_TYPE

local entries = {}
local viewerEntries = {}
local nextIndex = {}
local customIDCounter = 0

function EntrySystem.Initialize()
    entries = {}
    viewerEntries = {}
    nextIndex = {}
    customIDCounter = 0
    
    module:LogInfo("EntrySystem initialized")
end

function EntrySystem.EncodeID(trackingType, id)
    assert(trackingType >= TRACKING_TYPE.TRINKET and trackingType <= TRACKING_TYPE.SPELL, "Invalid tracking type")
    assert(type(id) == "number", "ID must be a number")
    assert(id > 0, "ID must be positive")
    return trackingType * 10000000 + id
end

function EntrySystem.DecodeID(encodedID)
    assert(type(encodedID) == "number", "EncodedID must be a number")
    assert(encodedID > 0, "EncodedID must be positive")
    local trackingType = math.floor(encodedID / 10000000)
    local id = encodedID % 10000000
    return trackingType, id
end

function EntrySystem.GenerateID(entryType, trackingType, id, viewerKey, index)
    if entryType == "blizzard" then
        index = index or (nextIndex[viewerKey] or 1)
        return "blizz_" .. viewerKey .. "_" .. index
    else
        if not trackingType or not id then
            customIDCounter = customIDCounter + 1
            return "custom_" .. GetTime() .. "_" .. customIDCounter
        end
        
        local baseID = EntrySystem.EncodeID(trackingType, id)
        customIDCounter = customIDCounter + 1
        return baseID * 1000 + customIDCounter
    end
end

function EntrySystem.DecodeCustomID(encodedID)
    if type(encodedID) == "string" then
        return nil, nil, nil
    end
    
    local counter = encodedID % 1000
    local baseID = math.floor(encodedID / 1000)
    local id = baseID % 10000000
    local trackingType = math.floor(baseID / 10000000)
    
    return trackingType, id, counter
end

function EntrySystem.CreateEntry(id, entryType, source, frame, metadata)
    if not id or not entryType or not source or not frame then
        module:LogError("EntrySystem.CreateEntry: Missing required parameters")
        return nil
    end
    
    if entries[id] then
        module:LogError("EntrySystem.CreateEntry: Entry with ID already exists: " .. tostring(id))
        return nil
    end
    
    local entry = {
        id = id,
        type = entryType,
        source = source,
        frame = frame,
        spellID = metadata and metadata.spellID,
        itemID = metadata and metadata.itemID,
        slotID = metadata and metadata.slotID,
        index = metadata and metadata.index,
        priority = metadata and metadata.priority or 0,
        config = metadata and metadata.config or {},
        layoutIndex = metadata and metadata.layoutIndex,
        enabled = metadata and metadata.enabled ~= false,
    }
    
    entries[id] = entry
    
    if not viewerEntries[source] then
        viewerEntries[source] = {}
    end
    table.insert(viewerEntries[source], entry)
    
    if entry.index and (not nextIndex[source] or entry.index >= nextIndex[source]) then
        nextIndex[source] = (entry.index or 0) + 1
    end
    
    return entry
end

function EntrySystem.GetEntry(id)
    return entries[id]
end

function EntrySystem.GetEntriesForViewer(viewerKey, entryType)
    local viewerEntriesList = viewerEntries[viewerKey] or {}
    
    if entryType then
        local filtered = {}
        for _, entry in ipairs(viewerEntriesList) do
            if entry.type == entryType then
                table.insert(filtered, entry)
            end
        end
        return EntrySystem.SortEntries(filtered)
    end
    
    return EntrySystem.SortEntries(viewerEntriesList)
end

function EntrySystem.RemoveEntry(id)
    local entry = entries[id]
    if not entry then return end
    
    local viewerList = viewerEntries[entry.source]
    if viewerList then
        for i, e in ipairs(viewerList) do
            if e.id == id then
                table.remove(viewerList, i)
                break
            end
        end
    end
    
    entries[id] = nil
end

function EntrySystem.SortEntries(entriesList)
    local sorted = {}
    for _, entry in ipairs(entriesList) do
        table.insert(sorted, entry)
    end
    
    table.sort(sorted, function(a, b)
        local indexA = a.index or 9999
        local indexB = b.index or 9999
        if indexA ~= indexB then
            return indexA < indexB
        end
        return (a.priority or 0) < (b.priority or 0)
    end)
    
    return sorted
end

function EntrySystem.GetMergedEntriesForViewer(viewerKey)
    local blizzEntries = {}
    local customEntries = {}
    
    if viewerKey == "essential" or viewerKey == "utility" or viewerKey == "buff" then
        blizzEntries = EntrySystem.GetEntriesForViewer(viewerKey, "blizzard")
    end
    
    if viewerKey == "essential" or viewerKey == "utility" then
        customEntries = EntrySystem.GetEntriesForViewer(viewerKey, "custom")
    end
    
    local merged = {}
    for _, entry in ipairs(blizzEntries) do
        if entry.enabled ~= false then
            table.insert(merged, entry)
        end
    end
    for _, entry in ipairs(customEntries) do
        if entry.enabled ~= false then
            table.insert(merged, entry)
        end
    end
    
    table.sort(merged, function(a, b)
        local indexA = a.index or 9999
        local indexB = b.index or 9999
        return indexA < indexB
    end)
    
    return merged
end

function EntrySystem.ReindexViewer(viewerKey)
    local allEntries = EntrySystem.GetMergedEntriesForViewer(viewerKey)
    
    for i, entry in ipairs(allEntries) do
        entry.index = i
    end
    
    if #allEntries > 0 then
        nextIndex[viewerKey] = #allEntries + 1
    else
        nextIndex[viewerKey] = 1
    end
end

function EntrySystem.GetNextIndex(viewerKey)
    if not nextIndex[viewerKey] then
        local allEntries = EntrySystem.GetMergedEntriesForViewer(viewerKey)
        nextIndex[viewerKey] = #allEntries + 1
    end
    return nextIndex[viewerKey]
end

function EntrySystem.ReorderEntry(id, newIndex)
    local entry = EntrySystem.GetEntry(id)
    if not entry then
        module:LogError("EntrySystem.ReorderEntry: Entry not found: " .. tostring(id))
        return false
    end
    
    local viewerKey = entry.source
    local mergedEntries = EntrySystem.GetMergedEntriesForViewer(viewerKey)
    
    local currentIndex = nil
    for i, e in ipairs(mergedEntries) do
        if e.id == id then
            currentIndex = i
            break
        end
    end
    
    if not currentIndex then
        module:LogError("EntrySystem.ReorderEntry: Entry not found in viewer list")
        return false
    end
    
    if newIndex < 1 or newIndex > #mergedEntries then
        module:LogError("EntrySystem.ReorderEntry: Invalid newIndex: " .. tostring(newIndex) .. " (max: " .. #mergedEntries .. ")")
        return false
    end
    
    table.remove(mergedEntries, currentIndex)
    table.insert(mergedEntries, newIndex, entry)
    
    for i, e in ipairs(mergedEntries) do
        e.index = i
    end
    
    if module.RefreshManager then
        module.RefreshManager.RefreshViewer(viewerKey)
    end
    
    return true
end

function EntrySystem.MoveEntryToViewer(id, newViewerKey)
    local entry = EntrySystem.GetEntry(id)
    if not entry then
        module:LogError("EntrySystem.MoveEntryToViewer: Entry not found: " .. tostring(id))
        return false
    end
    
    local oldViewerKey = entry.source
    if oldViewerKey == newViewerKey then
        return true
    end
    
    local oldViewerList = viewerEntries[oldViewerKey]
    if oldViewerList then
        for i, e in ipairs(oldViewerList) do
            if e.id == id then
                table.remove(oldViewerList, i)
                break
            end
        end
    end
    
    if not viewerEntries[newViewerKey] then
        viewerEntries[newViewerKey] = {}
    end
    
    table.insert(viewerEntries[newViewerKey], entry)
    entry.source = newViewerKey
    
    EntrySystem.ReindexViewer(oldViewerKey)
    EntrySystem.ReindexViewer(newViewerKey)
    
    return true
end

module.EntrySystem = EntrySystem
