# IchaTaunt - Tank Taunt Tracker for Turtle WoW

A comprehensive taunt tracking addon for Turtle WoW (1.12 client) that monitors taunt cooldowns across your raid, with real-time sync between tanks.

![Version](https://img.shields.io/badge/version-1.5.1-blue)
![Client](https://img.shields.io/badge/client-Turtle%20WoW%201.12-green)

## Features

### Real-Time Taunt Tracking
- **Visual cooldown bars** with countdown timers for all tracked taunters
- **Per-player tracking** - see exactly when each tank's taunt is ready
- **Smart time display** - shows `5:30` for long cooldowns, switches to seconds under 1 minute
- **Resist detection** - automatic "RESIST!" indicator when a taunt fails
- **Class-colored names** - easily identify tanks at a glance

### Cooldown Sync (NEW in 1.5)
- **Automatic broadcasting** - when you use a taunt, all raid members with IchaTaunt see your cooldown
- **Cross-tank visibility** - see when other tanks use Challenging Shout/Roar even from across the raid
- **PallyPower-style sync** - raid leader can set tank order, syncs to all members
- **Auto-sync toggle** - enable/disable automatic sync updates

### DTPS Module (Damage Taken Per Second)
- **Live damage tracking** - shows real-time DTPS for each tank
- **Rolling window calculation** - 3-second window for accurate live feed
- **Broadcast to raid** - other tanks can see your DTPS
- **Warning thresholds** - color-coded warnings for high damage intake
- **Toggle on/off** - disable if you don't need this info

### Supported Taunt Abilities

| Class | Spell | Cooldown |
|-------|-------|----------|
| **Warrior** | Taunt | 10 sec |
| **Warrior** | Mocking Blow | 2 min |
| **Warrior** | Challenging Shout | 10 min |
| **Druid** | Growl | 10 sec |
| **Druid** | Challenging Roar | 10 min |
| **Shaman** | Earthshaker Slam | 10 sec |
| **Paladin** | Hand of Reckoning | 10 sec |

*Shaman and Paladin taunts are Turtle WoW custom abilities*

### User Interface
- **Drag-and-drop configuration** - easily add/remove tanks from tracking
- **Reorderable tank list** - arrange tanks in your preferred priority order
- **Multiple themes** - Default WoW, Dark, and ElvUI styles
- **Scalable UI** - resize from 50% to 200%
- **Lock/unlock tracker** - lock to make click-through, unlock to reposition
- **Convert to Raid button** - quickly convert party to raid from the addon

## Installation

1. Download the addon
2. Extract to `World of Warcraft\Interface\AddOns\`
3. Rename the folder to `IchaTaunt` (case-sensitive)
4. Restart WoW or `/reload`

**Folder structure:**
```
Interface/AddOns/IchaTaunt/
  IchaTaunt.toc
  IchaTaunt.lua
  IchaTaunt_Spells.lua
  IchaTaunt_Themes.lua
  IchaTaunt_DPS.lua
```

## Quick Start

1. **Join a raid or party** with tanks
2. **Open configuration**: Type `/it`
3. **Add taunters**: Click the `+` button next to each tank you want to track
4. **Arrange order**: Use the up/down arrows to reorder tanks
5. **Close** the window - tracker appears automatically

## Slash Commands

### Basic Commands
| Command | Description |
|---------|-------------|
| `/it` | Open main config window |
| `/it config` | Open taunter selection |
| `/it options` | Open theme & scale options |
| `/it help` | Show all commands |

### Tracker Control
| Command | Description |
|---------|-------------|
| `/it show` | Show tracker bar |
| `/it hide` | Hide tracker bar |
| `/it toggle` | Toggle tracker visibility |
| `/it reset` | Reset tracker to screen center |
| `/it lock` | Lock tracker (click-through) |
| `/it unlock` | Unlock tracker |

### Appearance
| Command | Description |
|---------|-------------|
| `/it theme` | List available themes |
| `/it theme <name>` | Set theme (default, dark, elvui) |
| `/it scale` | Show current scale |
| `/it scale <value>` | Set scale (0.5-2.0 or 50-200%) |

### Sync Commands
| Command | Description |
|---------|-------------|
| `/it sync` | Force sync with raid |
| `/it autosync` | Toggle automatic sync |

### Testing Commands
| Command | Description |
|---------|-------------|
| `/it test` | Test cooldown on your class's first spell |
| `/it testresist` | Test resist indicator |
| `/it testtaunt` | Test Taunt (Warrior, 10s) |
| `/it testgrowl` | Test Growl (Druid, 10s) |
| `/it testroar` | Test Challenging Roar (10 min) |
| `/it testshout` | Test Challenging Shout (10 min) |
| `/it testmocking` | Test Mocking Blow (2 min) |
| `/it testearthshaker` | Test Earthshaker Slam (10s) |
| `/it testhand` | Test Hand of Reckoning (10s) |
| `/it testall` | Test ALL spell cooldowns |

### Debug Commands
| Command | Description |
|---------|-------------|
| `/it debug` | Toggle debug mode |
| `/it debugall` | Toggle verbose event logging |
| `/it dtps` | DTPS module commands |

## Configuration Options

### Options Menu (`/it options`)
- **Theme Selection** - Choose between Default WoW, Dark, or ElvUI styles
- **Scale** - Adjust tracker size (50% - 200%)
- **Lock/Unlock** - Toggle tracker position lock
- **Show in Raid Only** - Hide tracker when not in a raid
- **DTPS Display** - Enable/disable damage taken tracking

### Sync System
- **Raid Leader/Assist** can set tank order for the entire raid
- **Auto-sync** broadcasts changes automatically when enabled
- **Manual sync** available via `/it sync` or the Sync button
- **Cooldown sync** automatically shares your taunt usage with raid

## Themes

| Theme | Description |
|-------|-------------|
| `default` | Classic WoW tooltip style |
| `dark` | Minimal dark theme |
| `elvui` | Flat design matching ElvUI |

## Adding Custom Spells

Edit `IchaTaunt_Spells.lua` to add new Turtle WoW taunts:

```lua
[SPELL_ID] = {
    name = "Spell Name",
    cooldown = 10,  -- seconds
    icon = "Interface\\Icons\\IconName",
    classes = { "WARRIOR", "PALADIN" },
    description = "What the spell does"
},
```

## Troubleshooting

### Tracker won't show
- Use `/it show` to force display
- Check if "Show in Raid Only" is enabled when in a party
- Make sure you've added taunters via `/it config`

### Cooldowns not detecting
- Enable debug mode: `/it debug`
- Use a taunt and check for detection messages
- Verify the taunter is in your tracked list

### Sync not working
- Ensure all raid members have IchaTaunt installed
- Check that raid leader/assist has set the tank order
- Try `/it sync` to force a sync request

### UI is off-screen
- Use `/it reset` to center the tracker

### Long cooldowns showing wrong
- Cooldowns over 60 seconds show as `M:SS` format (e.g., `9:45`)
- Under 60 seconds shows just seconds (e.g., `45`)

## Technical Details

### How Detection Works
- Monitors combat log events (`CHAT_MSG_SPELL_*`)
- Parses spell casts and "afflicted by" messages
- Tracks individual cooldowns per player per spell
- Broadcasts cooldowns via addon messages

### Sync Protocol
- Uses `ICHAT` addon message prefix
- Messages: `ORDER:`, `TAUNTERS:`, `CD:`, `DTPS:`, `REQ`
- Requires raid/party channel

### Saved Variables
Settings saved in `WTF/Account/.../SavedVariables/IchaTaunt.lua`:
- Taunter list and order
- Tracker position and scale
- Theme selection
- DTPS configuration

## Version History

### v1.5.1
- Fixed cooldown sync broadcasting
- Smart time display (minutes:seconds for long CDs)
- Added test commands for all spells
- Renamed addon to "IchaTaunt"

### v1.5.0
- Added cooldown sync - broadcasts taunt usage to raid
- Added DTPS (Damage Taken Per Second) module
- Added theme system (default, dark, elvui)
- Added UI scaling (50% - 200%)
- Added auto-sync toggle
- Added Convert to Raid button

### v1.4.x
- PallyPower-style sync system
- Drag-and-drop tank reordering
- Lock/unlock tracker position
- Challenging Roar/Shout detection via "afflicted by"

### v1.0
- Initial release
- Basic taunt tracking
- Cooldown timers
- Resist detection

## Credits

**Dreamers**: Ichabaddie and Cinos (Oathsworn)
**Vibe-coded with**: Claude
**For**: Turtle WoW (1.12 client)
**License**: Free to use and modify

---

*Happy tanking! May your taunts never be resisted.*
