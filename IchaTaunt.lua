-- IchaTaunt AddOn (Turtle WoW)
-- Drag-sort list, per-caster cooldowns, manual taunter assignment, PallyPower-style sync

local ADDON_NAME = "IchaTaunt"
local IchaTaunt = CreateFrame("Frame", ADDON_NAME)

-- Addon message prefix for sync communication (must be defined before event handler)
ICHAT_PREFIX = "ICHAT"

-- No-op; chat printing removed for clean UI
local function IchaTaunt_Print(msg) end

-- All taunts broadcast on cast (range-independent; combat log has ~100 yd limit)
IchaTaunt.taunters = {}          -- [playerName] = true if manually assigned
IchaTaunt.order = {}             -- ordered list of player names
IchaTaunt.cooldowns = {}         -- per-player spell cooldown tracking
IchaTaunt.frame = nil
IchaTaunt.locked = false

-- Epoch time for persisting cooldowns across reload (GetTime() resets on reload)
local function GetEpochTime()
    if time and type(time) == "function" then return time() end
    if os and os.time and type(os.time) == "function" then return os.time() end
    return 0
end

-- SavedVariables
IchaTauntDB = IchaTauntDB or {
    showInRaidOnly = false,  -- false = show in party or raid; true = only show in raid
    mainTank = nil,
    taunterOrder = {},
    taunters = {},
    position = { x = 300, y = 300 },
    theme = "default", -- default, dark, elvui
    autoSync = true, -- automatically sync with raid
    locked = false, -- tracker position locked
    cooldownEndTimes = {}, -- [normalizedPlayerName][spellID] = epoch when CD ends (persist across reload)
}

-- Theme data is loaded from IchaTaunt_Themes.lua

-- ============================================
-- THEME FUNCTIONS
-- ============================================

-- Get current theme data
function IchaTaunt:GetTheme()
    local themeName = IchaTauntDB.theme or "default"
    return IchaTaunt_Themes[themeName] or IchaTaunt_Themes["default"]
end

-- Apply theme to tracker frame
function IchaTaunt:ApplyTrackerTheme()
    if not self.frame then return end

    local theme = self:GetTheme()
    local t = theme.tracker

    -- Apply backdrop (only show when unlocked)
    if not self.locked then
        self.frame:SetBackdrop(t.backdrop)
        self.frame:SetBackdropColor(unpack(t.bgColor))
        self.frame:SetBackdropBorderColor(unpack(t.borderColor))
    else
        -- Hide backdrop when locked - show only content
        self.frame:SetBackdrop(nil)
    end

    -- Update taunter bars if they exist
    self:RebuildList()
end

-- Set theme and apply
function IchaTaunt:SetTheme(themeName)
    if not IchaTaunt_Themes[themeName] then
        print("IchaTaunt: Unknown theme '" .. themeName .. "'. Available: default, dark, elvui")
        return
    end

    IchaTauntDB.theme = themeName
    print("IchaTaunt: Theme set to '" .. IchaTaunt_Themes[themeName].name .. "'")

    -- Apply to tracker
    self:ApplyTrackerTheme()

    -- Refresh config UI if open
    if self.taunterUI and self.taunterUI:IsVisible() then
        self:ApplyConfigTheme()
        self.taunterUI.RefreshPanels()
    end
end

-- Set scale for the tracker frame
function IchaTaunt:SetScale(scale)
    -- Clamp scale between 0.5 and 2.0
    if scale < 0.5 then scale = 0.5 end
    if scale > 2.0 then scale = 2.0 end

    if self.frame then
        -- Get current saved position (relative to screen center, already in screen coordinates)
        local savedX = IchaTauntDB.position.x or 0
        local savedY = IchaTauntDB.position.y or 0
        
        -- Apply new scale
        self.frame:SetScale(scale)
        
        -- Keep the same position (saved position is already in screen coordinates)
        -- No need to adjust - the position stays the same visually
        self.frame:ClearAllPoints()
        self.frame:SetPoint("CENTER", UIParent, "CENTER", savedX, savedY)
    end

    IchaTauntDB.scale = scale

    print("IchaTaunt: Scale set to " .. format("%.0f%%", scale * 100))
end

-- Apply saved scale to tracker
function IchaTaunt:ApplyScale()
    if self.frame and IchaTauntDB.scale then
        self.frame:SetScale(IchaTauntDB.scale)
    end
end

-- Apply theme to config window
function IchaTaunt:ApplyConfigTheme()
    if not self.taunterUI then return end

    local theme = self:GetTheme()
    local c = theme.config

    local f = self.taunterUI

    -- Apply main backdrop
    f:SetBackdrop(c.backdrop)
    f:SetBackdropColor(unpack(c.bgColor))

    -- Apply panel backdrops
    if f.leftPanel then
        f.leftPanel:SetBackdrop(c.panelBackdrop)
        f.leftPanel:SetBackdropColor(unpack(c.panelBgColor))
    end
    if f.rightPanel then
        f.rightPanel:SetBackdrop(c.panelBackdrop)
        f.rightPanel:SetBackdropColor(unpack(c.panelBgColor))
    end

    -- Apply title color
    if f.title then
        f.title:SetTextColor(unpack(c.titleColor))
    end
end

-- Use external spell configuration
-- All spell data is now in IchaTaunt_Spells.lua for easy editing

-- Event Registration
IchaTaunt:RegisterEvent("PLAYER_LOGIN")
IchaTaunt:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH") -- 1.12 combat log events
IchaTaunt:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
IchaTaunt:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF") -- Your own spell casts
IchaTaunt:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF") -- Your spell effects
IchaTaunt:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS") -- Your melee/spell hits
IchaTaunt:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES") -- Your misses
IchaTaunt:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE")
IchaTaunt:RegisterEvent("CHAT_MSG_SPELL_PARTY_DAMAGE")
IchaTaunt:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE")
IchaTaunt:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF") -- Party/raid member buffs
IchaTaunt:RegisterEvent("CHAT_MSG_SPELL_PARTY_BUFF") -- Party member buffs
IchaTaunt:RegisterEvent("CHAT_MSG_COMBAT_FRIENDLY_DEATH")
IchaTaunt:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE") -- Debuffs on creatures (Challenging Roar/Shout)
IchaTaunt:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF") -- Creature debuff messages
IchaTaunt:RegisterEvent("RAID_ROSTER_UPDATE")
IchaTaunt:RegisterEvent("PARTY_MEMBERS_CHANGED")
IchaTaunt:RegisterEvent("CHAT_MSG_ADDON")

IchaTaunt:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        IchaTaunt:Initialize()
    elseif event == "CHAT_MSG_SPELL_SELF_DAMAGE" or event == "CHAT_MSG_SPELL_SELF_BUFF" or
           event == "CHAT_MSG_SPELL_AURA_GONE_SELF" or event == "CHAT_MSG_COMBAT_SELF_HITS" or
           event == "CHAT_MSG_COMBAT_SELF_MISSES" or event == "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE" or
           event == "CHAT_MSG_SPELL_PARTY_DAMAGE" or event == "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE" or
           event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF" or event == "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE" or
           event == "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF" or event == "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE" or
           event == "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS" or event == "CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF" or
           event == "CHAT_MSG_SPELL_PARTY_BUFF" or event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" or
           event == "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF" then
        IchaTaunt:HandleCombatMessage(event)
    elseif event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
        IchaTaunt:RefreshRoster()
        -- Request sync when joining a group
        if (GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0) and not IchaTaunt:CanControl() then
            IchaTaunt:RequestSync()
        end
        -- Refresh config window if it's open (live feed)
        if IchaTaunt.taunterUI and IchaTaunt.taunterUI:IsVisible() and IchaTaunt.taunterUI.RefreshPanels then
            IchaTaunt.taunterUI.RefreshPanels()
            -- Schedule a delayed refresh to catch API timing issues
            -- (IsPartyLeader() may not update immediately when party forms)
            if not IchaTaunt.refreshTimer then
                IchaTaunt.refreshTimer = CreateFrame("Frame")
            end
            IchaTaunt.refreshTimer.elapsed = 0
            IchaTaunt.refreshTimer:SetScript("OnUpdate", function()
                this.elapsed = this.elapsed + arg1
                if this.elapsed >= 0.5 then
                    this:SetScript("OnUpdate", nil)
                    if IchaTaunt.taunterUI and IchaTaunt.taunterUI:IsVisible() and IchaTaunt.taunterUI.RefreshPanels then
                        IchaTaunt.taunterUI.RefreshPanels()
                    end
                end
            end)
        end
    elseif event == "CHAT_MSG_ADDON" then
        -- arg1 = prefix, arg2 = message, arg3 = channel, arg4 = sender
        if IchaTauntDB and IchaTauntDB.debugMode then
            print("[IchaTaunt Debug] CHAT_MSG_ADDON: prefix=" .. tostring(arg1) .. ", msg=" .. tostring(arg2) .. ", channel=" .. tostring(arg3) .. ", sender=" .. tostring(arg4))
        end

        if arg1 and arg2 and arg4 then
            if arg1 == ICHAT_PREFIX then
                -- Accept from any valid channel (PARTY, RAID, or possibly BATTLEGROUND)
                IchaTaunt:ParseSyncMessage(arg2, arg4)
            end
        end
    end
end)

