local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

--[[
    RotationAssist - Mirrors Blizzard's rotation assist highlight onto CDM icons.

    Strategy: hook AssistedCombatManager.UpdateAllAssistedHighlightFramesForSpell,
    which Blizzard already calls (event-driven) whenever the highlighted spell changes.
    This fires in perfect sync with action bar highlights — no polling required.

    Two overlay styles:
      "native"  - uses ActionBarButtonAssistedCombatHighlightTemplate (same animated
                  ants the player sees on their action bars)
      "border"  - configurable solid color inner border (color + thickness)
]]

local RotationAssist = {}

local overlays = {}         -- frame -> overlay widget
local currentSpellID = nil  -- last spellID passed to UpdateHighlights

--------------------------------------------------------------------------------
-- Spell matching
--------------------------------------------------------------------------------

local function MatchesSpell(item, spellID)
    if not item or not item.spellID or not spellID then return false end
    if item.spellID == spellID then return true end
    -- Check override in both directions (e.g. talented or shapeshifted variants)
    if C_Spell.GetOverrideSpell then
        local ok, fwd = pcall(C_Spell.GetOverrideSpell, item.spellID)
        if ok and fwd and fwd == spellID then return true end
        local ok2, rev = pcall(C_Spell.GetOverrideSpell, spellID)
        if ok2 and rev and rev == item.spellID then return true end
    end
    return false
end

--------------------------------------------------------------------------------
-- Overlay factories
--------------------------------------------------------------------------------

-- Returns the FlipBook animation object from an AnimationGroup.
-- Uses GetAnimations() — same approach as Masque's GetFlipBookAnimation.
local function GetFlipbookAnim(animGroup)
    for _, anim in ipairs({animGroup:GetAnimations()}) do
        if anim:GetObjectType() == "FlipBook" then
            return anim
        end
    end
end

local function CreateNativeOverlay(parent, duration)
    local ok, frame = pcall(CreateFrame, "Frame", nil, parent, "ActionBarButtonAssistedCombatHighlightTemplate")
    if not ok or not frame then return nil end

    -- The template defines the frame at 45×45 with the Flipbook texture at
    -- 66×66 centred inside it.  We re-anchor the frame to the icon's centre
    -- and leave the Flipbook entirely alone — touching its anchors or size
    -- after creation corrupts its atlas UV coords (causing the full flipbook
    -- strip to render instead of a single ants frame).
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", parent, "CENTER", 0, 0)
    frame:SetFrameLevel(parent:GetFrameLevel() + 15)

    -- Advance to first frame so Show() doesn't flash the full strip.
    -- Also apply the configured cycle duration (template default is 1s = very fast).
    if frame.Flipbook and frame.Flipbook.Anim then
        local flipAnim = GetFlipbookAnim(frame.Flipbook.Anim)
        if flipAnim then
            flipAnim:SetDuration(duration or 2.5)
        end
        frame.Flipbook.Anim:Play()
        frame.Flipbook.Anim:Stop()
    end

    frame:Hide()
    return frame
end

local function CreateBorderOverlay(parent)
    local overlay = CreateFrame("Frame", nil, parent)
    overlay:SetAllPoints(parent)
    overlay:SetFrameLevel(parent:GetFrameLevel() + 15)

    local edges = {}
    for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local tex = overlay:CreateTexture(nil, "OVERLAY")
        tex:SetColorTexture(1, 1, 1, 1)
        edges[side] = tex
    end
    overlay._edges = edges

    function overlay:Apply(color, thickness)
        local r, g, b, a = color.r or 0, color.g or 1, color.b or 0.84, color.a or 0.9
        local t = thickness or 2
        local e = self._edges

        e.TOP:SetColorTexture(r, g, b, a)
        e.TOP:SetPoint("TOPLEFT",     self, "TOPLEFT",     0,  0)
        e.TOP:SetPoint("TOPRIGHT",    self, "TOPRIGHT",    0,  0)
        e.TOP:SetHeight(t)

        e.BOTTOM:SetColorTexture(r, g, b, a)
        e.BOTTOM:SetPoint("BOTTOMLEFT",  self, "BOTTOMLEFT",  0, 0)
        e.BOTTOM:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
        e.BOTTOM:SetHeight(t)

        e.LEFT:SetColorTexture(r, g, b, a)
        e.LEFT:SetPoint("TOPLEFT",    self, "TOPLEFT",    0,  -t)
        e.LEFT:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0,   t)
        e.LEFT:SetWidth(t)

        e.RIGHT:SetColorTexture(r, g, b, a)
        e.RIGHT:SetPoint("TOPRIGHT",    self, "TOPRIGHT",    0, -t)
        e.RIGHT:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0,  t)
        e.RIGHT:SetWidth(t)
    end

    overlay:Hide()
    return overlay
end

