local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("ResourceBars")

local ColorModes = {}

local function ToCurveColor(c)
    if CreateColor and c and c.r and c.g and c.b then
        return CreateColor(c.r, c.g, c.b, type(c.a) == "number" and c.a or 1)
    end
    return c and (c.r and c.g and c.b and c) or { r = 1, g = 1, b = 1 }
end

local function FromEvalColor(evalColor)
    if not evalColor then return 1, 1, 1 end
    if evalColor.GetRGB then
        return evalColor:GetRGB()
    end
    if type(evalColor) == "table" and evalColor.r and evalColor.g and evalColor.b then
        return evalColor.r, evalColor.g, evalColor.b
    end
    return 1, 1, 1
end

local function CreateThresholdCurve(breakpoints)
    if not C_CurveUtil or type(C_CurveUtil.CreateColorCurve) ~= "function" then
        return nil
    end
    if not breakpoints or #breakpoints == 0 then
        return nil
    end
    local curve = C_CurveUtil.CreateColorCurve()
    if not curve or not curve.AddPoint then
        return nil
    end
    if curve.SetType and Enum and Enum.LuaCurveType then
        curve:SetType(Enum.LuaCurveType.Linear)
    end
    local sorted = {}
    for _, bp in ipairs(breakpoints) do
        table.insert(sorted, bp)
    end
    table.sort(sorted, function(a, b) return (a.threshold or 0) < (b.threshold or 0) end)
    for _, bp in ipairs(sorted) do
        curve:AddPoint(bp.threshold or 0, ToCurveColor(bp.color))
    end
    return curve
end

function ColorModes:GetColorForPercentage(normalizedPct, colorMode, config)
    if colorMode == module.CONSTANTS.COLOR_MODE_THRESHOLD then
        local curve = CreateThresholdCurve(config.breakpoints)
        if not curve or not curve.Evaluate then
            return 1, 1, 1
        end
        local evalColor = curve:Evaluate(normalizedPct)
        return FromEvalColor(evalColor)
    end
    local color = config.color or { r = 1, g = 1, b = 1 }
    return color.r or 1, color.g or 1, color.b or 1
end

function ColorModes:CreateThresholdCurve(breakpoints)
    return CreateThresholdCurve(breakpoints)
end

module.ColorModes = ColorModes