function IchaTaunt:Initialize()
    print("IchaTaunt loaded. Type /it for config, /it help for commands.")
    -- Ensure IchaTauntDB is properly initialized
    if not IchaTauntDB then
        IchaTauntDB = {
            showInRaidOnly = false,  -- false = show in party or raid; true = only show in raid
            mainTank = nil,
            taunterOrder = {},
            taunters = {},
            position = { x = 0, y = 0 },
            debugMode = false,
        }
    else
        if not IchaTauntDB.position then
            IchaTauntDB.position = { x = 0, y = 0 }
        end

    end

    -- Add missing fields if they don't exist
    if IchaTauntDB.debugMode == nil then
        IchaTauntDB.debugMode = false
    end
    if IchaTauntDB.debugAllEvents == nil then
        IchaTauntDB.debugAllEvents = false
    end
    if not IchaTauntDB.taunterOrder then
        IchaTauntDB.taunterOrder = {}
    end
    if not IchaTauntDB.taunters then
        IchaTauntDB.taunters = {}
    end
    if not IchaTauntDB.cooldownEndTimes then
        IchaTauntDB.cooldownEndTimes = {}
    end
    if IchaTauntDB.autoSync == nil then
        IchaTauntDB.autoSync = true -- Auto-sync enabled by default
    end
    if IchaTauntDB.scale == nil then
        IchaTauntDB.scale = 1.0 -- Default scale
    end
    if IchaTauntDB.locked == nil then
        IchaTauntDB.locked = false -- Default unlocked
    end

    self.taunters = IchaTauntDB.taunters or {}
    self.order = IchaTauntDB.taunterOrder or {}
    self.taunterBars = {}
    self.locked = IchaTauntDB.locked or false

    self:CreateUI()

    -- Debug: Show what we have on login
    if IchaTauntDB.taunterOrder then
        local count = 0
        for _ in pairs(IchaTauntDB.taunterOrder) do
            count = count + 1
        end
        if count > 0 then
            -- Force show the tracker on login if we have configured taunters
            self.forceVisible = true
            -- Immediately show the tracker
            if self.frame then
                self.frame:Show()
            end
        end
    end

    self:RefreshRoster()

    -- Register our addon message prefix so we receive sync (required on some clients e.g. Turtle WoW)
    if RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(ICHAT_PREFIX)
    end

    -- Initialize DPS module if available
    if IchaTaunt_DPS and IchaTaunt_DPS.Initialize then
        IchaTaunt_DPS:Initialize()
    end

    -- Helper: schedule broadcast for a taunt spell (same path as Roar/Shout/Mocking Blow)
    local function scheduleTauntBroadcast(spellID)
        if not spellID or not IchaTaunt_GetSpellData(spellID) then return end
        local f = self.broadcastAfterCastFrame
        if not f then
            f = CreateFrame("Frame")
            self.broadcastAfterCastFrame = f
        end
        f.spellID = spellID
        f:SetScript("OnUpdate", function()
            this:SetScript("OnUpdate", nil)
            IchaTaunt:StartCooldownFor(UnitName("player"), this.spellID, false, false)
        end)
    end

    -- Hook CastSpellByName so we broadcast when local player uses ANY taunt (range-independent)
    if not self._castSpellByNameHooked and CastSpellByName then
        self._castSpellByNameHooked = true
        local oldCastSpellByName = CastSpellByName
        CastSpellByName = function(spellName, target)
            oldCastSpellByName(spellName, target)
            local spellID = IchaTaunt_GetSpellByName(spellName)
            if spellID then scheduleTauntBroadcast(spellID) end
        end
    end

    -- Hook CastSpell(spellId, "spell") so action-bar Taunt/Growl etc use same broadcast path as Roar/Shout
    if not self._castSpellHooked and CastSpell then
        self._castSpellHooked = true
        local oldCastSpell = CastSpell
        CastSpell = function(idOrIndex, bookType)
            oldCastSpell(idOrIndex, bookType)
            -- When cast by spell ID (e.g. action bar): bookType == "spell" and first arg is spell ID
            local spellID = (type(idOrIndex) == "number" and bookType == "spell") and idOrIndex or nil
            if spellID and IchaTaunt_GetSpellData(spellID) then
                scheduleTauntBroadcast(spellID)
            end
        end
    end

    -- Cooldown poller: detect when local player casts any taunt by seeing cooldown go 0 -> >0 (works when hooks/combat log don't fire)
    self._lastCooldownDuration = self._lastCooldownDuration or {}
    self._cooldownPollerElapsed = 0
    if not self.cooldownPollerFrame then
        self.cooldownPollerFrame = CreateFrame("Frame")
        self.cooldownPollerFrame:SetScript("OnUpdate", function()
            IchaTaunt._cooldownPollerElapsed = IchaTaunt._cooldownPollerElapsed + (arg1 or 0)
            if IchaTaunt._cooldownPollerElapsed < 0.15 then return end
            IchaTaunt._cooldownPollerElapsed = 0

            local _, playerClass = UnitClass("player")
            if not playerClass then return end
            local spells = IchaTaunt_GetSpellsByClass(playerClass)
            if not spells then return end

            local bookType = (BOOKTYPE_SPELL and tostring(BOOKTYPE_SPELL)) or "spell"
            for spellID, _ in pairs(spells) do
                local start, duration = 0, 0
                local ok = pcall(function()
                    start, duration = GetSpellCooldown(spellID, bookType)
                end)
                if not ok then
                    -- Some clients use GetSpellCooldown(index, bookType); try spellbook index by name
                    local spellData = IchaTaunt_GetSpellData(spellID)
                    if spellData and spellData.name then
                        for i = 1, 200 do
                            local ok2, name = pcall(GetSpellName, i, bookType)
                            if ok2 and name and (name == spellData.name or strfind(name, spellData.name)) then
                                start, duration = GetSpellCooldown(i, bookType)
                                break
                            end
                        end
                    end
                end

                local last = IchaTaunt._lastCooldownDuration[spellID] or 0
                if duration and duration > 0 and last == 0 then
                    -- Use actual remaining from API so bar shows correct time (e.g. after reload)
                    local remaining = (start and duration) and math.max(0, (start + duration) - GetTime()) or nil
                    IchaTaunt:StartCooldownFor(UnitName("player"), spellID, false, false, remaining)
                end
                IchaTaunt._lastCooldownDuration[spellID] = duration and duration > 0 and duration or 0
            end
        end)
    end

    -- Request sync from leader after a short delay (allow group info to load)
    -- This ensures non-leaders get the current configuration
    self.syncTimer = CreateFrame("Frame")
    self.syncTimer:SetScript("OnUpdate", function()
        if not IchaTaunt.syncRequested then
            IchaTaunt.syncRequested = true
            -- Request sync if we're in a group
            if GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0 then
                IchaTaunt:RequestSync()
            end
            this:Hide()
        end
    end)
end

function IchaTaunt:RefreshRoster()
    -- If "only show in raid" is on and we're in party (not raid), hide tracker
    if IchaTauntDB.showInRaidOnly and (not GetNumRaidMembers or GetNumRaidMembers() == 0) then
        if self.frame then
            self.frame:Hide()
        end
        return
    end

    -- Check if we need to rebuild (only if taunter list actually changed)
    local currentTaunters = {}
    local hasTaunters = false
    for name, _ in pairs(self.taunters) do
        if self:IsPlayerInGroup(name) then
            currentTaunters[name] = true
            hasTaunters = true
        end
    end

    -- Compare with existing taunter bars to see if rebuild is needed
    local needsRebuild = false
    if not self.taunterBars then
        needsRebuild = true
    else
        -- Check if taunter list changed
        for name in pairs(currentTaunters) do
            if not self.taunterBars[name] then
                needsRebuild = true
                break
            end
        end
        if not needsRebuild then
            for name in pairs(self.taunterBars) do
                if not currentTaunters[name] then
                    needsRebuild = true
                    break
                end
            end
        end

        -- Also check if the ORDER changed (even if same taunters)
        if not needsRebuild and self.lastOrderHash then
            local currentOrderHash = ""
            local order = IchaTauntDB.taunterOrder or {}
            for i, name in ipairs(order) do
                currentOrderHash = currentOrderHash .. i .. ":" .. name .. ";"
            end
            if currentOrderHash ~= self.lastOrderHash then
                needsRebuild = true
            end
        end
    end
    
    if hasTaunters then
        if self.frame then
            self.frame:Show()
        end
        if needsRebuild then
            self:RebuildList()
        end
    else
        -- Show tracker if we have taunters configured (even if not currently in group)
        local hasConfiguredTaunters = false
        if IchaTauntDB.taunterOrder then
            for _ in pairs(IchaTauntDB.taunterOrder) do
                hasConfiguredTaunters = true
                break
            end
        end
        
        if hasConfiguredTaunters or self.forceVisible then
            -- Show if we have configured taunters or force visible
            if self.frame then
                self.frame:Show()
            end
            if needsRebuild then
                self:RebuildList()
            end
        else
            -- Only hide if no taunters configured AND not force visible
            if not self.forceVisible then
                if self.frame then
                    self.frame:Hide()
                end
                return
            else
                if self.frame then
                    self.frame:Show()
                end
            end
        end
    end
end

function IchaTaunt:HandleCombatMessage(eventType)
    -- Parse 1.12 combat log messages for taunt spells
    if arg1 then
        local caster = nil
        local spell = nil
        
        -- Debug: Print all combat messages to see what we're getting
        if IchaTauntDB.debugMode then
            print("[IchaTaunt Debug] " .. (eventType or "Unknown") .. ": " .. arg1)
        end
        
        -- Super debug mode - show ALL events
        if IchaTauntDB.debugAllEvents then
            print("[IchaTaunt ALL] " .. (eventType or "Unknown") .. ": " .. arg1)
        end
        
        -- Look for various taunt spell cast patterns
        if strfind(arg1, "(.+) casts (.+)%.") then
            _, _, caster, spell = strfind(arg1, "(.+) casts (.+)%.")
        elseif strfind(arg1, "(.+) begins to cast (.+)%.") then
            _, _, caster, spell = strfind(arg1, "(.+) begins to cast (.+)%.")
        elseif strfind(arg1, "(.+) performs (.+) on (.+)%.") then
            -- "Ichabaddie performs Earthshaker Slam on Hecklefang Hyena."
            local target
            _, _, caster, spell, target = strfind(arg1, "(.+) performs (.+) on (.+)%.")
        elseif strfind(arg1, "(.+) performs (.+)%.") then
            _, _, caster, spell = strfind(arg1, "(.+) performs (.+)%.")
        elseif strfind(arg1, "You cast (.+)%.") then
            -- "You cast Earthshaker Slam."
            caster = UnitName("player")
            _, _, spell = strfind(arg1, "You cast (.+)%.")
        elseif strfind(arg1, "You perform (.+) on (.+)%.") then
            -- "You perform Earthshaker Slam on Hecklefang Hyena."
            caster = UnitName("player")
            _, _, spell = strfind(arg1, "You perform (.+) on (.+)%.")
        elseif strfind(arg1, "You perform (.+)%.") then
            -- "You perform Earthshaker Slam."
            caster = UnitName("player")
            _, _, spell = strfind(arg1, "You perform (.+)%.")
        elseif strfind(arg1, "Your (.+) hits") then
            -- "Your Earthshaker Slam hits Hecklefang Hyena."
            caster = UnitName("player")
            _, _, spell = strfind(arg1, "Your (.+) hits")
        elseif strfind(arg1, "Your (.+) was resisted") then
            -- "Your Earthshaker Slam was resisted by Barrens Giraffe."
            caster = UnitName("player")
            _, _, spell = strfind(arg1, "Your (.+) was resisted")
        elseif strfind(arg1, "Your (.+) crits") then
            -- "Your Earthshaker Slam crits Mob for 456."
            caster = UnitName("player")
            _, _, spell = strfind(arg1, "Your (.+) crits")
        elseif strfind(arg1, "Your (.+) misses") then
            -- "Your Earthshaker Slam misses Mob."
            caster = UnitName("player")
            _, _, spell = strfind(arg1, "Your (.+) misses")
        elseif strfind(arg1, "(.+)'s (.+) was resisted") then
            -- "Playername's Earthshaker Slam was resisted by Mob."
            _, _, caster, spell = strfind(arg1, "(.+)'s (.+) was resisted")
        elseif strfind(arg1, "(.+)'s (.+) hits") then
            _, _, caster, spell = strfind(arg1, "(.+)'s (.+) hits")
        elseif strfind(arg1, "(.+) hits .+ with (.+)%.") then
            _, _, caster, spell = strfind(arg1, "(.+) hits .+ with (.+)%.")
        elseif strfind(arg1, "(.+) resists your (.+)") then
            -- "Mob resists your Earthshaker Slam."
            caster = UnitName("player")
            _, _, spell = strfind(arg1, "(.+) resists your (.+)")
        elseif strfind(arg1, "(.+) resists (.+)'s (.+)") then
            -- "Mob resists Playername's Earthshaker Slam."
            _, _, caster, spell = strfind(arg1, "(.+) resists (.+)'s (.+)")
        elseif strfind(arg1, "You use (.+)%.") then
            -- "You use Challenging Shout."
            caster = UnitName("player")
            _, _, spell = strfind(arg1, "You use (.+)%.")
        elseif strfind(arg1, "(.+) uses (.+)%.") then
            -- "Playername uses Challenging Shout."
            _, _, caster, spell = strfind(arg1, "(.+) uses (.+)%.")
        elseif strfind(arg1, "You shout%.") or strfind(arg1, "You shout!") then
            -- "You shout." (Challenging Shout)
            caster = UnitName("player")
            spell = "Challenging Shout"
        elseif strfind(arg1, "(.+) shouts%.") or strfind(arg1, "(.+) shouts!") then
            -- "Playername shouts." (Challenging Shout)
            _, _, caster = strfind(arg1, "(.+) shouts")
            spell = "Challenging Shout"
        elseif strfind(arg1, "You roar%.") or strfind(arg1, "You roar!") then
            -- "You roar." (Challenging Roar)
            caster = UnitName("player")
            spell = "Challenging Roar"
        elseif strfind(arg1, "(.+) roars%.") or strfind(arg1, "(.+) roars!") then
            -- "Playername roars." (Challenging Roar)
            _, _, caster = strfind(arg1, "(.+) roars")
            spell = "Challenging Roar"
        elseif strfind(arg1, "You gain (.+)%.") then
            -- Check if it's a self-buff that might indicate spell use
            local buffName
            _, _, buffName = strfind(arg1, "You gain (.+)%.")
            if buffName == "Challenging Shout" or buffName == "Challenging Roar" then
                caster = UnitName("player")
                spell = buffName
            end
        elseif strfind(arg1, "is afflicted by Challenging Roar") then
            -- "Elder Mottled Boar is afflicted by Challenging Roar."
            -- When YOU cast Challenging Roar, you see this message for each mob affected
            -- Only trigger cooldown once per cast (use a flag to prevent multiple triggers)
            -- NOTE: "afflicted by" messages only appear in YOUR combat log for YOUR casts.
            -- Other players' Challenging Roars won't show this message to you.
            if not IchaTaunt.lastChallengingRoar or (GetTime() - IchaTaunt.lastChallengingRoar) > 1 then
                IchaTaunt.lastChallengingRoar = GetTime()
                caster = UnitName("player")
                spell = "Challenging Roar"
            end
        elseif strfind(arg1, "is afflicted by Challenging Shout") then
            -- "Mob is afflicted by Challenging Shout."
            -- When YOU cast Challenging Shout, you see this message for each mob affected
            -- Only trigger cooldown once per cast (use a flag to prevent multiple triggers)
            -- NOTE: "afflicted by" messages only appear in YOUR combat log for YOUR casts.
            if not IchaTaunt.lastChallengingShout or (GetTime() - IchaTaunt.lastChallengingShout) > 1 then
                IchaTaunt.lastChallengingShout = GetTime()
                caster = UnitName("player")
                spell = "Challenging Shout"
            end
        elseif strfind(arg1, "is afflicted by Mocking Blow") then
            -- "Mob is afflicted by Mocking Blow."
            -- When YOU cast Mocking Blow, you may see this message
            -- Only trigger cooldown once per cast (use a flag to prevent multiple triggers)
            -- NOTE: "afflicted by" messages only appear in YOUR combat log for YOUR casts.
            if not IchaTaunt.lastMockingBlow or (GetTime() - IchaTaunt.lastMockingBlow) > 1 then
                IchaTaunt.lastMockingBlow = GetTime()
                caster = UnitName("player")
                spell = "Mocking Blow"
            end
        end
        
        if caster and spell then
            -- Clean up caster name (remove realm suffix if present)
            if strfind(caster, "%-") then
                _, _, caster = strfind(caster, "([^%-]+)")
            end

            -- Check if it's a taunt spell by name
            local spellID, spellData = IchaTaunt_GetSpellByName(spell)
            if spellID and spellData then
                -- Check if this was a resist
                local wasResisted = strfind(arg1, "was resisted") or strfind(arg1, "resists")

                -- Always process if caster is tracked OR if caster is the local player
                -- (local player should always broadcast even if not in their own taunter list)
                local isLocalPlayer = (caster == UnitName("player"))
                local isTracked = self.taunters[caster]

                if isTracked or isLocalPlayer then
                    if IchaTauntDB.debugMode then
                        print("[IchaTaunt Debug] " .. caster .. " used spell: " .. spell .. (isLocalPlayer and " (local player)" or ""))
                    end

                    if wasResisted then
                        if IchaTauntDB.debugMode then
                            print("[IchaTaunt] " .. caster .. "'s " .. spell .. " was RESISTED - starting " .. spellData.cooldown .. "s cooldown")
                        end
                        self:StartCooldownFor(caster, spellID, true) -- true = resisted
                    else
                        if IchaTauntDB.debugMode then
                            print("[IchaTaunt] " .. caster .. " used " .. spell .. " - starting " .. spellData.cooldown .. "s cooldown")
                        end
                        self:StartCooldownFor(caster, spellID, false) -- false = not resisted
                        -- Clear any existing resist status for this player since they had a successful taunt
                        self:ClearResistFor(caster)
                    end
                end
            elseif IchaTauntDB.debugMode then
                print("[IchaTaunt Debug] Unknown spell: " .. spell)
            end
        end
    end
end

function IchaTaunt:GetSpellIDByName(spellName)
    return IchaTaunt_GetSpellByName(spellName)
end

function IchaTaunt:StartCooldownFor(name, spellID, wasResisted, fromSync, remainingSec)
    local spellData = IchaTaunt_GetSpellData(spellID)
    if not spellData then return end

    -- Use remaining duration when provided (e.g. from cooldown poller after reload), else full cooldown
    local duration = (remainingSec and remainingSec > 0) and remainingSec or spellData.cooldown

    -- Broadcast cooldown to raid FIRST if this is the local player and not from sync
    -- Broadcast remaining seconds so others show correct time (important for long CDs after reload)
    if not fromSync and name == UnitName("player") then
        IchaTaunt_Print("StartCooldownFor (local player) - calling BroadcastCooldown")
        self:BroadcastCooldown(name, spellID, duration, wasResisted)
    end

    -- Update local UI if we have a bar for this player
    local taunterBar = self.taunterBars and self.taunterBars[name]
    if not taunterBar then return end

    local cdBar = taunterBar.cooldownBars and taunterBar.cooldownBars[spellID]
    if not cdBar then return end

    -- Start cooldown (use duration so we show remaining after reload)
    local endTime = GetTime() + duration
    cdBar.endTime = endTime

    -- Persist so we restore correct remaining time after reload
    if GetEpochTime and GetEpochTime() > 0 then
        IchaTauntDB.cooldownEndTimes = IchaTauntDB.cooldownEndTimes or {}
        local nameBase = self:NormalizePlayerName(name)
        if not IchaTauntDB.cooldownEndTimes[nameBase] then IchaTauntDB.cooldownEndTimes[nameBase] = {} end
        IchaTauntDB.cooldownEndTimes[nameBase][spellID] = GetEpochTime() + duration
    end

    -- Also store in syncedCooldowns for UpdateCooldownBars
    self.syncedCooldowns = self.syncedCooldowns or {}
    if not self.syncedCooldowns[name] then self.syncedCooldowns[name] = {} end
    self.syncedCooldowns[name][spellID] = endTime

    -- Handle resist status
    if wasResisted then
        self:ShowResistFor(name, spellID, duration)
    end

    if IchaTauntDB.debugMode then
        print("IchaTaunt: " .. name .. " used " .. spellData.name .. " - " .. duration .. "s remaining" .. (wasResisted and " (RESISTED)" or "") .. (fromSync and " (synced)" or ""))
    end
end

-- Broadcast cooldown usage to raid members
function IchaTaunt:BroadcastCooldown(playerName, spellID, cooldown, wasResisted)
    -- Support both 1.12 (no arg) and Turtle WoW (sometimes "player" arg) group APIs
    local raidCount = 0
    local partyCount = 0
    if GetNumRaidMembers then raidCount = GetNumRaidMembers() or 0 end
    if GetNumPartyMembers then
        partyCount = GetNumPartyMembers() or 0
        local ok, alt = pcall(GetNumPartyMembers, "player")
        if ok and alt and alt > 0 then partyCount = alt end
    end
    local inGroup = (raidCount > 0) or (partyCount > 0)

    IchaTaunt_Print("BroadcastCooldown for " .. tostring(playerName) .. " (inGroup=" .. tostring(inGroup) .. " raid=" .. tostring(raidCount) .. " party=" .. tostring(partyCount) .. ")")
    if not inGroup then
        IchaTaunt_Print("CD not sent - you must be in a party or raid")
        return
    end

    -- Throttle: avoid double-broadcast when both CastSpellByName hook and combat log fire for same cast
    -- Always allow resist updates through so single-target taunts and Mocking Blow resists are broadcast
    if playerName == UnitName("player") and not wasResisted then
        self._lastBroadcastCD = self._lastBroadcastCD or {}
        local key = playerName .. ":" .. spellID
        if self._lastBroadcastCD[key] and (GetTime() - self._lastBroadcastCD[key]) < 1.5 then
            return
        end
        self._lastBroadcastCD[key] = GetTime()
    end

    -- Format: CD:PlayerName:SpellID:Cooldown:Resisted
    local resistFlag = wasResisted and "1" or "0"
    local msg = "CD:" .. playerName .. ":" .. spellID .. ":" .. cooldown .. ":" .. resistFlag

    IchaTaunt_Print("Sending CD " .. playerName .. " spell " .. spellID .. " (" .. cooldown .. "s)")
    self:SendSyncMessage(msg)
end

-- Apply received cooldown from another player
function IchaTaunt:ApplySyncedCooldown(playerName, spellID, cooldown, wasResisted)
    IchaTaunt_Print("ApplySyncedCooldown ENTER " .. tostring(playerName) .. " spell " .. tostring(spellID))
    -- Don't apply to ourselves (we already tracked it locally)
    if self:NormalizePlayerName(playerName) == self:NormalizePlayerName(UnitName("player")) then
        IchaTaunt_Print("ApplySyncedCooldown SKIP - self")
        return
    end

    local playerNameBase = self:NormalizePlayerName(playerName)

    -- Find the bar for this player (by normalized name); we only need a bar to exist, not taunters
    local barKey = playerName
    local taunterBar = self.taunterBars and self.taunterBars[playerName]
    if not taunterBar and self.taunterBars then
        for name, bar in pairs(self.taunterBars) do
            if self:NormalizePlayerName(name) == playerNameBase then
                taunterBar = bar
                barKey = name
                break
            end
        end
    end
    if not taunterBar then
        IchaTaunt_Print("Ignored CD from " .. playerName .. " - no bar for that player in tracker")
        return
    end

    local cdBar = taunterBar.cooldownBars and taunterBar.cooldownBars[spellID]
    -- If no icon for this spell (e.g. bar was built when GetPlayerClass failed due to name/realm mismatch), create it now
    if not cdBar then
        local spellData = IchaTaunt_GetSpellData(spellID)
        if spellData and taunterBar.cooldownBars then
            local iconIndex = 0
            for _ in pairs(taunterBar.cooldownBars) do iconIndex = iconIndex + 1 end
            cdBar = self:CreateSpellIcon(taunterBar, spellID, spellData, iconIndex)
            taunterBar.cooldownBars[spellID] = cdBar
        end
    end
    if not cdBar then
        IchaTaunt_Print("Ignored CD from " .. playerName .. " spell " .. spellID .. " - no bar for that spell")
        return
    end

    -- Apply the cooldown (cooldown is remaining seconds from sender)
    local endTime = GetTime() + cooldown
    cdBar.endTime = endTime

    -- Also store in syncedCooldowns so UpdateCooldownBars can show it even if bar reference differs
    self.syncedCooldowns = self.syncedCooldowns or {}
    if not self.syncedCooldowns[barKey] then self.syncedCooldowns[barKey] = {} end
    self.syncedCooldowns[barKey][spellID] = endTime

    -- Persist so we restore correct remaining time after reload (sender may have logged off)
    if GetEpochTime and GetEpochTime() > 0 then
        IchaTauntDB.cooldownEndTimes = IchaTauntDB.cooldownEndTimes or {}
        local nameBase = self:NormalizePlayerName(barKey)
        if not IchaTauntDB.cooldownEndTimes[nameBase] then IchaTauntDB.cooldownEndTimes[nameBase] = {} end
        IchaTauntDB.cooldownEndTimes[nameBase][spellID] = GetEpochTime() + cooldown
    end

    -- Handle resist status (use barKey so we find the right bar)
    if wasResisted then
        self:ShowResistFor(barKey, spellID, cooldown)
    end

    local spellData = IchaTaunt_GetSpellData(spellID)
    local spellName = spellData and spellData.name or ("Spell " .. spellID)

    IchaTaunt_Print("Applied CD from " .. playerName .. " - " .. spellName .. " (" .. cooldown .. "s)")

    -- Force UI refresh so the receiver sees the cooldown immediately (don't wait for next OnUpdate)
    self:UpdateCooldownBars()
end

-- Apply cooldown snapshot from another raid member (e.g. after we DC and rejoin - they send current remaining)
-- No sender validation; we trust raid members for state sync
function IchaTaunt:ApplyCooldownSnapshot(playerName, spellID, remainingSeconds)
    if not playerName or not spellID or not remainingSeconds or remainingSeconds <= 0 then return end
    local playerNameBase = self:NormalizePlayerName(playerName)
    local barKey = playerName
    local taunterBar = self.taunterBars and self.taunterBars[playerName]
    if not taunterBar and self.taunterBars then
        for name, bar in pairs(self.taunterBars) do
            if self:NormalizePlayerName(name) == playerNameBase then
                taunterBar = bar
                barKey = name
                break
            end
        end
    end
    if not taunterBar then return end

    local cdBar = taunterBar.cooldownBars and taunterBar.cooldownBars[spellID]
    if not cdBar then
        local spellData = IchaTaunt_GetSpellData(spellID)
        if spellData and taunterBar.cooldownBars then
            local iconIndex = 0
            for _ in pairs(taunterBar.cooldownBars) do iconIndex = iconIndex + 1 end
            cdBar = self:CreateSpellIcon(taunterBar, spellID, spellData, iconIndex)
            taunterBar.cooldownBars[spellID] = cdBar
        end
    end
    if not cdBar then return end

    local cooldown = remainingSeconds
    local endTime = GetTime() + cooldown
    cdBar.endTime = endTime

    self.syncedCooldowns = self.syncedCooldowns or {}
    if not self.syncedCooldowns[barKey] then self.syncedCooldowns[barKey] = {} end
    self.syncedCooldowns[barKey][spellID] = endTime

    if GetEpochTime and GetEpochTime() > 0 then
        IchaTauntDB.cooldownEndTimes = IchaTauntDB.cooldownEndTimes or {}
        local nameBase = self:NormalizePlayerName(barKey)
        if not IchaTauntDB.cooldownEndTimes[nameBase] then IchaTauntDB.cooldownEndTimes[nameBase] = {} end
        IchaTauntDB.cooldownEndTimes[nameBase][spellID] = GetEpochTime() + cooldown
    end

    self:UpdateCooldownBars()
end

function IchaTaunt:ShowResistFor(name, spellID, cooldownDuration)
    local taunterBar = self.taunterBars and self.taunterBars[name]
    if not taunterBar then return end
    
    -- Initialize resist tracking if it doesn't exist
    if not taunterBar.resistStatus then
        taunterBar.resistStatus = {}
    end
    
    -- Set resist status for this spell with expiration time
    taunterBar.resistStatus[spellID] = GetTime() + cooldownDuration
    
    -- Show the resist text
    if taunterBar.resistText then
        taunterBar.resistText:Show()
    end
end

function IchaTaunt:ClearResistFor(name)
    local taunterBar = self.taunterBars and self.taunterBars[name]
    if not taunterBar then return end
    
    -- Clear all resist status for this player
    if taunterBar.resistStatus then
        taunterBar.resistStatus = {}
    end
    
    -- Hide the resist text
    if taunterBar.resistText then
        taunterBar.resistText:Hide()
    end
end

function IchaTaunt:UpdateResistStatus()
    local currentTime = GetTime()
    
    for name, taunterBar in pairs(self.taunterBars) do
        if taunterBar.resistStatus then
            local hasActiveResist = false
            
            -- Check if any resisted spells are still on cooldown
            for spellID, expireTime in pairs(taunterBar.resistStatus) do
                if expireTime > currentTime then
                    hasActiveResist = true
                    break
                end
            end
            
            -- Show/hide resist text based on active resists
            if taunterBar.resistText then
                if hasActiveResist then
                    taunterBar.resistText:Show()
                else
                    taunterBar.resistText:Hide()
                    taunterBar.resistStatus = {} -- Clear expired resists
                end
            end
        end
    end
end

function IchaTaunt:UpdateCooldownBars()
    local currentTime = GetTime()
    
    -- Update resist status first
    self:UpdateResistStatus()
    
    for name, taunterBar in pairs(self.taunterBars) do
        for spellID, iconFrame in pairs(taunterBar.cooldownBars) do
            -- Use synced cooldown if present and later (receiver may have bar keyed differently)
            local endTime = iconFrame.endTime
            if self.syncedCooldowns and self.syncedCooldowns[name] and self.syncedCooldowns[name][spellID] then
                local syncedEnd = self.syncedCooldowns[name][spellID]
                if syncedEnd > endTime then endTime = syncedEnd end
                if currentTime >= syncedEnd then self.syncedCooldowns[name][spellID] = nil end
            end
            local timeLeft = endTime - currentTime
            
            if timeLeft > 0 then
                -- On cooldown - show overlay and countdown
                local percent = timeLeft / iconFrame.spellData.cooldown
                
                -- Show cooldown overlay and bar
                iconFrame.cooldownOverlay:Show()
                iconFrame.cooldownBar:Show()
                iconFrame.cooldownBar:SetHeight(26 * percent) -- Fill from bottom (updated for new icon size)
                
                -- Show countdown text
                if timeLeft >= 60 then
                    -- Show minutes:seconds for cooldowns over 1 minute
                    local minutes = math.floor(timeLeft / 60)
                    local seconds = math.floor(timeLeft - (minutes * 60))
                    iconFrame.timerText:SetText(format("%d:%02d", minutes, seconds))
                elseif timeLeft >= 1 then
                    iconFrame.timerText:SetText(format("%.0f", timeLeft))
                else
                    iconFrame.timerText:SetText(format("%.1f", timeLeft))
                end
                
            else
                -- Ready - hide cooldown elements and clear persisted so we don't restore expired CD
                iconFrame.cooldownOverlay:Hide()
                iconFrame.cooldownBar:Hide()
                iconFrame.timerText:SetText("")
                if IchaTauntDB.cooldownEndTimes then
                    local nameBase = IchaTaunt:NormalizePlayerName(name)
                    if IchaTauntDB.cooldownEndTimes[nameBase] then
                        IchaTauntDB.cooldownEndTimes[nameBase][spellID] = nil
                    end
                end
            end
        end
    end
end

-- Normalize class to spell-data format (e.g. "WARRIOR"); UnitClass may return "Warrior" in some clients
local function NormalizeClassForSpells(class)
    if not class or class == "" then return nil end
    return strupper(class)
end

function IchaTaunt:GetPlayerClass(name)
    -- Get class for a player name (match with or without realm suffix)
    local nameBase = self:NormalizePlayerName(name)
    for i = 1, GetNumRaidMembers() do
        local raidName, _, _, _, _, classFile = GetRaidRosterInfo(i)
        if raidName and self:NormalizePlayerName(raidName) == nameBase then
            return NormalizeClassForSpells(classFile) or classFile
        end
    end
    
    for i = 1, GetNumPartyMembers() do
        local partyName = UnitName("party" .. i)
        if partyName and self:NormalizePlayerName(partyName) == nameBase then
            local c = UnitClass("party" .. i)
            return NormalizeClassForSpells(c)
        end
    end
    
    if nameBase == self:NormalizePlayerName(UnitName("player")) then
        local c = UnitClass("player")
        return NormalizeClassForSpells(c)
    end
    
    return nil
end

function IchaTaunt:GetClassColor(class)
    -- Return RGB color values for class
    local colors = {
        ["WARRIOR"] = {0.78, 0.61, 0.43}, -- Brown/tan
        ["PALADIN"] = {0.96, 0.55, 0.73}, -- Pink
        ["HUNTER"] = {0.67, 0.83, 0.45}, -- Green
        ["ROGUE"] = {1.0, 0.96, 0.41}, -- Yellow
        ["PRIEST"] = {1.0, 1.0, 1.0}, -- White
        ["SHAMAN"] = {0.14, 0.35, 1.0}, -- Blue
        ["MAGE"] = {0.25, 0.78, 0.92}, -- Light blue
        ["WARLOCK"] = {0.53, 0.53, 0.93}, -- Purple
        ["DRUID"] = {1.0, 0.49, 0.04}, -- Orange
    }
    
    return colors[class] or {1, 1, 1} -- Default to white
end

-- UI Creation - Clean Taunt Tracker
function IchaTaunt:CreateUI()
    if self.frame then return end

    local theme = self:GetTheme()
    local t = theme.tracker

    local f = CreateFrame("Frame", "IchaTauntFrame", UIParent)
    f:SetWidth(300)
    f:SetHeight(100)
    f:SetFrameStrata("MEDIUM")  -- Ensure tracker is visible above background elements

    -- Apply theme backdrop
    f:SetBackdrop(t.backdrop)
    f:SetBackdropColor(unpack(t.bgColor))
    f:SetBackdropBorderColor(unpack(t.borderColor))

    -- Load position relative to screen center
    local relativeX = IchaTauntDB.position.x or 0
    local relativeY = IchaTauntDB.position.y or 0
    local screenWidth = GetScreenWidth() or 1024
    local screenHeight = GetScreenHeight() or 768

    -- More lenient bounds checking - allow more positioning freedom
    local maxOffsetX = (screenWidth / 2) - 50   -- Allow frame closer to edge
    local maxOffsetY = (screenHeight / 2) - 25  -- Allow frame closer to edge

    if math.abs(relativeX) > maxOffsetX or math.abs(relativeY) > maxOffsetY then
        relativeX = 0
        relativeY = 0
        IchaTauntDB.position.x = 0
        IchaTauntDB.position.y = 0
    end
    
    -- Set position relative to screen center
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", relativeX, relativeY)
    
    -- Clean, borderless design - no backdrop
    
    -- Make it draggable
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() if not IchaTaunt.locked then this:StartMoving() end end)
    f:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        
        -- Save position relative to screen center for consistent loading
        local frameX, frameY = this:GetCenter()
        local screenCenterX = GetScreenWidth() / 2
        local screenCenterY = GetScreenHeight() / 2
        
        local relativeX = frameX - screenCenterX
        local relativeY = frameY - screenCenterY
        
        IchaTauntDB.position.x = relativeX
        IchaTauntDB.position.y = relativeY
    end)
    
    -- Right-click menu for lock/unlock
    f:SetScript("OnMouseUp", function(button)
        if button == "RightButton" then
            IchaTaunt:ToggleLock()
        end
    end)
    
    -- Lock icon button (top-right corner)
    local lockBtn = CreateFrame("Button", nil, f)
    lockBtn:SetWidth(16)
    lockBtn:SetHeight(16)
    lockBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    lockBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    lockBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    lockBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    
    -- Lock icon texture (shows lock/unlock state)
    lockBtn.icon = lockBtn:CreateTexture(nil, "OVERLAY")
    lockBtn.icon:SetAllPoints(lockBtn)
    lockBtn.icon:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    
    lockBtn:SetScript("OnClick", function()
        IchaTaunt:ToggleLock()
    end)
    
    lockBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        if IchaTaunt.locked then
            GameTooltip:SetText("Unlock Tracker")
            GameTooltip:AddLine("Click to unlock and show background", 1, 1, 1, 1)
        else
            GameTooltip:SetText("Lock Tracker")
            GameTooltip:AddLine("Click to lock and hide background", 1, 1, 1, 1)
        end
        GameTooltip:AddLine("Right-click tracker to toggle", 0.7, 0.7, 0.7, 1)
        GameTooltip:Show()
    end)

    lockBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
        -- Hide button again if locked (unless mouse is still over main frame)
        if IchaTaunt.locked and not MouseIsOver(f) then
            this:SetAlpha(0)
        end
    end)

    f.lockBtn = lockBtn

    -- Show/hide lock button on frame hover when locked
    f:SetScript("OnEnter", function()
        if IchaTaunt.locked and IchaTaunt.frame.lockBtn then
            IchaTaunt.frame.lockBtn:SetAlpha(1)
        end
    end)

    f:SetScript("OnLeave", function()
        if IchaTaunt.locked and IchaTaunt.frame.lockBtn then
            -- Small delay check - only hide if not hovering over lock button
            if not MouseIsOver(IchaTaunt.frame.lockBtn) then
                IchaTaunt.frame.lockBtn:SetAlpha(0)
            end
        end
    end)

    self.frame = f
    self.taunterBars = {}
    self.updateTimer = 0

    -- Apply saved scale
    self:ApplyScale()
    
    -- Apply lock state (hide backdrop if locked)
    self:UpdateLockState()

    -- Start update cycle
    f:SetScript("OnUpdate", function()
        IchaTaunt:UpdateCooldownBars()
        -- Update DPS displays if module is available
        if IchaTaunt_DPS and IchaTaunt_DPS.UpdateDisplays then
            IchaTaunt_DPS:UpdateDisplays()
        end
    end)
    
    -- Additional safety check - if frame is way off screen, center it
    local centerX, centerY = f:GetCenter()
    if centerX and centerY then
        if centerX < 100 or centerX > (screenWidth - 100) or centerY < 50 or centerY > (screenHeight - 50) then
            f:ClearAllPoints()
            f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            IchaTauntDB.position.x = 0
            IchaTauntDB.position.y = 0
        end
    end
