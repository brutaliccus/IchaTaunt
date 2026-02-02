
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
function IchaTaunt_GetSpellData(spellID)
    return IchaTaunt_SpellData[spellID]
end

function IchaTaunt_GetSpellsByClass(class)
    local spells = {}
    for id, data in pairs(IchaTaunt_SpellData) do
        for _, spellClass in ipairs(data.classes) do
            if spellClass == class then
                spells[id] = data
                break
            end
        end
    end
    return spells
end

function IchaTaunt_GetSpellByName(name)
    -- First try exact match
    for id, data in pairs(IchaTaunt_SpellData) do
        if data.name == name then
            return id, data
        end
    end

    -- Try case-insensitive match
    local lowerName = strlower(name)
    for id, data in pairs(IchaTaunt_SpellData) do
        if strlower(data.name) == lowerName then
            return id, data
        end
    end

    -- Try partial match (for spells with rank info like "Mocking Blow(Rank 4)")
    for id, data in pairs(IchaTaunt_SpellData) do
        if strfind(name, data.name) or strfind(data.name, name) then
            return id, data
        end
    end

    return nil
end

function IchaTaunt_GetAllTauntClasses()
    local classes = {}
    for _, data in pairs(IchaTaunt_SpellData) do
        for _, class in ipairs(data.classes) do
            classes[class] = true
        end
    end
    return classes
end