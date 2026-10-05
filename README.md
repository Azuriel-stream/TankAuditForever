# TankAudit Forever

**TankAudit Forever** is the WoW: Forever rewrite of **TankAudit**, the pre-pull checklist for tanks. A compact bar of
icons shows what you're missing before the pull, and most icons do something when clicked.

Supported tanks: **Warrior** and **Paladin**. Druid and Shaman support will follow once Forever's tanking for them is settled.

## What it checks

| Row | Icon | Click |
|---|---|---|
| Top | **Dispellable debuffs** (only those you or your group can remove) | Paladin: cast Cleanse/Purify. Otherwise: ask the group to dispel you |
| Top | **Blessing of Salvation** (red CANCEL) | Cancels it, even in combat if it was there before the pull |
| Bottom | **Self buffs**: Warrior Battle Shout + Defensive Stance; Paladin Righteous Fury | Casts it |
| Bottom | **Group buffs** from classes in your group: Fortitude, Divine Spirit, Mark of the Wild, Thorns, Arcane Intellect (not for warriors), Battle Shout (warrior in your subgroup), a Paladin Aura, and Blessings by your priority list (one per paladin) | Casts it if you can (e.g. a paladin's own Kings), otherwise asks your group in chat |
| Bottom | **Consumables** (in groups): Well Fed, weapon buff, plus Elixir or Flask depending on the mode | Opens your bags |
| Bottom | **Healthstone** when a warlock is in the group and you carry none | Asks for one |

Missing buffs are grey. Buffs about to expire show a countdown (yellow, red under 10 s).
When a buff you asked for arrives, TankAudit **whispers the caster a thank-you** (can be turned off).

When you're solo, buff reminders only appear if you have a hostile target and are missing a self buff.

### Combat Watch: your shout/fury timer in combat
Above the bar sits a **Combat Watch** icon for your key self buff: **Battle Shout** (warrior) or **Righteous Fury**
(paladin). It's drawn by Blizzard's own aura display, so it keeps a live, exact countdown **in combat**, which matters when
chain pulling without an out-of-combat moment:
- the countdown turns **red** under 15 seconds, with a sweep showing the time left
- when the buff is gone, a dimmed red icon shows it's missing
- in combat, a **warning sound and red glow** fire when about 15 seconds are left (timed from your last cast; turn off in options)

Options: show/hide Combat Watch, only in combat, sound + glow warning.

### In combat
WoW: Forever hides aura information from addons during combat, and the bar's click-to-cast buttons are protected. So
the bar **freezes in its pre-combat state** while you fight: countdowns keep running, and a Salvation cancel button set
up before the pull still works. It updates as soon as combat ends.

## Slash commands
| Command | Effect |
|---|---|
| `/taudit` | Open/close the options window |
| `/taudit unlock` / `lock` | Drag the bar / fix it in place |
| `/taudit reset` | Move the bar back to its default position |
| `/taudit scan` | Rescan now |
| `/taudit dump` | Print your current auras with spell IDs (helps report missing buffs) |
| `/taudit status` | Print what the bar currently shows |
| `/taudit on` / `off` | Enable / disable |
| `/taudit debug` | Show the last blocked action, if any |

## Options
Enable, lock and reset the bar, scale, which checks to run, consumable mode (Food only / Food & Elixirs / Food & Flasks),
whisper thanks, and the **Blessing priority** for your class (with N paladins in the group, the top N are expected).
While the options window is open or the bar is unlocked, the bar shows preview icons.

## Installation
Copy the `TankAuditForever` folder into `World of Warcraft\_<flavor>_\Interface\AddOns\`.
