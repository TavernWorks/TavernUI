local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local LDB = LibStub("LibDataBroker-1.1", true)
if not LDB then return end

local function StripColorCodes(text)
    if not text then return nil end
    return tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

local function RegisterLDBDatatext(name, obj)
    if not obj or (obj.type ~= "data source" and obj.type ~= "launcher") then
        return
    end

    local cleanName = StripColorCodes(name) or name
    local datatextName = "LDB: " .. cleanName

    DataBar:RegisterDatatext(datatextName, {
        label = cleanName,
        update = function()
            return obj.text or ""
        end,
        tooltip = function(frame)
            if obj.OnTooltipShow then
                GameTooltip:SetOwner(frame, "ANCHOR_TOP")
                GameTooltip:ClearLines()
                obj.OnTooltipShow(GameTooltip)
                GameTooltip:Show()
            elseif obj.OnEnter then
                obj.OnEnter(frame)
            end
        end,
        onClick = function(frame, button)
            if obj.OnClick then
                obj.OnClick(frame, button)
            end
        end,
    })
end

for name, obj in LDB:DataObjectIterator() do
    RegisterLDBDatatext(name, obj)
end

LDB.RegisterCallback(DataBar, "LibDataBroker_DataObjectCreated", function(_, name, obj)
    RegisterLDBDatatext(name, obj)
    DataBar:RefreshOptions(true)
end)

LDB.RegisterCallback(DataBar, "LibDataBroker_AttributeChanged", function(_, name, attr)
    if attr == "text" or attr == "value" then
        local cleanName = StripColorCodes(name) or name
        DataBar:RefreshDatatext("LDB: " .. cleanName)
    end
end)
