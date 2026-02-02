local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("DataBar", true)
if not module then return end
local LibSharedMedia = LibStub("LibSharedMedia-3.0", true)
local Anchor = LibStub("LibAnchorRegistry-1.0", true)

local playerClassColor
do
    local _, classToken = UnitClass("player")
    if classToken then
        playerClassColor = C_ClassColor.GetClassColor(classToken)
    end
end

function module:AddSlot(barId, slotIndex, datatextName)
    local bar = self:GetBar(barId)
    if not bar then
        return
    end

    slotIndex = slotIndex or (#bar.slots + 1)

    local slot = {
        datatext = datatextName or "",
        width = nil,
        textColor = nil,
        anchorConfig = nil,
    }

    table.insert(bar.slots, slotIndex, slot)
    self:SetSetting(string.format("bars[%d].slots", barId), bar.slots)

    if self:IsEnabled() then
        if not self.barFrames[barId] and bar.enabled then
            self:CreateBarFrame(barId, bar)
        end
        self:UpdateBar(barId)
    end
end

function module:RemoveSlot(barId, slotIndex)
    local bar = self:GetBar(barId)
    if not bar or not bar.slots[slotIndex] then
        return
    end

    self:UnregisterSlotUpdates(barId, slotIndex)
    table.remove(bar.slots, slotIndex)
    self:SetSetting(string.format("bars[%d].slots", barId), bar.slots)

    if self.slotFrames[barId] and self.slotFrames[barId][slotIndex] then
        local slotFrame = self.slotFrames[barId][slotIndex]
        slotFrame:Hide()
        slotFrame:SetParent(nil)
        self.slotFrames[barId][slotIndex] = nil
        self.slotTexts[barId][slotIndex] = nil
    end

    if self:IsEnabled() then
        self:UpdateBar(barId)
    end
end

function module:MoveSlot(barId, fromIndex, toIndex)
    local bar = self:GetBar(barId)
    if not bar or not bar.slots[fromIndex] then
        return
    end

    local slot = table.remove(bar.slots, fromIndex)
    table.insert(bar.slots, toIndex, slot)
    self:SetSetting(string.format("bars[%d].slots", barId), bar.slots)

    if self:IsEnabled() then
        self:UpdateBar(barId)
    end
end

function module:UpdateSlot(barId, slotIndex, config)
    local bar = self:GetBar(barId)
    if not bar or not bar.slots[slotIndex] then
        return
    end

    for k, v in pairs(config) do
        bar.slots[slotIndex][k] = v
    end

    if self:IsEnabled() then
        self:UpdateBar(barId)
    end
end

function module:UpdateBarSlots(barId, bar)
    if not bar then
        bar = self:GetBar(barId)
    end

    if not bar then
        self:Debug("UpdateBarSlots: No bar found for barId %d", barId)
        return
    end

    local frame = self.barFrames[barId]
    if not frame then
        self:Debug("UpdateBarSlots: No bar frame found for barId %d", barId)
        return
    end

    local numSlots = #bar.slots
    self:Debug("UpdateBarSlots: Updating %d slots for barId %d", numSlots, barId)

    for slotIndex, slot in ipairs(bar.slots) do
        self:Debug("UpdateBarSlots: Creating slot %d with datatext=%s", slotIndex, slot.datatext or "nil")
        self:CreateSlot(barId, slotIndex, slot, bar)
    end

    if self.slotFrames[barId] then
        for slotIndex = numSlots + 1, #self.slotFrames[barId] do
            if self.slotFrames[barId][slotIndex] then
                self.slotFrames[barId][slotIndex]:Hide()
            end
        end
    end

    self:LayoutSlots(barId, bar)
end

function module:CreateSlot(barId, slotIndex, slot, bar)
    if not self.barFrames[barId] then
        self:Debug("CreateSlot: No bar frame for barId %d", barId)
        return
    end

    if not self.slotFrames[barId] then
        self.slotFrames[barId] = {}
    end

    if not self.slotTexts[barId] then
        self.slotTexts[barId] = {}
    end

    self:UnregisterSlotUpdates(barId, slotIndex)

    local slotFrame = self.slotFrames[barId][slotIndex]
    if not slotFrame then
        slotFrame = CreateFrame("Frame", nil, self.barFrames[barId])
        self.slotFrames[barId][slotIndex] = slotFrame
    end

    local text = self.slotTexts[barId][slotIndex]
    if not text then
        text = slotFrame:CreateFontString(nil, "OVERLAY")
        self.slotTexts[barId][slotIndex] = text
        text:SetParent(slotFrame)
    end

    slotFrame:SetHeight(bar.height or 40)

    local fontPath = TavernUI:GetFontPath(bar.font)
    local fontSize = bar.fontSize or TavernUI:GetFontSize(12)
    local fontFlags = TavernUI:GetFontFlags()
    text:SetFont(fontPath, fontSize, fontFlags)
    TavernUI:ApplyFont(text, slotFrame, fontSize)

    local textColor = slot.textColor or bar.textColor
    text:SetTextColor(textColor.r, textColor.g, textColor.b, 1)

    local datatextName = slot.datatext or ""
    self:Debug("CreateSlot: barId %d, slotIndex %d, datatext=%s", barId, slotIndex, datatextName)

    if datatextName == "" then
        text:SetText("")
        text:Show()
        slotFrame:Show()
        slotFrame:SetParent(self.barFrames[barId])
        return
    end

    text:ClearAllPoints()
    text:SetPoint("LEFT", slotFrame, "LEFT", 1, 0)
    text:SetPoint("RIGHT", slotFrame, "RIGHT", -1, 0)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)

    self:SetupSlotInteractivity(slotFrame, slot)

    local datatext = self:GetDatatext(datatextName)
    if datatext and datatext.update then
        local value = datatext.update(slot)
        self:UpdateSlotLabel(barId, slotIndex, text, value or "")
    else
        text:SetText(datatextName)
    end

    self:UpdateSlotColor(barId, slotIndex, text)

    text:Show()
    slotFrame:Show()
    slotFrame:SetParent(self.barFrames[barId])

    self:RegisterSlotUpdates(barId, slotIndex, datatextName)
