local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local C_SpellBook    = C_SpellBook
local C_Container    = C_Container
local GetItemSpell   = GetItemSpell

local FRAME_WIDTH  = 380
local FRAME_HEIGHT = 480
local ROW_HEIGHT   = 32
local ICON_SIZE    = 24

local Picker = {}

local pickerFrame    = nil
local currentCallback = nil
local allEntries     = {}
local filteredEntries = {}

--------------------------------------------------------------------------------
-- Row pool
--------------------------------------------------------------------------------

local function GetOrCreateRow(index)
    local content = pickerFrame.Content
    local row = pickerFrame.rows[index]
    if not row then
        row = CreateFrame("Button", nil, content)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("LEFT",  content, "LEFT",  0, 0)
        row:SetPoint("RIGHT", content, "RIGHT", 0, 0)

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)

        local sep = row:CreateTexture(nil, "BACKGROUND")
        sep:SetHeight(1)
        sep:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  0, 0)
        sep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        sep:SetColorTexture(0.2, 0.2, 0.2, 0.6)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon:SetPoint("LEFT", row, "LEFT", 8, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.Icon = icon

        local nameText = row:CreateFontString(nil, "OVERLAY")
        nameText:SetFontObject(GameFontNormal)
        nameText:SetPoint("LEFT",  icon,   "RIGHT", 6,  0)
        nameText:SetPoint("RIGHT", row,    "RIGHT", -8, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)
        row.NameText = nameText

        row:SetScript("OnClick", function(self)
            if currentCallback and self.entryData then
                currentCallback(self.entryData)
            end
            pickerFrame:Hide()
        end)

        pickerFrame.rows[index] = row
    end
    return row
end

--------------------------------------------------------------------------------
-- Filter / render
--------------------------------------------------------------------------------

function Picker.ApplyFilter(filterText)
    if not pickerFrame then return end
    filterText = filterText and filterText:lower() or ""

    filteredEntries = {}
    for _, entry in ipairs(allEntries) do
        if filterText == "" or entry.nameLower:find(filterText, 1, true) then
            filteredEntries[#filteredEntries + 1] = entry
        end
    end

    local count  = #filteredEntries
    local content = pickerFrame.Content
    content:SetHeight(math.max(count * ROW_HEIGHT, 1))

    for i, entry in ipairs(filteredEntries) do
        local row = GetOrCreateRow(i)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row.Icon:SetTexture(entry.iconID)
        row.NameText:SetText(entry.name)
        row.entryData = entry
        row:Show()
    end

    for i = count + 1, #pickerFrame.rows do
        pickerFrame.rows[i]:Hide()
    end
end

--------------------------------------------------------------------------------
-- Data collectors
--------------------------------------------------------------------------------

local function CollectSpells()
    allEntries = {}
    local seen = {}

    local numLines = C_SpellBook.GetNumSpellBookSkillLines()
    for skillLineIndex = 1, numLines do
        local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(skillLineIndex)
        if lineInfo and not lineInfo.shouldHide then
            for i = 1, lineInfo.numSpellBookItems do
                local slotIndex = lineInfo.itemIndexOffset + i
                local info = C_SpellBook.GetSpellBookItemInfo(slotIndex, Enum.SpellBookSpellBank.Player)
                if info
                    and not info.isPassive
                    and info.itemType == Enum.SpellBookItemType.Spell
                then
                    local spellID = info.spellID or info.actionID
                    if spellID and not seen[spellID] then
                        seen[spellID] = true
                        local name = info.name or ""
                        allEntries[#allEntries + 1] = {
                            id       = spellID,
                            name     = name,
                            nameLower = name:lower(),
                            iconID   = info.iconID,
                            entryType = "spell",
                        }
                    end
                end
            end
        end
    end

    table.sort(allEntries, function(a, b) return a.name < b.name end)
end

local function CollectItems()
    allEntries = {}
    local seen = {}

    for bagIndex = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bagIndex)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bagIndex, slot)
            if info and info.itemID and not seen[info.itemID] then
                local _, itemSpellID = GetItemSpell(info.itemID)
                if itemSpellID then
                    seen[info.itemID] = true
                    local name = info.itemName or ""
                    allEntries[#allEntries + 1] = {
                        id        = info.itemID,
                        name      = name,
                        nameLower = name:lower(),
                        iconID    = info.iconFileID,
                        entryType = "item",
                    }
                end
            end
        end
    end

    table.sort(allEntries, function(a, b) return a.name < b.name end)
