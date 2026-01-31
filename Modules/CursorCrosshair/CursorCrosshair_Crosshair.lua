local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("CursorCrosshair")

local Crosshair = {}
module.Crosshair = Crosshair

local UIParent = UIParent
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UnitExists = UnitExists
local UnitCanAttack = UnitCanAttack
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local C_Spell = C_Spell
local GetActionInfo = (C_ActionBar and C_ActionBar.GetActionInfo) or GetActionInfo
local IsActionInRange = IsActionInRange
local IsSpellKnown = IsSpellKnown
local CheckInteractDistance = CheckInteractDistance
local ipairs = ipairs

local crosshairFrame, horizLine, vertLine, horizBorder, vertBorder
local rangeCheckFrame
local eventFrame

local isOutOfRange = false
local rangeCheckElapsed = 0

local CONSTANTS = module.CONSTANTS
local MELEE_RANGE_ABILITIES = module.MELEE_RANGE_ABILITIES

local function IsOutOfMeleeRange()
    if not UnitExists("target") then
        return false
    end

    if not UnitCanAttack("player", "target") then
        return false
    end

    if UnitIsDeadOrGhost("target") then
        return false
    end

    if IsActionInRange then
        for slot = 1, 180 do
            local actionType, id, subType = GetActionInfo(slot)
            if id and (actionType == "spell" or (actionType == "macro" and subType == "spell")) then
                for _, abilityID in ipairs(MELEE_RANGE_ABILITIES) do
                    if id == abilityID then
                        local inRange = IsActionInRange(slot)
                        if inRange == true then
                            return false
                        elseif inRange == false then
                            return true
                        end
                    end
                end
            end
        end
    end

    if C_Spell and C_Spell.IsSpellInRange then
        for _, spellID in ipairs(MELEE_RANGE_ABILITIES) do
            local spellKnown = IsSpellKnown and IsSpellKnown(spellID)
            if spellKnown then
                local inRange = C_Spell.IsSpellInRange(spellID, "target")
                if inRange == true then
                    return false
                elseif inRange == false then
                    return true
                end
            end
        end
    end

    local inRange = CheckInteractDistance("target", 3)
    if inRange ~= nil then
        return not inRange
    end

    return false
end

local function ApplyCrosshairColor(outOfRange)
    if not horizLine or not vertLine then return end

    local r, g, b, a

    if outOfRange and module:GetSetting("crosshair.changeColorOnRange", false) then
        local oorColor = module:GetSetting("crosshair.outOfRangeColor", { 0.65, 0.25, 0.25, 1 })
        r = oorColor[1] or 0.65
        g = oorColor[2] or 0.25
        b = oorColor[3] or 0.25
        a = oorColor[4] or 1
    else
        local c = module:GetSetting("crosshair.color", { 0.82, 0.82, 0.82, 1 })
        r = c[1] or 0.82
        g = c[2] or 0.82
        b = c[3] or 0.82
        a = c[4] or 1
    end

    horizLine:SetColorTexture(r, g, b, a)
    vertLine:SetColorTexture(r, g, b, a)
end

local function OnRangeUpdate(self, elapsed)
    rangeCheckElapsed = rangeCheckElapsed + elapsed
    if rangeCheckElapsed < CONSTANTS.RANGE_CHECK_INTERVAL then return end
    rangeCheckElapsed = 0

    local enabled = module:GetSetting("crosshair.enabled", false)
    local changeColorOnRange = module:GetSetting("crosshair.changeColorOnRange", false)
    if not enabled or not changeColorOnRange then
        self:SetScript("OnUpdate", nil)
        return
    end

    local inCombat = InCombatLockdown()

    if module:GetSetting("crosshair.rangeColorInCombatOnly", false) and not inCombat then
        if isOutOfRange then
            isOutOfRange = false
            ApplyCrosshairColor(false)
        end
        if module:GetSetting("crosshair.hideUntilOutOfRange", false) and crosshairFrame then
            crosshairFrame:Hide()
        end
        return
    end

    local newOutOfRange = IsOutOfMeleeRange()
    if newOutOfRange ~= isOutOfRange then
        isOutOfRange = newOutOfRange
        ApplyCrosshairColor(isOutOfRange)
    end

    if module:GetSetting("crosshair.hideUntilOutOfRange", false) and crosshairFrame then
        if inCombat and isOutOfRange then
            crosshairFrame:Show()
        else
            crosshairFrame:Hide()
        end
    end
end

local function UpdateRangeChecking()
    if not crosshairFrame then return end

    if not rangeCheckFrame then
        rangeCheckFrame = CreateFrame("Frame", "TavernUI_CrosshairRangeCheck", UIParent)
        rangeCheckFrame:SetSize(1, 1)
        rangeCheckFrame:SetPoint("CENTER")
        rangeCheckFrame:Show()
    end

    local enabled = module:GetSetting("crosshair.enabled", false)
    local changeColorOnRange = module:GetSetting("crosshair.changeColorOnRange", false)
    if enabled and changeColorOnRange then
        rangeCheckElapsed = 0
        rangeCheckFrame:SetScript("OnUpdate", OnRangeUpdate)

        local inCombat = InCombatLockdown()

        if module:GetSetting("crosshair.rangeColorInCombatOnly", false) and not inCombat then
            isOutOfRange = false
            ApplyCrosshairColor(false)
        else
            isOutOfRange = IsOutOfMeleeRange()
            ApplyCrosshairColor(isOutOfRange)
        end

        if module:GetSetting("crosshair.hideUntilOutOfRange", false) then
            if inCombat and isOutOfRange then
                crosshairFrame:Show()
            else
                crosshairFrame:Hide()
            end
        end
    else
        if rangeCheckFrame then
            rangeCheckFrame:SetScript("OnUpdate", nil)
        end
        isOutOfRange = false
    end
