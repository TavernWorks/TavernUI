-- TavernUI Core.lua

local AceAddon         = LibStub("AceAddon-3.0")
local AceDB            = LibStub("AceDB-3.0")
local AceDBOptions     = LibStub("AceDBOptions-3.0")
local AceConfig        = LibStub("AceConfig-3.0")
local AceConfigDialog  = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

local TavernUI = AceAddon:NewAddon("TavernUI",
    "AceConsole-3.0",
    "AceEvent-3.0"
)

_G.TavernUI = TavernUI

TavernUI.name = "TavernUI"
TavernUI.version = C_AddOns.GetAddOnMetadata("TavernUI", "Version") or "0.0.1"
TavernUI.author = "Mondo, LiQiuDgg"

-- Master defaults table - modules will add their defaults here BEFORE OnInitialize
TavernUI.defaults = {
    profile = {
        modules = {}, -- Individual module states (true/false), no wildcard
        general = {
            debug = false,
            font = {
                face = "",
                size = 12,
                flags = "OUTLINE",
                pixelPerfect = true,
                shadow = false,
            },
        },
    },
    global = {},
}

-- Module prototype for shared functionality
TavernUI.modulePrototype = {}

function TavernUI.modulePrototype:GetDB()
    -- Always return fresh reference to avoid stale data after profile changes
    if not TavernUI.db or not TavernUI.db.profile then
        return {}
    end
    return TavernUI.db.profile[self:GetName()] or {}
end

function TavernUI.modulePrototype:Debug(...)
    if TavernUI.db and TavernUI.db.profile.general.debug then
        TavernUI:Print("|cff999999[" .. self:GetName() .. "]|r", ...)
    end
end

function TavernUI.modulePrototype:GetModulePath()
    if not TavernUI.Config then
        return nil
    end
    return TavernUI.Config:GetModulePath(self:GetName())
end

function TavernUI.modulePrototype:GetSetting(path, defaultValue)
    if not TavernUI.Config then
        return defaultValue
    end
    local modulePath = self:GetModulePath()
    if not modulePath then
        return defaultValue
    end
    local fullPath = modulePath .. "." .. path
    return TavernUI.Config:Get(fullPath, defaultValue)
end

function TavernUI.modulePrototype:SetSetting(path, value, options)
    if not TavernUI.Config then
        return false
    end
    local modulePath = self:GetModulePath()
    if not modulePath then
        return false
    end
    local fullPath = modulePath .. "." .. path
    return TavernUI.Config:Set(fullPath, value, options)
end

function TavernUI.modulePrototype:WatchSetting(path, callback)
    if not TavernUI.Config then
        return nil
    end
    local modulePath = self:GetModulePath()
    if not modulePath then
        return nil
    end
    local fullPath = modulePath .. "." .. path
    return TavernUI.Config:RegisterChangeCallback(fullPath, callback)
end

function TavernUI.modulePrototype:UnwatchSetting(path, callbackId)
    if not TavernUI.Config then
        return false
    end
    local modulePath = self:GetModulePath()
    if not modulePath then
        return false
    end
    local fullPath = modulePath .. "." .. path
    return TavernUI.Config:UnregisterChangeCallback(fullPath, callbackId)
end

TavernUI:SetDefaultModulePrototype(TavernUI.modulePrototype)
TavernUI:SetDefaultModuleState(false) -- Modules disabled by default, we control enabling

function TavernUI:GetPixelSize(region, physicalPixels, direction)
    if not region or not physicalPixels or physicalPixels <= 0 then
        return physicalPixels or 0
    end
    if PixelUtil and PixelUtil.GetNearestPixelSize then
        local scale = region.GetEffectiveScale and region:GetEffectiveScale()
        if scale and scale > 0 then
            return PixelUtil.GetNearestPixelSize(physicalPixels, scale, direction or 0)
        end
    end
    return physicalPixels
end

function TavernUI:GetTexturePath(key, mediaType, default)
    if not key or key == "" then
        return default or "Interface\\Buttons\\WHITE8x8"
    end
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local path = LSM:Fetch(mediaType or "statusbar", key)
        if path then return path end
    end
    if type(key) == "string" then
        return key
    end
    return default or "Interface\\Buttons\\WHITE8x8"