end

-- Creates countdown bars for active taunters
function IchaTaunt:RebuildList()
    -- Save existing cooldown states and resist status before rebuilding
    local savedCooldowns = {}
    local savedResists = {}
    if self.taunterBars then
        for name, bar in pairs(self.taunterBars) do
            if bar and bar.cooldownBars then
                savedCooldowns[name] = {}
                for spellID, cdBar in pairs(bar.cooldownBars) do
                    savedCooldowns[name][spellID] = cdBar.endTime
                end
            end
            if bar and bar.resistStatus then
                savedResists[name] = {}
                for spellID, expireTime in pairs(bar.resistStatus) do
                    savedResists[name][spellID] = expireTime
                end
            end
        end
    end
    
    -- Clear existing bars safely
    if self.taunterBars then
        for _, bar in pairs(self.taunterBars) do 
            if bar and bar.Hide then
                bar:Hide() 
            end
        end
    end
    self.taunterBars = {}

    local yOffset = -5
    local barIndex = 1
    
    -- Use the exact order from IchaTauntDB.taunterOrder
    local orderedTaunters = {}
    for _, name in ipairs(IchaTauntDB.taunterOrder) do
        if self:IsPlayerInGroup(name) and IchaTauntDB.taunters[name] then
            table.insert(orderedTaunters, name)
        end
    end
    
    -- Create bars for each taunter in order
    for i, name in ipairs(orderedTaunters) do
        self:CreateTaunterBar(name, yOffset, i)
        yOffset = yOffset - 28  -- Reduced from 36 to 28 for tighter spacing
        barIndex = barIndex + 1
    end
    
    -- Restore saved cooldown states (in-session, same reload)
    for name, spellCooldowns in pairs(savedCooldowns) do
        if self.taunterBars[name] and self.taunterBars[name].cooldownBars then
            for spellID, endTime in pairs(spellCooldowns) do
                if self.taunterBars[name].cooldownBars[spellID] then
                    self.taunterBars[name].cooldownBars[spellID].endTime = endTime
                end
            end
        end
    end

    -- Restore cooldowns from persisted DB (survives reload / someone logging off)
    if GetEpochTime and GetEpochTime() > 0 and IchaTauntDB.cooldownEndTimes then
        for name, bar in pairs(self.taunterBars) do
            if bar and bar.cooldownBars then
                local nameBase = self:NormalizePlayerName(name)
                local saved = IchaTauntDB.cooldownEndTimes[nameBase]
                if saved then
                    for spellID, cdBar in pairs(bar.cooldownBars) do
                        local endEpoch = saved[spellID]
                        if endEpoch then
                            local remaining = endEpoch - GetEpochTime()
                            if remaining > 0 then
                                local endTime = GetTime() + remaining
                                cdBar.endTime = endTime
                                self.syncedCooldowns = self.syncedCooldowns or {}
                                if not self.syncedCooldowns[name] then self.syncedCooldowns[name] = {} end
                                self.syncedCooldowns[name][spellID] = endTime
                            else
                                saved[spellID] = nil
                            end
                        end
                    end
                end
            end
        end
    end

    -- For local player, refresh from GetSpellCooldown so we show exact remaining (e.g. after reload)
    local me = UnitName("player")
    if self.taunterBars[me] and self.taunterBars[me].cooldownBars then
        local bookType = (BOOKTYPE_SPELL and tostring(BOOKTYPE_SPELL)) or "spell"
        for spellID, cdBar in pairs(self.taunterBars[me].cooldownBars) do
            local start, duration = 0, 0
            local ok = pcall(function() start, duration = GetSpellCooldown(spellID, bookType) end)
            if not ok and IchaTaunt_GetSpellData(spellID) then
                for i = 1, 200 do
                    local ok2, sn = pcall(GetSpellName, i, bookType)
                    if ok2 and sn and IchaTaunt_GetSpellData(spellID) and (sn == IchaTaunt_GetSpellData(spellID).name or strfind(sn, IchaTaunt_GetSpellData(spellID).name)) then
                        start, duration = GetSpellCooldown(i, bookType)
                        break
                    end
                end
            end
            if duration and duration > 0 then
                local remaining = math.max(0, (start + duration) - GetTime())
                local endTime = GetTime() + remaining
                cdBar.endTime = endTime
                self.syncedCooldowns = self.syncedCooldowns or {}
                if not self.syncedCooldowns[me] then self.syncedCooldowns[me] = {} end
                self.syncedCooldowns[me][spellID] = endTime
                if GetEpochTime and GetEpochTime() > 0 then
                    IchaTauntDB.cooldownEndTimes = IchaTauntDB.cooldownEndTimes or {}
                    local nameBase = self:NormalizePlayerName(me)
                    if not IchaTauntDB.cooldownEndTimes[nameBase] then IchaTauntDB.cooldownEndTimes[nameBase] = {} end
                    IchaTauntDB.cooldownEndTimes[nameBase][spellID] = GetEpochTime() + remaining
                end
            end
        end
    end

    -- Restore saved resist status
    for name, resistStatus in pairs(savedResists) do
        if self.taunterBars[name] then
            self.taunterBars[name].resistStatus = resistStatus
        end
    end
    
    -- Resize frame based on content (28px per row + 10px padding)
    local frameHeight = math.max(35, (barIndex - 1) * 28 + 10)
    self.frame:SetHeight(frameHeight)

    -- Store the current order hash for change detection
    local orderHash = ""
    local order = IchaTauntDB.taunterOrder or {}
    for i, name in ipairs(order) do
        orderHash = orderHash .. i .. ":" .. name .. ";"
    end
    self.lastOrderHash = orderHash
