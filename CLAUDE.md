# TavernUI — Claude Development Guide

## Project Identity
- **Addon**: TavernUI — a modern, modular UI replacement for World of Warcraft
- **Authors**: Mondo, LiQiuDgg
- **Org**: TavernWorks (GitHub: https://github.com/TavernWorks/TavernUI)
- **WoW Target**: The War Within / World of Midnight — Interface `120001, 120000`
- **Lua Version**: 5.1 (WoW's embedded Lua; no external Lua toolchain)
- **SavedVariables**: `TavernUIConfig` (single AceDB-managed table)

---

## Environment Constraints

### Lua 5.1 — Critical Gotchas
- **No `continue`** — use `if not condition then ... end`, `repeat/until`, or restructure loops
- **No bitwise operators** (`&`, `|`, `~`, `>>`, `<<`) — use `bit.band()`, `bit.bor()`, `bit.bxor()`, `bit.rshift()`, `bit.lshift()`
- **No integer division `//`** — use `math.floor(a / b)`
- **`table.unpack` is `unpack`** — just `unpack(t)`, not `table.unpack(t)`
- **`#` on tables with holes is undefined** — avoid mixed arrays; use explicit counters
- **No `goto`** — refactor the logic
- **String templates** — use `string.format()`, never string concat in hot paths
- **`local` is mandatory for performance** — every function and variable should be `local` unless intentionally global
- **Closures capture by reference** — be careful with loop variables in closures; cache as local: `local i = i`
- **`pairs` vs `ipairs`**: `ipairs` stops at the first nil; `pairs` iterates all keys (unordered)
- **`tostring(nil)` is `"nil"`** — guard nil checks explicitly
- **No `string.split`** — use `strsplit()` (WoW global) or `string.gmatch`
- **Metatables for OOP**: `__index` for method lookup, `setmetatable` for inheritance

### WoW API Constraints
- **No `io`, `os`, `debug` libraries** — sandboxed environment
- **`print()` goes to chat** — use `DEFAULT_CHAT_FRAME:AddMessage()` or `UIErrorsFrame:AddMessage()`
- **Secure frames**: taint rules apply — never mix secure/insecure in combat
- **`InCombatLockdown()`** — check before modifying protected frames; queue for post-combat
- **`C_Timer.After(delay, fn)`** — for deferred execution; never `time()` or `os.time()`
- **`GetTime()`** — returns seconds since WoW session start (not epoch)
- **Event arguments**: first arg to handlers is always `self` (the frame), second is `event`
- **Frame pool pattern**: use `CreateFramePool` for repeated frame creation

---

## Architecture Overview

```
TavernUI.toc          ← Interface manifest, SavedVariables declaration
Core.lua              ← AceAddon instance, TavernUI namespace, module prototype
Core_Config.lua       ← Centralized config manager (path-based Get/Set + callbacks)
Localization/enUS.lua ← AceLocale-3.0 strings
libs/                 ← Embedded libraries (gitignored, built by packager)
Modules/              ← All feature modules (each self-contained)
.pkgmeta              ← BigWigs packager: library externals + release ignores
.wip/                 ← Work-in-progress modules (excluded from build)
```

**Load order**: `libs → Core.lua → Core_Config.lua → Localization → Modules`

---

## Module Pattern

Every module follows this exact structure:

```lua
local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:NewModule("ModuleName", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("TavernUI")

-- CRITICAL: Register defaults at file load time, BEFORE OnInitialize
TavernUI:RegisterModuleDefaults("ModuleName", {
    profile = {
        enabled = true,
        someOption = "default",
    }
}, false)  -- false = not standalone

function module:OnInitialize()
    -- First access to DB is safe here; defaults are already registered
end

function module:OnEnable()
    -- Register events, create frames, etc.
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
end

function module:OnDisable()
    -- Clean up events, hide frames
end

function module:OnPlayerEnteringWorld()
    -- Handler (self = module, no extra args needed when using method name)
end
```

**Module prototype methods** (defined in Core.lua):
- `module:GetDB()` — returns current profile DB for this module
- `module:GetSetting(key)` — gets a setting value from profile
- `module:SetSetting(key, value)` — sets a setting value
- `module:Debug(...)` — conditional debug output

---

## Config System (Core_Config.lua)

Path format: `"TUI.ModuleName.setting"` or `"TUI.ModuleName.nested.key"`

```lua
-- Read a setting (anywhere in the addon)
local value = TavernUI:GetConfig("TUI.UnitFrames.healthColorMode")

-- Write a setting
TavernUI:SetConfig("TUI.UnitFrames.healthColorMode", "CLASS")

-- Register a callback (fires when path changes or profile swaps)
TavernUI:RegisterConfigCallback("TUI.UnitFrames.healthColorMode", function(value)
    -- Update frames
end)
```

**Rules**:
- Paths MUST start with `"TUI."` — the config manager validates this
- Bracket notation supported: `"TUI.Module[key].sub"`
- Callbacks are auto-cleared on profile change to prevent stale subscriptions
- `module.requiresReload = true` flags settings that need `/reload`

---

## Theming System

```lua
-- Global theme accessors (defined in UnitFrames_Theme.lua)
TavernUI:GetThemeValue(key)          -- returns scalar theme value
TavernUI:GetThemeColor(key)          -- returns {r, g, b, a} table
TavernUI:GetThemeStatusBarTexture()  -- returns LSM texture path or ""

-- Color mode constants used across modules
-- "CLASS"       → unit class color
-- "CUSTOM"      → user-defined color
-- "POWER_TYPE"  → power type color (mana=blue, rage=red, etc.)
-- "REACTION"    → hostile/friendly/neutral
```

---

## Libraries Available

| Library | `LibStub` key | Purpose |
|---|---|---|
| AceAddon-3.0 | `"AceAddon-3.0"` | Module system |
| AceDB-3.0 | `"AceDB-3.0"` | SavedVariables management |
| AceEvent-3.0 | mixin | WoW event system |
| AceConfig-3.0 | `"AceConfig-3.0"` | Options panel registration |
| AceGUI-3.0 | `"AceGUI-3.0"` | GUI widgets |
| AceLocale-3.0 | `"AceLocale-3.0"` | Translations |
| oUF | `"oUF"` | Unit frame rendering |
| LibSharedMedia-3.0 | `"LibSharedMedia-3.0"` | Custom fonts/textures/sounds |
| LibDataBroker-1.1 | `"LibDataBroker-1.1"` | DataText protocol |
| LibAnchorRegistry-1.0 | `"LibAnchorRegistry-1.0"` | Inter-addon frame anchoring |
| LibSerialize | `"LibSerialize"` | Table serialization |
| LibDeflate | `"LibDeflate"` | Compression |
| LibDualSpec-1.0 | `"LibDualSpec-1.0"` | Per-spec settings |
| LibCustomGlow-1.0 | `"LibCustomGlow-1.0"` | Glow effects |
| LibEditMode | `"LibEditMode"` | EditMode API integration |

---

## Reference Addons

Located at `c:\Development\WoW\ReferenceAddons\`. **Always consult before implementing a feature.**

| Addon | Best for referencing |
|---|---|
| **DandersFrames** | Click-casting, auras, range fading, frame features, highlight systems |
| **PonyUnitFrames** | Clean Ace3+oUF module pattern, component registry, layout management |
| **Masque** | Multi-version compatibility, button skinning API, localization patterns |
| **QuaziiUI** | Monolithic UI replacement approach, aesthetic inspiration |
| **Blizzard Addons** | Ground truth WoW API — EditMode frames, secure action buttons, UIParent hierarchy |

**Rule**: When adding a new feature, search ReferenceAddons first for prior art. Prefer adapting proven patterns over inventing new ones.

---

## Sensitive Values

The following are **project-specific IDs** in `TavernUI.toc` — do not alter or commit changes to these without intent:
- `X-Curse-Project-ID: 1443486`
- `X-Wago-ID: qKQmgaKx`

**Never commit**:
- CurseForge API tokens or upload keys (used in CI/packager, stored in env vars only)
- WoW account-specific SavedVariables snapshots (`.wtf` files, `SavedVariables/*.lua`)
- Any file containing `APIKEY`, `TOKEN`, `SECRET`, or `PASSWORD` in content

**Pattern for runtime secrets** (e.g., per-character hidden values):
```lua
-- Store in SavedVariables under a non-obvious key, never in source
-- Use LibSerialize + LibDeflate for import/export of profile data
-- Never log sensitive values with Debug() or print()
```

---

## Code Conventions

From `CONTRIBUTING.md`:
- **Indentation**: 4 spaces (no tabs)
- **Locals**: `camelCase` — `local frameWidth`
- **Globals/Namespaces**: `PascalCase` — `TavernUI`, `UnitFrames`
- **Constants**: `UPPER_CASE` — `local MAX_COOLDOWNS = 20`
- **Functions**: small and focused; comment complex logic only (not obvious code)
- **Events**: prefer `self:RegisterEvent("EVENT", "MethodName")` over anonymous functions for debuggability
- **Branch names**: `feature/*`, `fix/*`, `refactor/*`, `docs/*`
- **Commits**: start with verb, under 72 chars — `"Add throttle to ResourceBars updater"`

---

## Development Workflow

### Testing
1. Symlink `c:\Development\WoW\TavernUI` → WoW `_retail_\Interface\AddOns\TavernUI`
2. `/reload` in-game after Lua changes
3. `/script` in-game for quick API experiments
4. Check Lua errors: enable Lua error display or use BugSack/BugGrabber
5. Test optional deps absent: disable LibSharedMedia, test fallback paths

### Library Setup (when libs/ is missing)
```bash
bash release.sh -d -z                         # packager downloads to .release/TavernUI/libs/
cp -r .release/TavernUI/libs/* libs/          # copy to dev folder
```

### Adding a New Module
1. Create `Modules/MyModule/MyModule.lua` (+ `MyModule.xml` if multiple files)
2. Register defaults at file scope with `TavernUI:RegisterModuleDefaults()`
3. Add to `Modules/Modules.xml` in load order
4. Add options table wired into `Modules/Options/Options.lua`
5. Register frames with `LibAnchorRegistry` if they need external anchoring
