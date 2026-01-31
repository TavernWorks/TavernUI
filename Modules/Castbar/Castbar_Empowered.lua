local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("Castbar")
local CONSTANTS = module.CONSTANTS
local STAGE_COLORS = module.STAGE_COLORS
local STAGE_FILL_COLORS = module.STAGE_FILL_COLORS

local Empowered = {}
module.Empowered = Empowered

local unpack = unpack

local function GetStageColor(unitKey, stageIndex)
    local settings = module:GetUnitSettings(unitKey) or {}
    if settings.empoweredStageColors and settings.empoweredStageColors[stageIndex] then
        return settings.empoweredStageColors[stageIndex]
    end
    return STAGE_COLORS[stageIndex] or STAGE_COLORS[1]
end

local function GetFillColor(unitKey, stageIndex)
    local settings = module:GetUnitSettings(unitKey) or {}
    if settings.empoweredFillColors and settings.empoweredFillColors[stageIndex] then
        return settings.empoweredFillColors[stageIndex]
    end
    return STAGE_FILL_COLORS[stageIndex] or STAGE_FILL_COLORS[1]
end

function Empowered:UpdateStages(bar, numStages)
    for _, stage in ipairs(bar.empoweredStages or {}) do
        if stage then stage:Hide() end
    end
    bar.stageOverlays = bar.stageOverlays or {}
    for _, overlay in ipairs(bar.stageOverlays) do
        if overlay then overlay:Hide() end
    end

    if not numStages or numStages <= 0 then
        bar.isEmpowered = false
        bar.numStages = 0
        if bar.statusBar and bar.statusBar.bgBar then bar.statusBar.bgBar:Show() end
        return
    end

    bar.isEmpowered = true
    bar.numStages = numStages
    if bar.statusBar and bar.statusBar.bgBar then bar.statusBar.bgBar:Hide() end

    C_Timer.After(0, function()
        if not bar.statusBar or not module.castbars[bar.unitKey] then return end
        if not bar.statusBar:IsVisible() then
            C_Timer.After(0.066, function()
                if not module.castbars[bar.unitKey] then return end
                Empowered:UpdateStages(bar, numStages)
            end)
            return
        end

        local barWidth = bar.statusBar:GetWidth()
        if barWidth <= 0 then barWidth = 150 end
        local barHeight = bar.statusBar:GetHeight()

        local stagePositions = CONSTANTS.STAGE_POSITIONS[numStages]
        if not stagePositions then
            stagePositions = CONSTANTS.STAGE_POSITIONS[1]
        end
        bar.stagePositions = stagePositions

        for i = 1, #stagePositions - 1 do
            local overlay = bar.stageOverlays[i]
            if not overlay then
                overlay = bar.statusBar:CreateTexture(nil, "BACKGROUND", nil, 1)
                bar.stageOverlays[i] = overlay
            end

            local startPos = stagePositions[i] * barWidth
            local endPos = stagePositions[i + 1] * barWidth
            local width = endPos - startPos

            local stageColor = GetStageColor(bar.unitKey, i)
            overlay:SetColorTexture(unpack(stageColor))
            overlay:SetSize(width, barHeight)
            overlay:ClearAllPoints()
            overlay:SetPoint("LEFT", bar.statusBar, "LEFT", startPos, 0)
            overlay:SetPoint("TOP", bar.statusBar, "TOP", 0, 0)
            overlay:SetPoint("BOTTOM", bar.statusBar, "BOTTOM", 0, 0)
            overlay:Show()
        end

        for i = 2, #stagePositions - 1 do
            local tickIndex = i - 1
            local stage = bar.empoweredStages[tickIndex]
            if not stage then
                stage = bar.statusBar:CreateTexture(nil, "OVERLAY", nil, 2)
                stage:SetColorTexture(1, 1, 1, 0.95)
                stage:SetWidth(2)
                bar.empoweredStages[tickIndex] = stage
            end

            stage:SetHeight(barHeight)
            local position = stagePositions[i] * barWidth
            stage:ClearAllPoints()
            stage:SetPoint("LEFT", bar.statusBar, "LEFT", position - 1, 0)
            stage:SetPoint("TOP", bar.statusBar, "TOP", 0, 0)
            stage:SetPoint("BOTTOM", bar.statusBar, "BOTTOM", 0, 0)
            stage:Show()
        end
    end)
end

function Empowered:ClearEmpoweredState(bar)
    if not bar then return end

    bar.isEmpowered = false
    bar.numStages = 0
    bar.stagePositions = nil

    for _, overlay in ipairs(bar.stageOverlays or {}) do
        if overlay then overlay:Hide() end
    end

    for _, stage in ipairs(bar.empoweredStages or {}) do
        if stage then stage:Hide() end
    end

    if bar.statusBar and bar.statusBar.bgBar then
        bar.statusBar.bgBar:Show()
    end

    if bar.empoweredLevelText then
        bar.empoweredLevelText:SetText("")
    end
end

function Empowered:UpdateFillColor(bar, progress, duration)
    if not bar.isEmpowered or not bar.stagePositions then return end

    local progressPercent = progress / duration
    local currentStage = 1

    for i = 2, #bar.stagePositions do
        if progressPercent >= bar.stagePositions[i] then
            currentStage = i
        else
            break
        end
    end

    local fillColor = GetFillColor(bar.unitKey, currentStage)
    if fillColor then
        bar.statusBar:SetStatusBarColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 1)
    end
end

function Empowered:GetEmpoweredLevel()
    local playerBar = module:GetCastbar(CONSTANTS.UNIT_PLAYER)
    if not playerBar or not playerBar.isEmpowered then
        return nil, nil, false
    end

    if not playerBar.startTime or not playerBar.endTime or not playerBar.stagePositions then
        return nil, nil, false
    end

    local now = GetTime()
    local progress = now - playerBar.startTime
    local duration = playerBar.endTime - playerBar.startTime

    if duration <= 0 then
        return nil, nil, false
    end

    local progressPercent = progress / duration
    local currentStage = 0

    for i = 2, #playerBar.stagePositions do
        if progressPercent >= playerBar.stagePositions[i] then
            currentStage = i - 1
        else
            break
        end
    end

    local maxStages = playerBar.numStages or 1
    if currentStage > maxStages then
        currentStage = maxStages
    end

    return currentStage, maxStages, true
end
