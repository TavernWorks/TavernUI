local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("UnitFrames")
if not module then return end

local WHITE8X8 = TavernUI.WHITE8X8

local Elements = {}
module.Elements = Elements

local function GetTexture()
    return TavernUI:GetThemeStatusBarTexture()
end

function Elements:CreateBackground(frame, db)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(TavernUI:GetThemeColor("frameBg"))
    frame.TUI_Bg = bg
    return bg
end

function Elements:CreateBorder(frame, db)
    local borderWidth = TavernUI:GetThemeValue("borderWidth") or 1

    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    border:SetFrameLevel(frame:GetFrameLevel() + 2)
    if borderWidth > 0 then
        border:SetPoint("TOPLEFT", -borderWidth, borderWidth)
        border:SetPoint("BOTTOMRIGHT", borderWidth, -borderWidth)
        border:SetBackdrop({ edgeFile = WHITE8X8, edgeSize = borderWidth })
        border:SetBackdropBorderColor(TavernUI:GetThemeColor("borderColor"))
    else
        border:Hide()
    end
    frame.TUI_Border = border
    return border
end

function Elements:CreateHealth(frame, unit, db)
    local health = CreateFrame("StatusBar", nil, frame)
    health:SetStatusBarTexture(GetTexture())
    health:SetPoint("TOPLEFT")
    health:SetPoint("TOPRIGHT")
    health:SetPoint("BOTTOMLEFT")
    health:SetPoint("BOTTOMRIGHT")

    local healthBg = health:CreateTexture(nil, "BACKGROUND")
    healthBg:SetAllPoints()
    healthBg:SetTexture(GetTexture())
    local hbg = TavernUI:GetThemeValue("healthBgColor")
    if hbg then
        healthBg:SetVertexColor(hbg.r, hbg.g, hbg.b, hbg.a or 1)
    end
    health.bg = healthBg

    health.colorDisconnected = true
    health.colorTapping = true

    if db.useClassColor then
        health.colorClass = true
        health.colorReaction = true
    else
        local colorMode = TavernUI:GetThemeValue("healthColorMode") or "CLASS"
        if colorMode == "CLASS" then
            health.colorClass = true
            health.colorReaction = true
        elseif colorMode == "REACTION" then
            health.colorReaction = true
        elseif colorMode == "HEALTH_GRADIENT" then
            health.colorSmooth = true
        elseif colorMode == "SOLID" then
            local solidColor = TavernUI:GetThemeValue("healthColor")
            if solidColor then
                health:SetStatusBarColor(solidColor.r, solidColor.g, solidColor.b, solidColor.a or 1)
            end
            health.PostUpdateColor = function(self, unit, color)
                local c = TavernUI:GetThemeValue("healthColor")
                if c then
                    self:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
                end
            end
        end
    end

    health.frequentUpdates = true

    frame.Health = health
    frame.Health.bg = healthBg
    return health
end

function Elements:CreatePower(frame, unit, db)
    local power = CreateFrame("StatusBar", nil, frame)
    power:SetStatusBarTexture(GetTexture())
    power:SetPoint("BOTTOMLEFT")
    power:SetPoint("BOTTOMRIGHT")
    power:SetHeight(db.power and db.power.height or 8)

    local powerBg = power:CreateTexture(nil, "BACKGROUND")
    powerBg:SetAllPoints()
    powerBg:SetTexture(GetTexture())
    local pbg = TavernUI:GetThemeValue("powerBgColor")
    if pbg then
        powerBg:SetVertexColor(pbg.r, pbg.g, pbg.b, pbg.a or 1)
    end
    power.bg = powerBg

    local colorMode = TavernUI:GetThemeValue("powerColorMode") or "POWER_TYPE"
    power.colorDisconnected = true
    if colorMode == "POWER_TYPE" then
        power.colorPower = true
    elseif colorMode == "CLASS" then
        power.colorClass = true
    elseif colorMode == "SOLID" then
        local solidColor = TavernUI:GetThemeValue("powerColor")
        if solidColor then
            power:SetStatusBarColor(solidColor.r, solidColor.g, solidColor.b, solidColor.a or 1)
        end
        power.PostUpdateColor = function(self, unit, color, r, g, b)
            local c = TavernUI:GetThemeValue("powerColor")
            if c then
                self:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
            end
        end
    end

    power.frequentUpdates = true

    frame.TUI_Power = power
    frame.TUI_PowerBg = powerBg

    if db.showPower then
        frame.Power = power
        frame.Power.bg = powerBg
    else
        power:Hide()
    end

    return power
