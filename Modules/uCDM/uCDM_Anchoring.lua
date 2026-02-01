local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)
if not module then return end

local Anchoring = {}

local function getDisplayName(viewerKey)
    if module.GetViewerDisplayName then
        return module:GetViewerDisplayName(viewerKey)
    end
    return (module.GetCustomViewerDisplayName and module:GetCustomViewerDisplayName(viewerKey)) or viewerKey
end

local function getConfig(id)
    return module:GetSetting("viewers." .. id .. ".anchorConfig") or {}
end

local function setConfig(id, config)
    module:SetSetting("viewers." .. id .. ".anchorConfig", config or {})
end

local function getContentSize(id)
    local LE = module.LayoutEngine
    if LE and LE.GetViewerContentSize then
        return LE.GetViewerContentSize(id)
    end
    return nil, nil
end

function Anchoring.RegisterViewer(viewerKey, viewerFrame)
    if not viewerFrame then return end
    viewerFrame.viewerKey = viewerKey
    TavernUI:RegisterAnchor(viewerKey, viewerFrame, {
        displayName = getDisplayName(viewerKey),
        anchorName = "TavernUI.uCDM." .. viewerKey,
        category = "ucdm",
        getConfig = getConfig,
        setConfig = setConfig,
        getContentSize = getContentSize,
        addToEditMode = false,
    })
end

function Anchoring.UnregisterViewer(viewerKey)
    TavernUI:UnregisterAnchor(viewerKey, "TavernUI.uCDM." .. viewerKey)
end

function Anchoring.RegisterAnchors()
    for _, id in ipairs(module:GetCustomViewerIds()) do
        local viewer = module:GetViewerFrame(id)
        if viewer then Anchoring.RegisterViewer(id, viewer) end
    end
end

function Anchoring.RefreshViewer(viewerKey)
    if not module:IsEnabled() then return end
    TavernUI:RefreshAnchor(viewerKey)
end

function Anchoring.Initialize()
    TavernUI:EnableModule("Anchoring")
    Anchoring.RegisterAnchors()
end

module.Anchoring = Anchoring