end

--------------------------------------------------------------------------------
-- Frame construction (lazy, created once)
--------------------------------------------------------------------------------

local function CreatePickerFrame()
    local frame = CreateFrame("Frame", "TavernUICDMPickerFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop",  frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.08, 0.08, 0.08, 0.97)
    frame:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    frame:Hide()

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetHeight(28)
    titleBar:SetPoint("TOPLEFT",  frame, "TOPLEFT",  1, -1)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    titleBar:SetBackdropColor(0.13, 0.13, 0.13, 1)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetFontObject(GameFontNormal)
    titleText:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    frame.TitleText = titleText

    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -2, 0)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Filter bar
    local filterBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    filterBar:SetHeight(30)
    filterBar:SetPoint("TOPLEFT",  titleBar, "BOTTOMLEFT",  0, -2)
    filterBar:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, -2)
    filterBar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    filterBar:SetBackdropColor(0.06, 0.06, 0.06, 1)
    filterBar:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    local filterBox = CreateFrame("EditBox", nil, filterBar)
    filterBox:SetFontObject(ChatFontNormal)
    filterBox:SetPoint("LEFT",  filterBar, "LEFT",  10, 0)
    filterBox:SetPoint("RIGHT", filterBar, "RIGHT", -10, 0)
    filterBox:SetHeight(20)
    filterBox:SetAutoFocus(false)
    filterBox:SetMaxLetters(64)
    filterBox:SetScript("OnTextChanged", function(self)
        Picker.ApplyFilter(self:GetText())
    end)
    filterBox:SetScript("OnEscapePressed", function(self)
        if self:GetText() ~= "" then
            self:SetText("")
        else
            frame:Hide()
        end
    end)

    local placeholder = filterBar:CreateFontString(nil, "OVERLAY")
    placeholder:SetFontObject(ChatFontNormal)
    placeholder:SetTextColor(0.45, 0.45, 0.45, 1)
    placeholder:SetText("Search...")
    placeholder:SetPoint("LEFT", filterBar, "LEFT", 10, 0)
    filterBox:HookScript("OnTextChanged", function(self)
        placeholder:SetShown(self:GetText() == "")
    end)

    frame.FilterBox = filterBox

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     filterBar, "BOTTOMLEFT",  0,  -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame,     "BOTTOMRIGHT", -22, 4)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(FRAME_WIDTH - 28)
    scrollFrame:SetScrollChild(content)

    frame.ScrollFrame = scrollFrame
    frame.Content     = content
    frame.rows        = {}

    return frame
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function Picker.ShowSpellPicker(onSelect)
    if not pickerFrame then
        pickerFrame = CreatePickerFrame()
    end
    currentCallback = onSelect
    pickerFrame.TitleText:SetText("Pick a Spell")
    pickerFrame.FilterBox:SetText("")
    CollectSpells()
    Picker.ApplyFilter("")
    pickerFrame:Show()
    pickerFrame.FilterBox:SetFocus()
end

function Picker.ShowItemPicker(onSelect)
    if not pickerFrame then
        pickerFrame = CreatePickerFrame()
    end
    currentCallback = onSelect
    pickerFrame.TitleText:SetText("Pick an Item from Bags")
    pickerFrame.FilterBox:SetText("")
    CollectItems()
    Picker.ApplyFilter("")
    pickerFrame:Show()
    pickerFrame.FilterBox:SetFocus()
end

module.Picker = Picker
