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
| Combat | Rescans every 3 s | **Tiles**: which tiles show is planned out of combat and frozen in combat; each tile's buff state/timer is drawn live by a Blizzard `CustomAuraContainer` slot (works with secret auras). Self-buff warning timed from own casts |
| Gratitude | Guess the caster from class counts; group chat | `AuraData.sourceUnit` → **whisper the real caster** |
| Position | X/Y edit boxes | Drag while unlocked + reset |
| Config | XML frame, `UIDropDownMenu`, Options templates | `ButtonFrameTemplate` panel, `WowStyle1DropdownTemplate`, `MinimalSliderWithSteppersTemplate` |
| Data | 1.12 assumptions (5-min blessings, Sanctuary) | Wowhead Forever data: 1-hour buffs, Kings/Spirit baseline, **no Sanctuary** |

## Modules and data flow
```
ADDON_LOADED ──► Bar builds every possible tile for the class (Blizzard aura frames must exist before PLAYER_LOGIN)

events / 3 s ticker (out of combat) ──► Scanner:Queue() ─0.2 s─► Scanner:Scan()
   ForEachAura(HELPFUL)        (aborts if data is secret; used for gratitude)
   BuildPlan(): Roster → self → stance → group → blessings → consumables → healthstone
                plan = { tiles = {ordered items + click actions}, salvation, dispelTypes }
   Gratitude:Check(auras)      ── whispers the caster of a requested buff
   Bar:Apply(plan)             ── show/arrange tiles; in combat stored as pending, applied on PLAYER_REGEN_ENABLED

Blizzard aura slots (always, in combat too) ──► each tile lit + countdown when the buff is up, else our missing art
Tile click (buff missing) ──► secure action (spell) ──► HookScript OnClick (up half) ──► Requests:OnClick
                                                             (chat request / open bags)
Salvation slot right-click ──► Blizzard CancelAuraByInstanceID
UNIT_SPELLCAST_SUCCEEDED (own) ──► SelfAlert ──► sound + tile glow at ~15 s left (in combat)
```

| File | Role |
|---|---|
| `Core/Init.lua` | namespace (`TankAuditForever` global), module lifecycle (`OnInitialize` → `OnLogin` → `OnEnable`), supported classes, blocked-action recorder |
| `Core/Config.lua` | defaults + merge, per-class blessing priority |
| `Core/Utils.lua` | secret-safe helpers, aura iteration, spell names/links, weapon enchant, Forever full names |
| `Data/Buffs.lua` | all spell/item IDs (Wowhead Forever, 1.60.1) |
| `Data/Messages.lua` | chat request texts and thank-you whispers |
| `Modules/Roster.lua` | group class composition |
| `Modules/Scanner.lua` | out of combat: plans which tiles show (checklist), their order and click actions, Salvation/debuff-type settings; `/taudit dump` |
| `Modules/Requests.lua` | chat requests (throttled), bags; remembers the pending request |
| `Modules/Gratitude.lua` | thank-you whisper |
| `Modules/Bar.lua` | tiles: every possible tile built at `ADDON_LOADED` (our SecureActionButton + missing art + Blizzard aura slot / item-enchant frame + glow); top row = Salvation slot (right-click cancel) + dispellable-debuff aura group; `Apply(plan)` lays out out of combat only; drag/lock, preview |
| `Modules/SelfAlert.lua` | Battle Shout / Righteous Fury: sound + tile glow ~15 s before expiry in combat, timed from own `UNIT_SPELLCAST_SUCCEEDED` with the duration learned out of combat |
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