end

function Elements:CreatePortrait(frame, unit, db)
    local pDb = db.portrait or {}
    local side = pDb.side or "LEFT"
    local size = frame:GetHeight()

    local container = CreateFrame("Frame", nil, frame)
    container:SetFrameLevel(frame:GetFrameLevel() + 4)
    container:SetSize(size, size)
    container:ClearAllPoints()
    if side == "RIGHT" then
        container:SetPoint("LEFT", frame, "RIGHT", 0, 0)
    else
        container:SetPoint("RIGHT", frame, "LEFT", 0, 0)
    end

    local portrait = container:CreateTexture(nil, "ARTWORK")
    portrait:SetAllPoints()
    portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)

    frame.TUI_Portrait = portrait
    frame.TUI_PortraitFrame = container

    if db.showPortrait then
        frame.Portrait = portrait
    else
        container:Hide()
    end

    return portrait
end

local function ApplyIndicatorAnchor(indicator, frame, cfg)
    local size = cfg.size or 16
    indicator:SetSize(size, size)
    indicator:ClearAllPoints()
    indicator:SetPoint(cfg.point or "CENTER", frame, cfg.relPoint or "TOP", cfg.offX or 0, cfg.offY or 0)
end

function Elements:CreateIndicators(frame, unit, db)
    local indDb = db.indicators or {}

    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(frame:GetFrameLevel() + 3)
    frame.TUI_IndicatorOverlay = overlay

    if indDb.raidTarget then
        local rt = overlay:CreateTexture(nil, "OVERLAY")
        ApplyIndicatorAnchor(rt, frame, indDb.raidTarget)
        frame.RaidTargetIndicator = rt
        frame.TUI_RaidTargetIndicator = rt
    end

    if indDb.combat then
        local combat = overlay:CreateTexture(nil, "OVERLAY")
        ApplyIndicatorAnchor(combat, frame, indDb.combat)
        frame.CombatIndicator = combat
        frame.TUI_CombatIndicator = combat
    end

    if indDb.resting then
        local resting = overlay:CreateTexture(nil, "OVERLAY")
        ApplyIndicatorAnchor(resting, frame, indDb.resting)
        frame.RestingIndicator = resting
        frame.TUI_RestingIndicator = resting
    end

    if indDb.leader then
        local leader = overlay:CreateTexture(nil, "OVERLAY")
        ApplyIndicatorAnchor(leader, frame, indDb.leader)
        frame.LeaderIndicator = leader
        frame.TUI_LeaderIndicator = leader

        local assistant = overlay:CreateTexture(nil, "OVERLAY")
        ApplyIndicatorAnchor(assistant, frame, indDb.leader)
        frame.AssistantIndicator = assistant
        frame.TUI_AssistantIndicator = assistant
    end
end

function Elements:CreateClassPower(frame, unit, db)
    if unit ~= "player" then return end

    local cpDb = db.classpower or {}
    local cpHeight = cpDb.height or 4

    local container = CreateFrame("Frame", nil, frame)
    container:SetHeight(cpHeight)
    container:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 0)
    container:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 0)

    local classpower = {}
    local maxPower = 10

    for i = 1, maxPower do
        local bar = CreateFrame("StatusBar", nil, container)
        bar:SetStatusBarTexture(GetTexture())
        bar:SetHeight(cpHeight)

        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.7)
        bar.bg = bg

        classpower[i] = bar
    end

    classpower.PostUpdate = function(element, cur, max, hasMaxChanged)
        if hasMaxChanged and max > 0 then
            local width = container:GetWidth() / max
            for i = 1, max do
                element[i]:SetWidth(width - 1)
                element[i]:SetHeight(container:GetHeight())
                element[i]:ClearAllPoints()
                if i == 1 then
                    element[i]:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
                else
                    element[i]:SetPoint("LEFT", element[i - 1], "RIGHT", 1, 0)
                end
                element[i]:Show()
            end
            for i = max + 1, #element do
                element[i]:Hide()
            end
        end
    end

    frame.TUI_ClassPower = classpower
    frame.TUI_ClassPowerContainer = container

    if db.showClassPower then
        frame.ClassPower = classpower
    else
        container:Hide()
    end

    return classpower