end

function IchaTaunt:IsPlayerInGroup(name)
    local nameBase = self:NormalizePlayerName(name)
    for i = 1, GetNumRaidMembers() do
        local raidName = GetRaidRosterInfo(i)
        if raidName and self:NormalizePlayerName(raidName) == nameBase then return true end
    end
    for i = 1, GetNumPartyMembers() do
        local partyName = UnitName("party" .. i)
        if partyName and self:NormalizePlayerName(partyName) == nameBase then return true end
    end
    if nameBase == self:NormalizePlayerName(UnitName("player")) then return true end
    return false
end

-- Create clean taunter row: Order | Name | Icons
function IchaTaunt:CreateTaunterBar(name, yOffset, orderNum)
    local theme = self:GetTheme()
    local t = theme.tracker

    local parent = self.frame
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetWidth(280)
    bar:SetHeight(26)  -- Reduced from 32 to 26 for tighter spacing
    bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, yOffset)

    -- Order number (left aligned) - use theme color
    bar.orderText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bar.orderText:SetPoint("LEFT", bar, "LEFT", 5, 0)
    bar.orderText:SetText(orderNum)
    bar.orderText:SetTextColor(unpack(t.orderTextColor))

    -- Player name (after order number)
    bar.nameText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.nameText:SetPoint("LEFT", bar.orderText, "RIGHT", 10, 0)
    bar.nameText:SetText(name)

    -- Apply class color to name
    local playerClass = self:GetPlayerClass(name)
    if playerClass then
        local r, g, b = unpack(self:GetClassColor(playerClass))
        bar.nameText:SetTextColor(r, g, b)
    else
        bar.nameText:SetTextColor(1, 1, 1) -- Default white if class unknown
    end

    -- Resist text (big red text over the name) - use theme color
    bar.resistText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    bar.resistText:SetPoint("CENTER", bar.nameText, "CENTER", 0, 10) -- Position above the name
    bar.resistText:SetText("RESIST!")
    bar.resistText:SetTextColor(unpack(t.resistTextColor))
    bar.resistText:SetFont("Fonts\\FRIZQT__.TTF", 16, "THICKOUTLINE") -- Large, bold font with thick outline
    bar.resistText:Hide() -- Initially hidden

    -- Initialize resist status tracking
    bar.resistStatus = {}

    -- Spell icons container
    bar.cooldownBars = {}
    
    -- Get spells for this player's class
    local playerClass = self:GetPlayerClass(name)
    if playerClass then
        local spells = IchaTaunt_GetSpellsByClass(playerClass)
        local iconIndex = 0
        
        for spellID, spellData in pairs(spells) do
            local iconFrame = self:CreateSpellIcon(bar, spellID, spellData, iconIndex)
            bar.cooldownBars[spellID] = iconFrame
            iconIndex = iconIndex + 1
        end
    end

    self.taunterBars[name] = bar
end

-- Create spell icon with internal cooldown overlay
function IchaTaunt:CreateSpellIcon(parent, spellID, spellData, iconIndex)
    -- Position icons after name text
    local xOffset = 120 + (iconIndex * 28) -- 26px icons + 2px spacing
    
    local theme = self:GetTheme()
    local t = theme.tracker

    local iconFrame = CreateFrame("Frame", nil, parent)
    iconFrame:SetWidth(26)  -- Reduced from 32 to 26
    iconFrame:SetHeight(26)  -- Reduced from 32 to 26
    iconFrame:SetPoint("LEFT", parent, "LEFT", xOffset, 0)

    -- Icon border (theme-dependent)
    if t.iconBorder then
        iconFrame.border = iconFrame:CreateTexture(nil, "BACKGROUND")
        iconFrame.border:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", -1, 1)
        iconFrame.border:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 1, -1)
        iconFrame.border:SetTexture(unpack(t.iconBorderColor))
    end

    -- Main spell icon
    iconFrame.icon = iconFrame:CreateTexture(nil, "ARTWORK")
    iconFrame.icon:SetAllPoints(true)
    iconFrame.icon:SetTexture(spellData.icon)

    -- Cooldown overlay (starts invisible) - use theme alpha
    iconFrame.cooldownOverlay = iconFrame:CreateTexture(nil, "OVERLAY")
    iconFrame.cooldownOverlay:SetAllPoints(true)
    iconFrame.cooldownOverlay:SetTexture(0, 0, 0, t.cooldownOverlayAlpha)
    iconFrame.cooldownOverlay:Hide()

    -- Cooldown progress bar (vertical fill from bottom) - use theme color
    iconFrame.cooldownBar = iconFrame:CreateTexture(nil, "OVERLAY")
    iconFrame.cooldownBar:SetPoint("BOTTOMLEFT", iconFrame, "BOTTOMLEFT", 0, 0)
    iconFrame.cooldownBar:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 0, 0)
    iconFrame.cooldownBar:SetHeight(26)  -- Updated to match new icon size
    iconFrame.cooldownBar:SetTexture(unpack(t.cooldownBarColor))
    iconFrame.cooldownBar:Hide()

    -- Timer text overlay - use theme color
    iconFrame.timerText = iconFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    iconFrame.timerText:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
    iconFrame.timerText:SetText("")
    iconFrame.timerText:SetTextColor(unpack(t.timerTextColor))
    iconFrame.timerText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    
    -- Spell tooltip
    iconFrame:EnableMouse(true)
    iconFrame:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText(spellData.name)
        GameTooltip:AddLine(spellData.description, 1, 1, 1, 1)
        GameTooltip:AddLine("Cooldown: " .. spellData.cooldown .. "s", 0.7, 0.7, 0.7, 1)
        GameTooltip:Show()
    end)
    iconFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Initialize state
    iconFrame.endTime = 0
    iconFrame.spellData = spellData
    
    return iconFrame
end

-- Show/hide the tracker based on settings
function IchaTaunt:ToggleTracker()
    if self.frame and self.frame:IsVisible() then
        self:HideTracker()
    else
        self:ShowTracker()
    end
end

function IchaTaunt:ShowTracker()
    if not self.frame then
        self:CreateUI()
    end
    self.frame:Show()
    self.forceVisible = true  -- Flag to keep tracker visible even without taunters
    self:RefreshRoster()
    if IchaTauntDB.debugMode then
        print("IchaTaunt: Tracker shown")
    end
end

function IchaTaunt:HideTracker()
    if self.frame then
        self.frame:Hide()
        self.forceVisible = false  -- Clear force visible flag
        if IchaTauntDB.debugMode then
            print("IchaTaunt: Tracker hidden")
        end
    end
end

-- Lock/unlock tracker position
function IchaTaunt:SetLocked(locked)
    self.locked = locked
    IchaTauntDB.locked = locked
    self:UpdateLockState()
    
    if locked then
        print("IchaTaunt: Tracker locked - background hidden")
    else
        print("IchaTaunt: Tracker unlocked - background visible")
    end
end

function IchaTaunt:ToggleLock()
    self:SetLocked(not self.locked)
end

function IchaTaunt:UpdateLockState()
    if not self.frame then return end

    -- When locked: click-through so the tracker doesn't block camera/clicking the world
    self.frame:EnableMouse(not self.locked)

    -- Update backdrop visibility based on lock state
    if self.locked then
        -- Hide backdrop when locked
        self.frame:SetBackdrop(nil)
    else
        -- Show backdrop when unlocked
        local theme = self:GetTheme()
        local t = theme.tracker
        self.frame:SetBackdrop(t.backdrop)
        self.frame:SetBackdropColor(unpack(t.bgColor))
        self.frame:SetBackdropBorderColor(unpack(t.borderColor))
    end

    -- Keep options menu lock/unlock button in sync
    self:RefreshLockUnlockButton()

    -- Update lock icon appearance and visibility
    if self.frame.lockBtn then
        if self.locked then
            -- Show locked icon (minimize button = locked)
            self.frame.lockBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
            self.frame.lockBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
            -- Hide the button when locked (will show on mouseover)
            self.frame.lockBtn:SetAlpha(0)
        else
            -- Show unlocked icon (maximize button = unlocked)
            self.frame.lockBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MaximizeButton-Up")
            self.frame.lockBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MaximizeButton-Down")
            -- Always show when unlocked
            self.frame.lockBtn:SetAlpha(1)
        end
    end
