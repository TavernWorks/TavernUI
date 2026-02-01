local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("ResourceBars")
if not module then return end

local RESOURCE_BAR_ANCHOR_NAME = "TavernUI.ResourceBars.ResourceBar"
local SPECIAL_RESOURCE_ANCHOR_NAME = "TavernUI.ResourceBars.SpecialResource"
local MAIN_DISPLAY_NAMES = {
    HEALTH = "Health",
    PRIMARY_POWER = "Primary Power",
    ALTERNATE_POWER = "Alternate Power",
}

local function GetAnchorName(barId)
    if module:IsSpecialResourceType(barId) then return SPECIAL_RESOURCE_ANCHOR_NAME end
    if module:IsResourceBarType(barId) then return RESOURCE_BAR_ANCHOR_NAME end
    return "TavernUI.ResourceBars." .. barId
end

local function GetDisplayName(barId)
    if module:IsSpecialResourceType(barId) then return "Special Resource" end
    if module:IsResourceBarType(barId) then return "Resource Bar" end
    return MAIN_DISPLAY_NAMES[barId] or barId
end

local function getConfig(barId)
    local config = module:GetBarConfig(barId)
    return (config and config.anchorConfig and type(config.anchorConfig) == "table") and config.anchorConfig or {}
end

local function persistBarAnchorConfig(barId, anchorConfig)
    if module:IsResourceBarType(barId) then
        module:SetSetting("resourceBarAnchorConfig", anchorConfig or {})
        if not anchorConfig or not anchorConfig.target then
            module:SetSetting("resourceBarAnchorCategory", nil)
        end
    elseif module:IsSpecialResourceType(barId) then
        module:SetSetting("specialResourceAnchorConfig", anchorConfig or {})
        if not anchorConfig or not anchorConfig.target then
            module:SetSetting("specialResourceAnchorCategory", nil)
        end
    else
        module:SetSetting("bars." .. barId .. "." .. module.CONSTANTS.KEY_ANCHOR_CONFIG, anchorConfig or {})
        if not anchorConfig or not anchorConfig.target then
            module:SetSetting("bars." .. barId .. ".anchorCategory", nil)
        end
    end
end

local function afterSetConfig(barId)
    if module:IsResourceBarType(barId) then
        for _, rid in ipairs(module:GetResourceBarIds()) do
            if rid ~= barId and module.bars and module.bars[rid] then
                TavernUI:ApplyAnchor(rid)
            end
        end
    elseif module:IsSpecialResourceType(barId) then
        for _, rid in ipairs(module:GetSpecialResourceBarIds()) do
            if rid ~= barId and module.bars and module.bars[rid] then
                TavernUI:ApplyAnchor(rid)
            end
        end
    end
end

local Anchoring = {}

function Anchoring:RegisterBar(barId, frame)
    if not frame then return end
    frame.barId = barId
    TavernUI:RegisterAnchor(barId, frame, {
        displayName = GetDisplayName(barId),
        anchorName = GetAnchorName(barId),
        category = "resourcebars",
        getConfig = getConfig,
        setConfig = persistBarAnchorConfig,
        afterSetConfig = afterSetConfig,
    })
end

function Anchoring:UnregisterBar(barId, frame)
    TavernUI:UnregisterAnchor(barId, GetAnchorName(barId))
end

function Anchoring:ApplyAnchor(barId)
    TavernUI:ApplyAnchor(barId)
end

function Anchoring:RefreshBar(barId)
    if not module:IsEnabled() then return end
    TavernUI:RefreshAnchor(barId)
end

function Anchoring:ClearLayoutPositionForBar(barId)
    TavernUI:ClearLayoutPosition(barId)
end

function Anchoring:UpdateAnchors()
    if not module:IsEnabled() then return end
    if TavernUI:IsEditModeActive() then return end
    for barId, _ in pairs(module.bars or {}) do
        local frame = module.bars[barId]
        if frame then
            self:RegisterBar(barId, frame)
            self:ApplyAnchor(barId)
        end
    end
end

function Anchoring:Initialize()
    TavernUI:EnableModule("Anchoring")
    self:UpdateAnchors()
end

module.Anchoring = Anchoring
