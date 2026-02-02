# IchaTaunt - Taunt Tracker for Turtle WoW

A modern taunt tracking addon for Turtle WoW (1.12 client) that monitors taunt cooldowns across your raid or party, syncs state between members, and shows live damage taken (DTPS) so tanks can coordinate threat and know when to taunt off each other.

---

## Overview

IchaTaunt provides:

- **Per-player taunt cooldown tracking** for all supported taunts (Warrior, Druid, Shaman, Paladin), with resist detection and broadcast so everyone sees who used what and when.
- **Raid-wide sync** (PallyPower-style): the leader sets taunter list and order; cooldown usage is broadcast so all members see the same timers. If you DC and rejoin, you can receive current cooldown state from the leader so Roar/Shout/Mocking Blow remaining time is correct.
- **Cooldown persistence** across reload and logoff: remaining time for long cooldowns (e.g. Challenging Roar/Shout) is saved and restored so the tracker doesn’t reset to full duration after a reload.
- **DTPS (Damage Taken Per Second)** per tank: each tank broadcasts their own DTPS in combat; others see incoming damage rate so they know when to taunt off someone taking heavy damage.
- **Clean, non-intrusive UI**: tracker is movable and themeable; when locked it is click-through so it doesn’t block camera or clicks. Unlock/lock from the options menu or the X on the tracker.

---

## Features

### Taunt tracking

- **Visual cooldown bars** with countdown timers (minutes:seconds for long CDs) for every tracked taunter and spell.
- **Resist detection**: when a taunt is resisted, the tracker shows a clear resist indicator and the resist state is broadcast so the raid sees it.
- **All taunts broadcast on use**: single-target (Taunt, Growl, Earthshaker Slam, Hand of Reckoning), Mocking Blow, and AOE (Challenging Shout, Challenging Roar). Detection uses cast hooks and a cooldown poller so it works regardless of how the spell is cast (action bar, macro, etc.).
- **Correct remaining time**: when you or someone else is already on cooldown and you reload/DC, the addon restores or receives the actual remaining duration (e.g. 5:00 left on Roar instead of 10:00).

### Raid sync (PallyPower-style)

- **Leader-controlled config**: raid leader (or officer) sets taunter list and order; sync is sent to the raid so everyone has the same tracker setup.
- **Cooldown broadcast**: when anyone uses a taunt, their client broadcasts it (player, spell, remaining cooldown, resist). Others apply it so everyone’s timers match.
- **Rejoin after DC**: when you request sync (e.g. after reconnecting), the leader sends config *and* a snapshot of all active cooldowns (remaining seconds). You get correct Roar/Shout/Mocking Blow (and other) timers even though you missed the original cast.

### Cooldown persistence

- **Survives reload and logoff**: active cooldown end times are stored (using real time where available). On load, the tracker restores saved cooldowns for all players and, for the local player, refreshes from the game’s spell cooldown API so the displayed remaining time is accurate.

### DTPS (Damage Taken Per Second)

- **Per-tank damage rate**: each tank’s DTPS is computed from the combat log (rolling window, default 3 seconds) and shown on their bar (e.g. `1.2k DTPS`). Color reflects thresholds (green / yellow / red).
- **Broadcast in combat only**: your DTPS is broadcast to the raid only while you are in combat, so it doesn’t spam when you’re idle.
- **Low impact**: small, fixed-size data (rolling window + one value per other tank); minimal memory and bandwidth.

### User interface

- **Tracker**
  - Draggable; position is saved.
  - **Locked = click-through**: when locked, the frame doesn’t capture mouse input, so there’s no dead area for camera or clicking the world.
  - **Unlock / Lock**: from the options menu (“Unlock Position” / “Lock Position”) or by clicking the X on the tracker. The menu button label reflects current state (Unlock when locked, Lock when unlocked).
- **Themes**: Default, Dark, and ElvUI-style; applies to tracker and config windows.
- **Scale**: adjustable tracker scale (e.g. 50%–200%).
- **Options menu** (`/it` or via config): theme, scale, Reset Position, Unlock/Lock Position, DTPS toggle, and (in main config) taunter selection and order.

### Supported taunt abilities

| Class   | Spell              | Cooldown |
|--------|--------------------|----------|
| Warrior | Taunt              | 10 s     |
| Warrior | Mocking Blow       | 2 min    |
| Warrior | Challenging Shout  | 10 min   |
| Druid   | Growl              | 10 s     |
| Druid   | Challenging Roar   | 10 min   |
| Shaman  | Earthshaker Slam   | 10 s     |
| Paladin | Hand of Reckoning  | 10 s     |

(Turtle WoW custom: Earthshaker Slam, Hand of Reckoning. Add more in `IchaTaunt_Spells.lua`.)

---

## Installation