end

-- Debug functions to catch all combat events
function IchaTaunt:RegisterAllCombatEvents()
    local allEvents = {
        "CHAT_MSG_COMBAT_SELF_HITS", "CHAT_MSG_COMBAT_SELF_MISSES",
        "CHAT_MSG_SPELL_SELF_DAMAGE", "CHAT_MSG_SPELL_SELF_BUFF",
        "CHAT_MSG_COMBAT_CREATURE_VS_SELF", "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE",
        "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF", "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE",
        "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS", "CHAT_MSG_SPELL_AURA_GONE_SELF",
    }
    for _, eventName in ipairs(allEvents) do
        self:RegisterEvent(eventName)
    end
end

function IchaTaunt:UnregisterAllCombatEvents()
    local allEvents = {
        "CHAT_MSG_COMBAT_SELF_HITS", "CHAT_MSG_COMBAT_SELF_MISSES",
        "CHAT_MSG_SPELL_SELF_DAMAGE", "CHAT_MSG_SPELL_SELF_BUFF",
        "CHAT_MSG_COMBAT_CREATURE_VS_SELF", "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE",
        "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF", "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE",
        "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS", "CHAT_MSG_SPELL_AURA_GONE_SELF",
    }
    for _, eventName in ipairs(allEvents) do
        self:UnregisterEvent(eventName)
    end
end

-- ============================================
-- SYNC SYSTEM (PallyPower-style)
-- ============================================

-- Note: ICHAT_PREFIX is defined at the top of the file as a global variable
-- This is required because the event handler references it before this section loads

-- Helper function to parse comma-separated strings (WoW 1.12 compatible)
-- Uses string.find in a loop since gfind is not available
local function ParseCommaSeparated(str)
    local result = {}
    if not str or str == "" then return result end
    
    local pos = 1
    local len = strlen(str)
    
    while pos <= len do
        -- Find the next item (non-comma characters)
        local startPos, endPos = strfind(str, "[^,]+", pos)
        if not startPos then break end
        
        local item = strsub(str, startPos, endPos)
        -- Trim whitespace
        item = gsub(item, "^%s*(.-)%s*$", "%1")
        if item and item ~= "" then
            table.insert(result, item)
        end
        
        -- Move past this item and the comma
        pos = endPos + 1
        -- Skip the comma if present
        if strsub(str, pos, pos) == "," then
            pos = pos + 1
        end
    end
    
    return result
end

-- Strip realm suffix from player name for comparison (e.g. "Alice-Realm" -> "Alice")
function IchaTaunt:NormalizePlayerName(name)
    if not name or name == "" then return name end
    local base = name
    if strfind(name, "%-") then
        local _
        _, _, base = strfind(name, "([^%-]+)")
    end
    return base or name
end

-- Check if player is raid leader or officer
function IchaTaunt:IsRaidLeader(name)
    if GetNumRaidMembers() == 0 then
        -- In party, check if party leader
        for i = 1, GetNumPartyMembers() do
            if name == UnitName("party" .. i) and UnitIsPartyLeader("party" .. i) then
                return true
            end
        end
        -- Check if we are the party leader
        if name == UnitName("player") and IsPartyLeader() then
            return true
        end
        return false
    end

    -- In raid, check rank (1 = assistant, 2 = leader)
    for i = 1, GetNumRaidMembers() do
        local raidName, rank = GetRaidRosterInfo(i)
        if raidName == name and rank >= 1 then
            return true
        end
    end
    return false
end

-- Check if current player can modify assignments
function IchaTaunt:CanControl()
    return IsPartyLeader() or IsRaidLeader() or IsRaidOfficer()
end

-- Send addon message to appropriate channel
-- BigWigs uses 3 params only: SendAddonMessage(prefix, message, channel); sender is implicit
function IchaTaunt:SendSyncMessage(msg)
    if not msg or msg == "" then return end

    local channel = "PARTY"
    if GetNumRaidMembers() > 0 then
        channel = "RAID"
    end

    -- Debug output
    if IchaTauntDB and IchaTauntDB.debugMode then
        print("[IchaTaunt Sync] Sending: " .. msg .. " to " .. channel)
    end

    SendAddonMessage(ICHAT_PREFIX, msg, channel)
end

-- Broadcast full configuration (order + taunters)
function IchaTaunt:BroadcastFullConfig()
    -- Send order
    self:BroadcastOrder()
    -- Send taunters list
    self:BroadcastTaunters()
end

-- Auto-broadcast when changes are made (sync is always on)
function IchaTaunt:AutoBroadcast()
    local inGroup = GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
    if inGroup and self:CanControl() then
        self:BroadcastFullConfig()
        if IchaTauntDB.debugMode then
            print("[IchaTaunt Sync] Auto-broadcasting changes to raid")
        end
    end
end

-- Broadcast taunter order
function IchaTaunt:BroadcastOrder()
    local serialized = "ORDER:"
    local order = IchaTauntDB.taunterOrder or {}
    for i, name in ipairs(order) do
        if name and name ~= "" then
            if i > 1 then serialized = serialized .. "," end
            serialized = serialized .. name
        end
    end
    -- Always send, even if empty (so members can clear their list too)
    self:SendSyncMessage(serialized)
    if IchaTauntDB.debugMode then
        print("[IchaTaunt Sync] Broadcasting order: " .. serialized)
    end
end

-- Broadcast taunters list
function IchaTaunt:BroadcastTaunters()
    local serialized = "TAUNTERS:"
    local first = true
    local taunters = IchaTauntDB.taunters or {}
    for name, _ in pairs(taunters) do
        if name and name ~= "" then
            if not first then serialized = serialized .. "," end
            serialized = serialized .. name
            first = false
        end
    end
    -- Always send, even if empty (so members can clear their list too)
    self:SendSyncMessage(serialized)
    if IchaTauntDB.debugMode then
        print("[IchaTaunt Sync] Broadcasting taunters: " .. serialized)
    end
end

-- Request sync data from leader (and CD snapshots from anyone online who has them)
function IchaTaunt:RequestSync()
    self:SendSyncMessage("REQ")
    if IchaTauntDB.debugMode then
        print("[IchaTaunt Sync] Requesting sync from leader")
    end
end

-- Broadcast our known active cooldowns so reconnecting players get current remaining (e.g. after DC)
-- Called when we receive REQ - anyone online who has CD state sends it
function IchaTaunt:BroadcastCooldownSnapshots()
    if not self.taunterBars then return end
    local now = GetTime()
    for name, bar in pairs(self.taunterBars) do
        if bar and bar.cooldownBars then
            for spellID, cdBar in pairs(bar.cooldownBars) do
                local endTime = (self.syncedCooldowns and self.syncedCooldowns[name] and self.syncedCooldowns[name][spellID]) or (cdBar and cdBar.endTime)
                if endTime and endTime > now then
                    local remaining = math.floor(endTime - now)
                    if remaining > 0 then
                        self:SendSyncMessage("CD_SNAPSHOT:" .. name .. ":" .. spellID .. ":" .. remaining)
                    end
                end
            end
        end
    end
end

-- Parse incoming addon messages
function IchaTaunt:ParseSyncMessage(msg, sender)
    -- Safety checks
    if not msg or not sender then return end
    if sender == UnitName("player") then return end

    if IchaTauntDB.debugMode then
        print("[IchaTaunt Sync] Received from " .. sender .. ": " .. (msg or "(nil)"))
    end

    -- REQ - Request for sync (leader sends config + CD snapshots so reconnecting player gets current cooldowns after DC)
    if msg == "REQ" then
        if self:CanControl() then
            self:BroadcastFullConfig()
            self:BroadcastCooldownSnapshots()
        end
        return
    end

    -- ORDER: message - Taunter order list
    if strfind(msg, "^ORDER:") then
        -- Only accept from leaders/officers
        if not self:IsRaidLeader(sender) then
            if IchaTauntDB.debugMode then
                print("[IchaTaunt Sync] Ignoring ORDER from non-leader: " .. sender)
            end
            return
        end

        local orderStr = strsub(msg, 7) -- Remove "ORDER:" prefix
        local newOrder = ParseCommaSeparated(orderStr)

        IchaTauntDB.taunterOrder = newOrder
        self.order = newOrder

        -- Check if we have any taunters
        local hasTaunters = false
        for _ in ipairs(newOrder) do
            hasTaunters = true
            break
        end

        -- Ensure tracker frame exists
        if not self.frame then
            self:CreateUI()
        end

        -- Show/hide based on whether we have taunters
        if hasTaunters then
            self.forceVisible = true
            self.frame:Show()
        else
            self.forceVisible = false
            -- Don't hide immediately - let RefreshRoster decide
        end

        -- Force rebuild the tracker list (order changed, must rebuild even if same taunters)
        self:RebuildList()

        -- Refresh config window if open
        if self.taunterUI and self.taunterUI:IsVisible() and self.taunterUI.RefreshPanels then
            self.taunterUI.RefreshPanels()
        end
        if IchaTauntDB.debugMode then
            print("[IchaTaunt Sync] Applied order from " .. sender .. " (" .. (hasTaunters and "has taunters" or "empty") .. ")")
        end
        return
    end

    -- TAUNTERS: message - Taunters list
    if strfind(msg, "^TAUNTERS:") then
        -- Only accept from leaders/officers
        if not self:IsRaidLeader(sender) then
            if IchaTauntDB.debugMode then
                print("[IchaTaunt Sync] Ignoring TAUNTERS from non-leader: " .. sender)
            end
            return
        end

        local taunterStr = strsub(msg, 10) -- Remove "TAUNTERS:" prefix
        local newTaunters = {}
        local taunterList = ParseCommaSeparated(taunterStr)
        for _, name in ipairs(taunterList) do
            if name and name ~= "" then
                newTaunters[name] = true
            end
        end

        IchaTauntDB.taunters = newTaunters
        self.taunters = newTaunters

        -- Check if we have any taunters
        local hasTaunters = false
        for _ in pairs(newTaunters) do
            hasTaunters = true
            break
        end

        -- Ensure tracker frame exists
        if not self.frame then
            self:CreateUI()
        end

        -- Show/hide based on whether we have taunters
        if hasTaunters then
            self.forceVisible = true
            self.frame:Show()
        else
            self.forceVisible = false
            -- Don't hide immediately - let RefreshRoster decide
        end

        -- Refresh roster which will rebuild the list
        self:RefreshRoster()

        -- Refresh config window if open
        if self.taunterUI and self.taunterUI:IsVisible() and self.taunterUI.RefreshPanels then
            self.taunterUI.RefreshPanels()
        end
        if IchaTauntDB.debugMode then
            print("[IchaTaunt Sync] Applied taunters from " .. sender .. " (" .. (hasTaunters and "has taunters" or "empty") .. ")")
        end
        return
    end

    -- ADD:name - Add a taunter (from leader)
    if strfind(msg, "^ADD:") then
        if not self:IsRaidLeader(sender) then return end

        local name = strsub(msg, 5)
        if not IchaTauntDB.taunters then IchaTauntDB.taunters = {} end
        if not IchaTauntDB.taunterOrder then IchaTauntDB.taunterOrder = {} end

        -- Add to taunters
        IchaTauntDB.taunters[name] = true
        self.taunters[name] = true

        -- Add to order if not present
        local found = false
        for _, orderName in ipairs(IchaTauntDB.taunterOrder) do
            if orderName == name then found = true break end
        end
        if not found then
            table.insert(IchaTauntDB.taunterOrder, name)
        end

        -- Update local order reference
        self.order = IchaTauntDB.taunterOrder

        -- Ensure tracker frame exists and is shown
        if not self.frame then
            self:CreateUI()
        end
        self.forceVisible = true
        self.frame:Show()

        -- Refresh roster which will rebuild the list
        self:RefreshRoster()

        -- Refresh config window if open
        if self.taunterUI and self.taunterUI:IsVisible() and self.taunterUI.RefreshPanels then
            self.taunterUI.RefreshPanels()
        end
        return
    end

    -- REMOVE:name - Remove a taunter (from leader)
    if strfind(msg, "^REMOVE:") then
        if not self:IsRaidLeader(sender) then return end

        local name = strsub(msg, 8)
        if IchaTauntDB.taunters then
            IchaTauntDB.taunters[name] = nil
        end
        if self.taunters then
            self.taunters[name] = nil
        end

        -- Remove from order
        if IchaTauntDB.taunterOrder then
            for i, orderName in ipairs(IchaTauntDB.taunterOrder) do
                if orderName == name then
                    table.remove(IchaTauntDB.taunterOrder, i)
                    break
                end
            end
        end

        -- Update local references
        self.order = IchaTauntDB.taunterOrder or {}

        -- Refresh roster which will rebuild the list
        self:RefreshRoster()

        -- Refresh config window if open
        if self.taunterUI and self.taunterUI:IsVisible() and self.taunterUI.RefreshPanels then
            self.taunterUI.RefreshPanels()
        end
        return
    end

    -- DTPS:value:window - Damage taken per second from sender (they broadcast their own)
    if strfind(msg, "^DTPS:") then
        if IchaTaunt_DPS and IchaTaunt_DPS.ReceiveDTPS then
            local dataStr = strsub(msg, 6)
            local parts = {}
            local pos = 1
            local len = strlen(dataStr)
            while pos <= len do
                local startPos, endPos = strfind(dataStr, "[^:]+", pos)
                if not startPos then break end
                table.insert(parts, strsub(dataStr, startPos, endPos))
                pos = endPos + 1
                if strsub(dataStr, pos, pos) == ":" then pos = pos + 1 end
            end
            if parts[1] then
                IchaTaunt_DPS:ReceiveDTPS(sender, parts[1], parts[2])
            end
        end
        return
    end

    -- CD_SNAPSHOT:PlayerName:SpellID:RemainingSeconds - Current cooldown state from raid member (for reconnecting after DC)
    if strfind(msg, "^CD_SNAPSHOT:") then
        local dataStr = strsub(msg, 13)
        local parts = {}
        local pos = 1
        local len = strlen(dataStr)
        while pos <= len do
            local startPos, endPos = strfind(dataStr, "[^:]+", pos)
            if not startPos then break end
            table.insert(parts, strsub(dataStr, startPos, endPos))
            pos = endPos + 1
            if strsub(dataStr, pos, pos) == ":" then pos = pos + 1 end
        end
        if parts[1] and parts[2] and parts[3] then
            local playerName = parts[1]
            local spellID = tonumber(parts[2])
            local remaining = tonumber(parts[3])
            if playerName and spellID and remaining and remaining > 0 then
                self:ApplyCooldownSnapshot(playerName, spellID, remaining)
            end
        end
        return
    end

    -- CD:PlayerName:SpellID:Cooldown:Resisted - Cooldown sync from another player
    if strfind(msg, "^CD:") then
        IchaTaunt_Print("Processing CD message: " .. strsub(msg, 1, 40))
        -- Parse the cooldown message: CD:PlayerName:SpellID:Cooldown:Resisted (split by colon, no gfind)
        local dataStr = strsub(msg, 4)
        local parts = {}
        local pos = 1
        local len = strlen(dataStr)
        while pos <= len do
            local startPos, endPos = strfind(dataStr, "[^:]+", pos)
            if not startPos then break end
            table.insert(parts, strsub(dataStr, startPos, endPos))
            pos = endPos + 1
            if strsub(dataStr, pos, pos) == ":" then pos = pos + 1 end
        end

        if parts[1] and parts[2] and parts[3] then
            local playerName = parts[1]
            local spellID = tonumber(parts[2])
            local cooldown = tonumber(parts[3])
            local wasResisted = parts[4] == "1"

            if playerName and spellID and cooldown then
                -- Verify the sender matches the player in the message (prevent spoofing)
                local senderBase = self:NormalizePlayerName(sender)
                local playerNameBase = self:NormalizePlayerName(playerName)
                IchaTaunt_Print("CD check: sender='" .. tostring(sender) .. "' senderBase='" .. tostring(senderBase) .. "' playerNameBase='" .. tostring(playerNameBase) .. "' match=" .. tostring(senderBase == playerNameBase))
                if senderBase == playerNameBase then
                    -- Resolve actual key (taunters/taunterBars may use "Alice" or "Alice-Realm")
                    local resolvedName = playerNameBase
                    if self.taunters then
                        for name, _ in pairs(self.taunters) do
                            if self:NormalizePlayerName(name) == playerNameBase then
                                resolvedName = name
                                break
                            end
                        end
                    end
                    IchaTaunt_Print("Calling ApplySyncedCooldown(" .. resolvedName .. ", " .. spellID .. ", " .. cooldown .. ")")
                    self:ApplySyncedCooldown(resolvedName, spellID, cooldown, wasResisted)
                else
                    IchaTaunt_Print("CD ignored - sender " .. tostring(sender) .. " != " .. tostring(playerName))
                end
            else
                IchaTaunt_Print("CD ignored - missing playerName/spellID/cooldown")
            end
        else
            IchaTaunt_Print("CD ignored - parse failed (parts)")
        end
        return
    end

    -- Legacy support: plain comma-separated names (old ORDER format)
    if not strfind(msg, ":") then
        if not self:IsRaidLeader(sender) then return end

        local newOrder = ParseCommaSeparated(msg)
        IchaTauntDB.taunterOrder = newOrder
        self.order = newOrder

        -- Ensure tracker frame exists and is shown
        if not self.frame then
            self:CreateUI()
        end
        self.forceVisible = true
        self.frame:Show()

        -- Refresh roster which will rebuild the list
        self:RefreshRoster()

        -- Refresh config window if open
        if self.taunterUI and self.taunterUI:IsVisible() and self.taunterUI.RefreshPanels then
            self.taunterUI.RefreshPanels()
        end
    end