end

local DEFAULT_FONT_PATH = "Fonts\\FRIZQT__.TTF"

function TavernUI:GetFontPath(key, default)
    local path = default or DEFAULT_FONT_PATH
    if key == nil and self.db and self.db.profile and self.db.profile.general and self.db.profile.general.font then
        key = self.db.profile.general.font.face
    end
    if not key or key == "" then
        return path
    end
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local fetched = LSM:Fetch("font", key)
        if fetched then return fetched end
    end
    if type(key) == "string" and key:match("\\") then
        return key
    end
    return path
end

function TavernUI:GetFontSize(default)
    if not self.db or not self.db.profile or not self.db.profile.general or not self.db.profile.general.font then
        return default or 12
    end
    local size = self.db.profile.general.font.size
    return (type(size) == "number" and size > 0) and size or (default or 12)
end

function TavernUI:GetFontFlags()
    if not self.db or not self.db.profile or not self.db.profile.general or not self.db.profile.general.font then
        return "OUTLINE"
    end
    local flags = self.db.profile.general.font.flags
    return (type(flags) == "string" and flags ~= "") and flags or "OUTLINE"
end

function TavernUI:GetFontSizeForRegion(region, requestedSize)
    local size = (type(requestedSize) == "number" and requestedSize > 0) and requestedSize or self:GetFontSize(12)
    if not region then return size end
    if not self.db or not self.db.profile or not self.db.profile.general or not self.db.profile.general.font then
        return size
    end
    if not self.db.profile.general.font.pixelPerfect then return size end
    local scale = (region.GetEffectiveScale and region:GetEffectiveScale()) or (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    if not scale or scale <= 0 then return size end
    return math.floor(size / scale + 0.5) * scale
end

function TavernUI:GetFontShadow()
    if not self.db or not self.db.profile or not self.db.profile.general or not self.db.profile.general.font then
        return false
    end
    return self.db.profile.general.font.shadow == true
end

local function SetupPixelPerfectText(fontString, region, size, path, flags)
    local scale = (region and region.GetEffectiveScale and region:GetEffectiveScale()) or (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    if not scale or scale <= 0 then return end
    local pixelSize = math.floor(size / scale + 0.5) * scale
    fontString:SetFont(path, pixelSize, flags)
    if PixelUtil and PixelUtil.GetNearestPixelSize and fontString.GetPoint and fontString.ClearAllPoints and fontString.SetPoint then
        local point, relativeTo, relativePoint, x, y = fontString:GetPoint(1)
        if point and x and y and relativeTo == region then
            local ok, px, py = pcall(function()
                return PixelUtil.GetNearestPixelSize(x, scale, 0), PixelUtil.GetNearestPixelSize(y, scale, 1)
            end)
            if ok and px and py then
                fontString:ClearAllPoints()
                fontString:SetPoint(point, relativeTo, relativePoint, px, py)
            end
        end
    end
end

function TavernUI:ApplyFont(fontString, region, defaultSize)
    if not fontString or not fontString.SetFont then return end
    local size = (type(defaultSize) == "number" and defaultSize > 0) and defaultSize or self:GetFontSize(12)
    local path = self:GetFontPath()
    local flags = self:GetFontFlags()
    local usePixelPerfect = self.db and self.db.profile and self.db.profile.general and self.db.profile.general.font and self.db.profile.general.font.pixelPerfect
    if usePixelPerfect and (region or UIParent) then
        SetupPixelPerfectText(fontString, region or UIParent, size, path, flags)
    else
        fontString:SetFont(path, size, flags)
    end
    if fontString.SetShadowColor and fontString.SetShadowOffset then
        if self:GetFontShadow() then
            fontString:SetShadowColor(0, 0, 0, 1)
            fontString:SetShadowOffset(1, -1)
        else
            fontString:SetShadowOffset(0, 0)
            fontString:SetShadowColor(0, 0, 0, 0)
        end
    end
    if not self._fontStringRegistry then
        self._fontStringRegistry = setmetatable({}, { __mode = "k" })
    end
    self._fontStringRegistry[fontString] = { region, defaultSize or 12 }
end

function TavernUI:RefreshAllFonts()
    if not self._fontStringRegistry then return end
    for fs, data in pairs(self._fontStringRegistry) do
        if fs.SetFont then
            self:ApplyFont(fs, data[1], data[2])
        end
    end
end

function TavernUI:CreateFontString(parent, defaultSize, name, layer, fontRegion)
    if not parent or not parent.CreateFontString then return nil end
    local fs = parent:CreateFontString(name, layer or "OVERLAY")
    if not fs then return nil end
    self:ApplyFont(fs, fontRegion or parent, defaultSize or 12)
    return fs
end

function TavernUI:GetLSMMediaList(mediaType)
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if not LSM then return {} end
    return LSM:List(mediaType or "statusbar") or {}
end

function TavernUI:GetLSMMediaDropdownValues(mediaType, defaultKey, defaultLabel)
    local values = {}
    if defaultKey ~= nil then
        values[defaultKey] = defaultLabel or ""
    end
    for _, key in ipairs(self:GetLSMMediaList(mediaType or "statusbar")) do
        values[key] = key
    end
    return values
end

function TavernUI:Debug(...)
    if self.db and self.db.profile.general.debug then
        self:Print("|cff999999[Core]|r", ...)
    end
end

-- Call this from modules BEFORE OnInitialize runs (at file load time)
function TavernUI:RegisterModuleDefaults(moduleName, moduleDefaults, enabledByDefault)
    -- Add module's defaults to master defaults table
    self.defaults.profile[moduleName] = moduleDefaults
    
    -- Set default enabled state
    if enabledByDefault == nil then
        enabledByDefault = true
    end
    self.defaults.profile.modules[moduleName] = enabledByDefault
    
    self:Debug("Registered defaults for module:", moduleName)
end

function TavernUI:OnInitialize()
    -- Create DB with the complete defaults table (modules have already registered their defaults)
    self.db = AceDB:New("TavernUIConfig", self.defaults, true)
    -- Do NOT call RegisterDefaults again - it's already set via New()
    
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
    
    -- Initialize Config system
    if self.Config then
        self.Config:OnInitialize()
    end
    
    self:InitializeOptions()
    self:RegisterChatCommand("tui", "SlashCommand")
    
    self:Debug("Core initialized")
end

function TavernUI:OnEnable()
    self:RefreshModuleStates()
    if not self._scaleFrame then
        self._scaleFrame = CreateFrame("Frame")
        self._scaleFrame:RegisterEvent("UI_SCALE_CHANGED")
        self._scaleFrame:SetScript("OnEvent", function()
            TavernUI:RefreshAllFonts()
        end)
    end
    self:SendMessage("TavernUI_CoreEnabled")
    self:Print(string.format("|cff00ff00TavernUI|r v%s loaded!", self.version))
end

function TavernUI:OnDisable()
    self:SendMessage("TavernUI_CoreDisabled")
end

function TavernUI:RefreshModuleStates()
    if not self.db or not self.db.profile then
        return
    end
    
    for name, module in self:IterateModules() do
        local shouldEnable = self.db.profile.modules[name]
        -- Default to true if not explicitly set
        if shouldEnable == nil then
            shouldEnable = true
        end
        
        if shouldEnable then
            if not module:IsEnabled() then
                self:EnableModule(name)
            elseif name == "uCDM" and module.OnEnable and not module.__onEnableCalled then
                module.__onEnableCalled = true
                module:OnEnable()
            end
        elseif not shouldEnable and module:IsEnabled() then
            self:DisableModule(name)
        end
    end
end

function TavernUI:ToggleModule(moduleName, state)
    local module = self:GetModule(moduleName, true)
    if not module then
        self:Print("Module not found:", moduleName)
        return false
    end
    
    self.db.profile.modules[moduleName] = state
    
    if state then
        self:EnableModule(moduleName)
        self:Print("Module enabled:", moduleName)
    else
        self:DisableModule(moduleName)
        self:Print("Module disabled:", moduleName)
    end
    
    self:SendMessage("TavernUI_ModuleToggled", moduleName, state)
    
    return true
end

function TavernUI:IsModuleEnabled(moduleName)
    local setting = self.db.profile.modules[moduleName]
    if setting == nil then
        return true -- Default to enabled
    end
    return setting
end

function TavernUI:RefreshConfig()
    self:SendMessage("TavernUI_ProfileChanged")
    self:RefreshModuleStates()
    self:RefreshAllFonts()
    self:Debug("Profile refreshed")
end

function TavernUI:GetOptions()
    if not self._optionsTable then
        self._optionsTable = {
            type = "group",
            name = "TavernUI",
            args = {
                general = {
                    type = "group",
                    name = "General",
                    order = 10,
                    args = {
                        debug = {
                            type = "toggle",
                            name = "Debug Mode",
                            desc = "Enable debug messages",
                            get = function() return self.db.profile.general.debug end,
                            set = function(_, value) self.db.profile.general.debug = value end,
                            order = 10,
                        },
                        font = {
                            type = "group",
                            name = "Font",
                            desc = "Changing font may require a /reload to take full effect.",
                            order = 20,
                            args = {
                                fontReloadWarning = {
                                    type = "description",
                                    name = "|cffffcc00Changing font face or style may require a /reload to take full effect.|r",
                                    order = 0,
                                },
                                face = {
                                    type = "select",
                                    name = "Font Face",
                                    desc = "Font used for TavernUI text (LibSharedMedia). Affects addon-wide text when modules use the global font.",
                                    values = function()
                                        return self:GetLSMMediaDropdownValues("font", "", "Default (Game)")
                                    end,
                                    get = function()
                                        local g = self.db.profile.general
                                        local v = g.font and g.font.face
                                        return (v ~= nil and v ~= "") and v or ""
                                    end,
                                    set = function(_, value)
                                        if not self.db.profile.general.font then
                                            self.db.profile.general.font = { face = "", size = 12, flags = "OUTLINE", pixelPerfect = true, shadow = false }
                                        end
                                        self.db.profile.general.font.face = (value ~= nil and value ~= "") and value or ""
                                        self:RefreshAllFonts()
                                    end,
                                    order = 10,
                                },
                                size = {
                                    type = "range",
                                    name = "Font Size",
                                    desc = "Default font size for TavernUI text (used when modules reference the global font).",
                                    min = 6,
                                    max = 24,
                                    step = 1,
                                    get = function()
                                        local g = self.db.profile.general
                                        local v = g.font and g.font.size
                                        return (type(v) == "number" and v >= 6 and v <= 24) and v or 12
                                    end,
                                    set = function(_, value)
                                        if not self.db.profile.general.font then
                                            self.db.profile.general.font = { face = "", size = 12, flags = "OUTLINE", pixelPerfect = true, shadow = false }
                                        end
                                        self.db.profile.general.font.size = (type(value) == "number" and value >= 6 and value <= 24) and value or 12
                                        self:RefreshAllFonts()
                                    end,
                                    order = 20,
                                },
                                flags = {
                                    type = "select",
                                    name = "Outline",
                                    desc = "Font outline / style (Blizzard-style). Outline + Monochrome gives crisp text.",
                                    values = {
                                        [""] = "None",
                                        ["OUTLINE"] = "Outline",
                                        ["THICKOUTLINE"] = "Thick Outline",
                                        ["MONOCHROME"] = "Monochrome",
                                        ["OUTLINE,MONOCHROME"] = "Outline + Monochrome",
                                    },
                                    get = function()
                                        local g = self.db.profile.general
                                        local v = g.font and g.font.flags
                                        return (type(v) == "string") and v or "OUTLINE"
                                    end,
                                    set = function(_, value)
                                        if not self.db.profile.general.font then
                                            self.db.profile.general.font = { face = "", size = 12, flags = "OUTLINE", pixelPerfect = true, shadow = false }
                                        end
                                        self.db.profile.general.font.flags = (type(value) == "string") and value or "OUTLINE"
                                        self:RefreshAllFonts()
                                    end,
                                    order = 30,
                                },
                                shadow = {
                                    type = "toggle",
                                    name = "Text Shadow",
                                    desc = "Draw a drop shadow behind text. Some prefer this over outline.",
                                    get = function()
                                        local g = self.db.profile.general
                                        return g.font and g.font.shadow == true
                                    end,
                                    set = function(_, value)
                                        if not self.db.profile.general.font then
                                            self.db.profile.general.font = { face = "", size = 12, flags = "OUTLINE", pixelPerfect = true, shadow = false }
                                        end
                                        self.db.profile.general.font.shadow = value == true
                                        self:RefreshAllFonts()
                                    end,
                                    order = 35,
                                },
                                pixelPerfect = {
                                    type = "toggle",
                                    name = "Pixel Perfect Size",
                                    desc = "Snap font height to pixel grid (Blizzard PixelUtil). Makes text look crisp at various UI scales.",
                                    get = function()
                                        local g = self.db.profile.general
                                        local v = g.font and g.font.pixelPerfect
                                        return v == nil or v == true
                                    end,
                                    set = function(_, value)
                                        if not self.db.profile.general.font then
                                            self.db.profile.general.font = { face = "", size = 12, flags = "OUTLINE", pixelPerfect = true, shadow = false }
                                        end
                                        self.db.profile.general.font.pixelPerfect = value
                                        self:RefreshAllFonts()
                                    end,
                                    order = 40,
                                },
                            },
                        },
                    },
                },
                modules = {
                    type = "group",
                    name = "Modules",
                    order = 20,
                    args = {},
                },
            },
        }
    end
    return self._optionsTable
end

local function FixScrollbarsInFrame(frame)
    if not frame then return end
    
    local function FixScrollFrame(scrollFrame)
        if scrollFrame and scrollFrame.obj and scrollFrame.obj.FixScroll then
            scrollFrame.obj:FixScroll()
        end
    end
    
    local function FindAndFixScrollFrames(parent)
        if not parent then return end
        
        local children = {parent:GetChildren()}
        for _, child in ipairs(children) do
            if child.GetObjectType and child:GetObjectType() == "ScrollFrame" then
                FixScrollFrame(child)
            end
            if child.GetChildren then
                FindAndFixScrollFrames(child)
            end
        end
        
        if parent.content and parent.content.GetChildren then
            FindAndFixScrollFrames(parent.content)
        end
    end
    
    FindAndFixScrollFrames(frame)
end

function TavernUI:InitializeOptions()
    local function getOptions()
        local options = self:GetOptions()
        if not options.args.profiles then
            options.args.profiles = AceDBOptions:GetOptionsTable(self.db)
            options.args.profiles.order = 100
        end
        return options
    end
    
    AceConfig:RegisterOptionsTable("TavernUI", getOptions)
    self.optionsFrame = AceConfigDialog:AddToBlizOptions("TavernUI", "TavernUI")
    
    AceConfigDialog:SetDefaultSize("TavernUI", 800, 800)
    
    local originalOpen = AceConfigDialog.Open
    AceConfigDialog.Open = function(self, appName, ...)
        local result = originalOpen(self, appName, ...)
        
        if appName == "TavernUI" then
            C_Timer.After(0.1, function()
                local frame = AceConfigDialog.OpenFrames["TavernUI"]
                if frame and frame.frame then
                    local windowFrame = frame.frame
                    
                    frame.frame:SetResizeBounds(800, 800, 1600, 1200)
                    
                    if not windowFrame._scrollbarFixed then
                        windowFrame._scrollbarFixed = true
                        
                        local function UpdateScrollbars()
                            FixScrollbarsInFrame(windowFrame)
                        end

                        windowFrame:HookScript("OnShow", function()
                            C_Timer.After(0.1, UpdateScrollbars)
                        end)
                        
                        if frame.content then
                            frame.content:HookScript("OnSizeChanged", function()
                                C_Timer.After(0.05, UpdateScrollbars)
                            end)
                        end
                        
                        UpdateScrollbars()
                    end
                end
            end)
        end
        
        return result
    end
end

function TavernUI:RegisterModuleOptions(moduleName, moduleOptions, displayName)
    displayName = displayName or moduleName
    
    local options = self:GetOptions()
    
    if not options.args.modules.args[moduleName] then
        options.args.modules.args[moduleName] = {
            type = "group",
            name = displayName,
            childGroups = "tab",
            args = {
                enabled = {
                    type = "toggle",
                    name = "Enable",
                    desc = string.format("Enable or disable the %s module", displayName),
                    order = 0,
                    width = "full",
                    get = function() return self:IsModuleEnabled(moduleName) end,
                    set = function(_, value) self:ToggleModule(moduleName, value) end,
                },
            },
        }
    end
    
    if moduleOptions and moduleOptions.args then
        for key, value in pairs(moduleOptions.args) do
            if value.order then
                value.order = value.order + 1
            end
            if value.disabled == nil and value.type ~= "header" and value.type ~= "description" then
                local originalDisabled = value.disabled
                value.disabled = function(info)
                    if not self:IsModuleEnabled(moduleName) then
                        return true
                    end
                    if type(originalDisabled) == "function" then
                        return originalDisabled(info)
                    end
                    return originalDisabled
                end
            end
            options.args.modules.args[moduleName].args[key] = value
        end
    end
    
    AceConfigRegistry:NotifyChange("TavernUI")
    
    C_Timer.After(0.2, function()
        local frame = AceConfigDialog.OpenFrames["TavernUI"]
        if frame and frame.frame then
            FixScrollbarsInFrame(frame.frame)
        end
    end)
end

function TavernUI:FindModuleByName(searchName)
    searchName = searchName:lower()
    for name, module in self:IterateModules() do
        if name:lower() == searchName then
            return name
        end
    end
    return nil
end

function TavernUI:OpenOptions(panel)
    panel = panel or "TavernUI"
    AceConfigDialog:Open(panel)
    
    C_Timer.After(0.1, function()
        local frame = AceConfigDialog.OpenFrames[panel]
        if frame and frame.frame then
            frame.frame:SetResizeBounds(600, 400, 1600, 1200)
            FixScrollbarsInFrame(frame.frame)
        end
    end)
end

function TavernUI:SlashCommand(input)
    input = input and input:gsub("^%s+", ""):gsub("%s+$", ""):lower() or ""
    
    if input == "" then
        self:OpenOptions()
    elseif input == "debug" then
        if self.db then
            self.db.profile.general.debug = not self.db.profile.general.debug
            self:Print("Debug mode:", self.db.profile.general.debug and "ON" or "OFF")
        end
    elseif input == "reset" then
        if self.db then
            self.db:ResetDB()
            self:RefreshModuleStates()
            self:Print("|cffff0000All saved variables have been reset to defaults.|r")
        else
            self:Print("Database not initialized.")
        end
    else
        local moduleName = self:FindModuleByName(input)
        if moduleName then
            local options = self:GetOptions()
            if options.args.modules.args[moduleName] then
                self:OpenOptions("TavernUI")
                AceConfigDialog:SelectGroup("TavernUI", "modules", moduleName)
            else
                self:Print("Module found but has no options panel.")
            end
        else
            self:Print("Unknown command. Use /tui to open config, /tui debug to toggle debug mode, or /tui reset to reset settings.")
        end
    end
end

function TavernUI:PrintHelp()
    self:Print("TavernUI Commands:")
    self:Print("  /tui or /tui help - Show this help")
    self:Print("  /tui config - Open configuration panel")
    self:Print("  /tui modules - List all modules and status")
    self:Print("  /tui enable <module> - Enable a module")
    self:Print("  /tui disable <module> - Disable a module")
    self:Print("  /tui debug - Toggle debug mode")
    self:Print("  /tui reset - Reset all saved variables to defaults")
end

function TavernUI:PrintModuleStatus()
    self:Print("--- TavernUI Modules ---")
    for name, module in self:IterateModules() do
        local status = module:IsEnabled() and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        self:Print(string.format("  %s: %s", name, status))
    end
end
