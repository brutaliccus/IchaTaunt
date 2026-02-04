-- IchaTaunt Trackable Spells
-- Curated list of spells with cooldowns that are worth tracking
-- Cooldowns sourced from database.turtlecraft.gg
-- Each spell has: name, icon, cooldown (in seconds), class, category

IchaTaunt_TrackableSpells = {
    -- ============================================================================
    -- WARRIOR (from database.turtlecraft.gg/?spells=7.1)
    -- ============================================================================
    WARRIOR = {
        -- Taunts
        { id = 355, name = "Taunt", icon = "Interface\\Icons\\Spell_Nature_Reincarnation", cooldown = 10, category = "Taunt" },
        { id = 694, name = "Mocking Blow", icon = "Interface\\Icons\\Ability_Warrior_PunishingBlow", cooldown = 120, category = "Taunt" },
        { id = 1161, name = "Challenging Shout", icon = "Interface\\Icons\\Ability_BullRush", cooldown = 600, category = "Taunt" },

        -- Defensive Cooldowns
        { id = 871, name = "Shield Wall", icon = "Interface\\Icons\\Ability_Warrior_ShieldWall", cooldown = 1800, category = "Defensive" },
        { id = 2565, name = "Shield Block", icon = "Interface\\Icons\\Ability_Defend", cooldown = 5, category = "Defensive" },
        { id = 20230, name = "Retaliation", icon = "Interface\\Icons\\Ability_Warrior_Challange", cooldown = 1800, category = "Defensive" },

        -- Interrupts
        { id = 6552, name = "Pummel", icon = "Interface\\Icons\\INV_Gauntlets_04", cooldown = 10, category = "Interrupt" },
        { id = 72, name = "Shield Bash", icon = "Interface\\Icons\\Ability_Warrior_ShieldBash", cooldown = 12, category = "Interrupt" },

        -- Mobility
        { id = 100, name = "Charge", icon = "Interface\\Icons\\Ability_Warrior_Charge", cooldown = 15, category = "Mobility" },
        { id = 20252, name = "Intercept", icon = "Interface\\Icons\\Ability_Rogue_Sprint", cooldown = 30, category = "Mobility" },
        { id = 45595, name = "Intervene", icon = "Interface\\Icons\\Ability_Warrior_VictoryRush", cooldown = 30, category = "Mobility" },

        -- Crowd Control
        { id = 676, name = "Disarm", icon = "Interface\\Icons\\Ability_Warrior_Disarm", cooldown = 60, category = "CC" },
        { id = 5246, name = "Intimidating Shout", icon = "Interface\\Icons\\Ability_GolemThunderClap", cooldown = 180, category = "CC" },

        -- Offensive
        { id = 1719, name = "Recklessness", icon = "Interface\\Icons\\Ability_CriticalStrike", cooldown = 1800, category = "Offensive" },
        { id = 18499, name = "Berserker Rage", icon = "Interface\\Icons\\Spell_Nature_AncestralGuardian", cooldown = 30, category = "Offensive" },
        { id = 2687, name = "Bloodrage", icon = "Interface\\Icons\\Ability_Racial_BloodRage", cooldown = 60, category = "Offensive" },
        { id = 1680, name = "Whirlwind", icon = "Interface\\Icons\\Ability_Whirlwind", cooldown = 10, category = "Offensive" },
        { id = 23922, name = "Shield Slam", icon = "Interface\\Icons\\INV_Shield_05", cooldown = 6, category = "Offensive" },
    },

    -- ============================================================================
    -- DRUID (from database.turtlecraft.gg/?spells=7.11)
    -- ============================================================================
    DRUID = {
        -- Taunts
        { id = 6795, name = "Growl", icon = "Interface\\Icons\\Ability_Physical_Taunt", cooldown = 10, category = "Taunt" },
        { id = 5209, name = "Challenging Roar", icon = "Interface\\Icons\\Ability_Druid_ChallangingRoar", cooldown = 600, category = "Taunt" },

        -- Defensive Cooldowns
        { id = 22812, name = "Barkskin", icon = "Interface\\Icons\\Spell_Nature_StoneClawTotem", cooldown = 60, category = "Defensive" },
        { id = 51452, name = "Barkskin (Feral)", icon = "Interface\\Icons\\Spell_Nature_StoneClawTotem", cooldown = 600, category = "Defensive" },
        { id = 22842, name = "Frenzied Regeneration", icon = "Interface\\Icons\\Ability_BullRush", cooldown = 300, category = "Defensive" },
        { id = 5229, name = "Enrage", icon = "Interface\\Icons\\Ability_Druid_Enrage", cooldown = 60, category = "Defensive" },

        -- Interrupts / CC
        { id = 5211, name = "Bash", icon = "Interface\\Icons\\Ability_Druid_Bash", cooldown = 60, category = "Interrupt" },
        { id = 16979, name = "Feral Charge", icon = "Interface\\Icons\\Ability_Hunter_Pet_Bear", cooldown = 15, category = "Interrupt" },

        -- Mobility
        { id = 1850, name = "Dash", icon = "Interface\\Icons\\Ability_Druid_Dash", cooldown = 300, category = "Mobility" },

        -- Utility
        { id = 29166, name = "Innervate", icon = "Interface\\Icons\\Spell_Nature_Lightning", cooldown = 360, category = "Utility" },
        { id = 20484, name = "Rebirth", icon = "Interface\\Icons\\Spell_Nature_Reincarnation", cooldown = 1800, category = "Utility" },
    },

    -- ============================================================================
    -- PALADIN (from database.turtlecraft.gg/?spells=7.2)
    -- ============================================================================
    PALADIN = {
        -- Taunts (Turtle WoW custom)
        { id = 51302, name = "Hand of Reckoning", icon = "Interface\\Icons\\Spell_Holy_Unyieldingfaith", cooldown = 10, category = "Taunt" },

        -- Defensive Cooldowns
        { id = 498, name = "Divine Protection", icon = "Interface\\Icons\\Spell_Holy_Restoration", cooldown = 300, category = "Defensive" },
        { id = 642, name = "Divine Shield", icon = "Interface\\Icons\\Spell_Holy_DivineIntervention", cooldown = 300, category = "Defensive" },
        { id = 633, name = "Lay on Hands", icon = "Interface\\Icons\\Spell_Holy_LayOnHands", cooldown = 3600, category = "Defensive" },

        -- Hands (Blessings)
        { id = 1022, name = "Hand of Protection", icon = "Interface\\Icons\\Spell_Holy_SealOfProtection", cooldown = 300, category = "Utility" },
        { id = 1044, name = "Hand of Freedom", icon = "Interface\\Icons\\Spell_Holy_SealOfValor", cooldown = 24, category = "Utility" },

        -- Interrupts / CC
        { id = 853, name = "Hammer of Justice", icon = "Interface\\Icons\\Spell_Holy_SealOfMight", cooldown = 60, category = "CC" },
    },

    -- ============================================================================
    -- SHAMAN (from database.turtlecraft.gg/?spells=7.7)
    -- ============================================================================
    SHAMAN = {
        -- Taunts (Turtle WoW custom)
        { id = 51365, name = "Earthshaker Slam", icon = "Interface\\Icons\\Spell_Nature_Earthquake", cooldown = 10, category = "Taunt" },

        -- Shocks (shared 6 sec cooldown)
        { id = 8042, name = "Earth Shock", icon = "Interface\\Icons\\Spell_Nature_EarthShock", cooldown = 6, category = "Interrupt" },

        -- Defensive / Utility Totems
        { id = 8177, name = "Grounding Totem", icon = "Interface\\Icons\\Spell_Nature_GroundingTotem", cooldown = 20, category = "Defensive" },
        { id = 16190, name = "Mana Tide Totem", icon = "Interface\\Icons\\Spell_Frost_SummonWaterElemental", cooldown = 300, category = "Utility" },

        -- Defensive Cooldowns (Turtle WoW custom)
        { id = 45502, name = "Ethereal Form", icon = "Interface\\Icons\\Spell_Nature_AstralRecal", cooldown = 900, category = "Defensive" },

        -- Offensive (Turtle WoW custom)
        { id = 45509, name = "Bloodlust", icon = "Interface\\Icons\\Spell_Nature_Bloodlust", cooldown = 300, category = "Offensive" },
        { id = 45505, name = "Feral Spirit", icon = "Interface\\Icons\\Spell_Shaman_FeralSpirit", cooldown = 240, category = "Offensive" },

        -- Utility
        { id = 20608, name = "Reincarnation", icon = "Interface\\Icons\\Spell_Nature_Reincarnation", cooldown = 3600, category = "Utility" },

        -- CC (Turtle WoW custom)
        { id = 45504, name = "Hex", icon = "Interface\\Icons\\Spell_Shaman_Hex", cooldown = 300, category = "CC" },
    },

    -- ============================================================================
    -- HUNTER (from database.turtlecraft.gg/?spells=7.3)
    -- ============================================================================
    HUNTER = {
        -- Utility
        { id = 5384, name = "Feign Death", icon = "Interface\\Icons\\Ability_Rogue_FeignDeath", cooldown = 30, category = "Utility" },
        { id = 19801, name = "Tranquilizing Shot", icon = "Interface\\Icons\\Spell_Nature_Drowsy", cooldown = 20, category = "Utility" },

        -- Offensive
        { id = 3045, name = "Rapid Fire", icon = "Interface\\Icons\\Ability_Hunter_RunningShot", cooldown = 300, category = "Offensive" },
        { id = 19574, name = "Bestial Wrath", icon = "Interface\\Icons\\Ability_Druid_FerociousBite", cooldown = 120, category = "Offensive" },

        -- Defensive
        { id = 19263, name = "Deterrence", icon = "Interface\\Icons\\Ability_Whirlwind", cooldown = 300, category = "Defensive" },

        -- Traps (shared 30s cooldown in vanilla)
        { id = 1499, name = "Freezing Trap", icon = "Interface\\Icons\\Spell_Frost_ChainsOfIce", cooldown = 30, category = "CC" },
        { id = 13809, name = "Frost Trap", icon = "Interface\\Icons\\Spell_Frost_FreezingBreath", cooldown = 30, category = "CC" },
        { id = 13795, name = "Immolation Trap", icon = "Interface\\Icons\\Spell_Fire_FlameShock", cooldown = 30, category = "Offensive" },
        { id = 13813, name = "Explosive Trap", icon = "Interface\\Icons\\Spell_Fire_SelfDestruct", cooldown = 30, category = "Offensive" },

        -- Pet
        { id = 19577, name = "Intimidation", icon = "Interface\\Icons\\Ability_Devour", cooldown = 60, category = "CC" },
    },

    -- ============================================================================
    -- ROGUE (from database.turtlecraft.gg/?spells=7.4)
    -- ============================================================================
    ROGUE = {
        -- Interrupts
        { id = 1766, name = "Kick", icon = "Interface\\Icons\\Ability_Kick", cooldown = 10, category = "Interrupt" },

        -- Defensive
        { id = 1856, name = "Vanish", icon = "Interface\\Icons\\Ability_Vanish", cooldown = 300, category = "Defensive" },
        { id = 5277, name = "Evasion", icon = "Interface\\Icons\\Spell_Shadow_ShadowWard", cooldown = 300, category = "Defensive" },

        -- Mobility
        { id = 2983, name = "Sprint", icon = "Interface\\Icons\\Ability_Rogue_Sprint", cooldown = 300, category = "Mobility" },

        -- Crowd Control
        { id = 2094, name = "Blind", icon = "Interface\\Icons\\Spell_Shadow_MindSteal", cooldown = 300, category = "CC" },
        { id = 408, name = "Kidney Shot", icon = "Interface\\Icons\\Ability_Rogue_KidneyShot", cooldown = 20, category = "CC" },
        { id = 1776, name = "Gouge", icon = "Interface\\Icons\\Ability_Gouge", cooldown = 10, category = "CC" },

        -- Offensive
        { id = 13750, name = "Adrenaline Rush", icon = "Interface\\Icons\\Spell_Shadow_ShadowWordDominate", cooldown = 300, category = "Offensive" },
        { id = 13877, name = "Blade Flurry", icon = "Interface\\Icons\\Ability_Warrior_PunishingBlow", cooldown = 120, category = "Offensive" },
        { id = 14177, name = "Cold Blood", icon = "Interface\\Icons\\Spell_Ice_Lament", cooldown = 180, category = "Offensive" },
        { id = 14185, name = "Preparation", icon = "Interface\\Icons\\Spell_Shadow_AntiShadow", cooldown = 600, category = "Utility" },
    },

    -- ============================================================================
    -- PRIEST (from database.turtlecraft.gg/?spells=7.5)
    -- ============================================================================
    PRIEST = {
        -- Defensive / Utility
        { id = 6346, name = "Fear Ward", icon = "Interface\\Icons\\Spell_Holy_Excorcism", cooldown = 30, category = "Utility" },
        { id = 13908, name = "Desperate Prayer", icon = "Interface\\Icons\\Spell_Holy_Restoration", cooldown = 600, category = "Defensive" },
        { id = 15487, name = "Silence", icon = "Interface\\Icons\\Spell_Shadow_ImpPhaseShift", cooldown = 45, category = "Interrupt" },

        -- Offensive / Utility
        { id = 10060, name = "Power Infusion", icon = "Interface\\Icons\\Spell_Holy_PowerInfusion", cooldown = 180, category = "Utility" },
        { id = 14751, name = "Inner Focus", icon = "Interface\\Icons\\Spell_Frost_WindWalkOn", cooldown = 180, category = "Utility" },

        -- Crowd Control
        { id = 10890, name = "Psychic Scream", icon = "Interface\\Icons\\Spell_Shadow_PsychicScream", cooldown = 30, category = "CC" },

        -- Shadow
        { id = 15286, name = "Vampiric Embrace", icon = "Interface\\Icons\\Spell_Shadow_UnsummonBuilding", cooldown = 10, category = "Offensive" },
        { id = 15407, name = "Mind Flay", icon = "Interface\\Icons\\Spell_Shadow_SiphonMana", cooldown = 0, category = "Offensive" },
    },

    -- ============================================================================
    -- MAGE (from database.turtlecraft.gg/?spells=7.8)
    -- ============================================================================
    MAGE = {
        -- Defensive
        { id = 11958, name = "Ice Block", icon = "Interface\\Icons\\Spell_Frost_Frost", cooldown = 300, category = "Defensive" },
        { id = 11426, name = "Ice Barrier", icon = "Interface\\Icons\\Spell_Ice_Lament", cooldown = 30, category = "Defensive" },
        { id = 543, name = "Fire Ward", icon = "Interface\\Icons\\Spell_Fire_FireArmor", cooldown = 30, category = "Defensive" },
        { id = 6143, name = "Frost Ward", icon = "Interface\\Icons\\Spell_Frost_FrostWard", cooldown = 30, category = "Defensive" },

        -- Interrupts
        { id = 2139, name = "Counterspell", icon = "Interface\\Icons\\Spell_Frost_IceShock", cooldown = 30, category = "Interrupt" },

        -- Mobility
        { id = 1953, name = "Blink", icon = "Interface\\Icons\\Spell_Arcane_Blink", cooldown = 15, category = "Mobility" },

        -- Utility
        { id = 12472, name = "Cold Snap", icon = "Interface\\Icons\\Spell_Frost_WizardMark", cooldown = 600, category = "Utility" },
        { id = 12051, name = "Evocation", icon = "Interface\\Icons\\Spell_Nature_Purge", cooldown = 480, category = "Utility" },

        -- Offensive
        { id = 11129, name = "Combustion", icon = "Interface\\Icons\\Spell_Fire_SealOfFire", cooldown = 180, category = "Offensive" },
        { id = 12042, name = "Arcane Power", icon = "Interface\\Icons\\Spell_Nature_Lightning", cooldown = 180, category = "Offensive" },
        { id = 11113, name = "Blast Wave", icon = "Interface\\Icons\\Spell_Holy_Excorcism_02", cooldown = 45, category = "Offensive" },
        { id = 11185, name = "Cone of Cold", icon = "Interface\\Icons\\Spell_Frost_Glacier", cooldown = 10, category = "Offensive" },

        -- Crowd Control
        { id = 12355, name = "Impact", icon = "Interface\\Icons\\Spell_Fire_MeteorStorm", cooldown = 0, category = "CC" },
    },

    -- ============================================================================
    -- WARLOCK (from database.turtlecraft.gg/?spells=7.9)
    -- ============================================================================
    WARLOCK = {
        -- Defensive
        { id = 6789, name = "Death Coil", icon = "Interface\\Icons\\Spell_Shadow_DeathCoil", cooldown = 120, category = "Defensive" },
        { id = 18288, name = "Amplify Curse", icon = "Interface\\Icons\\Spell_Shadow_Contagion", cooldown = 180, category = "Utility" },

        -- Crowd Control
        { id = 5484, name = "Howl of Terror", icon = "Interface\\Icons\\Spell_Shadow_DeathScream", cooldown = 40, category = "CC" },
        { id = 17928, name = "Howl of Terror (Improved)", icon = "Interface\\Icons\\Spell_Shadow_DeathScream", cooldown = 40, category = "CC" },
        { id = 6358, name = "Seduction (Succubus)", icon = "Interface\\Icons\\Spell_Shadow_MindSteal", cooldown = 30, category = "CC" },
        { id = 19647, name = "Spell Lock (Felhunter)", icon = "Interface\\Icons\\Spell_Shadow_MindRot", cooldown = 24, category = "Interrupt" },

        -- Offensive
        { id = 17877, name = "Shadowburn", icon = "Interface\\Icons\\Spell_Shadow_ScourgeBuild", cooldown = 15, category = "Offensive" },
        { id = 17962, name = "Conflagrate", icon = "Interface\\Icons\\Spell_Fire_Fireball", cooldown = 10, category = "Offensive" },
        { id = 18708, name = "Fel Domination", icon = "Interface\\Icons\\Spell_Nature_RemoveCurse", cooldown = 900, category = "Utility" },
        { id = 18540, name = "Ritual of Doom", icon = "Interface\\Icons\\Spell_Shadow_AntiMagicShell", cooldown = 3600, category = "Utility" },

        -- Pet
        { id = 19505, name = "Devour Magic (Felhunter)", icon = "Interface\\Icons\\Spell_Nature_Purge", cooldown = 8, category = "Utility" },
        { id = 17767, name = "Consume Shadows (Voidwalker)", icon = "Interface\\Icons\\Spell_Shadow_AntiShadow", cooldown = 10, category = "Utility" },
        { id = 19478, name = "Sacrifice (Voidwalker)", icon = "Interface\\Icons\\Spell_Shadow_SacrificialShield", cooldown = 300, category = "Defensive" },
    },
}

-- Helper function to get all trackable spells for a class
function IchaTaunt_GetTrackableSpells(class)
    return IchaTaunt_TrackableSpells[class] or {}
end

-- Helper function to get spell info from trackable list
function IchaTaunt_GetTrackableSpell(class, spellID)
    local spells = IchaTaunt_TrackableSpells[class]
    if spells then
        for _, spell in ipairs(spells) do
            if spell.id == spellID then
                return spell
            end
        end
    end
    return nil
end

-- Format cooldown for display
function IchaTaunt_FormatCooldown(seconds)
    if seconds >= 3600 then
        return format("%dh", seconds / 3600)
    elseif seconds >= 60 then
        return format("%dm", seconds / 60)
    else
        return format("%ds", seconds)
    end
end
