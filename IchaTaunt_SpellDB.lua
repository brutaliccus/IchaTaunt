-- IchaTaunt Spell Database
-- Comprehensive spell lookup for cross-class icon resolution
-- Data sourced from database.turtlecraft.gg

IchaTaunt_SpellDB = {}

-- Icon mappings for common spell types
local ICONS = {
    -- Shaman
    HEALING_WAVE = "Interface\\Icons\\Spell_Nature_MagicImmunity",
    LIGHTNING_BOLT = "Interface\\Icons\\Spell_Nature_Lightning",
    CHAIN_LIGHTNING = "Interface\\Icons\\Spell_Nature_ChainLightning",
    EARTH_SHOCK = "Interface\\Icons\\Spell_Nature_EarthShock",
    FROST_SHOCK = "Interface\\Icons\\Spell_Frost_FrostShock",
    FLAME_SHOCK = "Interface\\Icons\\Spell_Fire_FlameShock",
    LIGHTNING_SHIELD = "Interface\\Icons\\Spell_Nature_LightningShield",
    ROCKBITER = "Interface\\Icons\\Spell_Nature_RockBiter",
    FLAMETONGUE = "Interface\\Icons\\Spell_Fire_FlameTotem",
    FROSTBRAND = "Interface\\Icons\\Spell_Frost_IceShock",
    WINDFURY = "Interface\\Icons\\Spell_Nature_Cyclone",
    GHOST_WOLF = "Interface\\Icons\\Spell_Nature_SpiritWolf",
    PURGE = "Interface\\Icons\\Spell_Nature_Purge",
    GROUNDING_TOTEM = "Interface\\Icons\\Spell_Nature_GroundingTotem",
    TREMOR_TOTEM = "Interface\\Icons\\Spell_Nature_TremorTotem",
    EARTHBIND_TOTEM = "Interface\\Icons\\Spell_Nature_StrengthOfEarthTotem02",
    STONECLAW_TOTEM = "Interface\\Icons\\Spell_Nature_StoneClawTotem",
    STONESKIN_TOTEM = "Interface\\Icons\\Spell_Nature_StoneSkinTotem",
    STRENGTH_TOTEM = "Interface\\Icons\\Spell_Nature_EarthBindTotem",
    SEARING_TOTEM = "Interface\\Icons\\Spell_Fire_SearingTotem",
    FIRE_NOVA_TOTEM = "Interface\\Icons\\Spell_Fire_SealOfFire",
    MAGMA_TOTEM = "Interface\\Icons\\Spell_Fire_SelfDestruct",
    HEALING_STREAM = "Interface\\Icons\\INV_Spear_04",
    MANA_SPRING = "Interface\\Icons\\Spell_Nature_ManaRegenTotem",
    MANA_TIDE = "Interface\\Icons\\Spell_Frost_SummonWaterElemental",
    WINDFURY_TOTEM = "Interface\\Icons\\Spell_Nature_Windfury",
    GRACE_AIR = "Interface\\Icons\\Spell_Nature_InvisibilityTotem",
    FIRE_RESIST_TOTEM = "Interface\\Icons\\Spell_FireResistanceTotem_01",
    FROST_RESIST_TOTEM = "Interface\\Icons\\Spell_FrostResistanceTotem_01",
    NATURE_RESIST_TOTEM = "Interface\\Icons\\Spell_Nature_NatureResistanceTotem",
    CHAIN_HEAL = "Interface\\Icons\\Spell_Nature_HealingWaveGreater",
    LESSER_HEALING_WAVE = "Interface\\Icons\\Spell_Nature_HealingWaveLesser",
    ANCESTRAL_SPIRIT = "Interface\\Icons\\Spell_Nature_Regenerate",
    WATER_BREATHING = "Interface\\Icons\\Spell_Shadow_DemonBreath",
    WATER_WALKING = "Interface\\Icons\\Spell_Frost_WindWalkOn",
    FAR_SIGHT = "Interface\\Icons\\Spell_Nature_FarSight",
    ASTRAL_RECALL = "Interface\\Icons\\Spell_Nature_AstralRecal",
    REINCARNATION = "Interface\\Icons\\Spell_Nature_Reincarnation",
    CURE_POISON = "Interface\\Icons\\Spell_Nature_NullifyPoison",
    CURE_DISEASE = "Interface\\Icons\\Spell_Nature_RemoveDisease",
    DISEASE_CLEANSING = "Interface\\Icons\\Spell_Nature_DiseaseCleansingTotem",
    POISON_CLEANSING = "Interface\\Icons\\Spell_Nature_PoisonCleansingTotem",
    FLAMETONGUE_TOTEM = "Interface\\Icons\\Spell_Nature_GuardianWard",
    WINDWALL_TOTEM = "Interface\\Icons\\Spell_Nature_EarthBind",
    SENTRY_TOTEM = "Interface\\Icons\\Spell_Nature_RemoveCurse",
    HEX = "Interface\\Icons\\Spell_Shaman_Hex",
    EARTH_SHIELD = "Interface\\Icons\\Spell_Nature_SkinofEarth",
    WATER_SHIELD = "Interface\\Icons\\Ability_Shaman_WaterShield",
    BLOODLUST = "Interface\\Icons\\Spell_Nature_Bloodlust",
    FERAL_SPIRIT = "Interface\\Icons\\Spell_Shaman_FeralSpirit",
    LAVA_LASH = "Interface\\Icons\\Ability_Shaman_LavaLash",
    ETHEREAL_FORM = "Interface\\Icons\\Spell_Nature_AstralRecalGroup",
    TOTEMIC_SLAM = "Interface\\Icons\\Spell_Nature_EarthShock",
    EARTHQUAKE = "Interface\\Icons\\Spell_Shaman_Earthquake",
    EARTHSHAKER_SLAM = "Interface\\Icons\\earthshaker_slam_11",
    MOLTEN_BLAST = "Interface\\Icons\\Spell_Fire_Fireball",
    LIGHTNING_STRIKE = "Interface\\Icons\\Spell_Nature_Lightning",

    -- Warrior
    HEROIC_STRIKE = "Interface\\Icons\\Ability_Rogue_Ambush",
    BATTLE_STANCE = "Interface\\Icons\\Ability_Warrior_OffensiveStance",
    DEFENSIVE_STANCE = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
    BERSERKER_STANCE = "Interface\\Icons\\Ability_Racial_Avatar",
    BATTLE_SHOUT = "Interface\\Icons\\Ability_Warrior_BattleShout",
    REND = "Interface\\Icons\\Ability_Gouge",
    CHARGE = "Interface\\Icons\\Ability_Warrior_Charge",
    THUNDER_CLAP = "Interface\\Icons\\Spell_Nature_ThunderClap",
    HAMSTRING = "Interface\\Icons\\Ability_ShockWave",
    BLOODRAGE = "Interface\\Icons\\Ability_Racial_BloodRage",
    SUNDER_ARMOR = "Interface\\Icons\\Ability_Warrior_Sunder",
    TAUNT = "Interface\\Icons\\Spell_Nature_Reincarnation",
    SHIELD_BASH = "Interface\\Icons\\Ability_Warrior_ShieldBash",
    OVERPOWER = "Interface\\Icons\\Ability_MeleeDamage",
    DEMORALIZING_SHOUT = "Interface\\Icons\\Ability_Warrior_WarCry",
    REVENGE = "Interface\\Icons\\Ability_Warrior_Revenge",
    MOCKING_BLOW = "Interface\\Icons\\Ability_Warrior_PunishingBlow",
    SHIELD_BLOCK = "Interface\\Icons\\Ability_Defend",
    DISARM = "Interface\\Icons\\Ability_Warrior_Disarm",
    CLEAVE = "Interface\\Icons\\Ability_Warrior_Cleave",
    RETALIATION = "Interface\\Icons\\Ability_Warrior_Challange",
    INTIMIDATING_SHOUT = "Interface\\Icons\\Ability_GolemThunderClap",
    SHIELD_WALL = "Interface\\Icons\\Ability_Warrior_ShieldWall",
    EXECUTE = "Interface\\Icons\\INV_Sword_48",
    CHALLENGING_SHOUT = "Interface\\Icons\\ability_bullrush",
    INTERCEPT = "Interface\\Icons\\Ability_Rogue_Sprint",
    SHIELD_SLAM = "Interface\\Icons\\INV_Shield_05",
    BERSERKER_RAGE = "Interface\\Icons\\Spell_Nature_AncestralGuardian",
    WHIRLWIND = "Interface\\Icons\\Ability_Whirlwind",
    PUMMEL = "Interface\\Icons\\INV_Gauntlets_04",
    MORTAL_STRIKE = "Interface\\Icons\\Ability_Warrior_SavageBlow",
    BLOODTHIRST = "Interface\\Icons\\Spell_Nature_BloodLust",
    SLAM = "Interface\\Icons\\Ability_Warrior_DecisiveStrike",
    RECKLESSNESS = "Interface\\Icons\\Ability_CriticalStrike",
    INTERVENE = "Interface\\Icons\\Ability_Warrior_VictoryRush",
    COUNTERATTACK = "Interface\\Icons\\Ability_Warrior_Challange",

    -- Druid
    HEALING_TOUCH = "Interface\\Icons\\Spell_Nature_HealingTouch",
    MARK_OF_WILD = "Interface\\Icons\\Spell_Nature_Regeneration",
    GIFT_OF_WILD = "Interface\\Icons\\Spell_Nature_GiftOfTheWild",
    WRATH = "Interface\\Icons\\Spell_Nature_AbolishMagic",
    REJUVENATION = "Interface\\Icons\\Spell_Nature_Rejuvenation",
    MOONFIRE = "Interface\\Icons\\Spell_Nature_StarFall",
    THORNS = "Interface\\Icons\\Spell_Nature_Thorns",
    MANGLE = "Interface\\Icons\\Ability_Druid_Mangle2",
    ENTANGLING_ROOTS = "Interface\\Icons\\Spell_Nature_StrangleVines",
    DEMORALIZING_ROAR = "Interface\\Icons\\Ability_Druid_DemoralizingRoar",
    BEAR_FORM = "Interface\\Icons\\Ability_Racial_BearForm",
    DIRE_BEAR_FORM = "Interface\\Icons\\Ability_Racial_BearForm",
    MAUL = "Interface\\Icons\\Ability_Druid_Maul",
    GROWL = "Interface\\Icons\\Ability_Physical_Taunt",
    NATURES_GRASP = "Interface\\Icons\\Spell_Nature_NaturesWrath",
    TELEPORT_MOONGLADE = "Interface\\Icons\\Spell_Arcane_TeleportMoonglade",
    ENRAGE = "Interface\\Icons\\Ability_Druid_Enrage",
    REGROWTH = "Interface\\Icons\\Spell_Nature_ResistNature",
    BASH = "Interface\\Icons\\Ability_Druid_Bash",
    SWIPE = "Interface\\Icons\\INV_Misc_MonsterClaw_03",
    AQUATIC_FORM = "Interface\\Icons\\Ability_Druid_AquaticForm",
    FAERIE_FIRE = "Interface\\Icons\\Spell_Nature_FaerieFire",
    FAERIE_FIRE_FERAL = "Interface\\Icons\\Spell_Nature_FaerieFire",
    HIBERNATE = "Interface\\Icons\\Spell_Nature_Sleep",
    CAT_FORM = "Interface\\Icons\\Ability_Druid_CatForm",
    CLAW = "Interface\\Icons\\Ability_Druid_Rake",
    RIP = "Interface\\Icons\\Ability_GhoulFrenzy",
    PROWL = "Interface\\Icons\\Ability_Druid_Prowl",
    STARFIRE = "Interface\\Icons\\Spell_Arcane_StarFire",
    REBIRTH = "Interface\\Icons\\Spell_Nature_Reincarnation",
    INSECT_SWARM = "Interface\\Icons\\Spell_Nature_InsectSwarm",
    SHRED = "Interface\\Icons\\Spell_Shadow_VampiricAura",
    SOOTHE_ANIMAL = "Interface\\Icons\\Ability_Hunter_BeastSoothe",
    TIGERS_FURY = "Interface\\Icons\\Ability_Mount_JungleTiger",
    RAKE = "Interface\\Icons\\Ability_Druid_Disembowel",
    REMOVE_CURSE = "Interface\\Icons\\Spell_Nature_RemoveCurse",
    FEROCIOUS_BITE = "Interface\\Icons\\Ability_Druid_FerociousBite",
    DASH = "Interface\\Icons\\Ability_Druid_Dash",
    ABOLISH_POISON = "Interface\\Icons\\Spell_Nature_NullifyPoison_02",
    CHALLENGING_ROAR = "Interface\\Icons\\Ability_Druid_ChallangingRoar",
    COWER = "Interface\\Icons\\Ability_Druid_Cower",
    TRAVEL_FORM = "Interface\\Icons\\Ability_Druid_TravelForm",
    TRANQUILITY = "Interface\\Icons\\Spell_Nature_Tranquility",
    RAVAGE = "Interface\\Icons\\Ability_Druid_Ravage",
    POUNCE = "Interface\\Icons\\Ability_Druid_SupriseAttack",
    FRENZIED_REGEN = "Interface\\Icons\\Ability_BullRush",
    HURRICANE = "Interface\\Icons\\Spell_Nature_Cyclone",
    MOONKIN_FORM = "Interface\\Icons\\Spell_Nature_ForceOfNature",
    BARKSKIN = "Interface\\Icons\\Spell_Nature_StoneClawTotem",
    TREE_FORM = "Interface\\Icons\\Ability_Druid_TreeOfLife",
    BERSERK = "Interface\\Icons\\Ability_Druid_Berserk",
    TRACK_HUMANOIDS = "Interface\\Icons\\Ability_Tracking",
    SAVAGE_BITE = "Interface\\Icons\\Ability_Druid_FerociousBite",

    -- Paladin
    DEVOTION_AURA = "Interface\\Icons\\Spell_Holy_DevotionAura",
    HOLY_LIGHT = "Interface\\Icons\\Spell_Holy_HolyBolt",
    SEAL_RIGHTEOUSNESS = "Interface\\Icons\\Ability_ThunderBolt",
    JUDGEMENT = "Interface\\Icons\\Spell_Holy_RighteousFury",
    JUDGEMENT_RIGHTEOUSNESS = "Interface\\Icons\\Spell_Holy_RighteousFury",
    RIGHTEOUS_FURY = "Interface\\Icons\\Spell_Holy_SealOfFury",
    BLESSING_MIGHT = "Interface\\Icons\\Spell_Holy_FistOfJustice",
    HOLY_STRIKE = "Interface\\Icons\\Spell_Holy_SearingLight",
    DIVINE_PROTECTION = "Interface\\Icons\\Spell_Holy_Restoration",
    SEAL_CRUSADER = "Interface\\Icons\\Spell_Holy_HolySmite",
    PURIFY = "Interface\\Icons\\Spell_Holy_Purify",
    HAMMER_JUSTICE = "Interface\\Icons\\Spell_Holy_SealOfMight",
    LAY_ON_HANDS = "Interface\\Icons\\Spell_Holy_LayOnHands",
    HAND_PROTECTION = "Interface\\Icons\\Spell_Holy_SealOfProtection",
    CRUSADER_STRIKE = "Interface\\Icons\\Spell_Holy_CrusaderStrike",
    HAND_RECKONING = "Interface\\Icons\\Spell_Holy_Redemption",
    REDEMPTION = "Interface\\Icons\\Spell_Holy_Resurrection",
    BLESSING_WISDOM = "Interface\\Icons\\Spell_Holy_SealOfWisdom",
    RETRIBUTION_AURA = "Interface\\Icons\\Spell_Holy_AuraOfLight",
    HAND_FREEDOM = "Interface\\Icons\\Spell_Holy_SealOfValor",
    SEAL_WISDOM = "Interface\\Icons\\Spell_Holy_RighteousnessAura",
    EXORCISM = "Interface\\Icons\\Spell_Holy_Excorcism_02",
    SENSE_UNDEAD = "Interface\\Icons\\Spell_Holy_SenseUndead",
    FLASH_LIGHT = "Interface\\Icons\\Spell_Holy_FlashHeal",
    CONSECRATION = "Interface\\Icons\\Spell_Holy_InnerFire",
    BLESSING_KINGS = "Interface\\Icons\\Spell_Magic_MageArmor",
    CONCENTRATION_AURA = "Interface\\Icons\\Spell_Holy_MindSooth",
    SEAL_JUSTICE = "Interface\\Icons\\Spell_Holy_SealOfWrath",
    TURN_UNDEAD = "Interface\\Icons\\Spell_Holy_TurnUndead",
    BLESSING_SALVATION = "Interface\\Icons\\Spell_Holy_SealOfSalvation",
    SHADOW_RESIST_AURA = "Interface\\Icons\\Spell_Shadow_SealOfKings",
    FROST_RESIST_AURA = "Interface\\Icons\\Spell_Frost_WizardMark",
    FIRE_RESIST_AURA = "Interface\\Icons\\Spell_Fire_SealOfFire",
    SEAL_LIGHT = "Interface\\Icons\\Spell_Holy_HealingAura",
    DIVINE_INTERVENTION = "Interface\\Icons\\Spell_Nature_TimeStop",
    DIVINE_SHIELD = "Interface\\Icons\\Spell_Holy_DivineIntervention",
    SANCTITY_AURA = "Interface\\Icons\\Spell_Holy_MindVision",
    SUMMON_WARHORSE = "Interface\\Icons\\Spell_Nature_Swiftness",
    BLESSING_LIGHT = "Interface\\Icons\\Spell_Holy_PrayerOfHealing02",
    REPENTANCE = "Interface\\Icons\\Spell_Holy_PrayerOfHealing",
    HOLY_SHOCK = "Interface\\Icons\\Spell_Holy_SearingLight",
    CLEANSE = "Interface\\Icons\\Spell_Holy_Renew",
    HAMMER_WRATH = "Interface\\Icons\\Ability_ThunderClap",
    HAND_SACRIFICE = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
    HOLY_WRATH = "Interface\\Icons\\Spell_Holy_Excorcism",
    SUMMON_CHARGER = "Interface\\Icons\\Ability_Mount_Charger",
    GREATER_BLESSING_MIGHT = "Interface\\Icons\\Spell_Holy_GreaterBlessingofKings",
    GREATER_BLESSING_WISDOM = "Interface\\Icons\\Spell_Holy_GreaterBlessingofWisdom",
    GREATER_BLESSING_LIGHT = "Interface\\Icons\\Spell_Holy_GreaterBlessingofLight",
    GREATER_BLESSING_SALVATION = "Interface\\Icons\\Spell_Holy_GreaterBlessingofSalvation",
    GREATER_BLESSING_SANCTUARY = "Interface\\Icons\\Spell_Holy_GreaterBlessingofSanctuary",
    GREATER_BLESSING_KINGS = "Interface\\Icons\\Spell_Magic_GreaterBlessingofKings",
    SEAL_MARTYR = "Interface\\Icons\\Spell_Holy_RighteousFury",
}

