# IchaTaunt - Taunt Tracker for Turtle WoW

A comprehensive taunt tracking addon for Turtle WoW (1.12 client) that monitors taunt cooldowns across your raid or party, helping coordinate threat management.

## Features

### 📊 Real-Time Taunt Tracking
- **Visual cooldown bars** with countdown timers for all tracked taunters
- **Per-player tracking** - see exactly when each tank's taunt is ready
- **Resist detection** - automatic visual indicator when a taunt is resisted
- **Class-colored names** - easily identify taunters at a glance

### 🎯 Supported Taunt Abilities

#### Warrior
- **Taunt** - 10 second cooldown
- **Mocking Blow** - 2 minute cooldown
- **Challenging Shout** - 10 minute cooldown

#### Druid
- **Growl** - 10 second cooldown
- **Challenging Roar** - 10 second cooldown

#### Shaman (Turtle WoW Custom)
- **Earthshaker Slam** - 10 second cooldown

#### Paladin (Turtle WoW Custom)
- **Hand of Reckoning** - 10 second cooldown

### 🖱️ Easy Configuration
- **Drag-and-drop interface** - select taunters from your raid/party
- **Custom taunt order** - arrange tanks in priority order
- **Scrollable panels** - handles 40-player raids without UI overflow
- **Persistent settings** - your configuration saves between sessions

### 🎨 User Interface
- **Movable tracker bar** - position it anywhere on your screen
- **Lock/unlock mode** - prevent accidental moving during combat
- **Auto-show in raids** - optional automatic display when in raid groups
- **Clean, minimal design** - doesn't clutter your screen

## Installation