end

-- Legacy functions for backward compatibility
function IchaTaunt:ReceiveOrder(msg, sender)
    self:ParseSyncMessage("ORDER:" .. msg, sender)
end

function IchaTaunt:ReceiveTaunters(msg)
    self:ParseSyncMessage("TAUNTERS:" .. msg, "UNKNOWN")
end

-- Two-panel taunter selection UI
local function ShowTaunterPopup()
    if not IchaTaunt.taunterUI then
        local theme = IchaTaunt:GetTheme()
        local c = theme.config

        local f = CreateFrame("Frame", "IchaTauntTaunterUI", UIParent)
        f:SetWidth(600)
        f:SetHeight(400)  -- Standard height
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        f:SetFrameStrata("DIALOG")  -- Ensure config window appears above other UI elements

        -- Apply theme backdrop
        f:SetBackdrop(c.backdrop)
        f:SetBackdropColor(unpack(c.bgColor))

        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() this:StartMoving() end)
        f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

        -- Title with theme color
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", f, "TOP", 0, -15)
        title:SetText("IchaTaunt - Select Taunters")
        title:SetTextColor(unpack(c.titleColor))
        f.title = title

        -- Status text (leader/member indicator)
        local statusText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        statusText:SetPoint("TOP", title, "BOTTOM", 0, -3)
        f.statusText = statusText

        local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        subtitle:SetPoint("TOP", statusText, "BOTTOM", 0, -2)
        subtitle:SetText("Add taunters to track their cooldowns")
        f.subtitle = subtitle

        -- Close X (top right corner)
        local closeX = CreateFrame("Button", nil, f)
        closeX:SetWidth(20)
        closeX:SetHeight(20)
        closeX:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
        closeX:SetScript("OnClick", function()
            f:Hide()
            if IchaTaunt.optionsMenu and IchaTaunt.optionsMenu:IsVisible() then
                IchaTaunt.optionsMenu:Hide()
            end
        end)
        local closeXText = closeX:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        closeXText:SetPoint("CENTER", closeX, "CENTER", 0, 0)
        closeXText:SetText("X")
        closeXText:SetTextColor(1, 1, 1)
        closeX:SetScript("OnEnter", function() closeXText:SetTextColor(1, 0.82, 0) end)
        closeX:SetScript("OnLeave", function() closeXText:SetTextColor(1, 1, 1) end)

        -- Convert to Raid button (below close X)
        local convertBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        convertBtn:SetWidth(110)
        convertBtn:SetHeight(20)
        convertBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -15, -32)
        convertBtn:SetText("Convert to Raid")
        convertBtn:SetScript("OnClick", function()
            if GetNumRaidMembers() > 0 then
                print("IchaTaunt: Already in a raid")
            elseif GetNumPartyMembers() > 0 then
                ConvertToRaid()
                print("IchaTaunt: Converted party to raid")
            else
                print("IchaTaunt: Must be in a party to convert to raid")
            end
        end)
        convertBtn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
            GameTooltip:SetText("Convert to Raid")
            GameTooltip:AddLine("Convert your party to a raid group", 1, 1, 1)
            GameTooltip:Show()
        end)
        convertBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        f.convertBtn = convertBtn

        -- LEFT PANEL: Raid/Party Members
        local leftPanel = CreateFrame("Frame", nil, f)
        leftPanel:SetWidth(260)
        leftPanel:SetHeight(300)
        leftPanel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -60)
        leftPanel:SetBackdrop(c.panelBackdrop)
        leftPanel:SetBackdropColor(unpack(c.panelBgColor))

        local leftTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        leftTitle:SetPoint("TOP", leftPanel, "TOP", 0, -10)
        leftTitle:SetText("Raid/Party")
        leftTitle:SetTextColor(unpack(c.titleColor))
        
        -- Create scroll frame for left panel
        local leftScroll = CreateFrame("ScrollFrame", nil, leftPanel)
        leftScroll:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 10, -30)
        leftScroll:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -10, 10)
        leftScroll:EnableMouseWheel(true)
        leftScroll:SetScript("OnMouseWheel", function()
            local newValue = this:GetVerticalScroll() - (arg1 * 20)
            if newValue < 0 then
                newValue = 0
            end
            local maxValue = this:GetVerticalScrollRange()
            if newValue > maxValue then
                newValue = maxValue
            end
            this:SetVerticalScroll(newValue)
        end)
        
        local leftScrollChild = CreateFrame("Frame", nil, leftScroll)
        leftScrollChild:SetWidth(230)
        leftScrollChild:SetHeight(1)
        leftScroll:SetScrollChild(leftScrollChild)
        
        f.leftScrollChild = leftScrollChild
        
        -- RIGHT PANEL: Taunt Order
        local rightPanel = CreateFrame("Frame", nil, f)
        rightPanel:SetWidth(260)
        rightPanel:SetHeight(300)
        rightPanel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, -60)
        rightPanel:SetBackdrop(c.panelBackdrop)
        rightPanel:SetBackdropColor(unpack(c.panelBgColor))

        local rightTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rightTitle:SetPoint("TOP", rightPanel, "TOP", 0, -10)
        rightTitle:SetText("Taunt Order (use arrows to reorder)")
        rightTitle:SetTextColor(unpack(c.titleColor))
        
        -- Create scroll frame for right panel
        local rightScroll = CreateFrame("ScrollFrame", nil, rightPanel)
        rightScroll:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 10, -30)
        rightScroll:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -10, 10)
        rightScroll:EnableMouseWheel(true)
        rightScroll:SetScript("OnMouseWheel", function()
            local newValue = this:GetVerticalScroll() - (arg1 * 20)
            if newValue < 0 then
                newValue = 0
            end
            local maxValue = this:GetVerticalScrollRange()
            if newValue > maxValue then
                newValue = maxValue
            end
            this:SetVerticalScroll(newValue)
        end)
        
        local rightScrollChild = CreateFrame("Frame", nil, rightScroll)
        rightScrollChild:SetWidth(230)
        rightScrollChild:SetHeight(1)
        rightScroll:SetScrollChild(rightScrollChild)
        
        f.rightScrollChild = rightScrollChild

        -- Store panels for refresh function
        f.leftPanel = leftPanel
        f.rightPanel = rightPanel
        
        -- Function to refresh the UI panels
        local function RefreshPanels()
            -- Update status text based on leader status
            local canControl = IchaTaunt:CanControl()
            local inRaid = GetNumRaidMembers() > 0
            local inParty = GetNumPartyMembers() > 0
            local inGroup = inRaid or inParty

            if inGroup then
                if canControl then
                    f.statusText:SetText("|cFF00FF00[Leader/Officer]|r - Changes sync to raid")
                    f.statusText:SetTextColor(0, 1, 0)
                else
                    f.statusText:SetText("|cFFFF6600[Member]|r - View only, synced from leader")
                    f.statusText:SetTextColor(1, 0.4, 0)
                end
            else
                f.statusText:SetText("|cFFFFFF00[Solo]|r - Configure for when you join a group")
                f.statusText:SetTextColor(1, 1, 0)
            end

            -- Update Convert to Raid button state
            if f.convertBtn then
                if inRaid then
                    f.convertBtn:SetText("In Raid")
                    f.convertBtn:Disable()
                elseif inParty then
                    -- Check if we can convert (party leader can convert)
                    -- Use IsPartyLeader() directly for most accurate check
                    local isLeader = IsPartyLeader() == 1 or IsPartyLeader() == true
                    f.convertBtn:SetText("Convert to Raid")
                    if isLeader then
                        f.convertBtn:Enable()
                    else
                        f.convertBtn:Disable()
                    end
                else
                    f.convertBtn:SetText("Not in Group")
                    f.convertBtn:Disable()
                end
            end

            -- Clear existing elements
            if f.leftElements then
                for _, element in pairs(f.leftElements) do
                    if element.Hide then element:Hide() end
                end
            end
            if f.rightElements then
                for _, element in pairs(f.rightElements) do
                    if element.Hide then element:Hide() end
                end
            end

            f.leftElements = {}
            f.rightElements = {}
            
            -- LEFT PANEL: Show all group members with + buttons
            local yOffset = -5
            local allMembers = {}
            
            -- Get all group members
            if GetNumRaidMembers() > 0 then
                for i = 1, GetNumRaidMembers() do
                    local name, _, _, _, _, classFile = GetRaidRosterInfo(i)
                    if name and classFile then
                        table.insert(allMembers, {name = name, class = classFile})
                    end
                end
            elseif GetNumPartyMembers() > 0 then
                for i = 1, GetNumPartyMembers() do
                    local name = UnitName("party" .. i)
                    local classFile = UnitClass("party" .. i)
                    if name and classFile then
                        table.insert(allMembers, {name = name, class = classFile})
                    end
                end
                -- Add yourself
                local playerName = UnitName("player")
                local playerClass = UnitClass("player")
                if playerName and playerClass then
                    table.insert(allMembers, {name = playerName, class = playerClass})
                end
            else
                -- Solo
                local playerName = UnitName("player")
                local playerClass = UnitClass("player")
                if playerName and playerClass then
                    table.insert(allMembers, {name = playerName, class = playerClass})
                end
            end
            
            -- Sort members alphabetically
            table.sort(allMembers, function(a, b) return a.name < b.name end)
            
            -- Create left panel entries
            for _, member in ipairs(allMembers) do
                local name = member.name
                local class = member.class
                
                -- Only show taunting classes
                local tauntClasses = IchaTaunt_GetAllTauntClasses()
                if tauntClasses[class] then
                    local entry = CreateFrame("Frame", nil, f.leftScrollChild)
                    entry:SetWidth(240)
                    entry:SetHeight(20)
                    entry:SetPoint("TOPLEFT", f.leftScrollChild, "TOPLEFT", 0, yOffset)
                    
                    -- Player name with class color
                    local nameText = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    nameText:SetPoint("LEFT", entry, "LEFT", 0, 0)
                    nameText:SetText(name)
                    local r, g, b = unpack(IchaTaunt:GetClassColor(class))
                    nameText:SetTextColor(r, g, b)
                    
                    -- + button
                    local addBtn = CreateFrame("Button", nil, entry, "UIPanelButtonTemplate")
                    addBtn:SetWidth(20)
                    addBtn:SetHeight(20)
                    addBtn:SetPoint("RIGHT", entry, "RIGHT", 0, 0)
                    addBtn:SetText("+")
                    
                    -- Capture the name value locally to avoid closure issues
                    local playerName = name

                    -- Disable button if not leader in a group
                    local inGroup = GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
                    if inGroup and not IchaTaunt:CanControl() then
                        addBtn:Disable()
                    end

                    addBtn:SetScript("OnClick", function()
                        -- Check permissions in group
                        local inGroup = GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
                        if inGroup and not IchaTaunt:CanControl() then
                            print("IchaTaunt: Only raid leader/officers can modify taunter list")
                            return
                        end

                        -- Ensure IchaTauntDB exists and has proper structure
                        if not IchaTauntDB then
                            IchaTauntDB = {
                                taunterOrder = {},
                                taunters = {},
                                showInRaidOnly = false,  -- false = show in party or raid; true = only show in raid
                                position = { x = 0, y = 0 }
                            }
                        end
                        if not IchaTauntDB.taunterOrder then
                            IchaTauntDB.taunterOrder = {}
                        end
                        if not IchaTauntDB.taunters then
                            IchaTauntDB.taunters = {}
                        end

                        -- Add to taunt order if not already there
                        local found = false
                        for _, orderName in ipairs(IchaTauntDB.taunterOrder) do
                            if orderName == playerName then
                                found = true
                                break
                            end
                        end

                        if not found then
                            table.insert(IchaTauntDB.taunterOrder, playerName)
                            IchaTauntDB.taunters[playerName] = true
                            -- Safely update local references
                            IchaTaunt.taunters = IchaTauntDB.taunters or {}
                            IchaTaunt.order = IchaTauntDB.taunterOrder or {}

                            -- Auto-broadcast to raid if enabled
                            IchaTaunt:AutoBroadcast()

                            -- Safely refresh UI
                            if RefreshPanels then
                                RefreshPanels()
                            end
                            if IchaTaunt.RefreshRoster then
                                IchaTaunt:RefreshRoster()
                            end
                            if IchaTauntDB.debugMode then
                                print("IchaTaunt: Added " .. playerName .. " to taunt order")
                            end
                        end
                    end)
                    
                    -- Safely add to elements table
                    if f.leftElements then
                        table.insert(f.leftElements, entry)
                    end
                    yOffset = yOffset - 22
                end
            end
            
            -- Update left scroll child height
            local leftContentHeight = math.abs(yOffset) + 5
            f.leftScrollChild:SetHeight(math.max(leftContentHeight, 1))
            
            -- RIGHT PANEL: Show taunt order with drag handles and controls
            yOffset = -5
            local totalTaunters = 0
            for _ in ipairs(IchaTauntDB.taunterOrder) do
                totalTaunters = totalTaunters + 1
            end

            for i, name in ipairs(IchaTauntDB.taunterOrder) do
                local entry = CreateFrame("Frame", nil, f.rightScrollChild)
                entry:SetWidth(240)
                entry:SetHeight(20)
                entry:SetPoint("TOPLEFT", f.rightScrollChild, "TOPLEFT", 0, yOffset)
                entry.orderIndex = i
                entry.playerName = name

                -- Check if user can control
                local inGroup = GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
                local canControl = not inGroup or IchaTaunt:CanControl()

                -- Up arrow button
                local upBtn = CreateFrame("Button", nil, entry)
                upBtn:SetWidth(16)
                upBtn:SetHeight(16)
                upBtn:SetPoint("LEFT", entry, "LEFT", 0, 0)
                upBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
                upBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Down")
                upBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
                if i == 1 or not canControl then
                    upBtn:Disable()
                    upBtn:SetAlpha(0.3)
                end
                local capturedIndex = i
                upBtn:SetScript("OnClick", function()
                    if capturedIndex <= 1 then return end
                    -- Swap with previous
                    local temp = IchaTauntDB.taunterOrder[capturedIndex - 1]
                    IchaTauntDB.taunterOrder[capturedIndex - 1] = IchaTauntDB.taunterOrder[capturedIndex]
                    IchaTauntDB.taunterOrder[capturedIndex] = temp
                    IchaTaunt.order = IchaTauntDB.taunterOrder

                    -- Broadcast order change to raid (reorder is always intentional)
                    local inGroup = GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
                    if inGroup and IchaTaunt:CanControl() then
                        IchaTaunt:BroadcastOrder()
                    end

                    RefreshPanels()
                    -- Force rebuild tracker to reflect new order
                    IchaTaunt:RebuildList()
                end)

                -- Down arrow button
                local downBtn = CreateFrame("Button", nil, entry)
                downBtn:SetWidth(16)
                downBtn:SetHeight(16)
                downBtn:SetPoint("LEFT", upBtn, "RIGHT", 2, 0)
                downBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
                downBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
                downBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
                if i == totalTaunters or not canControl then
                    downBtn:Disable()
                    downBtn:SetAlpha(0.3)
                end
                downBtn:SetScript("OnClick", function()
                    if capturedIndex >= totalTaunters then return end
                    -- Swap with next
                    local temp = IchaTauntDB.taunterOrder[capturedIndex + 1]
                    IchaTauntDB.taunterOrder[capturedIndex + 1] = IchaTauntDB.taunterOrder[capturedIndex]
                    IchaTauntDB.taunterOrder[capturedIndex] = temp
                    IchaTaunt.order = IchaTauntDB.taunterOrder

                    -- Broadcast order change to raid (reorder is always intentional)
                    local inGroup = GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
                    if inGroup and IchaTaunt:CanControl() then
                        IchaTaunt:BroadcastOrder()
                    end

                    RefreshPanels()
                    -- Force rebuild tracker to reflect new order
                    IchaTaunt:RebuildList()
                end)

                -- Order number
                local orderText = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                orderText:SetPoint("LEFT", downBtn, "RIGHT", 5, 0)
                orderText:SetText(i .. ".")
                orderText:SetTextColor(1, 0.82, 0)

                -- Player name with class color
                local nameText = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                nameText:SetPoint("LEFT", orderText, "RIGHT", 5, 0)
                nameText:SetText(name)
                local class = IchaTaunt:GetPlayerClass(name)
                if class then
                    local r, g, b = unpack(IchaTaunt:GetClassColor(class))
                    nameText:SetTextColor(r, g, b)
                else
                    nameText:SetTextColor(1, 1, 1)
                end

                -- - button (remove)
                local removeBtn = CreateFrame("Button", nil, entry, "UIPanelButtonTemplate")
                removeBtn:SetWidth(20)
                removeBtn:SetHeight(20)
                removeBtn:SetPoint("RIGHT", entry, "RIGHT", 0, 0)
                removeBtn:SetText("-")

                -- Capture the name value locally to avoid closure issues
                local playerName = name

                -- Disable button if not leader in a group
                if not canControl then
                    removeBtn:Disable()
                end

                removeBtn:SetScript("OnClick", function()
                    -- Check permissions in group
                    local inGroup = GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
                    if inGroup and not IchaTaunt:CanControl() then
                        print("IchaTaunt: Only raid leader/officers can modify taunter list")
                        return
                    end

                    -- Ensure IchaTauntDB exists and has proper structure
                    if not IchaTauntDB then
                        IchaTauntDB = {
                            taunterOrder = {},
                            taunters = {},
                            showInRaidOnly = false,  -- false = show in party or raid; true = only show in raid
                            position = { x = 0, y = 0 }
                        }
                    end
                    if not IchaTauntDB.taunterOrder then
                        IchaTauntDB.taunterOrder = {}
                    end
                    if not IchaTauntDB.taunters then
                        IchaTauntDB.taunters = {}
                    end

                    -- Remove from taunt order
                    for j, orderName in ipairs(IchaTauntDB.taunterOrder) do
                        if orderName == playerName then
                            table.remove(IchaTauntDB.taunterOrder, j)
                            break
                        end
                    end

                    -- Remove from taunters if not in order anymore
                    local stillInOrder = false
                    if IchaTauntDB.taunterOrder then
                        for _, orderName in ipairs(IchaTauntDB.taunterOrder) do
                            if orderName == playerName then
                                stillInOrder = true
                                break
                            end
                        end
                    end
                    if not stillInOrder then
                        -- Ensure taunters table exists before modifying
                        if not IchaTauntDB.taunters then
                            IchaTauntDB.taunters = {}
                        end
                        -- Safe removal
                        IchaTauntDB.taunters[playerName] = nil
                    end

                    -- Safely update local references
                    IchaTaunt.taunters = IchaTauntDB.taunters or {}
                    IchaTaunt.order = IchaTauntDB.taunterOrder or {}

                    -- Auto-broadcast if enabled
                    IchaTaunt:AutoBroadcast()

                    -- Safely refresh UI
                    if RefreshPanels then
                        RefreshPanels()
                    end
                    if IchaTaunt.RefreshRoster then
                        IchaTaunt:RefreshRoster()
                    end

                    if IchaTauntDB.debugMode then
                        print("IchaTaunt: Removed " .. playerName .. " from taunt order")
                    end
                end)
                
                -- Safely add to elements table
                if f.rightElements then
                    table.insert(f.rightElements, entry)
                end
                yOffset = yOffset - 22
            end
            
            -- Update right scroll child height
            local rightContentHeight = math.abs(yOffset) + 5
            f.rightScrollChild:SetHeight(math.max(rightContentHeight, 1))
        end
        
        f.RefreshPanels = RefreshPanels

        -- Button container
        local buttonFrame = CreateFrame("Frame", nil, f)
        buttonFrame:SetWidth(500)
        buttonFrame:SetHeight(30)
        buttonFrame:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)

        -- Options button (opens theme & scale settings)
        local optionsBtn = CreateFrame("Button", nil, buttonFrame, "UIPanelButtonTemplate")
        optionsBtn:SetWidth(70)
        optionsBtn:SetHeight(22)
        optionsBtn:SetPoint("LEFT", buttonFrame, "LEFT", 20, 0)
        optionsBtn:SetText("Options")
        optionsBtn:SetScript("OnClick", function()
            IchaTaunt:ShowOptionsMenu()
        end)
        optionsBtn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_TOP")
            GameTooltip:SetText("Open theme and scale options")
            GameTooltip:Show()
        end)
        optionsBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        f:Hide()
        IchaTaunt.taunterUI = f
        
        -- Hook into the frame's OnHide to close options menu
        f:SetScript("OnHide", function()
            if IchaTaunt.optionsMenu and IchaTaunt.optionsMenu:IsVisible() then
                IchaTaunt.optionsMenu:Hide()
            end
        end)
    end

    -- Refresh panels and show
    IchaTaunt.taunterUI.RefreshPanels()
    IchaTaunt.taunterUI:Show()
