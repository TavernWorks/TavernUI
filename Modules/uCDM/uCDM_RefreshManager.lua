local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local RefreshManager = {}

local refreshPending = {}
local refreshVersion = {}
local refreshTimers = {}

function RefreshManager.Initialize()
    refreshPending = {}
    refreshVersion = {}
    refreshTimers = {}
    
    for _, viewerKey in ipairs({"essential", "utility", "buff", "custom"}) do
        refreshVersion[viewerKey] = 0
    end
    
    module:LogInfo("RefreshManager initialized")
end

local function SafeRefresh(operation, errorContext)
    local ok, result = pcall(operation)
    if not ok then
        module:LogError(errorContext .. ": " .. tostring(result))
        return nil, result
    end
    return result
end

function RefreshManager.RefreshViewer(viewerKey)
    if not viewerKey then
        module:LogError("RefreshManager.RefreshViewer: viewerKey is required")
        return
    end
    
    if refreshTimers[viewerKey] then
        refreshTimers[viewerKey]:Cancel()
        refreshTimers[viewerKey] = nil
    end
    
    refreshVersion[viewerKey] = (refreshVersion[viewerKey] or 0) + 1
    
    SafeRefresh(function()
        RefreshManager.RefreshViewerLayout(viewerKey)
        RefreshManager.RefreshViewerStyling(viewerKey)
        RefreshManager.RefreshKeybinds(viewerKey)
        RefreshManager.RefreshVisibility(viewerKey)
    end, "RefreshViewer(" .. viewerKey .. ")")
end

function RefreshManager.RefreshViewerLayout(viewerKey)
    if not viewerKey then return end
    
    SafeRefresh(function()
        if module.LayoutEngine then
            module.LayoutEngine.LayoutViewer(viewerKey)
        end
    end, "RefreshViewerLayout(" .. viewerKey .. ")")
end

function RefreshManager.RefreshViewerStyling(viewerKey)
    if not viewerKey then return end
    
    SafeRefresh(function()
        local entries = module.EntrySystem.GetMergedEntriesForViewer(viewerKey)
        local settings = module:GetViewerSettings(viewerKey)
        
        if module.Styler and settings then
            local activeRows = module.LayoutEngine.GetActiveRows(settings)
            local viewer = module.LayoutEngine.GetViewerFrame(viewerKey)
            
            if viewer then
                local rowDistribution = {}
                for _, entry in ipairs(entries) do
                    local rowNum = 1
                    if settings.rows and settings.rows[1] then
                        rowDistribution[rowNum] = rowDistribution[rowNum] or {}
                        table.insert(rowDistribution[rowNum], entry)
                    end
                end
                
                module.Styler.ApplyViewerStyling(viewer, rowDistribution, activeRows, viewerKey)
            end
        end
    end, "RefreshViewerStyling(" .. viewerKey .. ")")
end

function RefreshManager.RefreshEntry(entryID)
    if not entryID then return end
    
    SafeRefresh(function()
        local entry = module.EntrySystem.GetEntry(entryID)
        if not entry then return end
        
        if module.CooldownTracker then
            module.CooldownTracker.UpdateEntry(entry)
        end
        
        if module.Styler then
            local settings = module:GetViewerSettings(entry.source)
            if settings and settings.rows and settings.rows[1] then
                module.Styler.ApplyIconStyle(entry.frame, settings.rows[1])
            end
        end
        
        if module.Keybinds then
            module.Keybinds.UpdateEntry(entry)
        end
        
        if module.Conditions then
            module.Conditions.UpdateEntry(entry)
        end
    end, "RefreshEntry(" .. tostring(entryID) .. ")")
end

function RefreshManager.RefreshKeybinds(viewerKey)
    if not viewerKey then return end
    
    SafeRefresh(function()
        local entries = module.EntrySystem.GetMergedEntriesForViewer(viewerKey)
        if module.Keybinds then
            module.Keybinds.UpdateViewer(viewerKey, entries)
        end
    end, "RefreshKeybinds(" .. viewerKey .. ")")
end

function RefreshManager.RefreshVisibility(viewerKey)
    if not viewerKey then return end
    
    SafeRefresh(function()
        local entries = module.EntrySystem.GetMergedEntriesForViewer(viewerKey)
        if module.Conditions then
            for _, entry in ipairs(entries) do
                module.Conditions.UpdateEntry(entry)
            end
        end
    end, "RefreshVisibility(" .. viewerKey .. ")")
end

function RefreshManager.ThrottledRefresh(viewerKey, refreshType, delay)
    if not viewerKey then return end
    
    delay = delay or 0.1
    refreshType = refreshType or "full"
    
    if refreshTimers[viewerKey] then
        refreshTimers[viewerKey]:Cancel()
    end
    
    refreshTimers[viewerKey] = C_Timer.NewTimer(delay, function()
        refreshTimers[viewerKey] = nil
        
        if refreshType == "layout" then
            RefreshManager.RefreshViewerLayout(viewerKey)
        elseif refreshType == "styling" then
            RefreshManager.RefreshViewerStyling(viewerKey)
        else
            RefreshManager.RefreshViewer(viewerKey)
        end
    end)
end

function RefreshManager.Cleanup()
    for viewerKey, timer in pairs(refreshTimers) do
        if timer then
            timer:Cancel()
        end
    end
    refreshTimers = {}
    refreshPending = {}
end

module.RefreshManager = RefreshManager