end

function module:SetupSlotInteractivity(slotFrame, slot)
    slotFrame:SetScript("OnEnter", nil)
    slotFrame:SetScript("OnLeave", nil)
    slotFrame:SetScript("OnMouseUp", nil)

    local datatext = self:GetDatatext(slot.datatext or "")
    if not datatext then
        slotFrame.datatext = nil
        slotFrame:EnableMouse(false)
        return
    end

    slotFrame.datatext = datatext
    slotFrame:EnableMouse(true)

    if datatext.tooltip then
        slotFrame:SetScript("OnEnter", function(frame)
            datatext.tooltip(frame)
        end)
        slotFrame:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    if datatext.onClick then
        slotFrame:SetScript("OnMouseUp", function(frame, button)
            datatext.onClick(frame, button)
        end)
    end

    if datatext.onScroll then
        slotFrame:EnableMouseWheel(true)
        slotFrame:SetScript("OnMouseWheel", function(frame, delta)
            datatext.onScroll(frame, delta)
        end)
    else
        slotFrame:EnableMouseWheel(false)
        slotFrame:SetScript("OnMouseWheel", nil)
    end
end

function module:GetLabelColorEscape(barId)
    local bar = self:GetBar(barId)
    if not bar then return "|cffb3b3b3" end
    if bar.useLabelClassColor and playerClassColor then
        return string.format("|cff%02x%02x%02x", playerClassColor.r * 255, playerClassColor.g * 255, playerClassColor.b * 255)
    end
    local tc = bar.labelColor or { r = 0.7, g = 0.7, b = 0.7 }
    return string.format("|cff%02x%02x%02x", tc.r * 255, tc.g * 255, tc.b * 255)