end

-- ============================================
-- OPTIONS MENU (Theme & Scale Settings)
-- ============================================

function IchaTaunt:ShowOptionsMenu()
    if not self.optionsMenu then
        self:CreateOptionsMenu()
    end

    -- Refresh slider/checkbox states
    self:RefreshOptionsMenu()

    -- Position relative to main config window
    if self.taunterUI and self.taunterUI:IsVisible() then
        self.optionsMenu:ClearAllPoints()
        self.optionsMenu:SetPoint("TOPLEFT", self.taunterUI, "TOPRIGHT", 5, 0)
    else
        self.optionsMenu:ClearAllPoints()
        self.optionsMenu:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    self.optionsMenu:Show()
end

function IchaTaunt:CreateOptionsMenu()
    local theme = self:GetTheme()
    local c = theme.config

    local f = CreateFrame("Frame", "IchaTauntOptionsMenu", UIParent)
    f:SetWidth(220)
    f:SetHeight(400)  -- Height for theme, scale, position, show-in-raid, DTPS
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(10)

    -- Apply theme backdrop
    f:SetBackdrop(c.backdrop)
    f:SetBackdropColor(unpack(c.bgColor))

    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -12)
    title:SetText("Options")
    title:SetTextColor(unpack(c.titleColor))
    f.title = title

    -- Close X (top right)
    local closeX = CreateFrame("Button", nil, f)
    closeX:SetWidth(20)
    closeX:SetHeight(20)
    closeX:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    closeX:SetScript("OnClick", function() f:Hide() end)
    local closeXText = closeX:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    closeXText:SetPoint("CENTER", closeX, "CENTER", 0, 0)
    closeXText:SetText("X")
    closeXText:SetTextColor(1, 1, 1)
    closeX:SetScript("OnEnter", function() closeXText:SetTextColor(1, 0.82, 0) end)
    closeX:SetScript("OnLeave", function() closeXText:SetTextColor(1, 1, 1) end)

    -- ===== THEME SECTION =====
    local themeSection = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeSection:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -40)
    themeSection:SetText("Theme")
    themeSection:SetTextColor(unpack(c.titleColor))
    f.themeSection = themeSection

    -- Theme buttons container
    local themeOrder = {"default", "dark", "elvui"}
    local themeButtons = {}
    local yOffset = -60

    for i, themeKey in ipairs(themeOrder) do
        local themeData = IchaTaunt_Themes[themeKey]
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetWidth(190)
        btn:SetHeight(22)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", 15, yOffset)
        btn:SetText(themeData.name)

        local capturedKey = themeKey
        btn:SetScript("OnClick", function()
            IchaTaunt:SetTheme(capturedKey)
            IchaTaunt:RefreshOptionsMenu()
            -- Refresh main UI with new theme
            if IchaTaunt.taunterUI then
                IchaTaunt.taunterUI:Hide()
                IchaTaunt.taunterUI = nil
                ShowTaunterPopup()
                -- Reopen options menu
                IchaTaunt:ShowOptionsMenu()
            end
        end)

        themeButtons[themeKey] = btn
        yOffset = yOffset - 26
    end
    f.themeButtons = themeButtons

    -- ===== SCALE SECTION =====
    local scaleSection = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scaleSection:SetPoint("TOPLEFT", f, "TOPLEFT", 15, yOffset - 10)
    scaleSection:SetText("Tracker Scale")
    scaleSection:SetTextColor(unpack(c.titleColor))
    f.scaleSection = scaleSection

    -- Scale value display
    local scaleValue = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scaleValue:SetPoint("TOPRIGHT", f, "TOPRIGHT", -15, yOffset - 10)
    scaleValue:SetText(format("%.0f%%", (IchaTauntDB.scale or 1.0) * 100))
    f.scaleValue = scaleValue

    yOffset = yOffset - 35

    -- Scale slider container
    local sliderFrame = CreateFrame("Frame", nil, f)
    sliderFrame:SetWidth(190)
    sliderFrame:SetHeight(20)
    sliderFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 15, yOffset)

    -- Scale down button
    local scaleDown = CreateFrame("Button", nil, sliderFrame, "UIPanelButtonTemplate")
    scaleDown:SetWidth(30)
    scaleDown:SetHeight(22)
    scaleDown:SetPoint("LEFT", sliderFrame, "LEFT", 0, 0)
    scaleDown:SetText("-")
    scaleDown:SetScript("OnClick", function()
        local newScale = (IchaTauntDB.scale or 1.0) - 0.1
        IchaTaunt:SetScale(newScale)
        IchaTaunt:RefreshOptionsMenu()
    end)

    -- Scale up button
    local scaleUp = CreateFrame("Button", nil, sliderFrame, "UIPanelButtonTemplate")
    scaleUp:SetWidth(30)
    scaleUp:SetHeight(22)
    scaleUp:SetPoint("RIGHT", sliderFrame, "RIGHT", 0, 0)
    scaleUp:SetText("+")
    scaleUp:SetScript("OnClick", function()
        local newScale = (IchaTauntDB.scale or 1.0) + 0.1
        IchaTaunt:SetScale(newScale)
        IchaTaunt:RefreshOptionsMenu()
    end)

    -- Scale preset buttons
    yOffset = yOffset - 30
    local presetFrame = CreateFrame("Frame", nil, f)
    presetFrame:SetWidth(190)
    presetFrame:SetHeight(22)
    presetFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 15, yOffset)

    local presets = {
        {label = "50%", value = 0.5},
        {label = "100%", value = 1.0},
        {label = "150%", value = 1.5},
        {label = "200%", value = 2.0},
    }

    local presetWidth = 45
    for i, preset in ipairs(presets) do
        local btn = CreateFrame("Button", nil, presetFrame, "UIPanelButtonTemplate")
        btn:SetWidth(presetWidth)
        btn:SetHeight(20)
        btn:SetPoint("LEFT", presetFrame, "LEFT", (i-1) * (presetWidth + 2), 0)
        btn:SetText(preset.label)

        local capturedValue = preset.value
        btn:SetScript("OnClick", function()
            IchaTaunt:SetScale(capturedValue)
            IchaTaunt:RefreshOptionsMenu()
        end)
    end

    -- ===== RESET POSITION SECTION =====
    yOffset = yOffset - 30
    local resetSection = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resetSection:SetPoint("TOPLEFT", f, "TOPLEFT", 15, yOffset - 10)
    resetSection:SetText("Tracker Position")
    resetSection:SetTextColor(unpack(c.titleColor))
    f.resetSection = resetSection

    yOffset = yOffset - 30
    local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBtn:SetWidth(190)
    resetBtn:SetHeight(22)
    resetBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 15, yOffset)
    resetBtn:SetText("Reset Position")
    resetBtn:SetScript("OnClick", function()
        -- Reset position to screen center
        IchaTauntDB.position.x = 0
        IchaTauntDB.position.y = 0
        if IchaTaunt.frame then
            IchaTaunt.frame:ClearAllPoints()
            IchaTaunt.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            print("IchaTaunt: Tracker position reset to screen center")
        else
            print("IchaTaunt: Position will be reset when tracker is next shown")
        end
    end)
    resetBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText("Reset Tracker Position")
        GameTooltip:AddLine("Moves tracker to center of screen", 1, 1, 1, 1)
        GameTooltip:Show()
    end)
    resetBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Unlock / Lock Position (toggle; when locked the tracker is click-through so you need this or /it unlock)
    yOffset = yOffset - 28
    local lockUnlockBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    lockUnlockBtn:SetWidth(190)
    lockUnlockBtn:SetHeight(22)
    lockUnlockBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 15, yOffset)
    lockUnlockBtn:SetScript("OnClick", function()
        IchaTaunt:ToggleLock()
        if IchaTaunt.optionsMenu and IchaTaunt.optionsMenu.lockUnlockBtn then
            IchaTaunt:RefreshLockUnlockButton()
        end
    end)
    lockUnlockBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        if IchaTaunt.locked then
            GameTooltip:SetText("Unlock Tracker Position")
            GameTooltip:AddLine("Unlock so you can move the tracker", 1, 1, 1, 1)
        else
            GameTooltip:SetText("Lock Tracker Position")
            GameTooltip:AddLine("Lock so the tracker is click-through (no dead area)", 1, 1, 1, 1)
        end
        GameTooltip:AddLine("You can also click the X on the tracker to lock", 0.7, 0.7, 0.7, 1)
        GameTooltip:Show()
    end)
    lockUnlockBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    f.lockUnlockBtn = lockUnlockBtn
    lockUnlockBtn:SetText(IchaTaunt.locked and "Unlock Position" or "Lock Position")

    -- Only show in raid (hide tracker when in party)
    yOffset = yOffset - 28
    local showInRaidCheck = CreateFrame("CheckButton", "IchaTauntShowInRaidCheck", f, "UICheckButtonTemplate")
    showInRaidCheck:SetWidth(20)
    showInRaidCheck:SetHeight(20)
    showInRaidCheck:SetPoint("TOPLEFT", f, "TOPLEFT", 15, yOffset)
    showInRaidCheck:SetChecked(IchaTauntDB.showInRaidOnly)
    showInRaidCheck:SetScript("OnClick", function()
        IchaTauntDB.showInRaidOnly = (this:GetChecked() == 1)
        IchaTaunt:RefreshRoster()
    end)
    f.showInRaidCheck = showInRaidCheck
    local showInRaidLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    showInRaidLabel:SetPoint("LEFT", showInRaidCheck, "RIGHT", 5, 0)
    showInRaidLabel:SetText("Only show in raid")

    -- ===== DTPS SECTION =====
    yOffset = yOffset - 35
    local dtpsSection = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dtpsSection:SetPoint("TOPLEFT", f, "TOPLEFT", 15, yOffset)
    dtpsSection:SetText("DTPS Display")
    dtpsSection:SetTextColor(unpack(c.titleColor))
    f.dtpsSection = dtpsSection

    -- DTPS checkbox
    yOffset = yOffset - 22
    local dtpsCheck = CreateFrame("CheckButton", "IchaTauntDTPSCheck", f, "UICheckButtonTemplate")
    dtpsCheck:SetWidth(20)
    dtpsCheck:SetHeight(20)
    dtpsCheck:SetPoint("TOPLEFT", f, "TOPLEFT", 15, yOffset)

    -- Get current DTPS state
    local dtpsEnabled = true
    if IchaTaunt_DPS and IchaTaunt_DPS.config then
        dtpsEnabled = IchaTaunt_DPS.config.enabled
    end
    dtpsCheck:SetChecked(dtpsEnabled)

    dtpsCheck:SetScript("OnClick", function()
        local enabled = this:GetChecked() == 1
        if IchaTaunt_DPS then
            IchaTaunt_DPS:SetEnabled(enabled)
        end
    end)
    f.dtpsCheck = dtpsCheck

    local dtpsLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dtpsLabel:SetPoint("LEFT", dtpsCheck, "RIGHT", 5, 0)
    dtpsLabel:SetText("Show damage taken per second")

    f:Hide()
    self.optionsMenu = f