end

local function CreateCrosshairFrame()
    if crosshairFrame then return end

    crosshairFrame = CreateFrame("Frame", "TavernUI_Crosshair", UIParent)
    crosshairFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    crosshairFrame:SetSize(1, 1)
    crosshairFrame:SetFrameStrata("HIGH")

    horizBorder = crosshairFrame:CreateTexture(nil, "BACKGROUND")
    horizBorder:SetPoint("CENTER", crosshairFrame)
    horizBorder:SetColorTexture(0, 0, 0, 1)

    vertBorder = crosshairFrame:CreateTexture(nil, "BACKGROUND")
    vertBorder:SetPoint("CENTER", crosshairFrame)
    vertBorder:SetColorTexture(0, 0, 0, 1)

    horizLine = crosshairFrame:CreateTexture(nil, "ARTWORK")
    horizLine:SetPoint("CENTER", crosshairFrame)
    horizLine:SetColorTexture(0.82, 0.82, 0.82, 1)

    vertLine = crosshairFrame:CreateTexture(nil, "ARTWORK")
    vertLine:SetPoint("CENTER", crosshairFrame)
    vertLine:SetColorTexture(0.82, 0.82, 0.82, 1)

    crosshairFrame:Hide()
end

local function UpdateCrosshair()
    if not crosshairFrame then
        CreateCrosshairFrame()
    end

    local enabled = module:GetSetting("crosshair.enabled", false)
    local size = module:GetSetting("crosshair.size", 12)
    local thickness = module:GetSetting("crosshair.thickness", 3)
    local borderSz = module:GetSetting("crosshair.borderSize", 2)
    local offsetX = module:GetSetting("crosshair.offsetX", 0)
    local offsetY = module:GetSetting("crosshair.offsetY", 0)
    local strata = module:GetSetting("crosshair.strata", "HIGH")
    local onlyInCombat = module:GetSetting("crosshair.onlyInCombat", false)
    local changeColorOnRange = module:GetSetting("crosshair.changeColorOnRange", false)

    local bc = module:GetSetting("crosshair.borderColor", { 0, 0, 0, 1 })

    crosshairFrame:SetFrameStrata(strata)
    crosshairFrame:ClearAllPoints()
    crosshairFrame:SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY)

    horizBorder:SetSize((size * 2) + borderSz * 2, thickness + borderSz * 2)
    vertBorder:SetSize(thickness + borderSz * 2, (size * 2) + borderSz * 2)
    horizBorder:SetColorTexture(bc[1] or 0, bc[2] or 0, bc[3] or 0, bc[4] or 1)
    vertBorder:SetColorTexture(bc[1] or 0, bc[2] or 0, bc[3] or 0, bc[4] or 1)

    horizLine:SetSize(size * 2, thickness)
    vertLine:SetSize(thickness, size * 2)

    if changeColorOnRange then
        isOutOfRange = IsOutOfMeleeRange()
        ApplyCrosshairColor(isOutOfRange)
    else
        local c = module:GetSetting("crosshair.color", { 0.82, 0.82, 0.82, 1 })
        horizLine:SetColorTexture(c[1] or 0.82, c[2] or 0.82, c[3] or 0.82, c[4] or 1)
        vertLine:SetColorTexture(c[1] or 0.82, c[2] or 0.82, c[3] or 0.82, c[4] or 1)
    end

    if not enabled then
        crosshairFrame:Hide()
    elseif onlyInCombat then
        crosshairFrame:SetShown(InCombatLockdown())
    else
        crosshairFrame:Show()
    end

    UpdateRangeChecking()
end

local function OnCombatStart()
    local enabled = module:GetSetting("crosshair.enabled", false)
    if enabled and module:GetSetting("crosshair.onlyInCombat", false) then
        if crosshairFrame then
            crosshairFrame:Show()
            UpdateRangeChecking()
        end
    end
end

local function OnCombatEnd()
    if module:GetSetting("crosshair.onlyInCombat", false) then
        if crosshairFrame then
            crosshairFrame:Hide()
        end
    end
end

local function OnTargetChanged()
    local enabled = module:GetSetting("crosshair.enabled", false)
    if enabled and module:GetSetting("crosshair.changeColorOnRange", false) then
        isOutOfRange = IsOutOfMeleeRange()
        ApplyCrosshairColor(isOutOfRange)
    end
end

local function SetupEvents()
    if eventFrame then return end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            OnCombatStart()
        elseif event == "PLAYER_REGEN_ENABLED" then
            OnCombatEnd()
        elseif event == "PLAYER_TARGET_CHANGED" then
            OnTargetChanged()
        elseif event == "PLAYER_ENTERING_WORLD" then
            UpdateCrosshair()
        end
    end)
end

local function TeardownEvents()
    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
    end
end

function Crosshair:Enable()
    CreateCrosshairFrame()
    SetupEvents()
    UpdateCrosshair()
end

function Crosshair:Disable()
    TeardownEvents()
    if crosshairFrame then
        crosshairFrame:Hide()
    end
    if rangeCheckFrame then
        rangeCheckFrame:SetScript("OnUpdate", nil)
    end
    isOutOfRange = false
end

function Crosshair:Refresh()
    UpdateCrosshair()
end