end

function module:GetValueColorEscape(barId)
    local bar = self:GetBar(barId)
    if not bar then return "|cffffffff" end
    if bar.useClassColor and playerClassColor then
        return string.format("|cff%02x%02x%02x", playerClassColor.r * 255, playerClassColor.g * 255, playerClassColor.b * 255)
    end
    local tc = bar.textColor or { r = 1, g = 1, b = 1 }
    return string.format("|cff%02x%02x%02x", tc.r * 255, tc.g * 255, tc.b * 255)
end

function module:UpdateSlotLabel(barId, slotIndex, text, rawValue)
    local bar = self:GetBar(barId)
    local slot = bar and bar.slots[slotIndex]
    local slotFrame = self.slotFrames[barId] and self.slotFrames[barId][slotIndex]
    local datatext = slotFrame and slotFrame.datatext

    local label
    if slot and slot.labelMode and slot.labelMode ~= "none" then
        if datatext then
            if slot.labelMode == "short" and datatext.labelShort and datatext.labelShort ~= "" then
                label = datatext.labelShort
            elseif slot.labelMode == "full" or (slot.labelMode == "short" and datatext.labelShort == nil) then
                label = datatext.label
            end
        end
    end

    local valueStr = rawValue or ""
    local hasInlineColor = false
    if datatext and datatext.getColor then
        local r, g, b = datatext.getColor()
        if r and g and b then
            valueStr = string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, valueStr)
            hasInlineColor = true
        end
    end

    if label and label ~= "" then
        local labelEsc = self:GetLabelColorEscape(barId)
        if hasInlineColor then
            text:SetText(labelEsc .. label .. ":|r " .. valueStr)
        else
            local valueEsc = self:GetValueColorEscape(barId)
            text:SetText(labelEsc .. label .. ":|r " .. valueEsc .. (rawValue or "") .. "|r")
        end
    elseif rawValue then
        text:SetText(valueStr)
    end
end

function module:UpdateSlotColor(barId, slotIndex, text)
    local bar = self:GetBar(barId)
    local slot = bar and bar.slots[slotIndex]
    local slotFrame = self.slotFrames[barId] and self.slotFrames[barId][slotIndex]

    local hasLabel = slot and slot.labelMode and slot.labelMode ~= "none"
    if slotFrame and slotFrame.datatext and (slotFrame.datatext.getColor or hasLabel) then
        text:SetTextColor(1, 1, 1)
        return
    end

    if bar then
        if bar.useClassColor and playerClassColor then
            text:SetTextColor(playerClassColor.r, playerClassColor.g, playerClassColor.b)
            return
        end
        local tc = bar.textColor or {r = 1, g = 1, b = 1}
        text:SetTextColor(tc.r, tc.g, tc.b)
    end
end

function module:LayoutSlots(barId, bar)
    local frame = self.barFrames[barId]
    if not frame then
        self:Debug("LayoutSlots: No bar frame for barId %d", barId)
        return
    end

    local numSlots = #bar.slots
    if numSlots == 0 then
        return
    end

    local barWidth = frame:GetWidth()
    local barHeight = frame:GetHeight()
    local slotWidth = barWidth / numSlots

    self:Debug("LayoutSlots: Laying out %d slots for barId %d, slotWidth=%.1f", numSlots, barId, slotWidth)

    for slotIndex, slot in ipairs(bar.slots) do
        local slotFrame = self.slotFrames[barId][slotIndex]
        if not slotFrame then
            break
        end

        slotFrame:ClearAllPoints()
        slotFrame:SetSize(slotWidth, barHeight)
        slotFrame:SetPoint("LEFT", frame, "LEFT", (slotIndex - 1) * slotWidth, 0)
        slotFrame:Show()
    end
end
