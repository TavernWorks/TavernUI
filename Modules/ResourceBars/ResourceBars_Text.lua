local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("ResourceBars")

local Text = {}

local BAR_IDS_WITH_TEXT = {
    [module.CONSTANTS.BAR_ID_HEALTH] = true,
    [module.CONSTANTS.BAR_ID_PRIMARY_POWER] = true,
    [module.CONSTANTS.BAR_ID_STAGGER] = true,
    [module.CONSTANTS.BAR_ID_ALTERNATE_POWER] = true,
}

local TAG_NONE = "none"
local TAG_CURRENT = "current"
local TAG_CURRENT_MAX = "current_max"
local TAG_PERCENT = "percent"
local TAG_NAME = "name"
local TAG_CURRENT_PERCENT = "current_percent"
local TAG_PERCENT_CURRENT = "percent_current"

local POINTS = {
    "TOPLEFT", "TOP", "TOPRIGHT",
    "LEFT", "CENTER", "RIGHT",
    "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT",
}

local function AbbreviateNumber(num)
    if type(num) ~= "number" then return "" end
    if AbbreviateLargeNumbers then
        return AbbreviateLargeNumbers(num) or ""
    end
    return tostring(num)
end

local function GetPercentFromCurve(barId, result)
    if barId == module.CONSTANTS.BAR_ID_STAGGER then
        local cur = result and result.current
        local maxVal = result and result.max
        if type(cur) == "number" and type(maxVal) == "number" and maxVal > 0 then
            return math.min(100, (cur / maxVal) * 100)
        end
        return nil
    end
    if not CurveConstants or not CurveConstants.ScaleTo100 then return nil end
    local curve = CurveConstants.ScaleTo100
    if barId == module.CONSTANTS.BAR_ID_HEALTH then
        if UnitHealthPercent then
            return UnitHealthPercent("player", true, curve)
        end
    elseif barId == module.CONSTANTS.BAR_ID_PRIMARY_POWER then
        if UnitPowerPercent then
            return UnitPowerPercent("player", nil, true, curve)
        end
    elseif barId == module.CONSTANTS.BAR_ID_ALTERNATE_POWER then
        if UnitPowerPercent and Enum and Enum.PowerType then
            return UnitPowerPercent("player", Enum.PowerType.Alternate, true, curve)
        end
    end
    return nil
end

local function FormatOneTag(barId, tag, result)
    if not tag or tag == TAG_NONE or not result then return "" end
    if tag == TAG_NAME then
        return UnitName("player") or ""
    end
    if tag == TAG_CURRENT then
        return AbbreviateNumber(result.current)
    end
    if tag == TAG_CURRENT_MAX then
        local curStr = AbbreviateNumber(result.current)
        local maxStr = AbbreviateNumber(result.max or 1)
        return curStr .. " / " .. maxStr
    end
    if tag == TAG_PERCENT then
        local pct = GetPercentFromCurve(barId, result)
        if pct ~= nil then
            return string.format("%.1f%%", pct)
        end
        return ""
    end
    return ""
end

local function FormatTag(barId, tag, result)
    if not tag or tag == TAG_NONE or not result then return "" end
    if tag == TAG_CURRENT_PERCENT then
        return FormatOneTag(barId, TAG_CURRENT, result) .. " | " .. FormatOneTag(barId, TAG_PERCENT, result)
    end
    if tag == TAG_PERCENT_CURRENT then
        return FormatOneTag(barId, TAG_PERCENT, result) .. " | " .. FormatOneTag(barId, TAG_CURRENT, result)
    end
    return FormatOneTag(barId, tag, result)
end

local function GetTopFrameLevel(bar)
    if not bar or not bar.GetFrameLevel then return 0 end
    local level = bar:GetFrameLevel()
    if bar.GetNumChildren and bar.GetChildren then
        for i = 1, bar:GetNumChildren() do
            local child = select(i, bar:GetChildren())
            if child and child.GetFrameLevel then
                local childLevel = child:GetFrameLevel()
                if childLevel > level then level = childLevel end
            end
        end
    end
    return level
end

local function GetOrCreateFontString(frame, config)
    if type(frame.barTextFs) == "table" and frame.barTextFs[1] then
        frame.barTextFs = frame.barTextFs[1]
    end
    if frame.barTextFs and type(frame.barTextFs.SetText) == "function" then
        return frame.barTextFs
    end
    frame.barTextFs = nil
    local size = (type(config.barTextFontSize) == "number" and config.barTextFontSize > 0) and config.barTextFontSize or 12
    local fs = TavernUI:CreateFontString(frame, size, nil, "OVERLAY", frame)
    if fs then
        frame.barTextFs = fs
    end
    return fs
end

function Text:Apply(barId, frame, config, result)
    if not BAR_IDS_WITH_TEXT[barId] then return end
    local tag = config.barText or TAG_NONE
    if tag == TAG_NONE or not result then
        if type(frame.barTextFs) == "table" then
            for i = 1, 4 do
                if frame.barTextFs[i] and frame.barTextFs[i].Hide then
                    frame.barTextFs[i]:Hide()
                end
            end
        elseif frame.barTextFs and frame.barTextFs.Hide then
            frame.barTextFs:Hide()
        end
        return
    end
    local fs = GetOrCreateFontString(frame, config)
    if not fs then return end
    local barLevel = (frame.bar and GetTopFrameLevel(frame.bar)) or (frame.bar and frame.bar.GetFrameLevel and frame.bar:GetFrameLevel()) or 0
    if fs.SetFrameLevel then
        fs:SetFrameLevel(math.max(barLevel, 1) + 1)
    end
    local point = config.barTextPoint or "CENTER"
    local relPoint = config.barTextRelativePoint or point
    local ox = type(config.barTextOffsetX) == "number" and config.barTextOffsetX or 0
    local oy = type(config.barTextOffsetY) == "number" and config.barTextOffsetY or 0
    fs:ClearAllPoints()
    fs:SetPoint(point, frame, relPoint, ox, oy)
    local c = config.barTextColor or {}
    local r, g, b = c.r or 1, c.g or 1, c.b or 1
    local a = (type(c.a) == "number") and c.a or 1
    fs:SetTextColor(r, g, b, a)
    local size = (type(config.barTextFontSize) == "number" and config.barTextFontSize > 0) and config.barTextFontSize or 12
    TavernUI:ApplyFont(fs, frame, size)
    fs:SetText(FormatTag(barId, tag, result))
    fs:Show()
end

function Text:SupportsBarText(barId)
    return BAR_IDS_WITH_TEXT[barId] == true
end

Text.TAG_NONE = TAG_NONE
Text.TAG_CURRENT = TAG_CURRENT
Text.TAG_CURRENT_MAX = TAG_CURRENT_MAX
Text.TAG_PERCENT = TAG_PERCENT
Text.TAG_NAME = TAG_NAME
Text.TAG_CURRENT_PERCENT = TAG_CURRENT_PERCENT
Text.TAG_PERCENT_CURRENT = TAG_PERCENT_CURRENT
Text.POINTS = POINTS

module.Text = Text