-- ============================================================================
-- SHAMAN SPELLS
-- ============================================================================
local shamanSpells = {
    -- Healing Wave (all ranks)
    [331] = { name = "Healing Wave", icon = ICONS.HEALING_WAVE },
    [332] = { name = "Healing Wave", icon = ICONS.HEALING_WAVE },
    [547] = { name = "Healing Wave", icon = ICONS.HEALING_WAVE },
    [913] = { name = "Healing Wave", icon = ICONS.HEALING_WAVE },
    [939] = { name = "Healing Wave", icon = ICONS.HEALING_WAVE },
    [959] = { name = "Healing Wave", icon = ICONS.HEALING_WAVE },
    [8005] = { name = "Healing Wave", icon = ICONS.HEALING_WAVE },
    [10395] = { name = "Healing Wave", icon = ICONS.HEALING_WAVE },
    [10396] = { name = "Healing Wave", icon = ICONS.HEALING_WAVE },
    [25357] = { name = "Healing Wave", icon = ICONS.HEALING_WAVE },

    -- Lightning Bolt (all ranks)
    [403] = { name = "Lightning Bolt", icon = ICONS.LIGHTNING_BOLT },
    [529] = { name = "Lightning Bolt", icon = ICONS.LIGHTNING_BOLT },
    [548] = { name = "Lightning Bolt", icon = ICONS.LIGHTNING_BOLT },
    [915] = { name = "Lightning Bolt", icon = ICONS.LIGHTNING_BOLT },
    [943] = { name = "Lightning Bolt", icon = ICONS.LIGHTNING_BOLT },
    [6041] = { name = "Lightning Bolt", icon = ICONS.LIGHTNING_BOLT },
    [10391] = { name = "Lightning Bolt", icon = ICONS.LIGHTNING_BOLT },
    [10392] = { name = "Lightning Bolt", icon = ICONS.LIGHTNING_BOLT },
    [15207] = { name = "Lightning Bolt", icon = ICONS.LIGHTNING_BOLT },
    [15208] = { name = "Lightning Bolt", icon = ICONS.LIGHTNING_BOLT },

    -- Chain Lightning (all ranks)
    [421] = { name = "Chain Lightning", icon = ICONS.CHAIN_LIGHTNING },
    [930] = { name = "Chain Lightning", icon = ICONS.CHAIN_LIGHTNING },
    [2860] = { name = "Chain Lightning", icon = ICONS.CHAIN_LIGHTNING },
    [10605] = { name = "Chain Lightning", icon = ICONS.CHAIN_LIGHTNING },

    -- Earth Shock (all ranks)
    [8042] = { name = "Earth Shock", icon = ICONS.EARTH_SHOCK },
    [8044] = { name = "Earth Shock", icon = ICONS.EARTH_SHOCK },
    [8045] = { name = "Earth Shock", icon = ICONS.EARTH_SHOCK },
    [8046] = { name = "Earth Shock", icon = ICONS.EARTH_SHOCK },
    [10412] = { name = "Earth Shock", icon = ICONS.EARTH_SHOCK },
    [10413] = { name = "Earth Shock", icon = ICONS.EARTH_SHOCK },
    [10414] = { name = "Earth Shock", icon = ICONS.EARTH_SHOCK },

    -- Frost Shock (all ranks)
    [8056] = { name = "Frost Shock", icon = ICONS.FROST_SHOCK },
    [8058] = { name = "Frost Shock", icon = ICONS.FROST_SHOCK },
    [10472] = { name = "Frost Shock", icon = ICONS.FROST_SHOCK },
    [10473] = { name = "Frost Shock", icon = ICONS.FROST_SHOCK },

    -- Flame Shock (all ranks)
    [8050] = { name = "Flame Shock", icon = ICONS.FLAME_SHOCK },
    [8052] = { name = "Flame Shock", icon = ICONS.FLAME_SHOCK },
    [8053] = { name = "Flame Shock", icon = ICONS.FLAME_SHOCK },
    [10447] = { name = "Flame Shock", icon = ICONS.FLAME_SHOCK },
    [10448] = { name = "Flame Shock", icon = ICONS.FLAME_SHOCK },
    [29228] = { name = "Flame Shock", icon = ICONS.FLAME_SHOCK },

    -- Lightning Shield (all ranks)
    [324] = { name = "Lightning Shield", icon = ICONS.LIGHTNING_SHIELD },
    [325] = { name = "Lightning Shield", icon = ICONS.LIGHTNING_SHIELD },
    [905] = { name = "Lightning Shield", icon = ICONS.LIGHTNING_SHIELD },
    [945] = { name = "Lightning Shield", icon = ICONS.LIGHTNING_SHIELD },
    [8134] = { name = "Lightning Shield", icon = ICONS.LIGHTNING_SHIELD },
    [10431] = { name = "Lightning Shield", icon = ICONS.LIGHTNING_SHIELD },
    [10432] = { name = "Lightning Shield", icon = ICONS.LIGHTNING_SHIELD },

    -- Weapon Enchants
    [8017] = { name = "Rockbiter Weapon", icon = ICONS.ROCKBITER },
    [8018] = { name = "Rockbiter Weapon", icon = ICONS.ROCKBITER },
    [8019] = { name = "Rockbiter Weapon", icon = ICONS.ROCKBITER },
    [10399] = { name = "Rockbiter Weapon", icon = ICONS.ROCKBITER },
    [16314] = { name = "Rockbiter Weapon", icon = ICONS.ROCKBITER },
    [16315] = { name = "Rockbiter Weapon", icon = ICONS.ROCKBITER },
    [16316] = { name = "Rockbiter Weapon", icon = ICONS.ROCKBITER },
    [8024] = { name = "Flametongue Weapon", icon = ICONS.FLAMETONGUE },
    [8027] = { name = "Flametongue Weapon", icon = ICONS.FLAMETONGUE },
    [8030] = { name = "Flametongue Weapon", icon = ICONS.FLAMETONGUE },
    [16339] = { name = "Flametongue Weapon", icon = ICONS.FLAMETONGUE },
    [16341] = { name = "Flametongue Weapon", icon = ICONS.FLAMETONGUE },
    [16342] = { name = "Flametongue Weapon", icon = ICONS.FLAMETONGUE },
    [8033] = { name = "Frostbrand Weapon", icon = ICONS.FROSTBRAND },
    [8038] = { name = "Frostbrand Weapon", icon = ICONS.FROSTBRAND },
    [10456] = { name = "Frostbrand Weapon", icon = ICONS.FROSTBRAND },
    [16355] = { name = "Frostbrand Weapon", icon = ICONS.FROSTBRAND },
    [16356] = { name = "Frostbrand Weapon", icon = ICONS.FROSTBRAND },
    [8232] = { name = "Windfury Weapon", icon = ICONS.WINDFURY },
    [8235] = { name = "Windfury Weapon", icon = ICONS.WINDFURY },
    [10486] = { name = "Windfury Weapon", icon = ICONS.WINDFURY },
    [16362] = { name = "Windfury Weapon", icon = ICONS.WINDFURY },

    -- Totems
    [8071] = { name = "Stoneskin Totem", icon = ICONS.STONESKIN_TOTEM },
    [8154] = { name = "Stoneskin Totem", icon = ICONS.STONESKIN_TOTEM },
    [8155] = { name = "Stoneskin Totem", icon = ICONS.STONESKIN_TOTEM },
    [10406] = { name = "Stoneskin Totem", icon = ICONS.STONESKIN_TOTEM },
    [10407] = { name = "Stoneskin Totem", icon = ICONS.STONESKIN_TOTEM },
    [10408] = { name = "Stoneskin Totem", icon = ICONS.STONESKIN_TOTEM },
    [2484] = { name = "Earthbind Totem", icon = ICONS.EARTHBIND_TOTEM },
    [5730] = { name = "Stoneclaw Totem", icon = ICONS.STONECLAW_TOTEM },
    [6390] = { name = "Stoneclaw Totem", icon = ICONS.STONECLAW_TOTEM },
    [6391] = { name = "Stoneclaw Totem", icon = ICONS.STONECLAW_TOTEM },
    [6392] = { name = "Stoneclaw Totem", icon = ICONS.STONECLAW_TOTEM },
    [10427] = { name = "Stoneclaw Totem", icon = ICONS.STONECLAW_TOTEM },
    [10428] = { name = "Stoneclaw Totem", icon = ICONS.STONECLAW_TOTEM },
    [8075] = { name = "Strength of Earth Totem", icon = ICONS.STRENGTH_TOTEM },
    [8160] = { name = "Strength of Earth Totem", icon = ICONS.STRENGTH_TOTEM },
    [8161] = { name = "Strength of Earth Totem", icon = ICONS.STRENGTH_TOTEM },
    [10442] = { name = "Strength of Earth Totem", icon = ICONS.STRENGTH_TOTEM },
    [25361] = { name = "Strength of Earth Totem", icon = ICONS.STRENGTH_TOTEM },
    [8143] = { name = "Tremor Totem", icon = ICONS.TREMOR_TOTEM },
    [8177] = { name = "Grounding Totem", icon = ICONS.GROUNDING_TOTEM },
    [3599] = { name = "Searing Totem", icon = ICONS.SEARING_TOTEM },
    [6363] = { name = "Searing Totem", icon = ICONS.SEARING_TOTEM },
    [6364] = { name = "Searing Totem", icon = ICONS.SEARING_TOTEM },
    [6365] = { name = "Searing Totem", icon = ICONS.SEARING_TOTEM },
    [10437] = { name = "Searing Totem", icon = ICONS.SEARING_TOTEM },
    [10438] = { name = "Searing Totem", icon = ICONS.SEARING_TOTEM },
    [1535] = { name = "Fire Nova Totem", icon = ICONS.FIRE_NOVA_TOTEM },
    [8498] = { name = "Fire Nova Totem", icon = ICONS.FIRE_NOVA_TOTEM },
    [8499] = { name = "Fire Nova Totem", icon = ICONS.FIRE_NOVA_TOTEM },
    [11314] = { name = "Fire Nova Totem", icon = ICONS.FIRE_NOVA_TOTEM },
    [11315] = { name = "Fire Nova Totem", icon = ICONS.FIRE_NOVA_TOTEM },
    [8190] = { name = "Magma Totem", icon = ICONS.MAGMA_TOTEM },
    [10585] = { name = "Magma Totem", icon = ICONS.MAGMA_TOTEM },
    [10586] = { name = "Magma Totem", icon = ICONS.MAGMA_TOTEM },
    [10587] = { name = "Magma Totem", icon = ICONS.MAGMA_TOTEM },
    [5394] = { name = "Healing Stream Totem", icon = ICONS.HEALING_STREAM },
    [6375] = { name = "Healing Stream Totem", icon = ICONS.HEALING_STREAM },
    [6377] = { name = "Healing Stream Totem", icon = ICONS.HEALING_STREAM },
    [10462] = { name = "Healing Stream Totem", icon = ICONS.HEALING_STREAM },
    [10463] = { name = "Healing Stream Totem", icon = ICONS.HEALING_STREAM },
    [5675] = { name = "Mana Spring Totem", icon = ICONS.MANA_SPRING },
    [10495] = { name = "Mana Spring Totem", icon = ICONS.MANA_SPRING },
    [10496] = { name = "Mana Spring Totem", icon = ICONS.MANA_SPRING },
    [10497] = { name = "Mana Spring Totem", icon = ICONS.MANA_SPRING },
    [16190] = { name = "Mana Tide Totem", icon = ICONS.MANA_TIDE },
    [17354] = { name = "Mana Tide Totem", icon = ICONS.MANA_TIDE },
    [17359] = { name = "Mana Tide Totem", icon = ICONS.MANA_TIDE },
    [8512] = { name = "Windfury Totem", icon = ICONS.WINDFURY_TOTEM },
    [10613] = { name = "Windfury Totem", icon = ICONS.WINDFURY_TOTEM },
    [10614] = { name = "Windfury Totem", icon = ICONS.WINDFURY_TOTEM },
    [8835] = { name = "Grace of Air Totem", icon = ICONS.GRACE_AIR },
    [10627] = { name = "Grace of Air Totem", icon = ICONS.GRACE_AIR },
    [25359] = { name = "Grace of Air Totem", icon = ICONS.GRACE_AIR },
    [8181] = { name = "Frost Resistance Totem", icon = ICONS.FROST_RESIST_TOTEM },
    [10478] = { name = "Frost Resistance Totem", icon = ICONS.FROST_RESIST_TOTEM },
    [10479] = { name = "Frost Resistance Totem", icon = ICONS.FROST_RESIST_TOTEM },
    [8184] = { name = "Fire Resistance Totem", icon = ICONS.FIRE_RESIST_TOTEM },
    [10537] = { name = "Fire Resistance Totem", icon = ICONS.FIRE_RESIST_TOTEM },
    [10538] = { name = "Fire Resistance Totem", icon = ICONS.FIRE_RESIST_TOTEM },
    [10595] = { name = "Nature Resistance Totem", icon = ICONS.NATURE_RESIST_TOTEM },
    [10600] = { name = "Nature Resistance Totem", icon = ICONS.NATURE_RESIST_TOTEM },
    [10601] = { name = "Nature Resistance Totem", icon = ICONS.NATURE_RESIST_TOTEM },
    [8166] = { name = "Poison Cleansing Totem", icon = ICONS.POISON_CLEANSING },
    [8170] = { name = "Disease Cleansing Totem", icon = ICONS.DISEASE_CLEANSING },
    [8227] = { name = "Flametongue Totem", icon = ICONS.FLAMETONGUE_TOTEM },
    [8249] = { name = "Flametongue Totem", icon = ICONS.FLAMETONGUE_TOTEM },
    [10526] = { name = "Flametongue Totem", icon = ICONS.FLAMETONGUE_TOTEM },
    [16387] = { name = "Flametongue Totem", icon = ICONS.FLAMETONGUE_TOTEM },
    [15107] = { name = "Windwall Totem", icon = ICONS.WINDWALL_TOTEM },
    [15111] = { name = "Windwall Totem", icon = ICONS.WINDWALL_TOTEM },
    [15112] = { name = "Windwall Totem", icon = ICONS.WINDWALL_TOTEM },
    [6495] = { name = "Sentry Totem", icon = ICONS.SENTRY_TOTEM },

    -- Other Shaman spells
    [370] = { name = "Purge", icon = ICONS.PURGE },
    [8012] = { name = "Purge", icon = ICONS.PURGE },
    [2645] = { name = "Ghost Wolf", icon = ICONS.GHOST_WOLF },
    [1064] = { name = "Chain Heal", icon = ICONS.CHAIN_HEAL },
    [10622] = { name = "Chain Heal", icon = ICONS.CHAIN_HEAL },
    [10623] = { name = "Chain Heal", icon = ICONS.CHAIN_HEAL },
    [8004] = { name = "Lesser Healing Wave", icon = ICONS.LESSER_HEALING_WAVE },
    [8008] = { name = "Lesser Healing Wave", icon = ICONS.LESSER_HEALING_WAVE },
    [8010] = { name = "Lesser Healing Wave", icon = ICONS.LESSER_HEALING_WAVE },
    [10466] = { name = "Lesser Healing Wave", icon = ICONS.LESSER_HEALING_WAVE },
    [10467] = { name = "Lesser Healing Wave", icon = ICONS.LESSER_HEALING_WAVE },
    [10468] = { name = "Lesser Healing Wave", icon = ICONS.LESSER_HEALING_WAVE },
    [2008] = { name = "Ancestral Spirit", icon = ICONS.ANCESTRAL_SPIRIT },
    [20609] = { name = "Ancestral Spirit", icon = ICONS.ANCESTRAL_SPIRIT },
    [20610] = { name = "Ancestral Spirit", icon = ICONS.ANCESTRAL_SPIRIT },
    [20776] = { name = "Ancestral Spirit", icon = ICONS.ANCESTRAL_SPIRIT },
    [20777] = { name = "Ancestral Spirit", icon = ICONS.ANCESTRAL_SPIRIT },
    [131] = { name = "Water Breathing", icon = ICONS.WATER_BREATHING },
    [546] = { name = "Water Walking", icon = ICONS.WATER_WALKING },
    [6196] = { name = "Far Sight", icon = ICONS.FAR_SIGHT },
    [556] = { name = "Astral Recall", icon = ICONS.ASTRAL_RECALL },
    [20608] = { name = "Reincarnation", icon = ICONS.REINCARNATION },
    [21169] = { name = "Reincarnation", icon = ICONS.REINCARNATION },
    [526] = { name = "Cure Poison", icon = ICONS.CURE_POISON },
    [2870] = { name = "Cure Disease", icon = ICONS.CURE_DISEASE },

    -- Turtle WoW Shaman spells
    [51365] = { name = "Earthshaker Slam", icon = ICONS.EARTHSHAKER_SLAM },
    [45504] = { name = "Hex", icon = ICONS.HEX },
    [45525] = { name = "Earth Shield", icon = ICONS.EARTH_SHIELD },
    [51525] = { name = "Earth Shield", icon = ICONS.EARTH_SHIELD },
    [51526] = { name = "Earth Shield", icon = ICONS.EARTH_SHIELD },
    [45526] = { name = "Earth Shield", icon = ICONS.EARTH_SHIELD },
    [45527] = { name = "Water Shield", icon = ICONS.WATER_SHIELD },
    [51533] = { name = "Water Shield", icon = ICONS.WATER_SHIELD },
    [51534] = { name = "Water Shield", icon = ICONS.WATER_SHIELD },
    [51535] = { name = "Water Shield", icon = ICONS.WATER_SHIELD },
    [51536] = { name = "Water Shield", icon = ICONS.WATER_SHIELD },
    [45509] = { name = "Bloodlust", icon = ICONS.BLOODLUST },
    [45505] = { name = "Feral Spirit", icon = ICONS.FERAL_SPIRIT },
    [45514] = { name = "Feral Spirit", icon = ICONS.FERAL_SPIRIT },
    [45534] = { name = "Lava Lash", icon = ICONS.LAVA_LASH },
    [45502] = { name = "Ethereal Form", icon = ICONS.ETHEREAL_FORM },
    [45500] = { name = "Totemic Slam", icon = ICONS.TOTEMIC_SLAM },
    [48306] = { name = "Earthquake", icon = ICONS.EARTHQUAKE },
    [48307] = { name = "Earthquake", icon = ICONS.EARTHQUAKE },
    [48308] = { name = "Earthquake", icon = ICONS.EARTHQUAKE },
    [51363] = { name = "Spirit Link", icon = ICONS.CHAIN_HEAL },
    [36916] = { name = "Molten Blast", icon = ICONS.MOLTEN_BLAST },
    [36917] = { name = "Molten Blast", icon = ICONS.MOLTEN_BLAST },
    [36918] = { name = "Molten Blast", icon = ICONS.MOLTEN_BLAST },
    [36919] = { name = "Molten Blast", icon = ICONS.MOLTEN_BLAST },
    [36920] = { name = "Molten Blast", icon = ICONS.MOLTEN_BLAST },
    [36921] = { name = "Molten Blast", icon = ICONS.MOLTEN_BLAST },
    [51387] = { name = "Lightning Strike", icon = ICONS.LIGHTNING_STRIKE },
    [52420] = { name = "Lightning Strike", icon = ICONS.LIGHTNING_STRIKE },
    [52422] = { name = "Lightning Strike", icon = ICONS.LIGHTNING_STRIKE },
}