--------------------------------------------------------------------------------
-- Overlay management
--------------------------------------------------------------------------------

local function GetSetting(path, default)
    return module:GetSetting("rotationAssist." .. path, default)
end

local DEFAULT_COLOR = {r = 0, g = 1, b = 0.84, a = 0.9}

local function ShowOverlayOnFrame(frame)
    local style = GetSetting("style", "native")
    local ov = overlays[frame]

    -- Rebuild if style changed since the overlay was created
    local isNative = ov and (ov.Flipbook ~= nil)
    if ov and ((style == "native") ~= isNative) then
        ov:Hide()
        overlays[frame] = nil
        ov = nil
    end

    if not ov then
        if style == "native" then
            ov = CreateNativeOverlay(frame, GetSetting("animDuration", 2.5))
        end
        -- Fall back to border if template unavailable
        if not ov then
            ov = CreateBorderOverlay(frame)
        end
        overlays[frame] = ov
    end

    if ov.Apply then
        -- Border style: apply current color + thickness every show
        local color = GetSetting("color", DEFAULT_COLOR)
        local thickness = GetSetting("thickness", 2)
        ov:Apply(color, thickness)
    elseif ov.Flipbook and ov.Flipbook.Anim then
        -- Native style: always reset to first frame first (handles the case
        -- where the animation was stopped mid-play last time), then keep
        -- animating if we're in combat.
        ov.Flipbook.Anim:Play()
        ov.Flipbook.Anim:Stop()
        if InCombatLockdown() then
            ov.Flipbook.Anim:Play()
        end
    end

    ov:Show()
end

local function HideOverlayOnFrame(frame)
    local ov = overlays[frame]
    if not ov then return end
    if ov.Flipbook and ov.Flipbook.Anim then
        ov.Flipbook.Anim:Stop()
    end
    ov:Hide()
end

--------------------------------------------------------------------------------
-- Update
--------------------------------------------------------------------------------

-- viewerKey -> whether the user has it enabled for rotation assist
local BUILTIN_VIEWER_DEFAULTS = {
    essential = true,
    utility   = true,
    buff      = false,
    custom    = false,
}

local function UpdateHighlights(spellID)
    if not module:IsEnabled() then return end
    currentSpellID = spellID

    if not GetSetting("enabled", false) or not spellID then
        for frame in pairs(overlays) do
            HideOverlayOnFrame(frame)
        end
        return
    end

    if not module.ItemRegistry then return end

    -- Track which frames we actually lit up this pass
    local shown = {}

    for viewerKey, defaultOn in pairs(BUILTIN_VIEWER_DEFAULTS) do
        if GetSetting("viewers." .. viewerKey, defaultOn) then
            local items = module.ItemRegistry.GetItemsForViewer(viewerKey)
            for _, item in ipairs(items) do
                if item.frame and MatchesSpell(item, spellID) then
                    ShowOverlayOnFrame(item.frame)
                    shown[item.frame] = true
                end
            end
        end
    end

    -- Hide frames that were previously lit but no longer match
    for frame in pairs(overlays) do
        if not shown[frame] then
            HideOverlayOnFrame(frame)
        end
    end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function RotationAssist.HideAll()
    for frame in pairs(overlays) do
        HideOverlayOnFrame(frame)
    end
    currentSpellID = nil
end

function RotationAssist.Refresh()
    -- Wipe overlay cache so they're rebuilt with the current style
    for _, ov in pairs(overlays) do
        ov:Hide()
    end
    overlays = {}
    UpdateHighlights(currentSpellID)
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function RotationAssist.Initialize()
    -- Hook Blizzard's rotation assist highlight manager.
    -- This fires whenever Blizzard decides to show/hide the highlight on action
    -- bar buttons — no timer or polling needed on our side.
    if AssistedCombatManager and AssistedCombatManager.UpdateAllAssistedHighlightFramesForSpell then
        hooksecurefunc(
            AssistedCombatManager,
            "UpdateAllAssistedHighlightFramesForSpell",
            function(_, spellID)
                UpdateHighlights(spellID)
            end
        )
    end

    -- Live-update when settings change
    local watchPaths = {
        "rotationAssist.enabled",
        "rotationAssist.style",
        "rotationAssist.animDuration",
        "rotationAssist.color",
        "rotationAssist.thickness",
        "rotationAssist.viewers.essential",
        "rotationAssist.viewers.utility",
        "rotationAssist.viewers.buff",
        "rotationAssist.viewers.custom",
    }
    for _, path in ipairs(watchPaths) do
        module:WatchSetting(path, RotationAssist.Refresh)
    end

    -- Profile change: wipe cache and re-apply
    module:RegisterMessage("TavernUI_ProfileChanged", function()
        RotationAssist.HideAll()
        overlays = {}
    end)
end

module.RotationAssist = RotationAssist
