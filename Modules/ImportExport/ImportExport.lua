local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:NewModule("ProfileImportExport")

local L = LibStub("AceLocale-3.0"):GetLocale("TavernUI", true)
local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

local PROFILE_STRING_VERSION = "TUI1"
local pendingImportData = nil

module._pendingExportString = nil

local function copyTable(src)
    if type(src) ~= "table" then
        return src
    end
    local dst = {}
    for k, v in pairs(src) do
        dst[k] = copyTable(v)
    end
    return dst
end

function module:ExportProfileString()
    if not TavernUI.db or not TavernUI.db.profile then
        return ""
    end
    local payload = { version = PROFILE_STRING_VERSION, profile = copyTable(TavernUI.db.profile) }
    local serialized = LibSerialize:Serialize(payload)
    local compressed = LibDeflate:CompressDeflate(serialized)
    local encoded = LibDeflate:EncodeForPrint(compressed)
    return PROFILE_STRING_VERSION .. ":" .. encoded
end

function module:ImportProfileString(str)
    if type(str) ~= "string" or str:match("^%s*$") then
        pendingImportData = nil
        return false
    end
    str = str:gsub("^%s+", ""):gsub("%s+$", "")
    local versionPrefix, encoded = str:match("^(%w+):(.+)$")
    if versionPrefix ~= PROFILE_STRING_VERSION or not encoded then
        TavernUI:Print(L["PROFILE_IMPORT_FAILED"])
        pendingImportData = nil
        return false
    end
    local decoded = LibDeflate:DecodeForPrint(encoded)
    if not decoded then
        TavernUI:Print(L["PROFILE_IMPORT_FAILED"])
        pendingImportData = nil
        return false
    end
    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then
        TavernUI:Print(L["PROFILE_IMPORT_FAILED"])
        pendingImportData = nil
        return false
    end
    local success, data = LibSerialize:Deserialize(decompressed)
    if not success or not data or data.version ~= PROFILE_STRING_VERSION or not data.profile then
        TavernUI:Print(L["PROFILE_IMPORT_FAILED"])
        pendingImportData = nil
        return false
    end
    pendingImportData = data.profile
    return true
end

function module:ApplyPendingImport()
    if not pendingImportData or not TavernUI.db or not TavernUI.db.profile then
        return
    end
    for k, v in pairs(pendingImportData) do
        TavernUI.db.profile[k] = copyTable(v)
    end
    pendingImportData = nil
    TavernUI:RefreshConfig()
    TavernUI:Print(L["PROFILE_IMPORT_SUCCESS"])
end

function module:HasPendingImport()
    return pendingImportData ~= nil
end

local POPUP_Y_OFFSET = 180

StaticPopupDialogs["TavernUI_EXPORT_PROFILE"] = {
    text = L["PROFILE_EXPORT_DESC"] or "Copy this string to share your profile. Paste it elsewhere or save to a file.",
    button1 = CLOSE or "Close",
    hasEditBox = true,
    editBoxWidth = 350,
    OnShow = function(self)
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", 0, POPUP_Y_OFFSET)
        self:SetFrameStrata("FULLSCREEN_DIALOG")
        self:SetFrameLevel(1000)
        local exportString = module._pendingExportString or ""
        local editBox = self.editBox or (self.GetEditBox and self:GetEditBox())
        if editBox then
            editBox:SetText(exportString)
            editBox:SetFocus()
            editBox:HighlightText()
            if not self.exportCopyHint then
                self.exportCopyHint = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            end
            self.exportCopyHint:SetText(L["PROFILE_EXPORT_CTRL_C_HINT"] or "Ctrl + C to Copy")
            self.exportCopyHint:ClearAllPoints()
            self.exportCopyHint:SetPoint("TOP", editBox, "BOTTOM", 0, -4)
            self.exportCopyHint:Show()
        end
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["TavernUI_IMPORT_PROFILE"] = {
    text = L["PROFILE_IMPORT_WARNING"] or "Importing will override your current profile. Paste a profile string below and click Import.",
    button1 = L["PROFILE_IMPORT_CONFIRM"] or "Import",
    button2 = CANCEL or "Cancel",
    hasEditBox = true,
    editBoxWidth = 350,
    OnAccept = function(self)
        local editBox = self.editBox or (self.GetEditBox and self:GetEditBox())
        local text = editBox and editBox:GetText()
        if text and text:match("%S") then
            text = text:gsub("^%s+", ""):gsub("%s+$", "")
            if module:ImportProfileString(text) then
                module:ApplyPendingImport()
            end
        else
            TavernUI:Print(L["PROFILE_IMPORT_FAILED"])
        end
    end,
    OnShow = function(self)
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", 0, POPUP_Y_OFFSET)
        self:SetFrameStrata("FULLSCREEN_DIALOG")
        self:SetFrameLevel(1000)
        if self.exportCopyHint then
            self.exportCopyHint:Hide()
        end
        local editBox = self.editBox or (self.GetEditBox and self:GetEditBox())
        if editBox then
            editBox:SetText("")
            editBox:SetFocus()
        end
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function module:GetProfileImportExportOptions()
    return {
        exportDesc = {
            type = "description",
            name = L["PROFILE_EXPORT_DESC"],
            order = 0,
            width = "full",
        },
        exportExecute = {
            type = "execute",
            name = L["PROFILE_EXPORT"],
            order = 10,
            width = "full",
            func = function()
                local str = self:ExportProfileString()
                if str and str ~= "" then
                    module._pendingExportString = str
                    StaticPopup_Show("TavernUI_EXPORT_PROFILE")
                else
                    TavernUI:Print("Failed to generate export string.")
                end
            end,
        },
        importSpacer = {
            type = "header",
            name = L["PROFILE_IMPORT"],
            order = 20,
        },
        importWarning = {
            type = "description",
            name = "|cffffcc00" .. (L["PROFILE_IMPORT_WARNING"] or "Importing will override your current profile.") .. "|r",
            order = 21,
            width = "full",
        },
        importExecute = {
            type = "execute",
            name = L["PROFILE_IMPORT"],
            order = 22,
            width = "full",
            func = function()
                StaticPopup_Show("TavernUI_IMPORT_PROFILE")
            end,
        },
    }
end

function module:OnInitialize()
    if TavernUI.RegisterModuleOptions then
        TavernUI:RegisterModuleOptions("ProfileImportExport", {
            type = "group",
            name = "Import / Export",
            args = self:GetProfileImportExportOptions(),
        }, "Import / Export")
    end
end
