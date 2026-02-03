local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local CustomViewerManager = {}

local function CopyTableShallow(src)
    if type(src) ~= "table" then return src end
    local t = {}
    for k, v in pairs(src) do
        t[k] = (type(v) == "table" and v ~= src) and CopyTableShallow(v) or v
    end
    return t
end

function CustomViewerManager.CreateCustomViewerFrame(m, id, name)
    if not id then return end
    if not m.CustomViewerFrames then m.CustomViewerFrames = {} end
    local existing = m.CustomViewerFrames[id]
    if existing then
        if m.Anchoring and m.Anchoring.RegisterViewer then
            m.Anchoring.RegisterViewer(id, existing)
        end
        return existing
    end
    local defaultSettings = m.GetDefaultCustomViewerSettings and m:GetDefaultCustomViewerSettings() or {}
    local defaultRows = defaultSettings.rows
    local iconCount = (defaultRows and defaultRows[1] and defaultRows[1].iconCount) or 4
    local iconSize = (defaultRows and defaultRows[1] and defaultRows[1].iconSize) or 40
    local spacing = (defaultRows and defaultRows[1] and (defaultRows[1].spacing or defaultRows[1].padding)) or 0
    local aspectRatio = (defaultRows and defaultRows[1] and defaultRows[1].aspectRatioCrop) or 1.0
    local wPixels = iconCount * iconSize + (iconCount - 1) * spacing
    local hPixels = iconSize / aspectRatio

    -- Create the custom viewer as a sibling of the Essential viewer (when available)
    -- so its effective scale matches Blizzard's Essential Cooldown viewer. This keeps
    -- pixel-perfect math consistent between built-in and custom viewers.
    local globalName = "TavernUIuCDMViewer_" .. id:gsub("[^%w]", "_")
    local parent = UIParent
    local essentialViewer = m and m.GetViewerFrame and m:GetViewerFrame("essential")
    if essentialViewer and essentialViewer.GetParent then
        local p = essentialViewer:GetParent()
        if p then
            parent = p
        end
    end

    local frame = CreateFrame("Frame", globalName, parent)
    frame:SetSize(wPixels, hPixels)

    -- Default position: center on the same parent; anchoring/LibEditMode will usually
    -- reposition this frame based on the viewer's anchorConfig.
    frame:SetPoint("CENTER", parent, "CENTER", 0, 0)

    -- Match the local scale of the Essential viewer if present so that
    -- EffectiveScale(customViewer) ≈ EffectiveScale(essentialViewer).
    if essentialViewer and essentialViewer.GetScale and frame.SetScale then
        local es = essentialViewer:GetScale() or 1
        frame:SetScale(es)
    end

    m.CustomViewerFrames[id] = frame
    local list = m:GetSetting("customViewers", {})
    local alreadyInList
    for _, entry in ipairs(list) do
        if entry and entry.id == id then alreadyInList = true break end
    end
    if not alreadyInList then
        local settings = CopyTableShallow(defaultSettings)
        m:SetSetting(string.format("viewers.%s", id), settings)
        list[#list + 1] = { id = id, name = name or "New Viewer" }
        m:SetSetting("customViewers", list)
    end
    if m.Anchoring and m.Anchoring.RegisterViewer then
        m.Anchoring.RegisterViewer(id, frame)
    end
    return frame
end

function CustomViewerManager.RemoveCustomViewer(m, id)
    if not id or not CustomViewerManager.IsCustomViewerId(m, id) then return end
    local items = m.ItemRegistry and m.ItemRegistry.GetItemsForViewer(id) or {}
    for _, item in ipairs(items) do
        if item.source == "custom" and item.id and m.ItemRegistry.MoveItemToViewer then
            m.ItemRegistry.MoveItemToViewer(item.id, "essential")
        end
    end
    local customEntries = m:GetSetting("customEntries", {})
    for _, cfg in ipairs(customEntries) do
        if cfg.viewer == id then cfg.viewer = "essential" end
    end
    m:SetSetting("customEntries", customEntries)
    local frame = m.CustomViewerFrames and m.CustomViewerFrames[id]
    if frame then
        frame:Hide()
        frame:SetParent(nil)
        m.CustomViewerFrames[id] = nil
    end
    local list = m:GetSetting("customViewers", {})
    for i = #list, 1, -1 do
        if list[i] and list[i].id == id then
            table.remove(list, i)
            break
        end
    end
    m:SetSetting("customViewers", list)
    m:SetSetting(string.format("viewers.%s", id), nil)
    if m:GetSetting("defaultCustomViewer") == id then
        m:SetSetting("defaultCustomViewer", "essential")
    end
    if m.Anchoring and m.Anchoring.UnregisterViewer then
        m.Anchoring.UnregisterViewer(id)
    end
    if m.ItemRegistry and m.ItemRegistry.ClearViewerItems then
        m.ItemRegistry.ClearViewerItems(id)
    end
    if m:IsEnabled() and m.LayoutEngine then
        m.LayoutEngine.RefreshViewer("essential")
    end
end

function CustomViewerManager.SetCustomViewerName(m, id, name)
    if not id or not name or not CustomViewerManager.IsCustomViewerId(m, id) then return end
    local list = m:GetSetting("customViewers", {})
    for _, entry in ipairs(list) do
        if entry and entry.id == id then
            entry.name = name
            m:SetSetting("customViewers", list)
            if m.Anchoring and m.Anchoring.RegisterAnchors then
                m.Anchoring.RegisterAnchors()
            end
            return
        end
    end
end

function CustomViewerManager.GetCustomViewerIds(m)
    local list = m:GetSetting("customViewers", {})
    if not list or type(list) ~= "table" then return {} end
    local ids = {}
    for _, entry in ipairs(list) do
        if entry and entry.id then
            ids[#ids + 1] = entry.id
        end
    end
    return ids
end

function CustomViewerManager.IsCustomViewerId(m, viewerKey)
    if not viewerKey or type(viewerKey) ~= "string" then return false end
    for _, id in ipairs(CustomViewerManager.GetCustomViewerIds(m)) do
        if id == viewerKey then return true end
    end
    return false
end

function CustomViewerManager.GetCustomViewerDisplayName(m, viewerKey)
    local list = m:GetSetting("customViewers", {})
    if not list then return viewerKey end
    for _, entry in ipairs(list) do
        if entry and entry.id == viewerKey and entry.name then
            return entry.name
        end
    end
    return viewerKey
end

module.CustomViewerManager = CustomViewerManager
