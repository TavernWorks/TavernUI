local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("Castbar")
local CONSTANTS = module.CONSTANTS

local Cast = {}
module.Cast = Cast

local format = string.format
local max = math.max
local min = math.min
local floor = math.floor
local abs = math.abs
local GetTime = GetTime

local function SafeToNumber(v)
    if v == nil then return nil end
    if type(v) == "number" then return v end
    local ok, n = pcall(tonumber, v)
    if ok and type(n) == "number" then return n end
    return nil
end

Cast.SafeToNumber = SafeToNumber

local function GetCastInfo(unit)
    local spellName, text, texture, startTimeMS, endTimeMS, _, _, notInterruptible, unitSpellID = UnitCastingInfo(unit)
    local isChanneled = false
    local channelStages = 0

    if not spellName then
        spellName, text, texture, startTimeMS, endTimeMS, _, notInterruptible, _, _, channelStages = UnitChannelInfo(unit)
        if spellName then
            isChanneled = true
        end
    end

    local durationObj = nil
    if spellName then
        local getDurationFn = isChanneled and UnitChannelDuration or UnitCastingDuration
        if type(getDurationFn) == "function" then
            local ok, dur = pcall(getDurationFn, unit)
            if ok then durationObj = dur end
        end
    end

    local hasSecretTiming = false
    if spellName and startTimeMS and endTimeMS then
        if issecretvalue and issecretvalue(startTimeMS) then
            hasSecretTiming = true
        end
        if not hasSecretTiming then
            local ok = pcall(function() return startTimeMS + 0 end)
            if not ok then hasSecretTiming = true end
        end
    end

    return spellName, text, texture, startTimeMS, endTimeMS, notInterruptible,
           unitSpellID, isChanneled, channelStages, durationObj, hasSecretTiming
end

Cast.GetCastInfo = GetCastInfo

local function DetectEmpoweredCast(isPlayer, spellID, unitSpellID, isEmpowerEvent, isChanneled, channelStages)
    if not isPlayer then return false, 0 end

    local isEmpowered = isEmpowerEvent or false
    local numStages = 0

    if isChanneled and isEmpowerEvent and channelStages and channelStages > 0 then
        numStages = channelStages
        isEmpowered = true
    end

    local checkSpellID = spellID or unitSpellID
    if checkSpellID and C_Spell and C_Spell.GetSpellEmpowerInfo then
        local empowerInfo = C_Spell.GetSpellEmpowerInfo(checkSpellID)
        if empowerInfo and empowerInfo.numStages and empowerInfo.numStages > 0 then
            isEmpowered = true
            numStages = empowerInfo.numStages
        end
    end

    return isEmpowered, numStages
end

local function AdjustEmpoweredEndTime(unit, isPlayer, isEmpowered, endTime)
    if not (isPlayer and isEmpowered and GetUnitEmpowerHoldAtMaxTime) then
        return endTime
    end
    local ok, adjusted = pcall(function()
        local ht = GetUnitEmpowerHoldAtMaxTime(unit)
        if ht and ht > 0 then
            return endTime + (ht / 1000)
        end
        return endTime
    end)
    return ok and adjusted or endTime
end

local function ApplyBarColor(bar, notInterruptible)
    if not bar.statusBar then return end
    if notInterruptible then
        local settings = module:GetUnitSettings(bar.unitKey) or {}
        local c = settings.notInterruptibleColor
        if c then
            bar.statusBar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
        else
            bar.statusBar:SetStatusBarColor(0.7, 0.2, 0.2, 1)
        end
    else
        local r, g, b, a = module:GetBarColor(bar.unitKey)
        bar.statusBar:SetStatusBarColor(r, g, b, a)
    end
end

Cast.ApplyBarColor = ApplyBarColor

local function UpdateThrottledText(bar, elapsed, fontString, value)
    bar.textThrottle = (bar.textThrottle or 0) + elapsed
    if bar.textThrottle >= CONSTANTS.TEXT_THROTTLE then
        bar.textThrottle = 0
        if fontString then
            fontString:SetText(format("%.1f", value))
        end
        return true
    end
    return false
end

local function UpdateSpellText(bar, text, spellName)
    if not bar.spellText then return end
    local settings = module:GetUnitSettings(bar.unitKey) or {}
    local displayName = text or spellName or "Casting..."
    local maxLen = settings.maxTextLength
    if maxLen and maxLen > 0 then
        displayName = module.TruncateName(displayName, maxLen)
    end
    bar.spellText:SetText(displayName)
end