1. Download the addon
2. Extract to `World of Warcraft\Interface\AddOns\`
3. Ensure the folder is named `IchaTaunt`
4. Restart WoW or reload UI (`/reload`)

## Quick Start

### Basic Setup

1. **Join a raid or party** with tanks
2. **Open configuration**: Type `/it` or `/it config`
3. **Select taunters**: 
   - Left panel shows all raid/party members who can taunt
   - Click the **+** button next to each tank you want to track
4. **Arrange order** (optional):
   - Right panel shows your taunt order
   - Use **-** button to remove taunters
5. **Close** the configuration window

### Using the Tracker

The tracker bar will automatically appear when:
- You're in a raid (if "Show in Raid Only" is enabled)
- You have configured taunters who are in your group

Each taunter gets a bar showing:
- **Player name** (class-colored)
- **Cooldown timer** (when taunt is on cooldown)
- **READY** indicator (when taunt is available)
- **RESISTED** warning (bright yellow, when taunt is resisted)

## Slash Commands

### Main Commands
- `/it` - Open configuration window
- `/it config` - Open taunter selection panel
- `/it help` - Display all available commands

### Tracker Control
- `/it bar show` - Show the tracker bar
- `/it bar hide` - Hide the tracker bar
- `/it bar toggle` - Toggle tracker visibility
- `/it reset` or `/it center` - Reset tracker position to screen center

### Debug & Testing
- `/it debug` - Toggle debug mode (shows taunt detection messages)
- `/it debugall` - Toggle super debug mode (shows ALL combat events - very verbose)
- `/it test` - Test cooldown on first spell for your class (broadcasts in group)
- `/it testresist` - Test resist indicator on yourself
- `/it testtaunt` - Test Taunt (Warrior, 10s)
- `/it testgrowl` - Test Growl (Druid, 10s)
- `/it testroar` - Test Challenging Roar (Druid, 10 min)
- `/it testshout` - Test Challenging Shout (Warrior, 10 min)
- `/it testmocking` - Test Mocking Blow (Warrior, 2 min)
- `/it testearthshaker` or `/it testslam` - Test Earthshaker Slam (Shaman, 10s)
- `/it testhand` or `/it testreckoning` - Test Hand of Reckoning (Paladin, 10s)
- `/it testall` - Test ALL spell cooldowns (broadcasts each when in group)

## Configuration Options

Access the config panel with `/it` to adjust:

### Show in Raid Only
When enabled, the tracker only appears in raid groups. Disable to show in party/solo.

### Taunter Selection
- **Left Panel (Raid/Party)**: Shows all available taunters
  - Only displays classes with taunt abilities
  - Scroll with mouse wheel if you have 40 players
  - Click **+** to add to tracking
  
- **Right Panel (Taunt Order)**: Your active taunters
  - Shows in the order they'll appear on the tracker
  - Click **-** to remove from tracking
  - Scroll with mouse wheel for many taunters

## Customization

### Moving the Tracker
1. The tracker is unlocked by default
2. Click and drag the title bar to move it
3. Position saves automatically
4. Use `/it reset` if you lose it off-screen

### Adding Custom Taunt Spells

Edit `IchaTaunt_Spells.lua` to add new Turtle WoW custom taunts:

```lua
[SPELL_ID] = {
    name = "Spell Name",
    cooldown = 10,  -- in seconds
    icon = "Interface\\Icons\\IconName",
    classes = { "WARRIOR", "PALADIN" },  -- can be multiple
    description = "What the spell does"
},
```

**Finding Spell IDs**: Use `/dump GetSpellInfo("Spell Name")` in-game

## Technical Details

### How It Works
- Monitors combat log events (`CHAT_MSG_SPELL_*` events)
- Parses spell names and caster information
- Matches against known taunt spells in configuration
- Tracks individual cooldowns per player per spell
- Updates UI in real-time with countdown timers

### Performance
- Lightweight - minimal CPU usage
- Only processes combat messages for tracked players
- Efficient cooldown calculations
- No continuous polling or timers

### Data Storage
Settings are saved in `SavedVariables\IchaTauntDB.lua`:
- Taunter list and order
- Tracker position
- Display preferences
- Debug settings

## Troubleshooting

### Tracker won't show
- Check `/it bar show`
- Verify you're in a raid (if "Show in Raid Only" is enabled)
- Ensure you've added taunters via `/it config`
- Make sure taunters are currently in your group

### Cooldowns not detecting
- Enable debug mode: `/it debug`
- Cast a taunt and check for detection messages
- Verify the spell name matches exactly in `IchaTaunt_Spells.lua`
- Check if player is in your tracked taunters list

### UI is off-screen
- Use `/it reset` to center the tracker
- Use `/it bar show` to ensure it's visible

### Scrolling doesn't work in config
- Make sure your mouse is inside the panel
- Use mouse wheel to scroll up/down
- Works in both left (raid/party) and right (taunt order) panels

### Resist not showing
- Resist detection works by parsing combat log text
- Look for "was resisted" or "resists" in the combat message
- Enable `/it debug` to see raw combat messages

## FAQ

**Q: Does this work on retail WoW?**  
A: No, this is specifically designed for Turtle WoW (1.12 client) with custom spells.

**Q: Can I track hunters/rogues/etc?**  
A: Only classes with actual taunt abilities are shown (Warriors, Druids, Paladins, Shamans).

**Q: Will this work in dungeons?**  
A: Yes! Works in any group size - solo, party (5), or raid (40).

**Q: Does it sync between raid members?**  
A: Currently no - each player tracks independently. Future feature planned.

**Q: Can I customize the bar colors?**  
A: Not yet, but this is planned for a future update.

**Q: How do I report bugs?**  
A: Enable debug mode (`/it debug`), reproduce the issue, and share the output.

## Version History

### v1.1.1 (Current)
- ✅ Fixed panel spacing alignment in configuration UI
- ✅ Left and right panels now have consistent content positioning

### v1.1
- ✅ Removed debug chatter (now optional via `/it debug`)
- ✅ Added scrolling to raid/party panels (supports 40-player raids)
- ✅ Fixed spell cooldowns (Challenging Shout: 10min, Mocking Blow: 2min)
- ✅ Improved UI stability and error handling

### v1.0
- Initial release
- Basic taunt tracking
- Cooldown timers
- Resist detection
- Drag-and-drop configuration

## Credits

**Author**: Vibe-coded with Claude  
**Dreamers**: Ichabaddie and Cinos (Oathsworn)  
**Version**: 1.1.1  
**For**: Turtle WoW (1.12 client)  
**License**: Free to use and modify

## Support

For issues, suggestions, or contributions:
- Use debug mode to diagnose issues
- Check the FAQ above
- Customize `IchaTaunt_Spells.lua` for new spells
- Edit the code - it's yours to modify!

---

*Happy tanking! May your taunts never be resisted.* 🛡️
