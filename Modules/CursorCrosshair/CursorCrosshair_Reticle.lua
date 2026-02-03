local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("CursorCrosshair")

local Reticle = {}
module.Reticle = Reticle

local UIParent = UIParent
local CreateFrame = CreateFrame
local GetScaledCursorPosition = GetScaledCursorPosition
local InCombatLockdown = InCombatLockdown
local UnitClass = UnitClass
local C_ClassColor = C_ClassColor
local C_Spell = C_Spell
local type = type

local ringFrame, ringTexture, reticleTexture, gcdCooldown
local eventFrame

local cursorUpdateEnabled = false
local rightClickHookInstalled = false
local cachedOffsetX, cachedOffsetY = 0, 0
local lastCursorX, lastCursorY = 0, 0

local CONSTANTS = module.CONSTANTS

local RING_TEXTURES = {
    standard = "Interface\\AddOns\\TavernUI\\Modules\\CursorCrosshair\\assets\\tui_ring.png",
    thin     = "Interface\\AddOns\\TavernUI\\Modules\\CursorCrosshair\\assets\\tui_ring_thin.png",
}

local RETICLE_OPTIONS = {
    cross   = { path = "uitools-icon-plus", isAtlas = true },
    chevron = { path = "uitools-icon-chevron-down", isAtlas = true },
    diamond = { path = "UF-SoulShard-FX-FrameGlow", isAtlas = true },
}

local function GetRingColor()
    if module:GetSetting("reticle.useClassColor", false) then
        local _, classFile = UnitClass("player")
        local color = C_ClassColor.GetClassColor(classFile)
        if color then
            return color.r, color.g, color.b, 1
        end
        return 1, 1, 1, 1
    else
        local c = module:GetSetting("reticle.customColor", { 0.82, 0.82, 0.82, 1 })
        return c[1] or 0.82, c[2] or 0.82, c[3] or 0.82, c[4] or 1
    end
end

local function IsCooldownActive(start, duration)
    if not start or not duration then return false end

    if canaccessvalue and not canaccessvalue(start) then
        return true
    end

    if canaccessvalue and not canaccessvalue(duration) then
        return true
    end

    if duration == 0 or start == 0 then
        return false
    end

    return true
end

local function ReadSpellCooldown(spellID)
    if C_Spell and C_Spell.GetSpellCooldown then
        local a, b, c, d = C_Spell.GetSpellCooldown(spellID)
        if type(a) == "table" then
            local t = a
            return t.startTime or t.start, t.duration, t.modRate
        else
            return a, b, d
        end
    end
    if GetSpellCooldown then
        local s, d = GetSpellCooldown(spellID)
        return s, d, nil
    end
    return nil, nil, nil
end

local function CreateReticleFrame()
    if ringFrame then return end

    ringFrame = CreateFrame("Frame", "TavernUI_Reticle", UIParent)
    ringFrame:SetFrameStrata("TOOLTIP")
    ringFrame:EnableMouse(false)
    ringFrame:SetSize(80, 80)

    ringTexture = ringFrame:CreateTexture(nil, "BACKGROUND")
    ringTexture:SetAllPoints()
    ringTexture:SetTexture("Interface\\AddOns\\TavernUI\\Modules\\CursorCrosshair\\assets\\tui_ring.png")

    gcdCooldown = CreateFrame("Cooldown", nil, ringFrame, "CooldownFrameTemplate")
    gcdCooldown:SetAllPoints()
    gcdCooldown:EnableMouse(false)
    gcdCooldown:SetDrawSwipe(true)
    gcdCooldown:SetDrawEdge(false)
    gcdCooldown:SetHideCountdownNumbers(true)
    if gcdCooldown.SetDrawBling then gcdCooldown:SetDrawBling(false) end
    if gcdCooldown.SetUseCircularEdge then gcdCooldown:SetUseCircularEdge(true) end
    gcdCooldown:SetFrameLevel(ringFrame:GetFrameLevel() + 2)

    reticleTexture = ringFrame:CreateTexture(nil, "OVERLAY")
    reticleTexture:SetPoint("CENTER", ringFrame, "CENTER", 0, 0)

    ringFrame:Hide()
end

local function UpdateReticleDot()
    if not reticleTexture then return end

    local style = module:GetSetting("reticle.reticleStyle", "cross")
    local size = module:GetSetting("reticle.reticleSize", 10)
    local r, g, b, a = GetRingColor()

    local reticleInfo = RETICLE_OPTIONS[style] or RETICLE_OPTIONS.cross

    reticleTexture:SetAtlas(reticleInfo.path)
    reticleTexture:SetVertexColor(r, g, b, a)

    reticleTexture:SetSize(size, size)
end

local function UpdateRingAppearance()
    if not ringFrame or not ringTexture then return end

    local size = module:GetSetting("reticle.ringSize", 40)
    local style = module:GetSetting("reticle.ringStyle", "standard")
    local r, g, b, a = GetRingColor()
    local gcdEnabled = module:GetSetting("reticle.gcdEnabled", true)

    local texturePath = RING_TEXTURES[style] or RING_TEXTURES.standard
    ringTexture:SetTexture(texturePath)
    ringTexture:SetVertexColor(r, g, b, 1)

    local ringAlpha = a

    if gcdCooldown and gcdCooldown:IsShown() and gcdEnabled then
        local fadeAmount = module:GetSetting("reticle.gcdFadeRing", 0.35)
        ringAlpha = a * (1 - fadeAmount)
    end

    ringTexture:SetAlpha(ringAlpha)
    ringFrame:SetSize(size, size)

    if gcdCooldown and gcdEnabled then
        if gcdCooldown.SetSwipeTexture then
            gcdCooldown:SetSwipeTexture(texturePath)
        end
        gcdCooldown:SetSwipeColor(r, g, b, a)
        if gcdCooldown.SetReverse then
            gcdCooldown:SetReverse(module:GetSetting("reticle.gcdReverse", false))
        end
    end
