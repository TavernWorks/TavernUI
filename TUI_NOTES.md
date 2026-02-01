# TUI Notes – Action List & Status

Tracked list of feature and UX items for TavernUI, with current status. Update this file as items are completed or reclassified.

**Status legend**

- **Open** – Not done; actionable.
- **Partial** – Partially done (e.g. option exists but placement/behavior not fully as requested).
- **Unverified** – Needs in-game or code check to confirm.
- **Design** – Decision/design needed before implementation.
- **Confirmed** – Keep as-is; no change needed.
- **Planned** – On roadmap; not yet implemented.
- **Clarify** – Needs clarification (e.g. intended behavior or documentation).

---

## TUI (general)

- Add `/tui save` command to save profile on demand. **(Open)**
- Resizing: allow only increase; cannot decrease beyond default sizing. **(Unverified)**
- Planned skinning of the TUI UI. **(Planned)**
- Add individual movement arrows (X/Y offset) for any adjustable bar. **(Open)**

---

## CDM: Essentials CD tab

- Row Spacing: no visible result when only one row; disable or hide Row Spacing when there is a single row. **(Open)**
- Anchoring: when setting Anchoring Category, default Anchor Target to the first option in that category so the viewer moves immediately. **(Open)**
- Remove Row: consider hiding or removing “Remove Row” on the default (first) row for E.CD. **(Open)**
- Row growth: option to anchor the first icon and extend the row in one direction instead of centering and extending both sides. **(Open)**

---

## CDM: Utility CD tab

- Same as Essentials CD: row spacing, anchoring default target, remove row on default row, row growth option. **(Open)**

---

## CDM: Buff tab

- Same as Essentials CD: row spacing, anchoring, remove row, row growth. **(Open)**
- Keybinds for Buffs: decide whether to show keybind options for Buffs. **(Design)**

---

## CDM: Custom Items

- Drag & drop spells (and optionally items) for adding. **(Open)**
- Adding by spell name: passives, grey spells, talented spells produce no result; improve handling or feedback. **(Open)**
- Adding by trinket name produces no result; improve handling or feedback. **(Open)**
- Adding trinket via dropdown: displays on default viewer; fix placement/viewer. **(Open)**
- Macro/Action Bar slot: cooldown when the related spell is used from that slot does not show. **(Open)**
- Keep: ability to edit keybind and “Pick a slot” for Macro/Action Bar. **(Confirmed)**

---

## Menu / structure

- Move Resource Bar above QoL in the module list. **(Unverified)**
- QoL → Frame Hider: add default anchoring to player frame for Health, Power, and Resource so when the player frame is hidden those bars remain visible; currently they appear centered and under E.CD. **(Open)**
- UI Scale: have under General Settings as the first option to reduce confusion with Blizzard UI scaling. **(Partial)** – Options Scale exists under General but is not the first option.

---

## Resource Bars

- Move Anchoring to the top of Resource Bar options (currently at bottom). **(Open)**
- Power → Alternate Power: clarify which resource this displays; on Death Knight it shows nothing (may be correct when not in alternate-power content). **(Clarify)**

---

## Summary

| Status     | Count |
|-----------|-------|
| Open      | 18    |
| Partial   | 1     |
| Unverified| 2     |
| Design    | 1     |
| Confirmed | 1     |
| Planned   | 1     |
| Clarify   | 1     |
| **Total** | **22**|