-- ============================================================================
-- WARRIOR SPELLS
-- ============================================================================
local warriorSpells = {
    -- Stances
    [2457] = { name = "Battle Stance", icon = ICONS.BATTLE_STANCE },
    [71] = { name = "Defensive Stance", icon = ICONS.DEFENSIVE_STANCE },
    [2458] = { name = "Berserker Stance", icon = ICONS.BERSERKER_STANCE },

    -- Heroic Strike (all ranks)
    [78] = { name = "Heroic Strike", icon = ICONS.HEROIC_STRIKE },
    [284] = { name = "Heroic Strike", icon = ICONS.HEROIC_STRIKE },
    [285] = { name = "Heroic Strike", icon = ICONS.HEROIC_STRIKE },
    [1608] = { name = "Heroic Strike", icon = ICONS.HEROIC_STRIKE },
    [11564] = { name = "Heroic Strike", icon = ICONS.HEROIC_STRIKE },
    [11565] = { name = "Heroic Strike", icon = ICONS.HEROIC_STRIKE },
    [11566] = { name = "Heroic Strike", icon = ICONS.HEROIC_STRIKE },
    [11567] = { name = "Heroic Strike", icon = ICONS.HEROIC_STRIKE },
    [25286] = { name = "Heroic Strike", icon = ICONS.HEROIC_STRIKE },

    -- Battle Shout (all ranks)
    [6673] = { name = "Battle Shout", icon = ICONS.BATTLE_SHOUT },
    [5242] = { name = "Battle Shout", icon = ICONS.BATTLE_SHOUT },
    [6192] = { name = "Battle Shout", icon = ICONS.BATTLE_SHOUT },
    [11549] = { name = "Battle Shout", icon = ICONS.BATTLE_SHOUT },
    [11550] = { name = "Battle Shout", icon = ICONS.BATTLE_SHOUT },
    [11551] = { name = "Battle Shout", icon = ICONS.BATTLE_SHOUT },
    [25289] = { name = "Battle Shout", icon = ICONS.BATTLE_SHOUT },

    -- Rend (all ranks)
    [772] = { name = "Rend", icon = ICONS.REND },
    [6546] = { name = "Rend", icon = ICONS.REND },
    [6547] = { name = "Rend", icon = ICONS.REND },
    [6548] = { name = "Rend", icon = ICONS.REND },
    [11572] = { name = "Rend", icon = ICONS.REND },
    [11573] = { name = "Rend", icon = ICONS.REND },
    [11574] = { name = "Rend", icon = ICONS.REND },

    -- Charge (all ranks)
    [100] = { name = "Charge", icon = ICONS.CHARGE },
    [6178] = { name = "Charge", icon = ICONS.CHARGE },
    [11578] = { name = "Charge", icon = ICONS.CHARGE },

    -- Thunder Clap (all ranks)
    [6343] = { name = "Thunder Clap", icon = ICONS.THUNDER_CLAP },
    [8198] = { name = "Thunder Clap", icon = ICONS.THUNDER_CLAP },
    [8204] = { name = "Thunder Clap", icon = ICONS.THUNDER_CLAP },
    [8205] = { name = "Thunder Clap", icon = ICONS.THUNDER_CLAP },
    [11580] = { name = "Thunder Clap", icon = ICONS.THUNDER_CLAP },
    [11581] = { name = "Thunder Clap", icon = ICONS.THUNDER_CLAP },

    -- Hamstring
    [1715] = { name = "Hamstring", icon = ICONS.HAMSTRING },
    [7372] = { name = "Hamstring", icon = ICONS.HAMSTRING },
    [7373] = { name = "Hamstring", icon = ICONS.HAMSTRING },

    -- Sunder Armor (all ranks)
    [7386] = { name = "Sunder Armor", icon = ICONS.SUNDER_ARMOR },
    [7405] = { name = "Sunder Armor", icon = ICONS.SUNDER_ARMOR },
    [8380] = { name = "Sunder Armor", icon = ICONS.SUNDER_ARMOR },
    [11596] = { name = "Sunder Armor", icon = ICONS.SUNDER_ARMOR },
    [11597] = { name = "Sunder Armor", icon = ICONS.SUNDER_ARMOR },

    -- TAUNT
    [355] = { name = "Taunt", icon = ICONS.TAUNT },

    -- Shield Bash
    [72] = { name = "Shield Bash", icon = ICONS.SHIELD_BASH },
    [1671] = { name = "Shield Bash", icon = ICONS.SHIELD_BASH },
    [1672] = { name = "Shield Bash", icon = ICONS.SHIELD_BASH },

    -- Overpower
    [7384] = { name = "Overpower", icon = ICONS.OVERPOWER },
    [7887] = { name = "Overpower", icon = ICONS.OVERPOWER },
    [11584] = { name = "Overpower", icon = ICONS.OVERPOWER },
    [11585] = { name = "Overpower", icon = ICONS.OVERPOWER },

    -- Demoralizing Shout
    [1160] = { name = "Demoralizing Shout", icon = ICONS.DEMORALIZING_SHOUT },
    [6190] = { name = "Demoralizing Shout", icon = ICONS.DEMORALIZING_SHOUT },
    [11554] = { name = "Demoralizing Shout", icon = ICONS.DEMORALIZING_SHOUT },
    [11555] = { name = "Demoralizing Shout", icon = ICONS.DEMORALIZING_SHOUT },
    [11556] = { name = "Demoralizing Shout", icon = ICONS.DEMORALIZING_SHOUT },

    -- Revenge (all ranks)
    [6572] = { name = "Revenge", icon = ICONS.REVENGE },
    [6574] = { name = "Revenge", icon = ICONS.REVENGE },
    [7379] = { name = "Revenge", icon = ICONS.REVENGE },
    [11600] = { name = "Revenge", icon = ICONS.REVENGE },
    [11601] = { name = "Revenge", icon = ICONS.REVENGE },
    [25288] = { name = "Revenge", icon = ICONS.REVENGE },

    -- Mocking Blow
    [694] = { name = "Mocking Blow", icon = ICONS.MOCKING_BLOW },
    [7400] = { name = "Mocking Blow", icon = ICONS.MOCKING_BLOW },
    [7402] = { name = "Mocking Blow", icon = ICONS.MOCKING_BLOW },
    [20559] = { name = "Mocking Blow", icon = ICONS.MOCKING_BLOW },
    [20560] = { name = "Mocking Blow", icon = ICONS.MOCKING_BLOW },

    -- Shield Block
    [2565] = { name = "Shield Block", icon = ICONS.SHIELD_BLOCK },

    -- Disarm
    [676] = { name = "Disarm", icon = ICONS.DISARM },

    -- Cleave
    [845] = { name = "Cleave", icon = ICONS.CLEAVE },
    [7369] = { name = "Cleave", icon = ICONS.CLEAVE },
    [11608] = { name = "Cleave", icon = ICONS.CLEAVE },
    [11609] = { name = "Cleave", icon = ICONS.CLEAVE },
    [20569] = { name = "Cleave", icon = ICONS.CLEAVE },

    -- Retaliation
    [20230] = { name = "Retaliation", icon = ICONS.RETALIATION },

    -- Intimidating Shout
    [5246] = { name = "Intimidating Shout", icon = ICONS.INTIMIDATING_SHOUT },

    -- Challenging Shout
    [1161] = { name = "Challenging Shout", icon = ICONS.CHALLENGING_SHOUT },

    -- Shield Wall
    [871] = { name = "Shield Wall", icon = ICONS.SHIELD_WALL },

    -- Execute (all ranks)
    [5308] = { name = "Execute", icon = ICONS.EXECUTE },
    [20647] = { name = "Execute", icon = ICONS.EXECUTE },
    [20658] = { name = "Execute", icon = ICONS.EXECUTE },
    [20660] = { name = "Execute", icon = ICONS.EXECUTE },
    [20661] = { name = "Execute", icon = ICONS.EXECUTE },
    [20662] = { name = "Execute", icon = ICONS.EXECUTE },

    -- Intercept
    [20252] = { name = "Intercept", icon = ICONS.INTERCEPT },
    [20616] = { name = "Intercept", icon = ICONS.INTERCEPT },
    [20617] = { name = "Intercept", icon = ICONS.INTERCEPT },

    -- Shield Slam (all ranks)
    [23922] = { name = "Shield Slam", icon = ICONS.SHIELD_SLAM },
    [23923] = { name = "Shield Slam", icon = ICONS.SHIELD_SLAM },
    [23924] = { name = "Shield Slam", icon = ICONS.SHIELD_SLAM },
    [23925] = { name = "Shield Slam", icon = ICONS.SHIELD_SLAM },
    [52315] = { name = "Shield Slam", icon = ICONS.SHIELD_SLAM },

    -- Berserker Rage
    [18499] = { name = "Berserker Rage", icon = ICONS.BERSERKER_RAGE },

    -- Whirlwind
    [1680] = { name = "Whirlwind", icon = ICONS.WHIRLWIND },

    -- Pummel
    [6552] = { name = "Pummel", icon = ICONS.PUMMEL },

    -- Slam (all ranks)
    [1464] = { name = "Slam", icon = ICONS.SLAM },
    [8820] = { name = "Slam", icon = ICONS.SLAM },
    [11604] = { name = "Slam", icon = ICONS.SLAM },
    [11605] = { name = "Slam", icon = ICONS.SLAM },
    [45599] = { name = "Slam", icon = ICONS.SLAM },
    [45961] = { name = "Slam", icon = ICONS.SLAM },

    -- Mortal Strike (all ranks)
    [12294] = { name = "Mortal Strike", icon = ICONS.MORTAL_STRIKE },
    [21551] = { name = "Mortal Strike", icon = ICONS.MORTAL_STRIKE },
    [21552] = { name = "Mortal Strike", icon = ICONS.MORTAL_STRIKE },
    [21553] = { name = "Mortal Strike", icon = ICONS.MORTAL_STRIKE },

    -- Bloodthirst (all ranks)
    [23881] = { name = "Bloodthirst", icon = ICONS.BLOODTHIRST },
    [23892] = { name = "Bloodthirst", icon = ICONS.BLOODTHIRST },
    [23893] = { name = "Bloodthirst", icon = ICONS.BLOODTHIRST },
    [23894] = { name = "Bloodthirst", icon = ICONS.BLOODTHIRST },
    [23880] = { name = "Bloodthirst", icon = ICONS.BLOODTHIRST },
    [23885] = { name = "Bloodthirst", icon = ICONS.BLOODTHIRST },
    [23886] = { name = "Bloodthirst", icon = ICONS.BLOODTHIRST },
    [23887] = { name = "Bloodthirst", icon = ICONS.BLOODTHIRST },
    [23888] = { name = "Bloodthirst", icon = ICONS.BLOODTHIRST },
    [23889] = { name = "Bloodthirst", icon = ICONS.BLOODTHIRST },
    [23890] = { name = "Bloodthirst", icon = ICONS.BLOODTHIRST },
    [23891] = { name = "Bloodthirst", icon = ICONS.BLOODTHIRST },

    -- Recklessness
    [1719] = { name = "Recklessness", icon = ICONS.RECKLESSNESS },

    -- Bloodrage
    [2687] = { name = "Bloodrage", icon = ICONS.BLOODRAGE },

    -- Intervene (Turtle WoW)
    [45595] = { name = "Intervene", icon = ICONS.INTERVENE },

    -- Counterattack (Turtle WoW)
    [51626] = { name = "Counterattack", icon = ICONS.COUNTERATTACK },
    [51627] = { name = "Counterattack", icon = ICONS.COUNTERATTACK },
    [51628] = { name = "Counterattack", icon = ICONS.COUNTERATTACK },
    [51629] = { name = "Counterattack", icon = ICONS.COUNTERATTACK },
    [51630] = { name = "Counterattack", icon = ICONS.COUNTERATTACK },

    -- Master Strike (Turtle WoW)
    [54023] = { name = "Master Strike", icon = ICONS.MORTAL_STRIKE },
}

