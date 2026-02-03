local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local Preview = {}

local PREVIEW_FRAME_PREFIX = "__ucdmPreview"
local QUESTION_MARK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local PREVIEW_COOLDOWN_DURATION = 5
local CooldownItem = module.CooldownItem
local Helpers = module.CooldownTrackerHelpers
local CreateCooldownDuration = Helpers and Helpers.CreateCooldownDuration

local PREVIEW_KEYBINDS = { "1", "2", "3", "4", "R", "F", "Q", "E", "S1", "S2", "C1", "C2", "A1", "SP", "ESC", "N1", "N2", "B1", "B2" }

local function RandomKeybindText()
    return PREVIEW_KEYBINDS[math.random(1, #PREVIEW_KEYBINDS)]
end

function Preview.IsPreviewItem(item)
    if not item or not item.id then return false end
    local id = item.id
    return type(id) == "string" and id:match("^preview_") ~= nil
end

function Preview.ApplyPreviewFakeData(viewer, visibleItems)
    if not CreateCooldownDuration then return end
    local frames = {}
    for _, entry in ipairs(visibleItems) do
        local item = entry.item
        if not Preview.IsPreviewItem(item) then break end
        local frame = item.frame
        if frame then frames[#frames + 1] = frame end
    end
    if #frames == 0 then return end
    local active = viewer.__ucdmPreviewActiveFrames
    if active and #active == #frames then
        local same = true
        for i = 1, #frames do
            if active[i] ~= frames[i] then same = false break end
        end
        if same then return end
    end
    viewer.__ucdmPreviewCooldownCancelled = true
    viewer.__ucdmPreviewActiveFrames = nil
    local now = GetTime()
    for _, entry in ipairs(visibleItems) do
        local item = entry.item
        if not Preview.IsPreviewItem(item) then break end
        local frame = item.frame
        if frame then
            if frame.Count then
                local stack = (item.index or 1) % 10
                frame.Count:SetText(stack > 0 and tostring(stack) or "1")
                frame.Count:Show()
            end
            local settings = module:GetViewerSettings("buff")
            if settings and settings.showKeybinds and frame._ucdmKeybindText then
                frame._ucdmKeybindText:SetText(RandomKeybindText())
                local size = settings.keybindSize or 10
                TavernUI:ApplyFont(frame._ucdmKeybindText, frame, size)
                local color = settings.keybindColor or { r = 1, g = 1, b = 1, a = 1 }
                frame._ucdmKeybindText:SetTextColor(color.r, color.g, color.b, color.a)
                frame._ucdmKeybindText:ClearAllPoints()
                local bindPoint = frame.Icon or frame
                local pt = settings.keybindPoint or "TOPLEFT"
                frame._ucdmKeybindText:SetPoint(pt, bindPoint, pt, settings.keybindOffsetX or 2, settings.keybindOffsetY or -2)
                frame._ucdmKeybindText:Show()
            elseif frame._ucdmKeybindText then
                frame._ucdmKeybindText:Hide()
            end
            local cooldown = frame.Cooldown or frame.cooldown
            if cooldown then
                local offset = ((item.index or 1) - 1) * 0.6
                local startTime = now - offset
                local durationObj = CreateCooldownDuration(startTime, PREVIEW_COOLDOWN_DURATION)
                if durationObj and cooldown.SetCooldownFromDurationObject then
                    cooldown:SetCooldownFromDurationObject(durationObj, true)
                    cooldown:Show()
                end
            end
        end
    end
    viewer.__ucdmPreviewActiveFrames = frames
    viewer.__ucdmPreviewCooldownCancelled = false
    local function scheduleNext()
        if viewer.__ucdmPreviewCooldownCancelled or not viewer.__ucdmPreviewActiveFrames then return end
        local now = GetTime()
        for _, frame in ipairs(viewer.__ucdmPreviewActiveFrames) do
            if frame and frame:IsShown() then
                local cooldown = frame.Cooldown or frame.cooldown
                if cooldown and CreateCooldownDuration and cooldown.SetCooldownFromDurationObject then
                    local durationObj = CreateCooldownDuration(now, PREVIEW_COOLDOWN_DURATION)
                    if durationObj then
                        cooldown:SetCooldownFromDurationObject(durationObj, true)
                        cooldown:Show()
                    end
                end
            end
        end
        C_Timer.After(PREVIEW_COOLDOWN_DURATION, scheduleNext)
    end
    C_Timer.After(PREVIEW_COOLDOWN_DURATION, scheduleNext)
end

local function CreatePreviewFrame(viewer, index)
    local f = CreateFrame("Button", PREVIEW_FRAME_PREFIX .. "Frame_" .. index, viewer)
    f:SetFrameLevel(viewer:GetFrameLevel() + 1)
    f:SetSize(40, 40)

    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(f)
    icon:SetTexture(QUESTION_MARK_ICON)
    f.Icon = icon

    local cooldown = CreateFrame("Cooldown", nil, f)
    cooldown:SetAllPoints(f)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:SetDrawSwipe(true)
    cooldown:SetSwipeTexture("Interface\\Buttons\\WHITE8X8")
    cooldown:SetSwipeColor(0, 0, 0, 0.8)
    cooldown:SetHideCountdownNumbers(false)
    f.Cooldown = cooldown

    local count = TavernUI:CreateFontString(f, 16)
    count:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    f.Count = count

    local keybind = TavernUI:CreateFontString(f, 10)
    keybind:Hide()
    f._ucdmKeybindText = keybind
    return f
end

local function EnsurePreviewFrames(viewer, count)
    viewer[PREVIEW_FRAME_PREFIX .. "Pool"] = viewer[PREVIEW_FRAME_PREFIX .. "Pool"] or {}
    local pool = viewer[PREVIEW_FRAME_PREFIX .. "Pool"]
    while #pool < count do
        pool[#pool + 1] = CreatePreviewFrame(viewer, #pool + 1)
    end
    for i = count + 1, #pool do
        pool[i]:Hide()
    end
    return pool
end

function Preview.BuildPreviewItems(viewer, count)
    if not CooldownItem then return {} end
    local pool = EnsurePreviewFrames(viewer, count)
    local fakeItems = {}
    for i = 1, count do
        local f = pool[i]
        if f then
            fakeItems[i] = CooldownItem.new({
                id = "preview_" .. i,
                frame = f,
                source = "custom",
                enabled = true,
                layoutIndex = i,
                index = i,
            })
        end
    end
    return fakeItems
end

function Preview.HidePreviewFrames(viewer)
    viewer.__ucdmPreviewCooldownCancelled = true
    viewer.__ucdmPreviewActiveFrames = nil
    local pool = viewer[PREVIEW_FRAME_PREFIX .. "Pool"]
    if pool then
        for _, f in ipairs(pool) do
            if f.Cooldown then f.Cooldown:Clear() end
            if f.Count then f.Count:Hide() end
            if f._ucdmKeybindText then f._ucdmKeybindText:Hide() end
            f:Hide()
        end
    end
end

module.Preview = Preview