end

function IchaTaunt:RefreshLockUnlockButton()
    if not self.optionsMenu or not self.optionsMenu.lockUnlockBtn then return end
    local btn = self.optionsMenu.lockUnlockBtn
    if self.locked then
        btn:SetText("Unlock Position")
    else
        btn:SetText("Lock Position")
    end
end

function IchaTaunt:RefreshOptionsMenu()
    if not self.optionsMenu then return end

    local f = self.optionsMenu
    local theme = self:GetTheme()
    local c = theme.config

    -- Apply current theme backdrop
    f:SetBackdrop(c.backdrop)
    f:SetBackdropColor(unpack(c.bgColor))

    -- Update title color
    if f.title then
        f.title:SetTextColor(unpack(c.titleColor))
    end

    -- Update section header colors
    if f.themeSection then
        f.themeSection:SetTextColor(unpack(c.titleColor))
    end
    if f.scaleSection then
        f.scaleSection:SetTextColor(unpack(c.titleColor))
    end
    if f.resetSection then
        f.resetSection:SetTextColor(unpack(c.titleColor))
    end
    if f.dtpsSection then
        f.dtpsSection:SetTextColor(unpack(c.titleColor))
    end

    -- Update scale value display
    if f.scaleValue then
        f.scaleValue:SetText(format("%.0f%%", (IchaTauntDB.scale or 1.0) * 100))
    end

    -- Update lock/unlock button text
    self:RefreshLockUnlockButton()

    -- Highlight current theme button
    local currentTheme = IchaTauntDB.theme or "default"
    if f.themeButtons then
        for themeKey, btn in pairs(f.themeButtons) do
            if themeKey == currentTheme then
                -- Highlight current theme (gold text)
                btn:GetFontString():SetTextColor(1, 0.82, 0)
            else
                -- Normal color
                btn:GetFontString():SetTextColor(1, 1, 1)
            end
        end
    end

    -- Update "Only show in raid" checkbox
    if f.showInRaidCheck then
        f.showInRaidCheck:SetChecked(IchaTauntDB.showInRaidOnly)
    end

    -- Update DTPS checkbox
    if f.dtpsCheck and IchaTaunt_DPS then
        f.dtpsCheck:SetChecked(IchaTaunt_DPS.config.enabled)
    end
end

SLASH_ICHATAUNT1 = "/ichataunt"
SLASH_ICHATAUNT2 = "/it"
SlashCmdList["ICHATAUNT"] = function(msg)
    msg = strlower(msg or "")
    
    if msg == "" then
        -- Default /it opens config
        ShowTaunterPopup()
    elseif msg == "config" or msg == "setup" then
        ShowTaunterPopup()
    elseif strfind(msg, "^bar") then
        local _, _, action = strfind(msg, "^bar (.+)")
        if action == "show" then
            IchaTaunt:ShowTracker()
        elseif action == "hide" then
            IchaTaunt:HideTracker()
        else
            IchaTaunt:ToggleTracker()
        end
    elseif msg == "show" then
        IchaTaunt:ShowTracker()
    elseif msg == "hide" then
        IchaTaunt:HideTracker()
    elseif msg == "toggle" then
        IchaTaunt:ToggleTracker()
    elseif msg == "test" then
        -- Test cooldown on yourself
        local playerName = UnitName("player")
        local playerClass = UnitClass("player")
        local spells = IchaTaunt_GetSpellsByClass(playerClass)
        for spellID in pairs(spells) do
            IchaTaunt:StartCooldownFor(playerName, spellID, false)
            print("IchaTaunt: Testing cooldown for " .. playerName)
            break -- Just test first spell
        end
    elseif msg == "testresist" then
        -- Test resist on yourself
        local playerName = UnitName("player")
        local playerClass = UnitClass("player")
        local spells = IchaTaunt_GetSpellsByClass(playerClass)
        for spellID in pairs(spells) do
            IchaTaunt:StartCooldownFor(playerName, spellID, true)
            print("IchaTaunt: Testing RESIST for " .. playerName)
            break -- Just test first spell
        end
    elseif msg == "testroar" then
        -- Test Challenging Roar (Druid) - 10 minute cooldown
        IchaTaunt_Print("/it testroar - running")
        local playerName = UnitName("player")
        local spellID = 5209 -- Challenging Roar
        local spellData = IchaTaunt_GetSpellData(spellID)
        if spellData then
            IchaTaunt:StartCooldownFor(playerName, spellID, false)
            print("IchaTaunt: Testing Challenging Roar (" .. spellData.cooldown .. "s) for " .. playerName)
        else
            print("IchaTaunt: Challenging Roar spell data not found")
        end
    elseif msg == "testshout" then
        -- Test Challenging Shout (Warrior) - 10 minute cooldown
        local playerName = UnitName("player")
        local spellID = 1161 -- Challenging Shout
        local spellData = IchaTaunt_GetSpellData(spellID)
        if spellData then
            IchaTaunt:StartCooldownFor(playerName, spellID, false)
            print("IchaTaunt: Testing Challenging Shout (" .. spellData.cooldown .. "s) for " .. playerName)
        else
            print("IchaTaunt: Challenging Shout spell data not found")
        end
    elseif msg == "testmocking" then
        -- Test Mocking Blow (Warrior) - 2 minute cooldown
        local playerName = UnitName("player")
        local spellID = 694 -- Mocking Blow
        local spellData = IchaTaunt_GetSpellData(spellID)
        if spellData then
            IchaTaunt:StartCooldownFor(playerName, spellID, false)
            print("IchaTaunt: Testing Mocking Blow (" .. spellData.cooldown .. "s) for " .. playerName)
        else
            print("IchaTaunt: Mocking Blow spell data not found")
        end
    elseif msg == "testtaunt" then
        -- Test Taunt (Warrior) - 10 second cooldown
        local playerName = UnitName("player")
        local spellID = 355 -- Taunt
        local spellData = IchaTaunt_GetSpellData(spellID)
        if spellData then
            IchaTaunt:StartCooldownFor(playerName, spellID, false)
            print("IchaTaunt: Testing Taunt (" .. spellData.cooldown .. "s) for " .. playerName)
        else
            print("IchaTaunt: Taunt spell data not found")
        end
    elseif msg == "testgrowl" then
        -- Test Growl (Druid) - 10 second cooldown
        local playerName = UnitName("player")
        local spellID = 6795 -- Growl
        local spellData = IchaTaunt_GetSpellData(spellID)
        if spellData then
            IchaTaunt:StartCooldownFor(playerName, spellID, false)
            print("IchaTaunt: Testing Growl (" .. spellData.cooldown .. "s) for " .. playerName)
        else
            print("IchaTaunt: Growl spell data not found")
        end
    elseif msg == "testearthshaker" or msg == "testslam" then
        -- Test Earthshaker Slam (Shaman, Turtle WoW) - 10 second cooldown
        local playerName = UnitName("player")
        local spellID = 51365 -- Earthshaker Slam
        local spellData = IchaTaunt_GetSpellData(spellID)
        if spellData then
            IchaTaunt:StartCooldownFor(playerName, spellID, false)
            print("IchaTaunt: Testing Earthshaker Slam (" .. spellData.cooldown .. "s) for " .. playerName)
        else
            print("IchaTaunt: Earthshaker Slam spell data not found")
        end
    elseif msg == "testhand" or msg == "testreckoning" then
        -- Test Hand of Reckoning (Paladin, Turtle WoW) - 10 second cooldown
        local playerName = UnitName("player")
        local spellID = 51302 -- Hand of Reckoning
        local spellData = IchaTaunt_GetSpellData(spellID)
        if spellData then
            IchaTaunt:StartCooldownFor(playerName, spellID, false)
            print("IchaTaunt: Testing Hand of Reckoning (" .. spellData.cooldown .. "s) for " .. playerName)
        else
            print("IchaTaunt: Hand of Reckoning spell data not found")
        end
    elseif msg == "testall" then
        -- Test ALL spells on yourself (useful for seeing full tracker)
        local playerName = UnitName("player")
        local count = 0
        for spellID, spellData in pairs(IchaTaunt_SpellData) do
            IchaTaunt:StartCooldownFor(playerName, spellID, false)
            count = count + 1
        end
        print("IchaTaunt: Testing ALL " .. count .. " spells for " .. playerName)
    elseif msg == "reset" or msg == "center" then
        -- Reset position to screen center
        IchaTauntDB.position.x = 0
        IchaTauntDB.position.y = 0
        if IchaTaunt.frame then
            IchaTaunt.frame:ClearAllPoints()
            IchaTaunt.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            print("IchaTaunt: Position reset to screen center")
        else
            print("IchaTaunt: Position will be reset when tracker is next shown")
        end
    elseif strfind(msg, "^theme") then
        -- Theme command
        local _, _, themeName = strfind(msg, "^theme (.+)")
        if themeName then
            IchaTaunt:SetTheme(themeName)
        else
            -- List available themes
            print("IchaTaunt Themes:")
            print("  Current: " .. (IchaTauntDB.theme or "default"))
            print("  Available:")
            for key, data in pairs(IchaTaunt_Themes) do
                print("    - " .. key .. " (" .. data.name .. ")")
            end
            print("  Usage: /it theme <name>")
        end
    elseif strfind(msg, "^scale") then
        -- Scale command
        local _, _, scaleVal = strfind(msg, "^scale ([%d%.]+)")
        if scaleVal then
            local scale = tonumber(scaleVal)
            if scale then
                -- If user entered a percentage (like 80 or 120), convert to decimal
                if scale > 2 then
                    scale = scale / 100
                end
                IchaTaunt:SetScale(scale)
            else
                print("IchaTaunt: Invalid scale value")
            end
        else
            print("IchaTaunt Scale:")
            print("  Current: " .. format("%.0f%%", (IchaTauntDB.scale or 1.0) * 100))
            print("  Usage: /it scale <value>")
            print("  Example: /it scale 0.8 or /it scale 80")
            print("  Range: 50% - 200%")
        end
    elseif msg == "options" or msg == "settings" then
        -- Open options menu
        IchaTaunt:ShowOptionsMenu()
    elseif msg == "lock" then
        -- Lock tracker position (hide background)
        IchaTaunt:SetLocked(true)
    elseif msg == "unlock" then
        -- Unlock tracker position (show background)
        IchaTaunt:SetLocked(false)
    elseif msg == "togglelock" then
        -- Toggle lock state
        IchaTaunt:ToggleLock()
    elseif msg == "help" then
        print("IchaTaunt Commands:")
        print("/it - Open config window")
        print("/it show - Show tracker bar")
        print("/it hide - Hide tracker bar")
        print("/it config - Open taunter selection")
        print("/it options - Open theme & scale options")
        print("/it theme - List themes")
        print("/it theme <name> - Set theme (default, dark, elvui)")
        print("/it scale - Show current scale")
        print("/it scale <value> - Set scale (0.5-2.0 or 50-200)")
        print("/it reset - Reset tracker position")
        print("/it lock - Lock tracker (click-through)")
        print("/it unlock - Unlock tracker")
        print("/it togglelock - Toggle lock state")
        print("/it test - Test cooldown on first spell for your class")
        print("/it testresist - Test resist indicator")
        print("/it testtaunt - Test Taunt (Warrior, 10s)")
        print("/it testgrowl - Test Growl (Druid, 10s)")
        print("/it testroar - Test Challenging Roar (Druid, 10 min)")
        print("/it testshout - Test Challenging Shout (Warrior, 10 min)")
        print("/it testmocking - Test Mocking Blow (Warrior, 2 min)")
        print("/it testearthshaker - Test Earthshaker Slam (Shaman, 10s)")
        print("/it testhand - Test Hand of Reckoning (Paladin, 10s)")
        print("/it testall - Test ALL spell cooldowns (broadcasts each)")
        print("  (All /it test* commands broadcast to party/raid when in group)")
        print("/it help - Show this help")
    else
        print("IchaTaunt: Unknown command. Use '/it help' for help.")
    end
end