end

function Elements:CreateInfoBar(frame, unit, db)
    local infoDb = db.infoBar or {}

    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetStatusBarTexture(WHITE8X8)
    local r, g, b, a = TavernUI:GetThemeColor("frameBg")
    bar:SetStatusBarColor(r, g, b, a)
    bar:SetHeight(infoDb.height or 8)

    bar:SetPoint("BOTTOMLEFT")
    bar:SetPoint("BOTTOMRIGHT")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)

    local text = bar:CreateFontString(nil, "OVERLAY")
    TavernUI:ApplyFont(text, bar, 9)
    text:SetPoint("LEFT", bar, "LEFT", 2, 0)
    text:SetPoint("RIGHT", bar, "RIGHT", -2, 0)
    text:SetJustifyH("CENTER")
    text:SetWordWrap(false)
    local tr, tg, tb, ta = TavernUI:GetThemeColor("textColor")
    text:SetTextColor(tr, tg, tb, ta)

    local tagString = infoDb.tagString or ""
    if tagString ~= "" then
        frame:Tag(text, tagString)
        text.TUI_tagString = tagString
    end

    frame.TUI_InfoBar = bar
    frame.TUI_InfoBarText = text

    if not db.showInfoBar then
        bar:Hide()
    end

    return bar
end

function Elements:CreateNameTag(frame, unit, db)
    local nameDb = db.nameTag or {}
    local name = frame.Health:CreateFontString(nil, "OVERLAY")
    TavernUI:ApplyFont(name, frame.Health, 11)
    name:SetPoint("LEFT", frame.Health, "LEFT", 4, 0)
    name:SetPoint("RIGHT", frame.Health, "RIGHT", -4, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    local r, g, b, a = TavernUI:GetThemeColor("textColor")
    name:SetTextColor(r, g, b, a)

    local tagString = nameDb.tag or "[TUI:classcolor][TUI:name]|r"
    frame:Tag(name, tagString)
    name.TUI_tagString = tagString
    frame.TUI_NameTag = name

    if not nameDb.enabled then
        name:Hide()
    end

    return name
end

function Elements:CreateHealthTag(frame, unit, db)
    local healthDb = db.healthTag or {}
    local text = frame.Health:CreateFontString(nil, "OVERLAY")
    TavernUI:ApplyFont(text, frame.Health, 11)
    text:SetPoint("LEFT", frame.Health, "LEFT", 4, 0)
    text:SetPoint("RIGHT", frame.Health, "RIGHT", -4, 0)
    text:SetJustifyH("RIGHT")
    text:SetWordWrap(false)
    local r, g, b, a = TavernUI:GetThemeColor("textColor")
    text:SetTextColor(r, g, b, a)

    local tagString = healthDb.tag or "[TUI:curhp:short]/[TUI:maxhp:short]"
    frame:Tag(text, tagString)
    text.TUI_tagString = tagString
    frame.TUI_HealthTag = text

    if not healthDb.enabled then
        text:Hide()
    end

    return text
end

function Elements:CreatePowerTag(frame, unit, db)
    local powerDb = db.powerTag or {}
    local text = frame.TUI_Power:CreateFontString(nil, "OVERLAY")
    TavernUI:ApplyFont(text, frame.TUI_Power, 9)
    text:SetPoint("CENTER", frame.TUI_Power, "CENTER", 0, 0)
    local r, g, b, a = TavernUI:GetThemeColor("textColor")
    text:SetTextColor(r, g, b, a)

    local tagString = powerDb.tag or "[TUI:curpp:short]"
    frame:Tag(text, tagString)
    text.TUI_tagString = tagString
    frame.TUI_PowerTag = text

    if not powerDb.enabled or not db.showPower then
        text:Hide()
    end

    return text
end
