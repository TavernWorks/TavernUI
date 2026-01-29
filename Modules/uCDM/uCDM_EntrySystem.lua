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
local entriesByFrame = {}  -- Lookup table: frame -> entry (for blizzard entries)
local viewerEntries = {}
local nextIndex = {}
local customIDCounter = 0

function EntrySystem.Initialize()
    entries = {}
    entriesByFrame = {}
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
    if not id or not entryType or not source then
        module:LogError(string.format(
            "EntrySystem.CreateEntry: Missing required parameters - id=%s type=%s source=%s frame=%s",
            tostring(id), tostring(entryType), tostring(source), tostring(frame)
        ))
        return nil
    end
    
    -- Frame is required for blizzard entries
    if entryType == "blizzard" and not frame then
        module:LogError(string.format(
            "EntrySystem.CreateEntry: Blizzard entry '%s' created without frame!",
            tostring(id)
        ))
        return nil
    end
    
    -- For blizzard entries, check if this frame already has an entry for THIS viewer
    -- Blizzard frames are viewer-specific, so if frame has entry for different viewer, create new one
    local existingEntry = nil
    local shouldCreateNew = false
    
    if entryType == "blizzard" and entriesByFrame[frame] then
        local frameEntry = entriesByFrame[frame]
        -- Only reuse if it belongs to this viewer
        local belongsToViewer = false
        if frameEntry.sources then
            for _, s in ipairs(frameEntry.sources) do
                if s == source then
                    belongsToViewer = true
                    break
                end
            end
        elseif frameEntry.source == source then
            belongsToViewer = true
        end
        
        if belongsToViewer then
            existingEntry = frameEntry
            id = existingEntry.id
        else
            -- Frame has entry for different viewer - clear it and create new one
            entriesByFrame[frame] = nil
            shouldCreateNew = true
            -- Don't use the old entry's ID - generate a new one for this viewer
            local frameName = frame:GetName()
            id = "blizz_" .. source .. "_" .. (frameName or tostring(frame):match("%x+$"))
        end
    end
    
    -- Only reuse existing entry if it belongs to this viewer AND has the correct frame
    local entry = nil
    if not shouldCreateNew then
        entry = entries[id] or existingEntry
        -- For blizzard entries, verify frame matches
        if entry and entryType == "blizzard" then
            -- Frame must exist and match - entries without frames are invalid
            if not entry.frame or entry.frame ~= frame then
                entry = nil
                local frameName = frame:GetName()
                id = "blizz_" .. source .. "_" .. (frameName or tostring(frame):match("%x+$"))
            else
                -- Frame matches - verify it belongs to this viewer
                local belongsToViewer = false
                if entry.sources then
                    for _, s in ipairs(entry.sources) do
                        if s == source then
                            belongsToViewer = true
                            break
                        end
                    end
                elseif entry.source == source then
                    belongsToViewer = true
                end
                if not belongsToViewer then
                    -- Entry has correct frame but wrong viewer - we'll add viewer below
                end
            end
        end
    end
    
    if entry then
        -- ALWAYS update frame reference first - this is critical for preventing frame=nil
        if frame then
            entry.frame = frame
            -- Update frame lookup
            if entryType == "blizzard" then
                entriesByFrame[frame] = entry
            end
        elseif entryType == "blizzard" then
            module:LogError(string.format(
                "EntrySystem.CreateEntry: Updating entry '%s' but frame parameter is nil!",
                tostring(id)
            ))
        end
        
        -- Update index from metadata if provided
        if metadata and metadata.index then
            entry.index = metadata.index
        end
        
        -- Migrate old single-source entries to sources array
        if not entry.sources then
            if entry.source then
                entry.sources = {entry.source}
            else
                entry.sources = {}
            end
            entry.source = nil
        end
        
        local sourceExists = false
        for _, existingSource in ipairs(entry.sources) do
            if existingSource == source then
                sourceExists = true
                break
            end
        end
        
        if not sourceExists then
            table.insert(entry.sources, source)
            
            if not viewerEntries[source] then
                viewerEntries[source] = {}
            end
            
            -- Check if entry is already in this viewer's list to prevent duplicates
            local alreadyInList = false
            for _, e in ipairs(viewerEntries[source]) do
                if e.id == entry.id then
                    alreadyInList = true
                    break
                end
            end
            
            if not alreadyInList then
                table.insert(viewerEntries[source], entry)
            end
        end
        
        return entry
    end
    
    -- Create new entry - frame MUST be set for blizzard entries
    if entryType == "blizzard" and not frame then
        module:LogError(string.format(
            "EntrySystem.CreateEntry: Cannot create blizzard entry '%s' - frame is nil!",
            tostring(id)
        ))
        return nil
    end
    
    -- For blizzard entries, ensure no other entry exists for this frame in this viewer
    -- This prevents duplicates when frame gets a new ID
    if entryType == "blizzard" then
        local viewerList = viewerEntries[source] or {}
        for i = #viewerList, 1, -1 do
            local existingEntry = viewerList[i]
            if existingEntry.type == "blizzard" and existingEntry.frame == frame and existingEntry.id ~= id then
                -- Found duplicate entry for same frame - remove it
                table.remove(viewerList, i)
                -- Also clear from entriesByFrame if it was pointing to the old entry
                if entriesByFrame[frame] == existingEntry then
                    entriesByFrame[frame] = nil
                end
            end
        end
    end
    
    local entry = {
        id = id,
        type = entryType,
        sources = {source},
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
    
    -- Double-check frame is set
    if entryType == "blizzard" and not entry.frame then
        module:LogError(string.format(
            "EntrySystem.CreateEntry: Entry '%s' created but frame is nil after assignment!",
            tostring(id)
        ))
        return nil
    end
    
    entries[id] = entry
    
    -- Register frame lookup for blizzard entries
    if entryType == "blizzard" then
        entriesByFrame[frame] = entry
    end
    
    if not viewerEntries[source] then
        viewerEntries[source] = {}
    end
    
    -- Check if entry is already in this viewer's list to prevent duplicates
    local alreadyInList = false
    for _, e in ipairs(viewerEntries[source]) do
        if e.id == entry.id then
            alreadyInList = true
            break
        end
    end
    
    if not alreadyInList then
        table.insert(viewerEntries[source], entry)
    end
    
    if entry.index and (not nextIndex[source] or entry.index >= nextIndex[source]) then
        nextIndex[source] = (entry.index or 0) + 1
    end
    
    return entry
end

function EntrySystem.GetEntry(id)
    return entries[id]
end

function EntrySystem.GetEntryByFrame(frame, viewerKey)
    if not frame then return nil end
    
    -- Check frame lookup first (fastest)
    local entry = entriesByFrame[frame]
    if entry then
        -- Verify it belongs to this viewer
        if entry.sources then
            for _, source in ipairs(entry.sources) do
                if source == viewerKey then
                    return entry
                end
            end
        elseif entry.source == viewerKey then
            return entry
        end
    end
    
    -- Fallback: search viewer's entries for this frame
    local viewerList = viewerEntries[viewerKey] or {}
    for _, e in ipairs(viewerList) do
        if e.frame == frame then
            return e
        end
    end
    
    return nil
end

function EntrySystem.GetEntrySource(entry)
    if not entry then return nil end
    if entry.sources and #entry.sources > 0 then
        return entry.sources[1]
    end
    return entry.source
end

function EntrySystem.EntryHasViewer(entry, viewerKey)
    if not entry or not viewerKey then return false end
    if entry.sources then
        for _, source in ipairs(entry.sources) do
            if source == viewerKey then
                return true
            end
        end
        return false
    end
    return entry.source == viewerKey
end

function EntrySystem.GetEntriesForViewer(viewerKey, entryType)
    local viewerEntriesList = viewerEntries[viewerKey] or {}
    
    -- Validate that entries actually belong to this viewer
    local validatedList = {}
    for _, entry in ipairs(viewerEntriesList) do
        local belongsToViewer = false
        if entry.sources then
            for _, source in ipairs(entry.sources) do
                if source == viewerKey then
                    belongsToViewer = true
                    break
                end
            end
        elseif entry.source == viewerKey then
            belongsToViewer = true
        end
        
        -- Also validate entry ID matches viewer (for blizzard entries)
        if entry.type == "blizzard" and entry.id then
            local expectedPrefix = "blizz_" .. viewerKey .. "_"
            if string.sub(entry.id, 1, #expectedPrefix) ~= expectedPrefix then
                belongsToViewer = false
            end
        end
        
        if belongsToViewer then
            -- For blizzard entries, frame must exist - entries without frames are invalid
            if entry.type == "blizzard" and not entry.frame then
                -- Skip entries without frames
            else
                table.insert(validatedList, entry)
            end
        end
    end
    
    if entryType then
        local filtered = {}
        for _, entry in ipairs(validatedList) do
            if entry.type == entryType then
                table.insert(filtered, entry)
            end
        end
        return EntrySystem.SortEntries(filtered)
    end
    
    return EntrySystem.SortEntries(validatedList)
end

function EntrySystem.RemoveEntry(id)
    local entry = entries[id]
    if not entry then return end
    
    -- Remove frame lookup
    if entry.type == "blizzard" and entry.frame then
        entriesByFrame[entry.frame] = nil
    end
    
    local sources = {}
    if entry.sources then
        for _, source in ipairs(entry.sources) do
            if source then
                table.insert(sources, source)
            end
        end
    elseif entry.source then
        table.insert(sources, entry.source)
    end
    
    for _, source in ipairs(sources) do
        local viewerList = viewerEntries[source]
        if viewerList then
            for i, e in ipairs(viewerList) do
                if e.id == id then
                    table.remove(viewerList, i)
                    break
                end
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
    local allEntries = EntrySystem.GetEntriesForViewer(viewerKey)
    
    local merged = {}
    for _, entry in ipairs(allEntries) do
        if entry.enabled ~= false then
            table.insert(merged, entry)
        end
    end
    
    table.sort(merged, function(a, b)
        local indexA = a.index or 9999
        local indexB = b.index or 9999
        return indexA < indexB
    end)
    
    for i, entry in ipairs(merged) do
        entry.layoutIndex = i
    end

    if module:GetSetting("general.debug", false) then
        local labels = {}
        for _, entry in ipairs(merged) do
            local label = entry.id and tostring(entry.id) or (entry.frame and entry.frame.GetName and entry.frame:GetName()) or "?"
            table.insert(labels, tostring(label))
        end
        module:LogInfo("Merged " .. viewerKey .. " " .. #merged .. " entries: " .. table.concat(labels, ", "))
    end

    return merged
end

function EntrySystem.ReindexViewer(viewerKey)
    local viewerList = viewerEntries[viewerKey]
    if not viewerList then
        nextIndex[viewerKey] = 1
        return
    end
    
    for i, entry in ipairs(viewerList) do
        entry.index = i
    end
    
    if #viewerList > 0 then
        nextIndex[viewerKey] = #viewerList + 1
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

function EntrySystem.ReorderEntry(id, newIndex, viewerKey)
    local entry = EntrySystem.GetEntry(id)
    if not entry then
        module:LogError("EntrySystem.ReorderEntry: Entry not found: " .. tostring(id))
        return false
    end
    
    if not viewerKey then
        viewerKey = (entry.sources and entry.sources[1]) or entry.source
        if not viewerKey then
            module:LogError("EntrySystem.ReorderEntry: No viewer specified and entry has no sources")
            return false
        end
    end
    
    -- Work with the actual viewerEntries list, not a merged copy
    local viewerList = viewerEntries[viewerKey]
    if not viewerList then
        module:LogError("EntrySystem.ReorderEntry: Viewer list not found: " .. tostring(viewerKey))
        return false
    end
    
    local currentIndex = nil
    for i, e in ipairs(viewerList) do
        if e.id == id then
            currentIndex = i
            break
        end
    end
    
    if not currentIndex then
        module:LogError("EntrySystem.ReorderEntry: Entry not found in viewer list")
        return false
    end
    
    if newIndex < 1 or newIndex > #viewerList then
        module:LogError("EntrySystem.ReorderEntry: Invalid newIndex: " .. tostring(newIndex) .. " (max: " .. #viewerList .. ")")
        return false
    end
    
    table.remove(viewerList, currentIndex)
    table.insert(viewerList, newIndex, entry)
    
    -- Update indices for all entries in this viewer
    EntrySystem.ReindexViewer(viewerKey)
    
    if module.LayoutEngine then
        module.LayoutEngine.RefreshViewer(viewerKey)
    end
    
    if module.Styler then
        module.Styler.RefreshViewer(viewerKey)
    end
    
    return true
end

function EntrySystem.AddEntryToViewer(id, viewerKey)
    local entry = EntrySystem.GetEntry(id)
    if not entry then
        module:LogError("EntrySystem.AddEntryToViewer: Entry not found: " .. tostring(id))
        return false
    end
    
    if not entry.sources then
        entry.sources = {entry.source or viewerKey}
        entry.source = nil
    end
    
    local alreadyInViewer = false
    for _, source in ipairs(entry.sources) do
        if source == viewerKey then
            alreadyInViewer = true
            break
        end
    end
    
    if alreadyInViewer then
        return true
    end
    
    table.insert(entry.sources, viewerKey)
    
    if not viewerEntries[viewerKey] then
        viewerEntries[viewerKey] = {}
    end
    table.insert(viewerEntries[viewerKey], entry)
    
    EntrySystem.ReindexViewer(viewerKey)
    
    return true
end

function EntrySystem.RemoveEntryFromViewer(id, viewerKey)
    local entry = EntrySystem.GetEntry(id)
    if not entry then
        module:LogError("EntrySystem.RemoveEntryFromViewer: Entry not found: " .. tostring(id))
        return false
    end
    
    if not entry.sources then
        entry.sources = {entry.source or viewerKey}
        entry.source = nil
    end
    
    local found = false
    for i, source in ipairs(entry.sources) do
        if source == viewerKey then
            table.remove(entry.sources, i)
            found = true
            break
        end
    end
    
    if not found then
        return false
    end
    
    local viewerList = viewerEntries[viewerKey]
    if viewerList then
        for i, e in ipairs(viewerList) do
            if e.id == id then
                table.remove(viewerList, i)
                break
            end
        end
    end
    
    -- For blizzard entries, if removed from all viewers, clear frame lookup
    if entry.type == "blizzard" and entry.frame and #entry.sources == 0 then
        entriesByFrame[entry.frame] = nil
    end
    
    if #entry.sources == 0 then
        EntrySystem.RemoveEntry(id)
    else
        EntrySystem.ReindexViewer(viewerKey)
    end
    
    return true
end

function EntrySystem.MoveEntryToViewer(id, newViewerKey)
    local entry = EntrySystem.GetEntry(id)
    if not entry then
        module:LogError("EntrySystem.MoveEntryToViewer: Entry not found: " .. tostring(id))
        return false
    end
    
    local sources = entry.sources or {entry.source}
    if #sources == 1 and sources[1] == newViewerKey then
        return true
    end
    
    for _, oldViewerKey in ipairs(sources) do
        EntrySystem.RemoveEntryFromViewer(id, oldViewerKey)
    end
    
    EntrySystem.AddEntryToViewer(id, newViewerKey)
    
    return true
end

function EntrySystem.CleanupInvalidEntries(viewerKey)
    -- Remove blizzard entries without frames, without content, and duplicate entries for same frame
    local viewerList = viewerEntries[viewerKey] or {}
    local entriesToRemove = {}
    local framesSeen = {}
    
    for _, entry in ipairs(viewerList) do
        if entry.type == "blizzard" then
            if not entry.frame then
                -- Entry has no frame - invalid
                table.insert(entriesToRemove, entry.id)
            elseif not entry.spellID and not entry.itemID and not entry.slotID then
                -- Entry has no cooldown content - invalid (empty frame)
                table.insert(entriesToRemove, entry.id)
            elseif framesSeen[entry.frame] then
                -- Duplicate entry for same frame - remove this one (keep the first one)
                table.insert(entriesToRemove, entry.id)
            else
                -- First entry for this frame - mark it
                framesSeen[entry.frame] = entry.id
            end
        end
    end
    
    for _, entryID in ipairs(entriesToRemove) do
        EntrySystem.RemoveEntryFromViewer(entryID, viewerKey)
    end
    
    return #entriesToRemove
end

module.EntrySystem = EntrySystem