end

local function UpdateGCDCooldown()
    if not gcdCooldown then return end

    local gcdEnabled = module:GetSetting("reticle.gcdEnabled", true)
    if not gcdEnabled then
        gcdCooldown:Hide()
        UpdateRingAppearance()
        return
    end

    local start, duration, modRate = ReadSpellCooldown(CONSTANTS.GCD_SPELL_ID)

    if IsCooldownActive(start, duration) then
        gcdCooldown:Show()
        if modRate then
            gcdCooldown:SetCooldown(start, duration, modRate)
        else
            gcdCooldown:SetCooldown(start, duration)
        end
    else
        gcdCooldown:Hide()
    end

    UpdateRingAppearance()
end

local EnableCursorUpdate, DisableCursorUpdate

local function CursorOnUpdate(self, elapsed)
    local x, y = GetScaledCursorPosition()

    local dx, dy = x - lastCursorX, y - lastCursorY
    if dx > -CONSTANTS.CURSOR_MOVE_THRESHOLD and dx < CONSTANTS.CURSOR_MOVE_THRESHOLD
       and dy > -CONSTANTS.CURSOR_MOVE_THRESHOLD and dy < CONSTANTS.CURSOR_MOVE_THRESHOLD then
        return
    end
    lastCursorX, lastCursorY = x, y

    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x + cachedOffsetX, y + cachedOffsetY)
end

EnableCursorUpdate = function()
    if cursorUpdateEnabled or not ringFrame then return end
    cursorUpdateEnabled = true
    ringFrame:SetScript("OnUpdate", CursorOnUpdate)
end

DisableCursorUpdate = function()
    if not cursorUpdateEnabled or not ringFrame then return end
    cursorUpdateEnabled = false
    ringFrame:SetScript("OnUpdate", nil)
end

local function UpdateVisibility(forcedInCombat)
    if not ringFrame then return end

    local enabled = module:GetSetting("reticle.enabled", false)
    if not enabled then
        ringFrame:Hide()
        DisableCursorUpdate()
        return
    end

    local inCombat = (forcedInCombat ~= nil) and forcedInCombat or InCombatLockdown()

    if module:GetSetting("reticle.hideOutOfCombat", false) and not inCombat then
        ringFrame:Hide()
        DisableCursorUpdate()
        return
    end

    ringFrame:Show()
    EnableCursorUpdate()
end

local function UpdateReticle()
    if not ringFrame then
        CreateReticleFrame()
    end

    cachedOffsetX = 0
    cachedOffsetY = 0
    UpdateVisibility()
    UpdateReticleDot()
    UpdateRingAppearance()
    UpdateGCDCooldown()
end

local function OnCombatStart()
    UpdateVisibility(true)
    UpdateRingAppearance()
    UpdateGCDCooldown()
end

local function OnCombatEnd()
    UpdateVisibility(false)
    UpdateRingAppearance()
end

local function SetupRightClickHide()
    if rightClickHookInstalled then return end
    rightClickHookInstalled = true

    WorldFrame:HookScript("OnMouseDown", function(_, button)
        if button == "RightButton" then
            if module:GetSetting("reticle.hideOnRightClick", false) and ringFrame then
                ringFrame:Hide()
            end
        end
    end)

    WorldFrame:HookScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            local enabled = module:GetSetting("reticle.enabled", false)
            if enabled and module:GetSetting("reticle.hideOnRightClick", false) and ringFrame then
                if not module:GetSetting("reticle.hideOutOfCombat", false) or InCombatLockdown() then
                    ringFrame:Show()
                end
            end
        end
    end)
end

local function SetupEvents()
    if eventFrame then return end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    eventFrame:SetScript("OnEvent", function(self, event, unit, _, spellID)
        if event == "PLAYER_REGEN_DISABLED" then
            OnCombatStart()
        elseif event == "PLAYER_REGEN_ENABLED" then
            OnCombatEnd()
        elseif event == "SPELL_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_COOLDOWN" then
            UpdateGCDCooldown()
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
            if not module:GetSetting("reticle.gcdEnabled", true) then
                if gcdCooldown then gcdCooldown:Hide() end
                return
            end
            if spellID then
                local start, duration, modRate = ReadSpellCooldown(spellID)
                if IsCooldownActive(start, duration) then
                    if gcdCooldown then
                        gcdCooldown:Show()
                        if modRate then
                            gcdCooldown:SetCooldown(start, duration, modRate)
                        else
                            gcdCooldown:SetCooldown(start, duration)
                        end
                        UpdateRingAppearance()
                    end
                else
                    UpdateGCDCooldown()
                end
            else
                UpdateGCDCooldown()
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            UpdateReticle()
        end
    end)
end

local function TeardownEvents()
    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
    end
end

function Reticle:Enable()
    CreateReticleFrame()
    SetupEvents()
    SetupRightClickHide()
    UpdateReticle()
end

function Reticle:Disable()
    TeardownEvents()
    if ringFrame then
        ringFrame:Hide()
        DisableCursorUpdate()
    end
end

function Reticle:Refresh()
    UpdateReticle()
end
