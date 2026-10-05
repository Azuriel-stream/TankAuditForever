# TankAudit Forever

**TankAudit Forever** is the WoW: Forever rewrite of **TankAudit**, the pre-pull checklist for tanks. It only shows
something when you need to act: **no tiles = you're all good**. A tile appears when a buff you should have is **missing**
(dimmed red) or **about to expire** (live icon with a red countdown). It keeps working **in combat**, which matters when you
chain pull without an out-of-combat moment.

Supported tanks: **Warrior** and **Paladin**. Druid and Shaman support will follow once Forever's tanking for them is settled.

## The checklist

Bottom row: a tile appears for each expected buff that is missing or expiring:

| Tile | Checked when | Click (while missing) |
|---|---|---|
| **Self buff**: Battle Shout (warrior), Righteous Fury (paladin) | once learned (solo too) | casts it |
| **Defensive Stance** | in a group, when you're not in it | switches stance |
| **Group buffs**: Fortitude, Divine Spirit, Mark of the Wild, Thorns, Arcane Intellect (not for warriors), Battle Shout (warrior in your subgroup), a Paladin Aura | the class that provides it is in your group | casts it if you can, otherwise asks your group in chat |
| **Blessings**, by your priority list | one per paladin in the group | casts it if you can, otherwise asks |
| **Food, Elixir or Flask, weapon buff** | in groups (elixir/flask by mode) | opens your bags |
| **Healthstone** | a warlock is in the group and you carry none | asks for one |

A buff that's up stays out of sight until its last 15 s (self buffs) or 60 s (group buffs and consumables); then its tile
appears with Blizzard's own live icon, sweep and red countdown. Hover it for the normal buff tooltip.

Top row:
- **Blessing of Salvation** (red CANCEL): appears when you get it; **right-click to cancel**, in combat too.
- **Dispellable debuffs**: one tile per type (Magic, Curse, Poison, Disease) that you or someone in your group is
  high enough level to remove (e.g. a level 15 paladin covers Poison/Disease, Magic needs Cleanse at 42). Shown live
  in combat. **Click it** to dispel yourself (paladin: Purify/Cleanse) or to ask the group ("I have a Poison effect on
  me - dispel me please!"). With no debuff of that type on you the tile is invisible, but its spot stays clickable;
  unlock the bar or open options to see the squares.

**In-combat warning:** for Battle Shout / Righteous Fury, TankAudit plays a warning sound and glows the tile when about
15 seconds are left, timed from your last cast (the sound can be turned off).

When a buff you asked for arrives, TankAudit **whispers the caster a thank-you** (can be turned off).

### How it works in combat
WoW: Forever hides aura data from addons during combat and locks clickable buttons in place. TankAudit arranges the
tiles out of combat (from your class, group and settings) and the layout stays fixed while you fight; what's drawn on a
tile comes live from the game itself. During a fight:
- a buff that was fine at the pull **fades in** when it reaches its warning window (timed from what TankAudit saw before the pull)
- Battle Shout / Righteous Fury are timed from **your own casts**, so recasting mid-fight hides the tile again
- a tile that appears mid-fight can't be clicked until combat ends (cast your buff with your keybind)
- someone joining mid-fight gets their tiles after combat
- a buff removed early by the enemy shows up at its expected expiry, not immediately

## Slash commands
| Command | Effect |
|---|---|
| `/tau` (or `/taudit`) | Open/close the options window |
| `/tau unlock` / `lock` | Drag the bar / fix it in place |
| `/tau reset` | Move the bar back to its default position |
| `/tau scan` | Rescan now |
| `/tau dump` | Print your current auras with spell IDs (helps report missing buffs) |
| `/tau status` | Print which tiles the bar currently shows |
| `/tau on` / `off` | Enable / disable |
| `/tau debug` | Show the last blocked action, if any |

## Options
Enable, lock and reset the bar, scale, which checks to run, consumables (food and weapon buff, plus optionally an elixir or a flask),
whisper thanks, the **Blessing priority** for your class (with N paladins in the group, the top N are expected), and the
in-combat sound warning. While the options window is open or the bar is unlocked, every tile is shown as a preview.

## Installation
Copy the `TankAuditForever` folder into `World of Warcraft\_<flavor>_\Interface\AddOns\`.
