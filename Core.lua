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
    -- Notify modules first so they can update their state
    self:SendMessage("TavernUI_ProfileChanged")
    self:RefreshModuleStates()
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
