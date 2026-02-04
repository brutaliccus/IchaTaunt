
-- IchaTaunt Spell Configuration
-- This file contains all taunt spells and their properties
-- Edit this file to add new taunts discovered on Turtle WoW

IchaTaunt_SpellData = {
    -- Warrior Taunts
    [355] = {
        name = "Taunt",
        cooldown = 10,
        icon = "Interface\\Icons\\Spell_Nature_Reincarnation",
        classes = { "WARRIOR" },
        description = "Forces target to attack you"
    },
    [694] = {
        name = "Mocking Blow", 
        cooldown = 120,
        icon = "Interface\\Icons\\Ability_Warrior_PunishingBlow",
        classes = { "WARRIOR" },
        description = "Taunts target and deals damage"
    },
    [1161] = {
        name = "Challenging Shout",
        cooldown = 600, 
        icon = "Interface\\Icons\\ability_bullrush",
        classes = { "WARRIOR" },
        description = "Forces all enemies to attack you"
    },
    
    -- Druid Taunts
    [6795] = {
        name = "Growl",
        cooldown = 10,
        icon = "Interface\\Icons\\Ability_Physical_Taunt", 
        classes = { "DRUID" },
        description = "Forces target to attack you (Bear Form)"
    },
    [5209] = {
        name = "Challenging Roar",
        cooldown = 600,
        icon = "Interface\\Icons\\Ability_Druid_ChallangingRoar",
        classes = { "DRUID" },
        description = "Forces all enemies to attack you (Bear Form)"
    },
    
    -- Shaman Taunts (Turtle WoW)
    [51365] = {
        name = "Earthshaker Slam",
        cooldown = 10,
        icon = "Interface\\Icons\\earthshaker_slam_11",
        classes = { "SHAMAN" },
        description = "Slam target with earthen fury, taunting it to attack you"
    },
    
    -- Paladin Taunts (Turtle WoW)
    [51302] = {
        name = "Hand of Reckoning",
        cooldown = 10,
        icon = "Interface\\Icons\\Spell_Holy_Redemption",
        classes = { "PALADIN" },
        description = "Taunts the target to attack you, but has no effect if the target is already attacking you"
    },
    
    -- Turtle WoW Custom Taunts (add here as discovered)
    -- Example:
    -- [12345] = {
    --     name = "Custom Taunt",
    --     cooldown = 8,
    --     icon = "Interface\\Icons\\SomeIcon",
    --     classes = { "PALADIN", "SHAMAN" },
    --     description = "Custom taunt description"
    -- },
}

-- Helper functions

-- Get all spells (built-in + custom)
function IchaTaunt_GetAllSpells()
    local allSpells = {}

    -- Add built-in spells
    for id, data in pairs(IchaTaunt_SpellData) do
        allSpells[id] = data
    end

    -- Add custom spells from SavedVariables
    if IchaTauntDB and IchaTauntDB.customSpells then
        for id, data in pairs(IchaTauntDB.customSpells) do
            allSpells[id] = data
        end
    end

    return allSpells
end

function IchaTaunt_GetSpellData(spellID)
    -- Check built-in spells first
    if IchaTaunt_SpellData[spellID] then
        return IchaTaunt_SpellData[spellID]
    end

    -- Check custom spells
    if IchaTauntDB and IchaTauntDB.customSpells and IchaTauntDB.customSpells[spellID] then
        return IchaTauntDB.customSpells[spellID]
    end

    -- Check TrackableSpells (v2.0 - all class cooldowns)
    if IchaTaunt_TrackableSpells then
        for class, spells in pairs(IchaTaunt_TrackableSpells) do
            for _, spell in ipairs(spells) do
                if spell.id == spellID then
                    return {
                        name = spell.name,
                        cooldown = spell.cooldown,
                        icon = spell.icon,
                        classes = { class },
                        description = spell.category or "Tracked spell"
                    }
                end
            end
        end
    end

    return nil
end

function IchaTaunt_GetSpellsByClass(class)
    local spells = {}
    local allSpells = IchaTaunt_GetAllSpells()

    -- Add spells from main spell database
    for id, data in pairs(allSpells) do
        for _, spellClass in ipairs(data.classes) do
            if spellClass == class then
                spells[id] = data
                break
            end
        end
    end

    -- Add spells from TrackableSpells (v2.0 - all class cooldowns)
    if IchaTaunt_TrackableSpells and IchaTaunt_TrackableSpells[class] then
        for _, spell in ipairs(IchaTaunt_TrackableSpells[class]) do
            if not spells[spell.id] then  -- Don't override existing entries
                spells[spell.id] = {
                    name = spell.name,
                    cooldown = spell.cooldown,
                    icon = spell.icon,
                    classes = { class },
                    description = spell.category or "Tracked spell"
                }
            end
        end
    end

    return spells
end

function IchaTaunt_GetSpellByName(name)
    local allSpells = IchaTaunt_GetAllSpells()

    -- First try exact match in main spell database
    for id, data in pairs(allSpells) do
        if data.name == name then
            return id, data
        end
    end

    -- Try case-insensitive match
    local lowerName = strlower(name)
    for id, data in pairs(allSpells) do
        if strlower(data.name) == lowerName then
            return id, data
        end
    end

    -- Try partial match (for spells with rank info like "Mocking Blow(Rank 4)")
    for id, data in pairs(allSpells) do
        if strfind(name, data.name) or strfind(data.name, name) then
            return id, data
        end
    end

    -- Also search TrackableSpells for combat log fallback (v2.0)
    if IchaTaunt_TrackableSpells then
        for class, spells in pairs(IchaTaunt_TrackableSpells) do
            for _, spell in ipairs(spells) do
                if spell.name == name then
                    -- Convert TrackableSpell format to SpellData format
                    return spell.id, {
                        name = spell.name,
                        cooldown = spell.cooldown,
                        icon = spell.icon,
                        classes = { class },
                        description = spell.category or "Tracked spell"
                    }
                end
            end
        end
        -- Try case-insensitive match in TrackableSpells
        for class, spells in pairs(IchaTaunt_TrackableSpells) do
            for _, spell in ipairs(spells) do
                if strlower(spell.name) == lowerName then
                    return spell.id, {
                        name = spell.name,
                        cooldown = spell.cooldown,
                        icon = spell.icon,
                        classes = { class },
                        description = spell.category or "Tracked spell"
                    }
                end
            end
        end
    end

    return nil
end

function IchaTaunt_GetAllTauntClasses()
    local classes = {}
    local allSpells = IchaTaunt_GetAllSpells()

    for _, data in pairs(allSpells) do
        for _, class in ipairs(data.classes) do
            classes[class] = true
        end
    end
    return classes
end