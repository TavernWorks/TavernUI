-- TavernUI Core.lua

local AF = LibStub("AbstractFramework", true) or _G.AbstractFramework

local TavernUI = LibStub("AceAddon-3.0"):NewAddon("TavernUI",
    "AceConsole-3.0",
    "AceEvent-3.0"
)

TavernUI.AF = AF
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
    return TavernUI.db.profile[self:GetName()] or {}
end

function TavernUI.modulePrototype:Debug(...)
    if TavernUI.db and TavernUI.db.profile.general.debug then
        TavernUI:Print("|cff999999[" .. self:GetName() .. "]|r", ...)
    end
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
    self.db = LibStub("AceDB-3.0"):New("TavernUIConfig", self.defaults, true)
    -- Do NOT call RegisterDefaults again - it's already set via New()
    
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
    
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
        
        if shouldEnable and not module:IsEnabled() then
            self:EnableModule(name)
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

function TavernUI:InitializeOptions()
    local function getOptions()
        local options = self:GetOptions()
        if not options.args.profiles then
            options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
            options.args.profiles.order = 100
        end
        return options
    end
    
    LibStub("AceConfig-3.0"):RegisterOptionsTable("TavernUI", getOptions)
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("TavernUI", "TavernUI")
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
    
    LibStub("AceConfigRegistry-3.0"):NotifyChange("TavernUI")
end

function TavernUI:OpenOptions(panel)
    panel = panel or "TavernUI"
    LibStub("AceConfigDialog-3.0"):Open(panel)
end

function TavernUI:SlashCommand(input)
    input = input and input:gsub("^%s+", ""):gsub("%s+$", ""):lower() or ""
    
    if input == "" or input == "help" then
        self:PrintHelp()
    elseif input == "config" or input == "options" then
        self:OpenOptions()
    elseif input == "modules" then
        self:PrintModuleStatus()
    elseif input:match("^enable%s+(.+)$") then
        local moduleName = input:match("^enable%s+(.+)$")
        self:ToggleModule(moduleName, true)
    elseif input:match("^disable%s+(.+)$") then
        local moduleName = input:match("^disable%s+(.+)$")
        self:ToggleModule(moduleName, false)
    elseif input == "debug" then
        if self.db then
            self.db.profile.general.debug = not self.db.profile.general.debug
            self:Print("Debug mode:", self.db.profile.general.debug and "ON" or "OFF")
        end
    else
        self:Print("Unknown command. Type /tui help for commands.")
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
end

function TavernUI:PrintModuleStatus()
    self:Print("--- TavernUI Modules ---")
    for name, module in self:IterateModules() do
        local status = module:IsEnabled() and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        self:Print(string.format("  %s: %s", name, status))
    end
end