-- ============================================================================
-- DRUID SPELLS
-- ============================================================================
local druidSpells = {
    -- Forms
    [5487] = { name = "Bear Form", icon = ICONS.BEAR_FORM },
    [9634] = { name = "Dire Bear Form", icon = ICONS.DIRE_BEAR_FORM },
    [768] = { name = "Cat Form", icon = ICONS.CAT_FORM },
    [1066] = { name = "Aquatic Form", icon = ICONS.AQUATIC_FORM },
    [783] = { name = "Travel Form", icon = ICONS.TRAVEL_FORM },
    [24858] = { name = "Moonkin Form", icon = ICONS.MOONKIN_FORM },
    [51430] = { name = "Moonkin Form", icon = ICONS.MOONKIN_FORM },
    [45705] = { name = "Tree of Life Form", icon = ICONS.TREE_FORM },

    -- Growl (Taunt)
    [6795] = { name = "Growl", icon = ICONS.GROWL },

    -- Challenging Roar
    [5209] = { name = "Challenging Roar", icon = ICONS.CHALLENGING_ROAR },

    -- Maul (all ranks)
    [6807] = { name = "Maul", icon = ICONS.MAUL },
    [6808] = { name = "Maul", icon = ICONS.MAUL },
    [6809] = { name = "Maul", icon = ICONS.MAUL },
    [8972] = { name = "Maul", icon = ICONS.MAUL },
    [9745] = { name = "Maul", icon = ICONS.MAUL },
    [9880] = { name = "Maul", icon = ICONS.MAUL },
    [9881] = { name = "Maul", icon = ICONS.MAUL },

    -- Swipe (all ranks)
    [779] = { name = "Swipe", icon = ICONS.SWIPE },
    [780] = { name = "Swipe", icon = ICONS.SWIPE },
    [769] = { name = "Swipe", icon = ICONS.SWIPE },
    [9754] = { name = "Swipe", icon = ICONS.SWIPE },
    [9908] = { name = "Swipe", icon = ICONS.SWIPE },

    -- Bash (all ranks)
    [5211] = { name = "Bash", icon = ICONS.BASH },
    [6798] = { name = "Bash", icon = ICONS.BASH },
    [8983] = { name = "Bash", icon = ICONS.BASH },

    -- Demoralizing Roar (all ranks)
    [99] = { name = "Demoralizing Roar", icon = ICONS.DEMORALIZING_ROAR },
    [1735] = { name = "Demoralizing Roar", icon = ICONS.DEMORALIZING_ROAR },
    [9490] = { name = "Demoralizing Roar", icon = ICONS.DEMORALIZING_ROAR },
    [9747] = { name = "Demoralizing Roar", icon = ICONS.DEMORALIZING_ROAR },
    [9898] = { name = "Demoralizing Roar", icon = ICONS.DEMORALIZING_ROAR },

    -- Enrage
    [5229] = { name = "Enrage", icon = ICONS.ENRAGE },

    -- Frenzied Regeneration
    [22842] = { name = "Frenzied Regeneration", icon = ICONS.FRENZIED_REGEN },
    [22895] = { name = "Frenzied Regeneration", icon = ICONS.FRENZIED_REGEN },
    [22896] = { name = "Frenzied Regeneration", icon = ICONS.FRENZIED_REGEN },

    -- Barkskin
    [22812] = { name = "Barkskin", icon = ICONS.BARKSKIN },
    [51401] = { name = "Barkskin", icon = ICONS.BARKSKIN },
    [51451] = { name = "Barkskin", icon = ICONS.BARKSKIN },
    [51452] = { name = "Barkskin", icon = ICONS.BARKSKIN },

    -- Healing Touch (all ranks)
    [5185] = { name = "Healing Touch", icon = ICONS.HEALING_TOUCH },
    [5186] = { name = "Healing Touch", icon = ICONS.HEALING_TOUCH },
    [5187] = { name = "Healing Touch", icon = ICONS.HEALING_TOUCH },
    [5188] = { name = "Healing Touch", icon = ICONS.HEALING_TOUCH },
    [5189] = { name = "Healing Touch", icon = ICONS.HEALING_TOUCH },
    [6778] = { name = "Healing Touch", icon = ICONS.HEALING_TOUCH },
    [8903] = { name = "Healing Touch", icon = ICONS.HEALING_TOUCH },
    [9758] = { name = "Healing Touch", icon = ICONS.HEALING_TOUCH },
    [9888] = { name = "Healing Touch", icon = ICONS.HEALING_TOUCH },
    [9889] = { name = "Healing Touch", icon = ICONS.HEALING_TOUCH },
    [25297] = { name = "Healing Touch", icon = ICONS.HEALING_TOUCH },

    -- Mark of the Wild (all ranks)
    [1126] = { name = "Mark of the Wild", icon = ICONS.MARK_OF_WILD },
    [5232] = { name = "Mark of the Wild", icon = ICONS.MARK_OF_WILD },
    [6756] = { name = "Mark of the Wild", icon = ICONS.MARK_OF_WILD },
    [5234] = { name = "Mark of the Wild", icon = ICONS.MARK_OF_WILD },
    [8907] = { name = "Mark of the Wild", icon = ICONS.MARK_OF_WILD },
    [9884] = { name = "Mark of the Wild", icon = ICONS.MARK_OF_WILD },
    [9885] = { name = "Mark of the Wild", icon = ICONS.MARK_OF_WILD },

    -- Gift of the Wild
    [21849] = { name = "Gift of the Wild", icon = ICONS.GIFT_OF_WILD },
    [21850] = { name = "Gift of the Wild", icon = ICONS.GIFT_OF_WILD },

    -- Wrath (all ranks)
    [5176] = { name = "Wrath", icon = ICONS.WRATH },
    [5177] = { name = "Wrath", icon = ICONS.WRATH },
    [5178] = { name = "Wrath", icon = ICONS.WRATH },
    [5179] = { name = "Wrath", icon = ICONS.WRATH },
    [5180] = { name = "Wrath", icon = ICONS.WRATH },
    [6780] = { name = "Wrath", icon = ICONS.WRATH },
    [8905] = { name = "Wrath", icon = ICONS.WRATH },
    [9912] = { name = "Wrath", icon = ICONS.WRATH },
    [45967] = { name = "Wrath", icon = ICONS.WRATH },

    -- Rejuvenation (all ranks)
    [774] = { name = "Rejuvenation", icon = ICONS.REJUVENATION },
    [1058] = { name = "Rejuvenation", icon = ICONS.REJUVENATION },
    [1430] = { name = "Rejuvenation", icon = ICONS.REJUVENATION },
    [2090] = { name = "Rejuvenation", icon = ICONS.REJUVENATION },
    [2091] = { name = "Rejuvenation", icon = ICONS.REJUVENATION },
    [3627] = { name = "Rejuvenation", icon = ICONS.REJUVENATION },
    [8910] = { name = "Rejuvenation", icon = ICONS.REJUVENATION },
    [9839] = { name = "Rejuvenation", icon = ICONS.REJUVENATION },
    [9840] = { name = "Rejuvenation", icon = ICONS.REJUVENATION },
    [9841] = { name = "Rejuvenation", icon = ICONS.REJUVENATION },
    [25299] = { name = "Rejuvenation", icon = ICONS.REJUVENATION },

    -- Moonfire (all ranks)
    [8921] = { name = "Moonfire", icon = ICONS.MOONFIRE },
    [8924] = { name = "Moonfire", icon = ICONS.MOONFIRE },
    [8925] = { name = "Moonfire", icon = ICONS.MOONFIRE },
    [8926] = { name = "Moonfire", icon = ICONS.MOONFIRE },
    [8927] = { name = "Moonfire", icon = ICONS.MOONFIRE },
    [8928] = { name = "Moonfire", icon = ICONS.MOONFIRE },
    [8929] = { name = "Moonfire", icon = ICONS.MOONFIRE },
    [9833] = { name = "Moonfire", icon = ICONS.MOONFIRE },
    [9834] = { name = "Moonfire", icon = ICONS.MOONFIRE },
    [9835] = { name = "Moonfire", icon = ICONS.MOONFIRE },

    -- Starfire (all ranks)
    [2912] = { name = "Starfire", icon = ICONS.STARFIRE },
    [8949] = { name = "Starfire", icon = ICONS.STARFIRE },
    [8950] = { name = "Starfire", icon = ICONS.STARFIRE },
    [8951] = { name = "Starfire", icon = ICONS.STARFIRE },
    [9875] = { name = "Starfire", icon = ICONS.STARFIRE },
    [9876] = { name = "Starfire", icon = ICONS.STARFIRE },
    [25298] = { name = "Starfire", icon = ICONS.STARFIRE },

    -- Thorns (all ranks)
    [467] = { name = "Thorns", icon = ICONS.THORNS },
    [782] = { name = "Thorns", icon = ICONS.THORNS },
    [1075] = { name = "Thorns", icon = ICONS.THORNS },
    [8914] = { name = "Thorns", icon = ICONS.THORNS },
    [9756] = { name = "Thorns", icon = ICONS.THORNS },
    [9910] = { name = "Thorns", icon = ICONS.THORNS },

    -- Regrowth (all ranks)
    [8936] = { name = "Regrowth", icon = ICONS.REGROWTH },
    [8938] = { name = "Regrowth", icon = ICONS.REGROWTH },
    [8939] = { name = "Regrowth", icon = ICONS.REGROWTH },
    [8940] = { name = "Regrowth", icon = ICONS.REGROWTH },
    [8941] = { name = "Regrowth", icon = ICONS.REGROWTH },
    [9750] = { name = "Regrowth", icon = ICONS.REGROWTH },
    [9856] = { name = "Regrowth", icon = ICONS.REGROWTH },
    [9857] = { name = "Regrowth", icon = ICONS.REGROWTH },
    [9858] = { name = "Regrowth", icon = ICONS.REGROWTH },

    -- Entangling Roots (all ranks)
    [339] = { name = "Entangling Roots", icon = ICONS.ENTANGLING_ROOTS },
    [1062] = { name = "Entangling Roots", icon = ICONS.ENTANGLING_ROOTS },
    [5195] = { name = "Entangling Roots", icon = ICONS.ENTANGLING_ROOTS },
    [5196] = { name = "Entangling Roots", icon = ICONS.ENTANGLING_ROOTS },
    [9852] = { name = "Entangling Roots", icon = ICONS.ENTANGLING_ROOTS },
    [9853] = { name = "Entangling Roots", icon = ICONS.ENTANGLING_ROOTS },

    -- Faerie Fire (all ranks)
    [770] = { name = "Faerie Fire", icon = ICONS.FAERIE_FIRE },
    [778] = { name = "Faerie Fire", icon = ICONS.FAERIE_FIRE },
    [9749] = { name = "Faerie Fire", icon = ICONS.FAERIE_FIRE },
    [16857] = { name = "Faerie Fire (Feral)", icon = ICONS.FAERIE_FIRE_FERAL },
    [17390] = { name = "Faerie Fire (Feral)", icon = ICONS.FAERIE_FIRE_FERAL },
    [17391] = { name = "Faerie Fire (Feral)", icon = ICONS.FAERIE_FIRE_FERAL },
    [17392] = { name = "Faerie Fire (Feral)", icon = ICONS.FAERIE_FIRE_FERAL },

    -- Nature's Grasp (all ranks)
    [16689] = { name = "Nature's Grasp", icon = ICONS.NATURES_GRASP },
    [16810] = { name = "Nature's Grasp", icon = ICONS.NATURES_GRASP },
    [16811] = { name = "Nature's Grasp", icon = ICONS.NATURES_GRASP },
    [16812] = { name = "Nature's Grasp", icon = ICONS.NATURES_GRASP },
    [16813] = { name = "Nature's Grasp", icon = ICONS.NATURES_GRASP },
    [17329] = { name = "Nature's Grasp", icon = ICONS.NATURES_GRASP },

    -- Hibernate (all ranks)
    [2637] = { name = "Hibernate", icon = ICONS.HIBERNATE },
    [18657] = { name = "Hibernate", icon = ICONS.HIBERNATE },
    [18658] = { name = "Hibernate", icon = ICONS.HIBERNATE },

    -- Cat abilities
    [1082] = { name = "Claw", icon = ICONS.CLAW },
    [3029] = { name = "Claw", icon = ICONS.CLAW },
    [5201] = { name = "Claw", icon = ICONS.CLAW },
    [9849] = { name = "Claw", icon = ICONS.CLAW },
    [9850] = { name = "Claw", icon = ICONS.CLAW },
    [1079] = { name = "Rip", icon = ICONS.RIP },
    [9492] = { name = "Rip", icon = ICONS.RIP },
    [9493] = { name = "Rip", icon = ICONS.RIP },
    [9752] = { name = "Rip", icon = ICONS.RIP },
    [9894] = { name = "Rip", icon = ICONS.RIP },
    [9896] = { name = "Rip", icon = ICONS.RIP },
    [5215] = { name = "Prowl", icon = ICONS.PROWL },
    [6783] = { name = "Prowl", icon = ICONS.PROWL },
    [9913] = { name = "Prowl", icon = ICONS.PROWL },
    [5221] = { name = "Shred", icon = ICONS.SHRED },
    [6800] = { name = "Shred", icon = ICONS.SHRED },
    [8992] = { name = "Shred", icon = ICONS.SHRED },
    [9829] = { name = "Shred", icon = ICONS.SHRED },
    [9830] = { name = "Shred", icon = ICONS.SHRED },
    [45969] = { name = "Shred", icon = ICONS.SHRED },
    [5217] = { name = "Tiger's Fury", icon = ICONS.TIGERS_FURY },
    [6793] = { name = "Tiger's Fury", icon = ICONS.TIGERS_FURY },
    [9845] = { name = "Tiger's Fury", icon = ICONS.TIGERS_FURY },
    [9846] = { name = "Tiger's Fury", icon = ICONS.TIGERS_FURY },
    [1822] = { name = "Rake", icon = ICONS.RAKE },
    [1823] = { name = "Rake", icon = ICONS.RAKE },
    [1824] = { name = "Rake", icon = ICONS.RAKE },
    [9904] = { name = "Rake", icon = ICONS.RAKE },
    [22557] = { name = "Ferocious Bite", icon = ICONS.FEROCIOUS_BITE },
    [22568] = { name = "Ferocious Bite", icon = ICONS.FEROCIOUS_BITE },
    [22827] = { name = "Ferocious Bite", icon = ICONS.FEROCIOUS_BITE },
    [22828] = { name = "Ferocious Bite", icon = ICONS.FEROCIOUS_BITE },
    [22829] = { name = "Ferocious Bite", icon = ICONS.FEROCIOUS_BITE },
    [31018] = { name = "Ferocious Bite", icon = ICONS.FEROCIOUS_BITE },
    [1850] = { name = "Dash", icon = ICONS.DASH },
    [9821] = { name = "Dash", icon = ICONS.DASH },
    [6785] = { name = "Ravage", icon = ICONS.RAVAGE },
    [9866] = { name = "Ravage", icon = ICONS.RAVAGE },
    [9867] = { name = "Ravage", icon = ICONS.RAVAGE },
    [9005] = { name = "Pounce", icon = ICONS.POUNCE },
    [9823] = { name = "Pounce", icon = ICONS.POUNCE },
    [9827] = { name = "Pounce", icon = ICONS.POUNCE },
    [8998] = { name = "Cower", icon = ICONS.COWER },
    [9000] = { name = "Cower", icon = ICONS.COWER },
    [9892] = { name = "Cower", icon = ICONS.COWER },

    -- Other Druid spells
    [18960] = { name = "Teleport: Moonglade", icon = ICONS.TELEPORT_MOONGLADE },
    [20484] = { name = "Rebirth", icon = ICONS.REBIRTH },
    [20739] = { name = "Rebirth", icon = ICONS.REBIRTH },
    [20742] = { name = "Rebirth", icon = ICONS.REBIRTH },
    [20747] = { name = "Rebirth", icon = ICONS.REBIRTH },
    [20748] = { name = "Rebirth", icon = ICONS.REBIRTH },
    [5570] = { name = "Insect Swarm", icon = ICONS.INSECT_SWARM },
    [24974] = { name = "Insect Swarm", icon = ICONS.INSECT_SWARM },
    [24975] = { name = "Insect Swarm", icon = ICONS.INSECT_SWARM },
    [24976] = { name = "Insect Swarm", icon = ICONS.INSECT_SWARM },
    [24977] = { name = "Insect Swarm", icon = ICONS.INSECT_SWARM },
    [2782] = { name = "Remove Curse", icon = ICONS.REMOVE_CURSE },
    [2893] = { name = "Abolish Poison", icon = ICONS.ABOLISH_POISON },
    [8946] = { name = "Cure Poison", icon = ICONS.CURE_POISON },
    [2908] = { name = "Soothe Animal", icon = ICONS.SOOTHE_ANIMAL },
    [8955] = { name = "Soothe Animal", icon = ICONS.SOOTHE_ANIMAL },
    [9901] = { name = "Soothe Animal", icon = ICONS.SOOTHE_ANIMAL },
    [740] = { name = "Tranquility", icon = ICONS.TRANQUILITY },
    [8918] = { name = "Tranquility", icon = ICONS.TRANQUILITY },
    [9862] = { name = "Tranquility", icon = ICONS.TRANQUILITY },
    [9863] = { name = "Tranquility", icon = ICONS.TRANQUILITY },
    [16914] = { name = "Hurricane", icon = ICONS.HURRICANE },
    [17401] = { name = "Hurricane", icon = ICONS.HURRICANE },
    [17402] = { name = "Hurricane", icon = ICONS.HURRICANE },
    [22570] = { name = "Mangle", icon = ICONS.MANGLE },
    [5225] = { name = "Track Humanoids", icon = ICONS.TRACK_HUMANOIDS },

    -- Turtle WoW Druid spells
    [45708] = { name = "Berserk", icon = ICONS.BERSERK },
    [45736] = { name = "Savage Bite", icon = ICONS.SAVAGE_BITE },
    [51397] = { name = "Efflorescence", icon = ICONS.REJUVENATION },
    [51398] = { name = "Swift Travel Form", icon = ICONS.TRAVEL_FORM },
}