1. Download the addon.
2. Extract to `World of Warcraft\Interface\AddOns\`.
3. Ensure the folder is named `IchaTaunt`.
4. Restart WoW or `/reload`.

---

## Quick start

1. **Join a raid or party** with tanks.
2. **Open config**: `/it` or `/it config`.
3. **Set taunters**: in the left panel, click **+** next to each tank to track; order in the right panel is the display order. (Leader’s list/order syncs to the raid.)
4. **Tracker**: appears when you have taunters and (optionally) are in a raid. Each bar shows name, spell icons, cooldown timers, resist, and DTPS when enabled.
5. **Move / lock**: drag to move; use **Lock Position** in options or the **X** on the tracker to lock (click-through). Use **Unlock Position** in options to unlock and move again.

---

## Slash commands

| Command | Description |
|--------|-------------|
| `/it` | Open config window |
| `/it config` | Open taunter selection |
| `/it help` | List all commands |
| `/it show` / `hide` / `toggle` | Show/hide tracker |
| `/it reset` or `center` | Reset tracker position to center |
| `/it lock` / `unlock` / `togglelock` | Lock/unlock tracker |
| `/it sync` | Request sync from leader (or send config if you’re leader) |
| `/it theme <name>` | Set theme (default, dark, elvui) |
| `/it scale <value>` | Set scale (0.5–2.0 or 50–200) |
| `/it dtps` | DTPS subcommands; `/it dtps help` for list |
| `/it debug` | Toggle debug mode (taunt/sync messages) |
| `/it test` | Test cooldown (first spell for your class, broadcasts in group) |
| `/it testtaunt` / `testgrowl` / `testroar` / `testshout` / `testmocking` / `testearthshaker` / `testhand` | Test specific taunt (broadcasts in group) |
| `/it testall` | Test all spell cooldowns (broadcasts each in group) |

---

## Configuration

- **Main config** (`/it` or `/it config`): taunter list and order, show-in-raid-only, lock state. Leader’s choices sync to the raid.
- **Options menu** (Theme & scale): theme, scale, **Reset Position**, **Unlock Position** / **Lock Position** (toggle), DTPS on/off. Unlock/lock here or via the X on the tracker.

### Lock / unlock flow

- When the tracker is **locked**, it is click-through (no dead area). The X on the tracker is not clickable in this state.
- Use the options menu: **Unlock Position** to unlock, move the tracker, then **Lock Position** (or click the X on the tracker) to lock again.

---

## Customization

- **Themes**: `/it theme default|dark|elvui` or via options. Definitions in `IchaTaunt_Themes.lua`.
- **Scale**: `/it scale 0.8` or options.
- **Custom taunts**: edit `IchaTaunt_Spells.lua` (spell ID, name, cooldown, icon, classes). Use `/dump GetSpellInfo("Spell Name")` for IDs.

---

## Technical notes

- **Sync**: Addon messages (prefix `ICHAT`) on PARTY/RAID. Messages include ORDER, TAUNTERS, CD (player, spellID, remaining, resist), CD_SNAPSHOT (for rejoin), DTPS, REQ (request config + CD snapshot). Leader responds to REQ with config and CD snapshots.
- **Cooldown persistence**: End times are stored in `IchaTauntDB.cooldownEndTimes` (by normalized name and spell ID). On load, remaining time is restored from DB; for the local player, remaining time is also refreshed from `GetSpellCooldown` when available.
- **DTPS**: Combat log events feed a rolling window per player; DTPS is broadcast only in combat. Other tanks’ values are stored from addon messages and shown on their bars.

---

## Troubleshooting

- **Tracker doesn’t show**: Ensure taunters are added and in group; check “Show in Raid Only” and `/it bar show`.
- **Cooldowns not updating**: Ensure you’re in group for broadcast; try `/it debug` and cast a taunt to see detection.
- **Can’t move tracker when locked**: Use options menu → **Unlock Position**, then move, then lock again (menu or X).
- **DTPS not showing**: Enable in options or `/it dtps on`; you must be in combat to broadcast.

---

## FAQ

**Q: Does it sync between raid members?**  
A: Yes. Taunter list and order sync from the leader; cooldown usage and resist are broadcast by the caster; on rejoin you can get current cooldown state from the leader.

**Q: Does it work in party as well as raid?**  
A: Yes. Sync and broadcast work in party and raid.

**Q: Is DTPS heavy on memory or bandwidth?**  
A: No. Small fixed buffers and one broadcast per tank per second in combat only.

**Q: Can I add custom taunts?**  
A: Yes. Edit `IchaTaunt_Spells.lua` with spell ID, name, cooldown, icon, and classes.

**Q: Retail WoW?**  
A: No. Built for Turtle WoW (1.12 client).

---

## Version history

### Modernized (current)

- Raid sync: PallyPower-style config sync, cooldown broadcast, CD snapshot on rejoin after DC.
- Cooldown persistence across reload/logoff with correct remaining time.
- All taunts broadcast (single-target and AOE); resist broadcast; cooldown poller when hooks don’t fire.
- DTPS module: per-tank damage rate, in-combat-only broadcast.
- Tracker lock = click-through; Unlock/Lock Position in options (toggle button); X on tracker to lock.
- Themes (default, dark, elvui) and scale.
- Chat printing removed for clean UI; debug optional via `/it debug`.

### Earlier

- v1.1: Scrolling raid/party panels, fixed long cooldowns, optional debug.
- v1.0: Basic taunt tracking, cooldown timers, resist, drag-and-drop config.

---

## Credits

**Author**: Vibe-coded with Claude  
**Dreamers**: Ichabaddie and Cinos (Oathsworn)  
**For**: Turtle WoW (1.12 client)  
**License**: Free to use and modify  

*Happy tanking. May your taunts never be resisted.*
