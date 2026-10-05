# TankAuditForever: Design

Rewrite of TankAudit 1.4.1 (Vanilla/Turtle WoW 1.12) for **WoW: Forever** (`16001`), following the TankAlertForever
architecture. The workspace knowledge base (`../kb/`) has the background; `kb/addons/TankAudit.md` has the feature
inventory and feasibility analysis.

## Legacy vs Forever

| Dimension | Legacy TankAudit (1.12) | TankAuditForever |
|---|---|---|
| Structure | 1 Lua file (1,315 lines) of global functions + XML | `Core/`, `Data/`, `Modules/`, `UI/`, `Locales/`, private namespace |
| Aura detection | Buff **icon texture** matching (`GetPlayerBuff`, `UnitBuff`) | **Spell IDs, every rank** (`C_UnitAuras.GetAuraDataByIndex`). Icons are numeric file IDs now |
| Stance | `GetShapeshiftFormInfo` texture | `GetShapeshiftFormInfo(i)` → spellID |
| Known spells | Spellbook texture cache | `C_SpellBook.IsSpellKnown` (global `IsPlayerSpell` is only a deprecation shim) |
| Weapon buff / Rockbiter | `GetWeaponEnchantInfo()` + tooltip scan | `C_Item.GetWeaponEnchantInfo(Enum.WeaponSlot.MainHand)` |
| Healthstone | Bag scan for "Healthstone" in links | `C_Item.GetItemCount` over healthstone item IDs |
| Click to cast / cancel | `CastSpellByName`, `CancelPlayerBuff` | `SecureActionButtonTemplate` (`type=spell` / `type=cancelaura`). Those functions are protected |
| Combat | Rescans every 3 s | **Frozen**: auras are secret and secure buttons are locked in combat |
| Gratitude | Guess the caster from class counts; group chat | `AuraData.sourceUnit` → **whisper the real caster** |
| Position | X/Y edit boxes | Drag while unlocked + reset |
| Config | XML frame, `UIDropDownMenu`, Options templates | `ButtonFrameTemplate` panel, `WowStyle1DropdownTemplate`, `MinimalSliderWithSteppersTemplate` |
| Data | 1.12 assumptions (5-min blessings, Sanctuary) | Wowhead Forever data: 1-hour buffs, Kings/Spirit baseline, **no Sanctuary** |

## Modules and data flow
```
events / 3 s ticker (out of combat) ──► Scanner:Queue() ─0.2 s─► Scanner:Scan()
   Roster:Update()  (class counts, my subgroup)
   ReadAuras(HELPFUL/HARMFUL)  (aborts if data is secret)
   self → group → blessings → consumables → healthstone → unwanted → debuffs → smart visibility
   state = { top = {debuffs, unwanted}, bottom = {missing, expiring} }
   Gratitude:Check(auras)   ── whispers the caster of a requested buff
   Bar:Render(state)        ── in combat: stored as pending, applied on PLAYER_REGEN_ENABLED
Bar button click ──► secure action (spell / cancelaura) ──► HookScript OnClick ──► Requests:OnClick
                                                              (chat request / open bags)
```

| File | Role |
|---|---|
| `Core/Init.lua` | namespace (`TankAuditForever` global), module lifecycle (`OnInitialize` → `OnLogin` → `OnEnable`), supported classes, blocked-action recorder |
| `Core/Config.lua` | defaults + merge, per-class blessing priority |
| `Core/Utils.lua` | secret-safe helpers, aura iteration, spell names/links, weapon enchant, Forever full names |
| `Data/Buffs.lua` | all spell/item IDs (Wowhead Forever, 1.60.1) |
| `Data/Messages.lua` | chat request texts and thank-you whispers |
| `Modules/Roster.lua` | group class composition |
| `Modules/Scanner.lua` | builds the audit state; `/taudit dump` |
| `Modules/Requests.lua` | chat requests (throttled), bags; remembers the pending request |
| `Modules/Gratitude.lua` | thank-you whisper |
| `Modules/Bar.lua` | 16 secure buttons, layout, countdowns, drag/lock, preview, combat freeze |
| `UI/Options.lua` | options window, `/taudit` commands |
| `tests/` | headless wowsim tests (run `../tools/test.ps1 TankAuditForever`) |

## Extending
- **New tank class:** add `D.SELF.<CLASS>` (and `D.PLAYER_DISPELS.<CLASS>`) in `Data/Buffs.lua`, a default in
  `Config.blessingPriority`, and the class in `TAU.SUPPORTED_CLASSES`.
- **New buff:** find IDs with `../tools/wowhead.ps1 "<name>" -Exact`, add a `D.GROUP` entry, and a message list in `Data/Messages.lua`.

## Known unknowns (verify in-game)
- `C_Item.GetWeaponEnchantInfo` `timeLeft` units (assumed ms). `/taudit dump` prints the raw value.
- Spell IDs come from Wowhead; confirm with `/taudit dump`.
- Whisper target format for Forever full names ("First Last").