local function SimulateCast(bar)
    if not bar or not bar.frame then return end

    bar.isPreviewSimulation = true
    bar.isChanneled = false
    bar.isEmpowered = false
    bar.notInterruptible = false
    bar.timerDriven = false

    local duration = CONSTANTS.PREVIEW_DURATION
    local now = GetTime()
    bar.previewStartTime = now
    bar.previewEndTime = now + duration
    bar.previewMaxValue = duration
    bar.previewValue = 0

    bar.statusBar:SetMinMaxValues(0, duration)
    bar.statusBar:SetValue(0)
    bar.statusBar:SetReverseFill(false)

    local r, g, b, a = module:GetBarColor(bar.unitKey)
    bar.statusBar:SetStatusBarColor(r, g, b, a)

    if bar.icon and bar.icon.texture then
        bar.icon.texture:SetTexture(CONSTANTS.PREVIEW_ICON_ID)
    end

    if bar.spellText then bar.spellText:SetText("Preview Cast") end
    if bar.timeText then bar.timeText:SetText(format("%.1f", duration)) end

    bar.frame:Show()
end

local function ClearPreviewSimulation(bar)
    if not bar then return end

    bar.isPreviewSimulation = false
    bar.previewStartTime = nil
    bar.previewEndTime = nil
    bar.previewMaxValue = nil
    bar.previewValue = nil

    if not UnitCastingInfo(bar.unitKey) and not UnitChannelInfo(bar.unitKey) then
        bar.frame:Hide()
    end
end

local function StopCast(bar, checkPreview)
    if bar.isPlayer and module.Empowered then
        module.Empowered:ClearEmpoweredState(bar)
    end

    bar.timerDriven = false
    bar.durationObj = nil
    bar.isChanneled = false
    bar.isEmpowered = false
    bar.notInterruptible = false
    bar.numStages = 0
    bar.settings = nil
    bar.frame:SetScript("OnUpdate", nil)
    bar.frame:Hide()

    if checkPreview then
        local unitKey = bar.unitKey
        C_Timer.After(0.1, function()
            if not UnitCastingInfo(unitKey) and not UnitChannelInfo(unitKey) then
                local settings = module:GetUnitSettings(unitKey) or {}
                if settings.previewMode and bar.frame then
                    SimulateCast(bar)
                    bar.frame:SetScript("OnUpdate", bar.onUpdate)
                end
            end
        end)
    end
end

