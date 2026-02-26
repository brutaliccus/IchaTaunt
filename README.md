# IchaTaunt - Raid Cooldown Tracker for Turtle WoW

A raid cooldown tracker for Turtle WoW (1.12 client) that monitors taunt, defensive, and interrupt cooldowns across your raid with category organization and real-time sync.

![Version](https://img.shields.io/badge/version-2.1.0-blue)
![Client](https://img.shields.io/badge/client-Turtle%20WoW%201.12-green)

## Features

### Category-Based Tracking (v2.0)
- **Four role categories** - Tanks, Healers, Interrupters, and Other
- **Deterministic stacking** - category frames stack vertically as a single unit
- **Drag to reposition** - grab any frame to move the entire stack
- **Auto grow/shrink** - adding a player expands the frame and pushes categories below it down; removing pulls them back up
- **Empty frame positioning** - unlock the tracker to see and position all 4 categories before adding players

### Real-Time Cooldown Tracking
- **Visual cooldown bars** with countdown timers for all tracked players
- **Per-player tracking** - see exactly when each player's abilities are ready
- **Smart time display** - shows `5:30` for long cooldowns, switches to seconds under 1 minute
- **Resist detection** - automatic "RESIST!" indicator when a taunt fails
- **Class-colored names** - easily identify players at a glance

### Cooldown Sync
- **Automatic broadcasting** - when you use an ability, all raid members with IchaTaunt see your cooldown
- **Cross-player visibility** - see cooldowns from anyone in your raid who has the addon
- **PallyPower-style sync** - raid leader/officers can set player assignments, synced to all members
- **Cooldown persistence** - cooldowns survive UI reloads via epoch-time tracking

### DTPS Module (Damage Taken Per Second)
- **Live damage tracking** - shows real-time DTPS for each tracked player
- **Rolling window calculation** - 3-second window for accurate live feed
- **Broadcast to raid** - other players can see your DTPS
- **Warning thresholds** - color-coded warnings for high damage intake
- **Toggle on/off** - disable if you don't need this info

### All-Categories Player List (v2.1)
- **See all assignments at once** - the right panel in `/it` shows all 4 categories with their members
- **Per-category reordering** - up/down arrows swap players within the same category
- **Direct removal** - remove button targets the correct category without switching tabs
- **Colored headers** - each category section is color-coded for quick identification

### Spell Picker
- **Visual spell picker** - dual-list UI to easily add spells to track
- **Pre-built spell database** - curated list of trackable spells for all classes
- **Category organization** - spells grouped by Taunt, Defensive, Interrupt, Mobility, CC, Offensive, Utility
- **Cooldown override** - adjust cooldowns for talents that reduce them
- **Cross-class support** - add spells from any class to your tracker

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

*Shaman and Paladin taunts are Turtle WoW custom abilities. Many more spells (defensives, interrupts, etc.) are available via the spell picker.*

### User Interface
- **Category toggle buttons** - select which category new players are added to
- **Two-panel configuration** - left panel shows available raid members, right panel shows all tracked players by category
- **Click to add/remove** - use `+` and `-` buttons to manage your player list
- **Arrow reordering** - use up/down arrows to change player priority within each category
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
  IchaTaunt_SpellDB.lua
  IchaTaunt_TrackableSpells.lua
  IchaTaunt_Themes.lua
  IchaTaunt_Categories.lua
  IchaTaunt_DPS.lua
```

## Quick Start

1. **Join a raid or party**
2. **Open configuration**: Type `/it`
3. **Select a category**: Click Tanks, Healers, Interrupters, or Other
4. **Add players**: Click the `+` button next to each player you want to track (left panel)
5. **Review assignments**: The right panel shows all 4 categories and their members
6. **Close** the window - tracker frames appear automatically
7. **Position**: Use `/it unlock` to drag the stack, `/it lock` when done

## Slash Commands

### Basic Commands
| Command | Description |
|---------|-------------|
| `/it` | Open main config window |
| `/it config` | Open player selection |
| `/it options` | Open theme & scale options |
| `/it help` | Show all commands |

### Tracker Control
| Command | Description |
|---------|-------------|
| `/it show` | Show tracker frames |
| `/it hide` | Hide tracker frames |
| `/it toggle` | Toggle tracker visibility |
| `/it reset` | Reset stack to screen center |
| `/it lock` | Lock tracker (click-through) |
| `/it unlock` | Unlock tracker (draggable, shows empty frames) |

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
| `/it debug` | Toggle debug mode (off by default, resets each login) |
| `/it debugall` | Toggle verbose event logging |

## Configuration Options

### Options Menu (`/it options`)
- **Theme Selection** - Choose between Default WoW, Dark, or ElvUI styles
- **Scale** - Adjust tracker size (50% - 200%)
- **Lock/Unlock** - Toggle tracker position lock
- **Show in Raid Only** - Hide tracker when not in a raid
- **DTPS Display** - Enable/disable damage taken tracking
- **Cooldown Only Mode** - Hide icons until spell is on cooldown
- **Custom Spells** - Add your own spells to track via the spell picker

### Sync System
- **Raid Leader/Assist** can set player assignments for the entire raid
- Changes broadcast automatically when in a group as leader/officer
- Manual sync available via `/it sync`
- Cooldown usage automatically shared with raid members

## Themes

| Theme | Description |
|-------|-------------|
| `default` | Classic WoW tooltip style |
| `dark` | Minimal dark theme |
| `elvui` | Flat design matching ElvUI |

## Adding Custom Spells

### Via Spell Picker (Recommended)
1. Open Options: `/it options`
2. Click "Manage Custom Spells"
3. Select a class tab (Warrior, Druid, Paladin, Shaman)
4. Click on a spell in the left panel to select it
5. Optionally enter a cooldown override (for talents that reduce cooldowns)
6. Click `>>` to add the spell to your tracker
7. Use `<<` or click the X to remove spells

### Cooldown Override
If you have talents that reduce cooldown (e.g., Improved Taunt), enter the reduced cooldown in seconds before adding the spell. Leave blank to use the default cooldown.

### Via File (Advanced)
Edit `IchaTaunt_Spells.lua` to add new spells:

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
- Use `/it unlock` to see empty category frames for positioning
- Check if "Show in Raid Only" is enabled when in a party
- Make sure you've added players via `/it`

### Cooldowns not detecting
- Enable debug mode: `/it debug`
- Use an ability and check for detection messages in chat
- Verify the player is in your tracked list

### Sync not working
- Ensure all raid members have IchaTaunt installed
- Check that raid leader/assist has set the assignments
- Try `/it sync` to force a sync request

### UI is off-screen
- Use `/it reset` to center the tracker stack

### Player shows as tracked but not visible
- Re-add the player via `/it` - the addon will automatically remove and re-add them to fix ghost entries

## Technical Details

### How Detection Works
- Monitors combat log events (`CHAT_MSG_SPELL_*`)
- Parses spell casts and "afflicted by" messages
- Tracks individual cooldowns per player per spell
- Broadcasts cooldowns via addon messages
- Hooks `CastSpellByName` for local player instant detection

### Sync Protocol
- Uses `ICHAT` addon message prefix
- Messages: `ORDER:`, `TAUNTERS:`, `CD:`, `DTPS:`, `REQ`, `CLEARALL`, `ADD:`, `REMOVE:`
- Requires raid/party channel

### Saved Variables
Settings saved in `WTF/Account/.../SavedVariables/IchaTaunt.lua`:
- Player list and category assignments
- Stack position and scale
- Theme selection
- DTPS configuration
- Custom spells
- Display options

## Version History

### v2.1.0
- **All-categories right panel** - see all 4 categories and their members at once in `/it` config
- **Per-category reordering** - up/down arrows only swap within the same category
- **Silenced debug/combat log spam** - debug output disabled by default, resets each login
- **Category reassignment fix** - re-adding a tracked player instantly updates the tracker

### v2.0.0
- **Category system** - organize tracked players into Tanks, Healers, Interrupters, and Other
- **Deterministic stack positioning** - all category frames stack as a single vertical unit
- **Drag entire stack** - dragging any frame repositions the whole stack
- **Auto grow/shrink** - frames expand when players are added and contract when removed
- **Empty frame visibility** - all 4 category frames visible when unlocked for positioning
- **Ghost tracking fix** - re-adding an already-tracked player forces a clean remove and re-add

### v1.7.x
- Spell Picker UI with trackable spells database
- Cooldown Only Mode
- Custom Spells Editor
- GCD broadcast fix
- Barkskin (Feral) added to spell picker

### v1.5.x - v1.6.x
- Cooldown sync broadcasting
- DTPS module
- Theme system (default, dark, elvui)
- UI scaling
- Options menu theming
- Smart time display

### v1.4.x
- PallyPower-style sync system
- Button-based reordering
- Lock/unlock tracker
- Challenging Roar/Shout detection

### v1.0
- Initial release with basic taunt tracking

## Credits

**Dreamers**: Ichabaddie and Cinos (Oathsworn)
**Vibe-coded with**: Claude
**For**: Turtle WoW (1.12 client)
**License**: Free to use and modify

---

*Happy tanking! May your taunts never be resisted.*
