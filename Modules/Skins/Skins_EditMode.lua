local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("Skins", true)
if not module then return end

local Theme = module.Theme
if not Theme then return end

local LibEditMode = LibStub("LibEditMode", true)
local skinned
local editModeHooked
local CLEAR_TEXTURE = "Interface\\Buttons\\WHITE8x8"

local function applyBackdrop(frame, theme)
    if not frame or not frame.SetBackdrop then return end
    local w = (theme.borderWidth or 1)
    frame:SetBackdrop({
        bgFile = CLEAR_TEXTURE,
        edgeFile = CLEAR_TEXTURE,
        edgeSize = w,
        insets = { left = w, right = w, top = w, bottom = w },
    })
    local bg, border = theme.frameBg, theme.borderColor
    frame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a or 0.98)
    frame:SetBackdropBorderColor(border.r, border.g, border.b, border.a or 1)
end

local function skinEditModeManagerFrame()
    local em = _G.EditModeManagerFrame
    if not em or skinned then return end
    skinned = true

    local border = em.Border
    if border then
        if border.SetBackdrop then
            border:SetBackdrop(nil)
            applyBackdrop(border, Theme)
        elseif border.Bg and border.Bg.SetColorTexture then
            border.Bg:SetColorTexture(Theme.frameBg.r, Theme.frameBg.g, Theme.frameBg.b, Theme.frameBg.a or 0.98)
        end
    end

    if em.Title and em.Title.SetFont then
        TavernUI:ApplyFont(em.Title, em, 14)
        if Theme.textColor then
            em.Title:SetTextColor(Theme.textColor.r, Theme.textColor.g, Theme.textColor.b, Theme.textColor.a or 1)
        end
    end

    if em.LayoutLabel and em.LayoutLabel.SetFont then
        TavernUI:ApplyFont(em.LayoutLabel, em, 12)
        if Theme.textColor then
            em.LayoutLabel:SetTextColor(Theme.textColor.r, Theme.textColor.g, Theme.textColor.b, Theme.textColor.a or 1)
        end
    end
end

local function styleLibEditModeSelections()
    if not LibEditMode or not LibEditMode.frameSelections then return end
    for frame, selection in next, LibEditMode.frameSelections do
        if selection and selection.SetBackdrop and not selection.__tuiEditModeSkinned then
            selection.__tuiEditModeSkinned = true
            selection:SetBackdrop({
                bgFile = CLEAR_TEXTURE,
                edgeFile = CLEAR_TEXTURE,
                edgeSize = Theme.borderWidth or 2,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })
            local accent = Theme.accentColor or Theme.borderColor
            selection:SetBackdropColor(accent.r, accent.g, accent.b, 0.2)
            selection:SetBackdropBorderColor(accent.r, accent.g, accent.b, 1)
            if selection.MouseOverHighlight and selection.MouseOverHighlight.SetVertexColor then
                selection.MouseOverHighlight:SetVertexColor(accent.r, accent.g, accent.b, 0.4)
            end
        end
    end
end

local function onEditModeEnter()
    skinEditModeManagerFrame()
    if LibEditMode then
        C_Timer.After(0, styleLibEditModeSelections)
    end
end

local function trySkin()
    local em = _G.EditModeManagerFrame
    if not em then return false end
    skinEditModeManagerFrame()
    if em:IsShown() then
        onEditModeEnter()
    end
    if not editModeHooked then
        editModeHooked = true
        em:HookScript("OnShow", onEditModeEnter)
    end
    return true
end

function module:SkinEditMode()
    if not self or self ~= module then return end
    if trySkin() then return end
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(_, event, name)
        if event == "ADDON_LOADED" and name == "Blizzard_EditMode" then
            trySkin()
        end
    end)
    C_Timer.After(1, function()
        if trySkin() then
            f:UnregisterEvent("ADDON_LOADED")
        end
    end)
end

function module:EnableEditModeSkin()
    if not self or self ~= module then return end
    self:SkinEditMode()
    trySkin()
    if LibEditMode and LibEditMode.RegisterCallback then
        LibEditMode:RegisterCallback("enter", onEditModeEnter)
    end
end