function Cast:SetupEvents(bar, unitKey)
    local frame = bar.frame
    local isPlayer = bar.isPlayer
    local unit = unitKey

    local function OnUpdate(self, elapsed)
        local spellName = UnitCastingInfo(unit)
        local channelName = UnitChannelInfo(unit)
        local isInEmpoweredHold = isPlayer and bar.isEmpowered and bar.startTime and bar.endTime

        if spellName or channelName or isInEmpoweredHold then

            if bar.timerDriven and not isPlayer then
                local remaining = nil

                if bar.durationObj then
                    local getter = bar.durationObj.GetRemainingDuration or bar.durationObj.GetRemaining
                    if getter then
                        local okRem, rem = pcall(getter, bar.durationObj)
                        if okRem and rem ~= nil then
                            remaining = SafeToNumber(rem)
                        end
                    end
                end

                if remaining == nil and bar.statusBar.GetValue then
                    local okV, value = pcall(bar.statusBar.GetValue, bar.statusBar)
                    local okMM, minV, maxV = pcall(bar.statusBar.GetMinMaxValues, bar.statusBar)
                    if okV and okMM then
                        value = SafeToNumber(value)
                        minV = SafeToNumber(minV) or 0
                        maxV = SafeToNumber(maxV)
                        if value and maxV and maxV > minV then
                            local span = maxV - minV
                            if bar._assumeCountdown == nil then
                                bar._assumeCountdown = (abs(maxV - value) < abs(value - minV))
                            end
                            remaining = bar._assumeCountdown and (value - minV) or (maxV - value)
                            remaining = max(0, min(span, remaining))
                        end
                    end
                end

                if remaining ~= nil then
                    UpdateThrottledText(bar, elapsed, bar.timeText, remaining)
                end
                return
            end

            local startTime = bar.startTime
            local endTime = bar.endTime

            if not startTime or not endTime then
                StopCast(bar, true)
                return
            end

            local now = GetTime()
            if now >= endTime then
                StopCast(bar, true)
                return
            end

            local duration = endTime - startTime
            if duration <= 0 then duration = 0.001 end

            local settings = bar.settings or module:GetUnitSettings(unitKey) or {}
            local shouldDrain = bar.isChanneled and not bar.isEmpowered and not settings.channelFillForward
            local progress = shouldDrain and (endTime - now) or (now - startTime)
            local remaining = endTime - now

            bar.statusBar:SetMinMaxValues(0, duration)
            bar.statusBar:SetValue(progress)

            if isPlayer and bar.isEmpowered and module.Empowered then
                module.Empowered:UpdateFillColor(bar, progress, duration)

                if settings.showEmpoweredLevel and bar.empoweredLevelText then
                    local currentStage, _, isEmp = module.Empowered:GetEmpoweredLevel()
                    if isEmp and currentStage then
                        bar.textThrottle = (bar.textThrottle or 0) + elapsed
                        if bar.textThrottle >= CONSTANTS.TEXT_THROTTLE then
                            bar.textThrottle = 0
                            bar.empoweredLevelText:SetText(tostring(floor(currentStage)))
                        end
                    else
                        bar.empoweredLevelText:SetText("")
                    end
                elseif bar.empoweredLevelText then
                    bar.empoweredLevelText:SetText("")
                end

                if settings.hideTimeTextOnEmpowered and bar.timeText then
                    bar.timeText:Hide()
                end
            elseif isPlayer and bar.empoweredLevelText then
                bar.empoweredLevelText:SetText("")
                if settings.showTimeText ~= false and bar.timeText then
                    bar.timeText:Show()
                end
            end

            if not (isPlayer and bar.isEmpowered and settings.hideTimeTextOnEmpowered) then
                UpdateThrottledText(bar, elapsed, bar.timeText, max(0, remaining))
            end

        elseif bar.isPreviewSimulation then
            if not bar.previewStartTime or not bar.previewEndTime then return end

            local now = GetTime()
            if now >= bar.previewEndTime then
                bar.previewStartTime = now
                bar.previewEndTime = now + bar.previewMaxValue
                bar.previewValue = 0
            end

            bar.previewValue = (bar.previewValue or 0) + elapsed
            local progress = min(bar.previewValue, bar.previewMaxValue)
            local remaining = bar.previewMaxValue - progress

            bar.statusBar:SetValue(progress)
            UpdateThrottledText(bar, elapsed, bar.timeText, remaining)
        else
            StopCast(bar, true)
        end
    end

    bar.onUpdate = OnUpdate

    local function StartCast(spellID, isEmpowerEvent)
        local spellName, text, texture, startTimeMS, endTimeMS, notInterruptible,
              unitSpellID, isChanneled, channelStages, durationObj, hasSecretTiming = GetCastInfo(unit)

        local isEmpowered, numStages = DetectEmpoweredCast(isPlayer, spellID, unitSpellID, isEmpowerEvent, isChanneled, channelStages)

        local canShowCast = false
        local useTimerDriven = false
        local startTime, endTime

        if spellName then
            if isPlayer then
                if startTimeMS and endTimeMS then
                    local success
                    success, startTime, endTime = pcall(function()
                        return startTimeMS / 1000, endTimeMS / 1000
                    end)
                    canShowCast = success
                end
            else
                if hasSecretTiming and durationObj and bar.statusBar.SetTimerDuration then
                    useTimerDriven = true
                    canShowCast = true
                elseif startTimeMS and endTimeMS then
                    local success
                    success, startTime, endTime = pcall(function()
                        return startTimeMS / 1000, endTimeMS / 1000
                    end)
                    canShowCast = success
                elseif durationObj and bar.statusBar.SetTimerDuration then
                    useTimerDriven = true
                    canShowCast = true
                end
            end
        end

        if canShowCast then
            if bar.isPreviewSimulation then
                ClearPreviewSimulation(bar)
            end

            bar.isChanneled = isChanneled
            bar.isEmpowered = isEmpowered
            bar.numStages = numStages or 0
            bar.notInterruptible = notInterruptible
            bar.timerDriven = useTimerDriven
            bar.durationObj = durationObj
            bar._assumeCountdown = nil
            bar.textThrottle = 0
            bar.settings = module:GetUnitSettings(unitKey) or {}

            if useTimerDriven then
                local direction = (isChanneled and not bar.settings.channelFillForward) and 1 or 0
                local ok = pcall(bar.statusBar.SetTimerDuration, bar.statusBar, durationObj, 0, direction)
                if not ok then
                    pcall(bar.statusBar.SetTimerDuration, bar.statusBar, durationObj)
                end
                bar.startTime = nil
                bar.endTime = nil
            else
                endTime = AdjustEmpoweredEndTime(unit, isPlayer, isEmpowered, endTime)
                bar.startTime = startTime
                bar.endTime = endTime

                local now = GetTime()
                local duration = endTime - startTime
                if duration > 0 then
                    local shouldDrain = isChanneled and not isEmpowered and not bar.settings.channelFillForward
                    local progress = shouldDrain and (endTime - now) or (now - startTime)
                    bar.statusBar:SetMinMaxValues(0, duration)
                    bar.statusBar:SetValue(max(0, min(duration, progress)))
                end

                if bar.timeText then
                    local remaining = endTime - GetTime()
                    bar.timeText:SetText(format("%.1f", max(0, remaining)))
                end
            end

            if texture and bar.icon and bar.icon.texture then
                bar.icon.texture:SetTexture(texture)
                if bar.settings.showIcon ~= false then
                    bar.icon:Show()
                end
            end

            UpdateSpellText(bar, text, spellName)
            ApplyBarColor(bar, notInterruptible)

            if isPlayer and module.Empowered then
                if isEmpowered and numStages > 0 then
                    module.Empowered:UpdateStages(bar, numStages)
                else
                    module.Empowered:ClearEmpoweredState(bar)
                end
            end

            frame:SetScript("OnUpdate", OnUpdate)
            frame:Show()
        else
            C_Timer.After(0.1, function()
                if not UnitCastingInfo(unit) and not UnitChannelInfo(unit) then
                    if isPlayer and module.Empowered then
                        module.Empowered:ClearEmpoweredState(bar)
                    end
                    bar.timerDriven = false
                    bar.durationObj = nil

                    local settings = module:GetUnitSettings(unitKey) or {}
                    if settings.previewMode then
                        SimulateCast(bar)
                        frame:SetScript("OnUpdate", OnUpdate)
                    else
                        if bar.isPreviewSimulation then
                            ClearPreviewSimulation(bar)
                        end
                        frame:SetScript("OnUpdate", nil)
                        frame:Hide()
                    end
                end
            end)
        end
    end

    bar.StartCast = StartCast

    local eventHandlers = {
        PLAYER_TARGET_CHANGED = function() StartCast() end,
        PLAYER_FOCUS_CHANGED  = function() StartCast() end,

        UNIT_SPELLCAST_START         = function(spellID) StartCast(spellID, false) end,
        UNIT_SPELLCAST_CHANNEL_START = function(spellID) StartCast(spellID, false) end,

        UNIT_SPELLCAST_STOP          = function() StopCast(bar, true) end,
        UNIT_SPELLCAST_CHANNEL_STOP  = function() StopCast(bar, true) end,
        UNIT_SPELLCAST_FAILED        = function() StopCast(bar, true) end,
        UNIT_SPELLCAST_INTERRUPTED   = function() StopCast(bar, true) end,

        UNIT_SPELLCAST_INTERRUPTIBLE = function()
            bar.notInterruptible = false
            ApplyBarColor(bar, false)
        end,
        UNIT_SPELLCAST_NOT_INTERRUPTIBLE = function()
            bar.notInterruptible = true
            ApplyBarColor(bar, true)
        end,
    }

    if isPlayer then
        eventHandlers.UNIT_SPELLCAST_EMPOWER_START = function(spellID)
            StartCast(spellID, true)
        end
        eventHandlers.UNIT_SPELLCAST_EMPOWER_UPDATE = function(spellID)
            StartCast(spellID, true)
        end
        eventHandlers.UNIT_SPELLCAST_EMPOWER_STOP = function(spellID)
            local name = UnitCastingInfo(unit)
            if name then
                if module.Empowered then
                    module.Empowered:ClearEmpoweredState(bar)
                end
                StartCast(spellID, false)
            else
                StopCast(bar, true)
            end
        end
    end

    frame:RegisterUnitEvent("UNIT_SPELLCAST_START", unit)
    frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", unit)
    frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", unit)
    frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unit)
    frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", unit)
    frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", unit)
    frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", unit)
    frame:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", unit)

    if isPlayer then
        frame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", unit)
        frame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", unit)
        frame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", unit)
    end

    if unit == "target" then
        frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif unit == "focus" then
        frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    end

    frame:SetScript("OnEvent", function(self, event, eventUnit, castGUID, spellID)
        local handler = eventHandlers[event]
        if handler then handler(spellID) end
    end)

    StartCast()
end

function Cast:EnablePreview(bar)
    if not bar then return end
    SimulateCast(bar)
    bar.frame:SetScript("OnUpdate", bar.onUpdate)
end

function Cast:DisablePreview(bar)
    if not bar then return end
    ClearPreviewSimulation(bar)
    if not UnitCastingInfo(bar.unitKey) and not UnitChannelInfo(bar.unitKey) then
        bar.frame:SetScript("OnUpdate", nil)
        bar.frame:Hide()
    end
end
