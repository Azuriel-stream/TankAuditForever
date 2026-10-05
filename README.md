# TankAudit Forever

**TankAudit Forever** is the WoW: Forever rewrite of **TankAudit**, the pre-pull checklist for tanks. A compact bar of
tiles shows every buff you should have: **lit with a live timer when it's up, dimmed red when it's missing**. It keeps
working **in combat**, which matters when you chain pull without an out-of-combat moment.

Supported tanks: **Warrior** and **Paladin**. Druid and Shaman support will follow once Forever's tanking for them is settled.

## The checklist

Bottom row, one tile per expected buff:

| Tile | Shown when | Click (while missing) |
|---|---|---|
| **Self buff**: Battle Shout (warrior), Righteous Fury (paladin) | always (once learned) | casts it |
| **Defensive Stance** | in a group, when you're not in it | switches stance |
| **Group buffs**: Fortitude, Divine Spirit, Mark of the Wild, Thorns, Arcane Intellect (not for warriors), Battle Shout (warrior in your subgroup), a Paladin Aura | the class that provides it is in your group | casts it if you can, otherwise asks your group in chat |
| **Blessings**, by your priority list | one per paladin in the group | casts it if you can, otherwise asks |
| **Food, Elixir or Flask, weapon buff** | in groups (elixir/flask by mode) | opens your bags |
| **Healthstone** | a warlock is in the group and you carry none | asks for one |

While a buff is up, its tile shows Blizzard's own aura icon with a sweep and countdown, which turns **red** when it's
about to fall off (15 s for self buffs, 60 s for the rest). Hover it for the normal buff tooltip. When it drops, even
mid-fight, the tile goes back to dimmed red.

Top row:
- **Blessing of Salvation** (red CANCEL): appears when you get it; **right-click to cancel**, in combat too.
- **Dispellable debuffs**: one tile per type (Magic, Curse, Poison, Disease) that you or someone in your group is
  high enough level to remove (e.g. a level 15 paladin covers Poison/Disease, Magic needs Cleanse at 42). Shown live
  in combat. **Click it** to dispel yourself (paladin: Purify/Cleanse) or to ask the group ("I have a Poison effect on
  me - dispel me please!"). The faint square marks the clickable spot when no debuff of that type is on you.

**In-combat warning:** for Battle Shout / Righteous Fury, TankAudit plays a warning sound and glows the tile when about
15 seconds are left, timed from your last cast (the sound can be turned off).

When a buff you asked for arrives, TankAudit **whispers the caster a thank-you** (can be turned off).

### How it works in combat
WoW: Forever hides aura data from addons during combat and locks clickable spell buttons. TankAudit decides *which*
tiles to show out of combat (from your class, group and settings), and that layout stays fixed while you fight. Each
tile's buff state and timer are drawn live by the game itself, so they stay accurate. A buff that lands mid-fight
lights up its tile, and someone joining mid-fight gets their tiles after combat.

## Slash commands
| Command | Effect |
|---|---|
| `/taudit` | Open/close the options window |
| `/taudit unlock` / `lock` | Drag the bar / fix it in place |
| `/taudit reset` | Move the bar back to its default position |
| `/taudit scan` | Rescan now |
| `/taudit dump` | Print your current auras with spell IDs (helps report missing buffs) |
| `/taudit status` | Print which tiles the bar currently shows |
| `/taudit on` / `off` | Enable / disable |
| `/taudit debug` | Show the last blocked action, if any |

## Options
Enable, lock and reset the bar, scale, which checks to run, consumable mode (Food only / Food & Elixirs / Food & Flasks),
whisper thanks, the **Blessing priority** for your class (with N paladins in the group, the top N are expected), and the
in-combat sound warning. While the options window is open or the bar is unlocked, every tile is shown as a preview.

## Installation
Copy the `TankAuditForever` folder into `World of Warcraft\_<flavor>_\Interface\AddOns\`.