-- ============================================================================
-- PALADIN SPELLS
-- ============================================================================
local paladinSpells = {
    -- Auras
    [465] = { name = "Devotion Aura", icon = ICONS.DEVOTION_AURA },
    [10290] = { name = "Devotion Aura", icon = ICONS.DEVOTION_AURA },
    [643] = { name = "Devotion Aura", icon = ICONS.DEVOTION_AURA },
    [10291] = { name = "Devotion Aura", icon = ICONS.DEVOTION_AURA },
    [1032] = { name = "Devotion Aura", icon = ICONS.DEVOTION_AURA },
    [10292] = { name = "Devotion Aura", icon = ICONS.DEVOTION_AURA },
    [10293] = { name = "Devotion Aura", icon = ICONS.DEVOTION_AURA },
    [7294] = { name = "Retribution Aura", icon = ICONS.RETRIBUTION_AURA },
    [10298] = { name = "Retribution Aura", icon = ICONS.RETRIBUTION_AURA },
    [10299] = { name = "Retribution Aura", icon = ICONS.RETRIBUTION_AURA },
    [10300] = { name = "Retribution Aura", icon = ICONS.RETRIBUTION_AURA },
    [10301] = { name = "Retribution Aura", icon = ICONS.RETRIBUTION_AURA },
    [19746] = { name = "Concentration Aura", icon = ICONS.CONCENTRATION_AURA },
    [19876] = { name = "Shadow Resistance Aura", icon = ICONS.SHADOW_RESIST_AURA },
    [19895] = { name = "Shadow Resistance Aura", icon = ICONS.SHADOW_RESIST_AURA },
    [19896] = { name = "Shadow Resistance Aura", icon = ICONS.SHADOW_RESIST_AURA },
    [19888] = { name = "Frost Resistance Aura", icon = ICONS.FROST_RESIST_AURA },
    [19897] = { name = "Frost Resistance Aura", icon = ICONS.FROST_RESIST_AURA },
    [19898] = { name = "Frost Resistance Aura", icon = ICONS.FROST_RESIST_AURA },
    [19891] = { name = "Fire Resistance Aura", icon = ICONS.FIRE_RESIST_AURA },
    [19899] = { name = "Fire Resistance Aura", icon = ICONS.FIRE_RESIST_AURA },
    [19900] = { name = "Fire Resistance Aura", icon = ICONS.FIRE_RESIST_AURA },
    [20218] = { name = "Sanctity Aura", icon = ICONS.SANCTITY_AURA },

    -- Hand of Reckoning (Taunt - Turtle WoW)
    [51302] = { name = "Hand of Reckoning", icon = ICONS.HAND_RECKONING },

    -- Holy Light (all ranks)
    [635] = { name = "Holy Light", icon = ICONS.HOLY_LIGHT },
    [639] = { name = "Holy Light", icon = ICONS.HOLY_LIGHT },
    [647] = { name = "Holy Light", icon = ICONS.HOLY_LIGHT },
    [1026] = { name = "Holy Light", icon = ICONS.HOLY_LIGHT },
    [3472] = { name = "Holy Light", icon = ICONS.HOLY_LIGHT },
    [10328] = { name = "Holy Light", icon = ICONS.HOLY_LIGHT },
    [10329] = { name = "Holy Light", icon = ICONS.HOLY_LIGHT },
    [25292] = { name = "Holy Light", icon = ICONS.HOLY_LIGHT },
    [19968] = { name = "Holy Light", icon = ICONS.HOLY_LIGHT },
    [19980] = { name = "Holy Light", icon = ICONS.HOLY_LIGHT },
    [19981] = { name = "Holy Light", icon = ICONS.HOLY_LIGHT },
    [19982] = { name = "Holy Light", icon = ICONS.HOLY_LIGHT },

    -- Flash of Light (all ranks)
    [19750] = { name = "Flash of Light", icon = ICONS.FLASH_LIGHT },
    [19939] = { name = "Flash of Light", icon = ICONS.FLASH_LIGHT },
    [19940] = { name = "Flash of Light", icon = ICONS.FLASH_LIGHT },
    [19941] = { name = "Flash of Light", icon = ICONS.FLASH_LIGHT },
    [19942] = { name = "Flash of Light", icon = ICONS.FLASH_LIGHT },
    [19943] = { name = "Flash of Light", icon = ICONS.FLASH_LIGHT },
    [19993] = { name = "Flash of Light", icon = ICONS.FLASH_LIGHT },
    [51743] = { name = "Flash of Light", icon = ICONS.FLASH_LIGHT },

    -- Seals
    [20154] = { name = "Seal of Righteousness", icon = ICONS.SEAL_RIGHTEOUSNESS },
    [21084] = { name = "Seal of Righteousness", icon = ICONS.SEAL_RIGHTEOUSNESS },
    [20287] = { name = "Seal of Righteousness", icon = ICONS.SEAL_RIGHTEOUSNESS },
    [20288] = { name = "Seal of Righteousness", icon = ICONS.SEAL_RIGHTEOUSNESS },
    [20289] = { name = "Seal of Righteousness", icon = ICONS.SEAL_RIGHTEOUSNESS },
    [20290] = { name = "Seal of Righteousness", icon = ICONS.SEAL_RIGHTEOUSNESS },
    [20291] = { name = "Seal of Righteousness", icon = ICONS.SEAL_RIGHTEOUSNESS },
    [20292] = { name = "Seal of Righteousness", icon = ICONS.SEAL_RIGHTEOUSNESS },
    [20293] = { name = "Seal of Righteousness", icon = ICONS.SEAL_RIGHTEOUSNESS },
    [21082] = { name = "Seal of the Crusader", icon = ICONS.SEAL_CRUSADER },
    [20162] = { name = "Seal of the Crusader", icon = ICONS.SEAL_CRUSADER },
    [20305] = { name = "Seal of the Crusader", icon = ICONS.SEAL_CRUSADER },
    [20306] = { name = "Seal of the Crusader", icon = ICONS.SEAL_CRUSADER },
    [20307] = { name = "Seal of the Crusader", icon = ICONS.SEAL_CRUSADER },
    [20308] = { name = "Seal of the Crusader", icon = ICONS.SEAL_CRUSADER },
    [20166] = { name = "Seal of Wisdom", icon = ICONS.SEAL_WISDOM },
    [20356] = { name = "Seal of Wisdom", icon = ICONS.SEAL_WISDOM },
    [20357] = { name = "Seal of Wisdom", icon = ICONS.SEAL_WISDOM },
    [51745] = { name = "Seal of Wisdom", icon = ICONS.SEAL_WISDOM },
    [51746] = { name = "Seal of Wisdom", icon = ICONS.SEAL_WISDOM },
    [20164] = { name = "Seal of Justice", icon = ICONS.SEAL_JUSTICE },
    [20165] = { name = "Seal of Light", icon = ICONS.SEAL_LIGHT },
    [20347] = { name = "Seal of Light", icon = ICONS.SEAL_LIGHT },
    [20348] = { name = "Seal of Light", icon = ICONS.SEAL_LIGHT },
    [20349] = { name = "Seal of Light", icon = ICONS.SEAL_LIGHT },
    [45802] = { name = "Seal of the Martyr", icon = ICONS.SEAL_MARTYR },

    -- Judgement
    [20271] = { name = "Judgement", icon = ICONS.JUDGEMENT },
    [20187] = { name = "Judgement of Righteousness", icon = ICONS.JUDGEMENT_RIGHTEOUSNESS },
    [20280] = { name = "Judgement of Righteousness", icon = ICONS.JUDGEMENT_RIGHTEOUSNESS },
    [20281] = { name = "Judgement of Righteousness", icon = ICONS.JUDGEMENT_RIGHTEOUSNESS },
    [20282] = { name = "Judgement of Righteousness", icon = ICONS.JUDGEMENT_RIGHTEOUSNESS },
    [20283] = { name = "Judgement of Righteousness", icon = ICONS.JUDGEMENT_RIGHTEOUSNESS },
    [20284] = { name = "Judgement of Righteousness", icon = ICONS.JUDGEMENT_RIGHTEOUSNESS },
    [20285] = { name = "Judgement of Righteousness", icon = ICONS.JUDGEMENT_RIGHTEOUSNESS },
    [20286] = { name = "Judgement of Righteousness", icon = ICONS.JUDGEMENT_RIGHTEOUSNESS },

    -- Blessings
    [19740] = { name = "Blessing of Might", icon = ICONS.BLESSING_MIGHT },
    [19834] = { name = "Blessing of Might", icon = ICONS.BLESSING_MIGHT },
    [19835] = { name = "Blessing of Might", icon = ICONS.BLESSING_MIGHT },
    [19836] = { name = "Blessing of Might", icon = ICONS.BLESSING_MIGHT },
    [19837] = { name = "Blessing of Might", icon = ICONS.BLESSING_MIGHT },
    [19838] = { name = "Blessing of Might", icon = ICONS.BLESSING_MIGHT },
    [25291] = { name = "Blessing of Might", icon = ICONS.BLESSING_MIGHT },
    [19742] = { name = "Blessing of Wisdom", icon = ICONS.BLESSING_WISDOM },
    [19850] = { name = "Blessing of Wisdom", icon = ICONS.BLESSING_WISDOM },
    [19852] = { name = "Blessing of Wisdom", icon = ICONS.BLESSING_WISDOM },
    [19853] = { name = "Blessing of Wisdom", icon = ICONS.BLESSING_WISDOM },
    [19854] = { name = "Blessing of Wisdom", icon = ICONS.BLESSING_WISDOM },
    [25290] = { name = "Blessing of Wisdom", icon = ICONS.BLESSING_WISDOM },
    [20217] = { name = "Blessing of Kings", icon = ICONS.BLESSING_KINGS },
    [1038] = { name = "Blessing of Salvation", icon = ICONS.BLESSING_SALVATION },
    [19977] = { name = "Blessing of Light", icon = ICONS.BLESSING_LIGHT },
    [19978] = { name = "Blessing of Light", icon = ICONS.BLESSING_LIGHT },
    [19979] = { name = "Blessing of Light", icon = ICONS.BLESSING_LIGHT },
    [25782] = { name = "Greater Blessing of Might", icon = ICONS.GREATER_BLESSING_MIGHT },
    [25916] = { name = "Greater Blessing of Might", icon = ICONS.GREATER_BLESSING_MIGHT },
    [25894] = { name = "Greater Blessing of Wisdom", icon = ICONS.GREATER_BLESSING_WISDOM },
    [25918] = { name = "Greater Blessing of Wisdom", icon = ICONS.GREATER_BLESSING_WISDOM },
    [25898] = { name = "Greater Blessing of Kings", icon = ICONS.GREATER_BLESSING_KINGS },
    [25895] = { name = "Greater Blessing of Salvation", icon = ICONS.GREATER_BLESSING_SALVATION },
    [25890] = { name = "Greater Blessing of Light", icon = ICONS.GREATER_BLESSING_LIGHT },
    [25899] = { name = "Greater Blessing of Sanctuary", icon = ICONS.GREATER_BLESSING_SANCTUARY },

    -- Hands
    [1022] = { name = "Hand of Protection", icon = ICONS.HAND_PROTECTION },
    [5599] = { name = "Hand of Protection", icon = ICONS.HAND_PROTECTION },
    [10278] = { name = "Hand of Protection", icon = ICONS.HAND_PROTECTION },
    [1044] = { name = "Hand of Freedom", icon = ICONS.HAND_FREEDOM },
    [6940] = { name = "Hand of Sacrifice", icon = ICONS.HAND_SACRIFICE },
    [20729] = { name = "Hand of Sacrifice", icon = ICONS.HAND_SACRIFICE },

    -- Divine spells
    [498] = { name = "Divine Protection", icon = ICONS.DIVINE_PROTECTION },
    [5573] = { name = "Divine Protection", icon = ICONS.DIVINE_PROTECTION },
    [642] = { name = "Divine Shield", icon = ICONS.DIVINE_SHIELD },
    [1020] = { name = "Divine Shield", icon = ICONS.DIVINE_SHIELD },
    [19752] = { name = "Divine Intervention", icon = ICONS.DIVINE_INTERVENTION },
    [633] = { name = "Lay on Hands", icon = ICONS.LAY_ON_HANDS },
    [2800] = { name = "Lay on Hands", icon = ICONS.LAY_ON_HANDS },
    [10310] = { name = "Lay on Hands", icon = ICONS.LAY_ON_HANDS },

    -- Hammer of Justice
    [853] = { name = "Hammer of Justice", icon = ICONS.HAMMER_JUSTICE },
    [5588] = { name = "Hammer of Justice", icon = ICONS.HAMMER_JUSTICE },
    [5589] = { name = "Hammer of Justice", icon = ICONS.HAMMER_JUSTICE },
    [10308] = { name = "Hammer of Justice", icon = ICONS.HAMMER_JUSTICE },

    -- Hammer of Wrath
    [24275] = { name = "Hammer of Wrath", icon = ICONS.HAMMER_WRATH },
    [24274] = { name = "Hammer of Wrath", icon = ICONS.HAMMER_WRATH },
    [24239] = { name = "Hammer of Wrath", icon = ICONS.HAMMER_WRATH },

    -- Holy Shock
    [25914] = { name = "Holy Shock", icon = ICONS.HOLY_SHOCK },
    [25911] = { name = "Holy Shock", icon = ICONS.HOLY_SHOCK },
    [25912] = { name = "Holy Shock", icon = ICONS.HOLY_SHOCK },
    [25913] = { name = "Holy Shock", icon = ICONS.HOLY_SHOCK },
    [25902] = { name = "Holy Shock", icon = ICONS.HOLY_SHOCK },
    [25903] = { name = "Holy Shock", icon = ICONS.HOLY_SHOCK },

    -- Exorcism
    [879] = { name = "Exorcism", icon = ICONS.EXORCISM },
    [5614] = { name = "Exorcism", icon = ICONS.EXORCISM },
    [5615] = { name = "Exorcism", icon = ICONS.EXORCISM },
    [10312] = { name = "Exorcism", icon = ICONS.EXORCISM },
    [10313] = { name = "Exorcism", icon = ICONS.EXORCISM },
    [10314] = { name = "Exorcism", icon = ICONS.EXORCISM },

    -- Holy Wrath
    [2812] = { name = "Holy Wrath", icon = ICONS.HOLY_WRATH },
    [10318] = { name = "Holy Wrath", icon = ICONS.HOLY_WRATH },

    -- Consecration
    [26573] = { name = "Consecration", icon = ICONS.CONSECRATION },
    [20116] = { name = "Consecration", icon = ICONS.CONSECRATION },
    [20922] = { name = "Consecration", icon = ICONS.CONSECRATION },
    [20923] = { name = "Consecration", icon = ICONS.CONSECRATION },
    [20924] = { name = "Consecration", icon = ICONS.CONSECRATION },

    -- Crusader Strike (Turtle WoW)
    [2537] = { name = "Crusader Strike", icon = ICONS.CRUSADER_STRIKE },
    [8823] = { name = "Crusader Strike", icon = ICONS.CRUSADER_STRIKE },
    [8824] = { name = "Crusader Strike", icon = ICONS.CRUSADER_STRIKE },
    [10336] = { name = "Crusader Strike", icon = ICONS.CRUSADER_STRIKE },
    [10337] = { name = "Crusader Strike", icon = ICONS.CRUSADER_STRIKE },

    -- Holy Strike
    [679] = { name = "Holy Strike", icon = ICONS.HOLY_STRIKE },
    [678] = { name = "Holy Strike", icon = ICONS.HOLY_STRIKE },
    [1866] = { name = "Holy Strike", icon = ICONS.HOLY_STRIKE },
    [680] = { name = "Holy Strike", icon = ICONS.HOLY_STRIKE },
    [2495] = { name = "Holy Strike", icon = ICONS.HOLY_STRIKE },
    [5569] = { name = "Holy Strike", icon = ICONS.HOLY_STRIKE },
    [10332] = { name = "Holy Strike", icon = ICONS.HOLY_STRIKE },

    -- Repentance
    [20066] = { name = "Repentance", icon = ICONS.REPENTANCE },
    [51557] = { name = "Repentance", icon = ICONS.REPENTANCE },
    [51558] = { name = "Repentance", icon = ICONS.REPENTANCE },

    -- Other
    [25780] = { name = "Righteous Fury", icon = ICONS.RIGHTEOUS_FURY },
    [25781] = { name = "Righteous Fury", icon = ICONS.RIGHTEOUS_FURY },
    [1152] = { name = "Purify", icon = ICONS.PURIFY },
    [4987] = { name = "Cleanse", icon = ICONS.CLEANSE },
    [5502] = { name = "Sense Undead", icon = ICONS.SENSE_UNDEAD },
    [2878] = { name = "Turn Undead", icon = ICONS.TURN_UNDEAD },
    [5627] = { name = "Turn Undead", icon = ICONS.TURN_UNDEAD },
    [10326] = { name = "Turn Undead", icon = ICONS.TURN_UNDEAD },
    [7328] = { name = "Redemption", icon = ICONS.REDEMPTION },
    [10322] = { name = "Redemption", icon = ICONS.REDEMPTION },
    [10324] = { name = "Redemption", icon = ICONS.REDEMPTION },
    [20772] = { name = "Redemption", icon = ICONS.REDEMPTION },
    [20773] = { name = "Redemption", icon = ICONS.REDEMPTION },
    [13819] = { name = "Summon Warhorse", icon = ICONS.SUMMON_WARHORSE },
    [23214] = { name = "Summon Charger", icon = ICONS.SUMMON_CHARGER },
}

-- ============================================================================
-- MERGE ALL SPELLS INTO IchaTaunt_SpellDB
-- ============================================================================
for id, data in pairs(shamanSpells) do
    IchaTaunt_SpellDB[id] = data
end

for id, data in pairs(warriorSpells) do
    IchaTaunt_SpellDB[id] = data
end

for id, data in pairs(druidSpells) do
    IchaTaunt_SpellDB[id] = data
end

for id, data in pairs(paladinSpells) do
    IchaTaunt_SpellDB[id] = data
end

-- Helper function to lookup spell by ID
function IchaTaunt_SpellDB_Lookup(spellID)
    return IchaTaunt_SpellDB[spellID]
end

-- Helper function to lookup spell by name (returns first match)
function IchaTaunt_SpellDB_LookupByName(spellName)
    local lowerName = strlower(spellName)
    for id, data in pairs(IchaTaunt_SpellDB) do
        if strlower(data.name) == lowerName then
            return id, data
        end
    end
    return nil, nil
end
