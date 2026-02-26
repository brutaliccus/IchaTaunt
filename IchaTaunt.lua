-- IchaTaunt AddOn (Turtle WoW)
-- Target: Lua 5.0 / Vanilla 1.12 (table.getn, unpack, strfind/strsub/strlen; no # for tables)
-- Drag-sort list, per-caster cooldowns, manual taunter assignment, PallyPower-style sync

-- DEFAULT_CHAT_FRAME:AddMessage("IchaTaunt.lua FILE IS LOADING...")

local ADDON_NAME = "IchaTaunt"
local IchaTaunt = CreateFrame("Frame", ADDON_NAME)

-- DEFAULT_CHAT_FRAME:AddMessage("IchaTaunt frame created: " .. tostring(IchaTaunt))

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
IchaTaunt.lastSyncReceived = {}  -- [playerName][spellID] = GetTime() of last broadcast sync

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
    cooldownOnlyMode = false, -- hide icons until they're on cooldown
    customSpells = {}, -- user-defined custom spells to track
    growUpward = false, -- false = list grows downward (default), true = list grows upward
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
    if not self.categoryFrames and not self.frame then return end

    local theme = self:GetTheme()
    local t = theme.tracker

    -- Apply backdrop to all category frames
    if self.categoryFrames then
        for _, frame in pairs(self.categoryFrames) do
            if frame then
                if not self.locked then
                    frame:SetBackdrop(t.backdrop)
                    frame:SetBackdropColor(unpack(t.bgColor))
                    frame:SetBackdropBorderColor(unpack(t.borderColor))
                else
                    frame:SetBackdrop(nil)
                end
            end
        end
    elseif self.frame then
        -- Backward compatibility
        if not self.locked then
            self.frame:SetBackdrop(t.backdrop)
            self.frame:SetBackdropColor(unpack(t.bgColor))
            self.frame:SetBackdropBorderColor(unpack(t.borderColor))
        else
            self.frame:SetBackdrop(nil)
        end
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

    if self.categoryFrames then
        -- Scale all category frames and maintain their positions
        for category, frame in pairs(self.categoryFrames) do
            if frame then
                local catData = IchaTauntDB.categories[category]
                local savedX = catData.position.x or 0
                local savedY = catData.position.y or 0

                frame:SetScale(scale)
                frame:ClearAllPoints()
                frame:SetPoint("TOP", UIParent, "TOP", savedX, savedY)
            end
        end
    elseif self.frame then
        -- Backward compatibility: single frame
        local savedX = IchaTauntDB.position.x or 0
        local savedY = IchaTauntDB.position.y or 0

        self.frame:SetScale(scale)
        self.frame:ClearAllPoints()
        self.frame:SetPoint("CENTER", UIParent, "CENTER", savedX, savedY)
    end

    IchaTauntDB.scale = scale

    print("IchaTaunt: Scale set to " .. format("%.0f%%", scale * 100))
end

-- Apply saved scale to tracker
function IchaTaunt:ApplyScale()
    if IchaTauntDB.scale then
        if self.categoryFrames then
            for _, frame in pairs(self.categoryFrames) do
                if frame then
                    frame:SetScale(IchaTauntDB.scale)
                end
            end
        elseif self.frame then
            self.frame:SetScale(IchaTauntDB.scale)
        end
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

-- DEFAULT_CHAT_FRAME:AddMessage("IchaTaunt: Registering events...")

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
    -- Debug: Show ALL events when debugMode is enabled (except spam combat log events)
    -- Combat log events are logged in HandleCombatMessage with more detail
    local spamEvents = {
        ["RAID_ROSTER_UPDATE"] = true,
        ["PARTY_MEMBERS_CHANGED"] = true,
        ["CHAT_MSG_ADDON"] = true,
        ["CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF"] = true,
        ["CHAT_MSG_SPELL_PARTY_BUFF"] = true,
        ["CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS"] = true,
        ["CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE"] = true,
        ["CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF"] = true,
        ["CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE"] = true,
        ["CHAT_MSG_SPELL_PARTY_DAMAGE"] = true,
        ["CHAT_MSG_SPELL_SELF_DAMAGE"] = true,
        ["CHAT_MSG_SPELL_SELF_BUFF"] = true,
        ["CHAT_MSG_COMBAT_SELF_HITS"] = true,
        ["CHAT_MSG_COMBAT_SELF_MISSES"] = true,
        ["CHAT_MSG_COMBAT_CREATURE_VS_SELF"] = true,
        ["CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE"] = true,
        ["CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF"] = true,
        ["CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE"] = true,
        ["CHAT_MSG_SPELL_AURA_GONE_SELF"] = true,
        ["CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE"] = true,
    }
    if IchaTauntDB and IchaTauntDB.debugMode and not spamEvents[event] then
        DEFAULT_CHAT_FRAME:AddMessage("[IchaTaunt Event] " .. tostring(event))
    end

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
        -- Debug logging moved into HandleCombatMessage after filtering
        local success, err = pcall(function()
            IchaTaunt:HandleCombatMessage(event)
        end)
        if not success then
            DEFAULT_CHAT_FRAME:AddMessage("[IchaTaunt ERROR] HandleCombatMessage failed: " .. tostring(err))
        end
    -- REMOVED: This was spamming chat
    -- elseif IchaTauntDB and IchaTauntDB.debugMode and strfind(event, "CHAT_MSG") then
    --     -- Catch any CHAT_MSG events we're not handling
    --     DEFAULT_CHAT_FRAME:AddMessage("[IchaTaunt] Unhandled CHAT_MSG event: " .. tostring(event))
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
    DEFAULT_CHAT_FRAME:AddMessage("IchaTaunt v2.1 loaded. Type /it for options.")
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
    IchaTauntDB.debugMode = false
    IchaTauntDB.debugAllEvents = false
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
    if IchaTauntDB.growUpward == nil then
        IchaTauntDB.growUpward = false -- Default grow downward
    end
    if not IchaTauntDB.stackPosition then
        -- Migrate from old per-category positions if available
        local migrated = false
        if IchaTauntDB.categories and IchaTauntDB.categories.tanks and IchaTauntDB.categories.tanks.position then
            local p = IchaTauntDB.categories.tanks.position
            if p.x ~= 0 or p.y ~= 0 then
                IchaTauntDB.stackPosition = {x = p.x, y = p.y}
                migrated = true
            end
        end
        if not migrated then
            IchaTauntDB.stackPosition = {x = 0, y = 0}
        end
    end

    self.taunters = IchaTauntDB.taunters or {}
    self.order = IchaTauntDB.taunterOrder or {}
    self.taunterBars = {}
    self.locked = IchaTauntDB.locked or false

    -- Initialize Categories first so IchaTauntDB.categories and category members exist before we build the tracker
    if IchaTaunt_Categories and IchaTaunt_Categories.InitializeDB then
        local success, err = pcall(function()
            IchaTaunt_Categories:InitializeDB()
        end)
        if not success then
            DEFAULT_CHAT_FRAME:AddMessage("[IchaTaunt ERROR] Categories init failed: " .. tostring(err))
        end
        -- Migrate any players in taunters list that aren't in any category (fixes ghost entries)
        if IchaTauntDB.taunters then
            local migratedCount = 0
            for name, _ in pairs(IchaTauntDB.taunters) do
                local existingCategory = IchaTaunt_Categories:GetPlayerCategory(name)
                if not existingCategory then
                    IchaTaunt_Categories:AddToCategory(name, "tanks")
                    migratedCount = migratedCount + 1
                end
            end
            if migratedCount > 0 and IchaTauntDB.debugMode then
                DEFAULT_CHAT_FRAME:AddMessage("[IchaTaunt] Migrated " .. migratedCount .. " ghost entries to tanks category")
            end
        end
    end

    -- Also populate self.taunters from all category members for combat log detection
    if IchaTaunt_Categories and IchaTauntDB.categories then
        for _, cat in ipairs(IchaTaunt_Categories.CATEGORY_ORDER) do
            if IchaTauntDB.categories[cat] and IchaTauntDB.categories[cat].members then
                for memberName, _ in pairs(IchaTauntDB.categories[cat].members) do
                    self.taunters[memberName] = true
                end
            end
        end
    end

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

    -- DEFAULT_CHAT_FRAME:AddMessage("[IchaTaunt] Initialization complete!")

    -- Helper: schedule broadcast for a taunt spell (same path as Roar/Shout/Mocking Blow)
    local function scheduleTauntBroadcast(spellID)
        -- Skip if broadcasts are disabled (testmode)
        if IchaTauntDB.disableBroadcast then
            return
        end

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
            -- Skip cooldown polling if in testmode (only use combat log)
            if IchaTauntDB and IchaTauntDB.disableBroadcast then return end

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
                -- Filter out GCD (typically 1.5s) - only track cooldowns > 2 seconds
                if duration and duration > 2 and last == 0 then
                    -- Use actual remaining from API so bar shows correct time (e.g. after reload)
                    local remaining = (start and duration) and math.max(0, (start + duration) - GetTime()) or nil
                    IchaTaunt:StartCooldownFor(UnitName("player"), spellID, false, false, remaining)
                end
                -- Only store duration if it's a real cooldown (> 2s), otherwise treat as 0
                IchaTaunt._lastCooldownDuration[spellID] = (duration and duration > 2) and duration or 0
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
    -- Ensure tracker UI exists before we try to show or rebuild (e.g. when adding first player before tracker was ever shown)
    if not self.categoryFrames and not self.frame then
        self:CreateUI()
    end

    -- Helper function to hide/show all category frames
    local function HideAllFrames()
        if self.categoryFrames then
            for _, frame in pairs(self.categoryFrames) do
                if frame then frame:Hide() end
            end
        elseif self.frame then
            self.frame:Hide()
        end
    end

    local function ShowAllFrames()
        if self.categoryFrames then
            for _, frame in pairs(self.categoryFrames) do
                if frame then frame:Show() end
            end
        elseif self.frame then
            self.frame:Show()
        end
    end

    -- If "only show in raid" is on and we're not in a raid, hide tracker
    if IchaTauntDB.showInRaidOnly and (not GetNumRaidMembers or GetNumRaidMembers() == 0) then
        HideAllFrames()
        return
    end

    -- Check if we're in any group (raid or party)
    local inRaid = GetNumRaidMembers and GetNumRaidMembers() > 0
    local inParty = GetNumPartyMembers and GetNumPartyMembers() > 0
    local inGroup = inRaid or inParty

    -- Check if we need to rebuild (only if taunter list actually changed)
    local currentTaunters = {}
    local hasTaunters = false
    for name, _ in pairs(self.taunters) do
        -- Show taunter if they're in group, OR if we're solo (show all configured)
        if self:IsPlayerInGroup(name) or not inGroup then
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

    -- When unlocked, always show all frames (including empties) for positioning
    if not self.locked then
        ShowAllFrames()
        if needsRebuild then
            self:RebuildList()
        end
        return
    end

    if hasTaunters then
        ShowAllFrames()
        if needsRebuild then
            self:RebuildList()
        end
    else
        local hasConfiguredTaunters = false
        if IchaTauntDB.taunterOrder then
            for _ in pairs(IchaTauntDB.taunterOrder) do
                hasConfiguredTaunters = true
                break
            end
        end

        if hasConfiguredTaunters or self.forceVisible then
            ShowAllFrames()
            if needsRebuild then
                self:RebuildList()
            end
        else
            HideAllFrames()
            return
        end
    end
end

-- Debug logging function
function IchaTaunt:DebugLog(msg)
    if not IchaTauntDB then return end
    if not IchaTauntDB.debugLog then
        IchaTauntDB.debugLog = {}
    end
    -- Keep last 500 messages
    if table.getn(IchaTauntDB.debugLog) > 500 then
        table.remove(IchaTauntDB.debugLog, 1)
    end
    table.insert(IchaTauntDB.debugLog, date("%H:%M:%S") .. " " .. msg)
end

-- Clear all tracked members (called by /clearall and CLEARALL broadcast)
function IchaTaunt:ClearAllTrackedMembers()
    local taunterCount = 0
    local categoryCount = 0

    -- Clear taunters list
    if IchaTauntDB.taunters then
        for name, _ in pairs(IchaTauntDB.taunters) do
            taunterCount = taunterCount + 1
        end
        IchaTauntDB.taunters = {}
    end

    -- Clear all category members
    if IchaTaunt_Categories and IchaTauntDB.categories then
        for _, cat in ipairs(IchaTaunt_Categories.CATEGORY_ORDER) do
            if IchaTauntDB.categories[cat] and IchaTauntDB.categories[cat].members then
                for name, _ in pairs(IchaTauntDB.categories[cat].members) do
                    categoryCount = categoryCount + 1
                end
                IchaTauntDB.categories[cat].members = {}
            end
        end
    end

    -- Clear self.taunters runtime table
    if self.taunters then
        self.taunters = {}
    end

    return taunterCount, categoryCount
end

function IchaTaunt:HandleCombatMessage(eventType)
    -- Parse 1.12 combat log messages for taunt spells
    if arg1 then
        local caster = nil
        local spell = nil

        -- Debug log the raw message
        if IchaTauntDB and IchaTauntDB.debugMode then
            self:DebugLog("=== EVENT: " .. tostring(eventType) .. " ===")
            self:DebugLog("RAW: " .. tostring(arg1))
        end

        -- Look for various taunt spell cast patterns
        if strfind(arg1, "(.+) casts (.+)%.") then
            _, _, caster, spell = strfind(arg1, "(.-) casts (.+)%.")
            if IchaTauntDB and IchaTauntDB.debugMode then
                self:DebugLog("MATCHED: '(.+) casts (.+)%.' -> caster=" .. tostring(caster) .. ", spell=" .. tostring(spell))
            end
        elseif strfind(arg1, "(.+) begins to cast (.+)%.") then
            _, _, caster, spell = strfind(arg1, "(.+) begins to cast (.+)%.")
        elseif strfind(arg1, "(.+) begins to perform (.+)%.") then
            -- "Playername begins to perform Spell."
            _, _, caster, spell = strfind(arg1, "(.+) begins to perform (.+)%.")
            if IchaTauntDB and IchaTauntDB.debugMode then
                self:DebugLog("MATCHED: \"(.+) begins to perform (.+)%.\" -> caster=" .. tostring(caster) .. ", spell=" .. tostring(spell))
            end
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
        elseif strfind(arg1, "You begin to perform (.+)%.") then
            -- "You begin to perform Spell."
            caster = UnitName("player")
            _, _, spell = strfind(arg1, "You begin to perform (.+)%.")
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
        elseif strfind(arg1, "Your (.+) was dodged") then
            -- "Your Spell was dodged."
            caster = UnitName("player")
            _, _, spell = strfind(arg1, "Your (.-) was dodged")
        elseif strfind(arg1, "Your (.+) was parried") then
            -- "Your Spell was parried."
            caster = UnitName("player")
            _, _, spell = strfind(arg1, "Your (.-) was parried")
        elseif strfind(arg1, "Your (.+) was blocked") then
            -- "Your Spell was blocked."
            caster = UnitName("player")
            _, _, spell = strfind(arg1, "Your (.-) was blocked")
        elseif strfind(arg1, "Your (.+) crits") then
            -- "Your Earthshaker Slam crits Mob for 456."
            caster = UnitName("player")
            _, _, spell = strfind(arg1, "Your (.+) crits")
        elseif strfind(arg1, "Your (.+) misses") then
            -- "Your Earthshaker Slam misses Mob."
            caster = UnitName("player")
            _, _, spell = strfind(arg1, "Your (.+) misses")
        elseif strfind(arg1, "(.+) 's (.-) was resisted") then
            -- "Playername 's Earthshaker Slam was resisted by Mob." (note space before 's)
            _, _, caster, spell = strfind(arg1, "(.+) 's (.-) was resisted")
            if IchaTauntDB and IchaTauntDB.debugMode then
                self:DebugLog("MATCHED: \"(.+) 's (.-) was resisted\" -> caster=" .. tostring(caster) .. ", spell=" .. tostring(spell))
            end
        elseif strfind(arg1, "(.+) 's (.-) was dodged") then
            -- "Playername 's Execute was dodged by Target."
            _, _, caster, spell = strfind(arg1, "(.+) 's (.-) was dodged")
            if IchaTauntDB and IchaTauntDB.debugMode then
                self:DebugLog("MATCHED: \"(.+) 's (.-) was dodged\" -> caster=" .. tostring(caster) .. ", spell=" .. tostring(spell))
            end
        elseif strfind(arg1, "(.+) 's (.-) was parried") then
            -- "Playername 's Spell was parried."
            _, _, caster, spell = strfind(arg1, "(.+) 's (.-) was parried")
            if IchaTauntDB and IchaTauntDB.debugMode then
                self:DebugLog("MATCHED: \"(.+) 's (.-) was parried\" -> caster=" .. tostring(caster) .. ", spell=" .. tostring(spell))
            end
        elseif strfind(arg1, "(.+) 's (.-) was blocked") then
            -- "Playername 's Spell was blocked."
            _, _, caster, spell = strfind(arg1, "(.+) 's (.-) was blocked")
            if IchaTauntDB and IchaTauntDB.debugMode then
                self:DebugLog("MATCHED: \"(.+) 's (.-) was blocked\" -> caster=" .. tostring(caster) .. ", spell=" .. tostring(spell))
            end
        elseif strfind(arg1, "(.+) 's (.-) hits") then
            -- "Playername 's Spellname hits Target" (note space before 's)
            _, _, caster, spell = strfind(arg1, "(.+) 's (.-) hits")
            if IchaTauntDB and IchaTauntDB.debugMode then
                self:DebugLog("MATCHED: \"(.+) 's (.-) hits\" -> caster=" .. tostring(caster) .. ", spell=" .. tostring(spell))
            end
        elseif strfind(arg1, "(.+) 's (.-) crits") then
            -- "Playername 's Shadowburn crits Target for X damage." (note space before 's)
            _, _, caster, spell = strfind(arg1, "(.+) 's (.-) crits")
            if IchaTauntDB and IchaTauntDB.debugMode then
                self:DebugLog("MATCHED: \"(.+) 's (.-) crits\" -> caster=" .. tostring(caster) .. ", spell=" .. tostring(spell))
            end
        elseif strfind(arg1, "(.+) 's (.-) misses") then
            -- "Playername 's Taunt misses Target." (note space before 's)
            _, _, caster, spell = strfind(arg1, "(.+) 's (.-) misses")
            if IchaTauntDB and IchaTauntDB.debugMode then
                self:DebugLog("MATCHED: \"(.+) 's (.-) misses\" -> caster=" .. tostring(caster) .. ", spell=" .. tostring(spell))
            end
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
        elseif strfind(arg1, "(.+) 's (.+) fails%.") then
            -- "Playername 's Spell fails." (spell failed due to conditions)
            _, _, caster, spell = strfind(arg1, "(.+) 's (.-) fails")
            if IchaTauntDB and IchaTauntDB.debugMode then
                self:DebugLog("MATCHED: \"(.+) 's (.-) fails\" -> caster=" .. tostring(caster) .. ", spell=" .. tostring(spell))
            end
        elseif strfind(arg1, "(.+) 's (.-) is interrupted") then
            -- "Playername 's Spell is interrupted."
            _, _, caster, spell = strfind(arg1, "(.+) 's (.-) is interrupted")
            if IchaTauntDB and IchaTauntDB.debugMode then
                self:DebugLog("MATCHED: \"(.+) 's (.-) is interrupted\" -> caster=" .. tostring(caster) .. ", spell=" .. tostring(spell))
            end
        elseif strfind(arg1, "(.+) interrupts (.+)'s .+ with (.+)%.") then
            -- "Rogue interrupts Caster's Spell with Kick."
            _, _, caster, spell = strfind(arg1, "(.+) interrupts .+ with (.+)%.")
            if IchaTauntDB and IchaTauntDB.debugMode then
                self:DebugLog("MATCHED: \"(.+) interrupts .+ with (.+)%.\" -> caster=" .. tostring(caster) .. ", spell=" .. tostring(spell))
            end
        elseif strfind(arg1, "You interrupt .+ with (.+)%.") then
            -- "You interrupt Caster's Spell with Kick."
            caster = UnitName("player")
            _, _, spell = strfind(arg1, "You interrupt .+ with (.+)%.")
        elseif strfind(arg1, "Your (.+) fails%.") then
            -- "Your Spell fails."
            caster = UnitName("player")
            _, _, spell = strfind(arg1, "Your (.-) fails")
        elseif strfind(arg1, "(.+) casts (.+) on (.+)%.") then
            -- "Playername casts Spell on Target." (targeted spell cast)
            _, _, caster, spell = strfind(arg1, "(.+) casts (.-) on")
            if IchaTauntDB and IchaTauntDB.debugMode then
                self:DebugLog("MATCHED: \"(.+) casts (.-) on\" -> caster=" .. tostring(caster) .. ", spell=" .. tostring(spell))
            end
        elseif strfind(arg1, "You cast (.+) on (.+)%.") then
            -- "You cast Spell on Target."
            caster = UnitName("player")
            _, _, spell = strfind(arg1, "You cast (.-) on")
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
        elseif strfind(arg1, "(.+) gains (.+)%.") and not strfind(arg1, " from ") then
            -- "PlayerName gains SpellName." (without "from" clause - direct buff gain)
            -- This catches defensive cooldowns and self-buffs for OTHER players
            -- Let the database check below filter to only tracked spells
            _, _, caster, spell = strfind(arg1, "(.-) gains (.+)%.")
            if IchaTauntDB and IchaTauntDB.debugMode then
                self:DebugLog("MATCHED: \"(.-) gains (.+)%.\" -> caster=" .. tostring(caster) .. ", spell=" .. tostring(spell))
            end
        elseif strfind(arg1, "You gain (.+)%.") then
            -- "You gain SpellName." - self buff gain
            -- Let the database check below filter to only tracked spells
            caster = UnitName("player")
            _, _, spell = strfind(arg1, "You gain (.+)%.")
        elseif strfind(arg1, "(.+) fades from you%.") then
            -- "SpellName fades from you." - for instant-cast buffs like Blink that don't show "You gain" messages
            -- Detect the fade and backdate the cooldown start
            caster = UnitName("player")
            _, _, spell = strfind(arg1, "(.+) fades from you%.")
            if IchaTauntDB and IchaTauntDB.debugMode then
                self:DebugLog("MATCHED: \"(.+) fades from you%.\" -> spell=" .. tostring(spell))
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

            -- Check if caster is in raid/party (filter out random people nearby)
            local isInGroup = self:IsPlayerInGroup(caster)

            -- Only show debug/logs for players in your group
            if not isInGroup then
                if IchaTauntDB and IchaTauntDB.debugMode then
                    self:DebugLog("Skipped - not in group")
                end
                return
            end

            -- Debug log: Group member detection
            if IchaTauntDB and IchaTauntDB.debugMode then
                self:DebugLog("In group: YES")
                self:DebugLog("After cleanup - caster: " .. tostring(caster) .. ", spell: " .. tostring(spell))
            end

            -- Check if it's a tracked spell by name
            local spellID, spellData = IchaTaunt_GetSpellByName(spell)

            if IchaTauntDB and IchaTauntDB.debugMode then
                if spellID and spellData then
                    self:DebugLog("Spell FOUND in DB: ID=" .. spellID .. ", Name=" .. spellData.name)
                else
                    self:DebugLog("Spell NOT in database: " .. tostring(spell))
                end
            end

            if spellID and spellData then
                -- Check if this was a resist
                local wasResisted = strfind(arg1, "was resisted") or strfind(arg1, "resists")

                -- Always process if caster is tracked OR if caster is the local player
                local isLocalPlayer = (caster == UnitName("player"))
                local isTracked = IchaTauntDB.taunters[caster] or self.taunters[caster]

                -- Also check if player is in any category
                local inAnyCategory = false
                if IchaTaunt_Categories and IchaTauntDB.categories then
                    for _, cat in ipairs(IchaTaunt_Categories.CATEGORY_ORDER) do
                        if IchaTauntDB.categories[cat] and IchaTauntDB.categories[cat].members and IchaTauntDB.categories[cat].members[caster] then
                            inAnyCategory = true
                            if IchaTauntDB and IchaTauntDB.debugMode then
                                self:DebugLog("Caster found in category: " .. cat)
                            end
                            break
                        end
                    end
                end

                if IchaTauntDB and IchaTauntDB.debugMode then
                    self:DebugLog("isLocalPlayer: " .. tostring(isLocalPlayer))
                    self:DebugLog("isTracked: " .. tostring(isTracked))
                    self:DebugLog("inAnyCategory: " .. tostring(inAnyCategory))
                end

                if isTracked or isLocalPlayer or inAnyCategory then
                    -- Check if we have a recent broadcast sync for this player/spell (priority: broadcast > combat log)
                    local casterNormalized = self:NormalizePlayerName(caster)
                    local hasBroadcast = false
                    if not isLocalPlayer and self.lastSyncReceived and self.lastSyncReceived[casterNormalized] then
                        local lastSync = self.lastSyncReceived[casterNormalized][spellID]
                        if lastSync and (GetTime() - lastSync) < 5 then
                            hasBroadcast = true
                        end
                    end

                    if IchaTauntDB and IchaTauntDB.debugMode then
                        self:DebugLog("hasBroadcast: " .. tostring(hasBroadcast))
                    end

                    -- Only process combat log if this is the local player (always) OR no recent broadcast (fallback for non-addon users)
                    if isLocalPlayer or not hasBroadcast then
                        if IchaTauntDB and IchaTauntDB.debugMode then
                            self:DebugLog("TRIGGERING COOLDOWN: " .. caster .. " - " .. spellData.name)
                        end
                        self:StartCooldownFor(caster, spellID, wasResisted, nil) -- nil = from combat log
                        -- Clear any existing resist status for successful spell
                        if not wasResisted then
                            self:ClearResistFor(caster)
                        end
                    else
                        if IchaTauntDB and IchaTauntDB.debugMode then
                            self:DebugLog("Skipped - broadcast already handled it")
                        end
                    end
                else
                    if IchaTauntDB and IchaTauntDB.debugMode then
                        self:DebugLog("Skipped - player not tracked")
                    end
                end
            else
                if IchaTauntDB and IchaTauntDB.debugMode then
                    self:DebugLog("Skipped - spell not in database")
                end
            end
        else
            -- Debug: Show parsing failure
            if IchaTauntDB and IchaTauntDB.debugMode then
                if not caster and not spell then
                    self:DebugLog("PARSE FAILED - no caster/spell")
                elseif not spell then
                    self:DebugLog("PARSE FAILED - no spell (caster: " .. tostring(caster) .. ")")
                elseif not caster then
                    self:DebugLog("PARSE FAILED - no caster (spell: " .. tostring(spell) .. ")")
                end
            end
        end
    end
end

function IchaTaunt:GetSpellIDByName(spellName)
    return IchaTaunt_GetSpellByName(spellName)
end

function IchaTaunt:StartCooldownFor(name, spellID, wasResisted, fromSync, remainingSec)
    local spellData = IchaTaunt_GetSpellData(spellID)
    if not spellData then
        return
    end

    -- Use remaining duration when provided (e.g. from cooldown poller after reload), else full cooldown
    local duration = (remainingSec and remainingSec > 0) and remainingSec or spellData.cooldown

    -- Determine the source of this cooldown
    local source = "UNKNOWN"
    if fromSync == true then
        source = "BROADCAST SYNC"
    elseif remainingSec and remainingSec > 0 then
        source = "RELOAD RESTORE"
    elseif fromSync == false then
        source = "SPELL HOOK"
    elseif fromSync == nil then
        source = "COMBAT LOG"
    end

    if IchaTauntDB.debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("========================================")
        DEFAULT_CHAT_FRAME:AddMessage("COOLDOWN DETECTED:")
        DEFAULT_CHAT_FRAME:AddMessage("  Method: [" .. source .. "]")
        DEFAULT_CHAT_FRAME:AddMessage("  Player: " .. name)
        DEFAULT_CHAT_FRAME:AddMessage("  Spell: " .. spellData.name)
        DEFAULT_CHAT_FRAME:AddMessage("  Duration: " .. duration .. "s")
        if wasResisted then
            DEFAULT_CHAT_FRAME:AddMessage("  Status: RESISTED")
        end
        DEFAULT_CHAT_FRAME:AddMessage("========================================")
    end

    -- Broadcast cooldown to raid FIRST if this is the local player and not from sync
    -- Broadcast remaining seconds so others show correct time (important for long CDs after reload)
    if not fromSync and name == UnitName("player") then
        if IchaTauntDB.debugMode then
            print("[IchaTaunt Debug] This is local player - attempting broadcast...")
        end
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

    -- Force UI refresh so the cooldown shows immediately
    self:UpdateCooldownBars()
end

-- Broadcast cooldown usage to raid members
function IchaTaunt:BroadcastCooldown(playerName, spellID, cooldown, wasResisted)
    -- Check if broadcasts are disabled for testing
    if IchaTauntDB.disableBroadcast then
        if IchaTauntDB.debugMode then
            print("[IchaTaunt Debug] Broadcast DISABLED - combat log will handle this spell")
        end
        return
    end

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

    -- Record that we received a broadcast sync for this player/spell (for combat log fallback priority)
    self.lastSyncReceived[playerNameBase] = self.lastSyncReceived[playerNameBase] or {}
    self.lastSyncReceived[playerNameBase][spellID] = GetTime()

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
    -- Only apply cooldown if this player already has an icon for this spell
    -- (the icon is created based on the player's class in CreateTaunterBar)
    -- Do NOT create icons dynamically here - that would add wrong spell icons to other classes
    if not cdBar then
        IchaTaunt_Print("Ignored CD from " .. playerName .. " spell " .. spellID .. " - no icon for that spell on their bar")
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
    -- Only apply cooldown if this player already has an icon for this spell
    -- (the icon is created based on the player's class in CreateTaunterBar)
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
    local cooldownOnlyMode = IchaTauntDB.cooldownOnlyMode

    -- Update resist status first
    self:UpdateResistStatus()

    for name, taunterBar in pairs(self.taunterBars) do
        -- First pass: update cooldown states
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
                -- On cooldown - show icon (always visible when on CD)
                iconFrame:Show()

                -- Show cooldown overlay and countdown
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

                -- In cooldown-only mode, hide the icon when ready
                if cooldownOnlyMode then
                    iconFrame:Hide()
                else
                    iconFrame:Show()
                end

                if IchaTauntDB.cooldownEndTimes then
                    local nameBase = IchaTaunt:NormalizePlayerName(name)
                    if IchaTauntDB.cooldownEndTimes[nameBase] then
                        IchaTauntDB.cooldownEndTimes[nameBase][spellID] = nil
                    end
                end
            end
        end

        -- Second pass: reposition icons in cooldown-only mode
        -- In cooldown-only mode, icons on cooldown should be left-aligned and grow right
        if cooldownOnlyMode then
            local visibleIcons = {}
            -- Collect all visible (on-cooldown) icons
            for spellID, iconFrame in pairs(taunterBar.cooldownBars) do
                if iconFrame:IsVisible() then
                    table.insert(visibleIcons, {spellID = spellID, frame = iconFrame})
                end
            end

            -- Sort by original position to maintain consistent order
            table.sort(visibleIcons, function(a, b)
                return a.frame.originalIndex < b.frame.originalIndex
            end)

            -- Reposition visible icons starting from position 0
            for i, icon in ipairs(visibleIcons) do
                local xOffset = 120 + ((i - 1) * 28)  -- Start from left, grow right
                icon.frame:ClearAllPoints()
                icon.frame:SetPoint("LEFT", taunterBar, "LEFT", xOffset, 0)
            end
        else
            -- Not in cooldown-only mode: restore original positions
            for spellID, iconFrame in pairs(taunterBar.cooldownBars) do
                local xOffset = 120 + (iconFrame.originalIndex * 28)
                iconFrame:ClearAllPoints()
                iconFrame:SetPoint("LEFT", taunterBar, "LEFT", xOffset, 0)
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

-- Deterministic stack positioning: places all visible category frames in a
-- vertical stack anchored at IchaTauntDB.stackPosition. Called after any
-- height change, drag, or visibility change.
function IchaTaunt:RepositionStack()
    if not self.categoryFrames then return end
    local pos = IchaTauntDB.stackPosition or {x = 0, y = 0}
    local currentY = pos.y
    for _, category in ipairs(IchaTaunt_Categories.CATEGORY_ORDER) do
        local frame = self.categoryFrames[category]
        if frame and frame:IsVisible() then
            frame:ClearAllPoints()
            frame:SetPoint("TOP", UIParent, "TOP", pos.x, currentY)
            currentY = currentY - frame:GetHeight()
        end
    end
end

-- UI Creation - Individual Category Frame
function IchaTaunt:CreateCategoryFrame(category)
    local theme = self:GetTheme()
    local t = theme.tracker

    local frameName = "IchaTauntFrame_" .. category
    local f = CreateFrame("Frame", frameName, UIParent)
    f:SetWidth(300)
    f:SetHeight(100)
    f:SetFrameStrata("MEDIUM")
    f.category = category

    -- Apply theme backdrop
    f:SetBackdrop(t.backdrop)
    f:SetBackdropColor(unpack(t.bgColor))
    f:SetBackdropBorderColor(unpack(t.borderColor))

    -- Initial position is temporary; RepositionStack() will place it correctly
    f:ClearAllPoints()
    f:SetPoint("TOP", UIParent, "TOP", 0, 0)

    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    f:SetScript("OnDragStart", function()
        if not IchaTaunt.locked then
            local sx, sy = this:GetCenter()
            this._dragStartX = sx
            this._dragStartY = sy
            this:StartMoving()
        end
    end)

    f:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local startX = this._dragStartX
        local startY = this._dragStartY
        this._dragStartX = nil
        this._dragStartY = nil
        local finalX, finalY = this:GetCenter()
        if finalX and finalY and startX and startY then
            local deltaX = finalX - startX
            local deltaY = finalY - startY
            local pos = IchaTauntDB.stackPosition or {x = 0, y = 0}
            pos.x = pos.x + deltaX
            pos.y = pos.y + deltaY
            IchaTauntDB.stackPosition = pos
        end
        IchaTaunt:RepositionStack()
    end)

    -- Right-click menu removed - use /ichataunt lock/unlock or options menu instead
    -- f:SetScript("OnMouseUp", function(button)
    --     if arg1 == "RightButton" then
    --         IchaTaunt:ToggleLock()
    --     end
    -- end)

    -- Apply scale
    local scale = IchaTauntDB.scale or 1.0
    f:SetScale(scale)

    return f
end

-- UI Creation - Create All Category Frames
function IchaTaunt:CreateUI()
    if self.categoryFrames then return end

    -- Create individual frames for each category
    self.categoryFrames = {}
    self.taunterBars = {}
    self.updateTimer = 0

    for _, category in ipairs(IchaTaunt_Categories.CATEGORY_ORDER) do
        local frame = self:CreateCategoryFrame(category)
        self.categoryFrames[category] = frame

        -- Add OnUpdate to each frame for cooldown updates
        frame:SetScript("OnUpdate", function()
            IchaTaunt:UpdateCooldownBars()
            -- Update DPS displays if module is available
            if IchaTaunt_DPS and IchaTaunt_DPS.UpdateDisplays then
                IchaTaunt_DPS:UpdateDisplays()
            end
        end)
    end

    -- Keep backward compatibility - self.frame points to tanks frame
    self.frame = self.categoryFrames.tanks

    -- Apply lock state to all frames
    self:UpdateLockState()

    -- Position all frames in the deterministic stack
    self:RepositionStack()
end

-- Creates countdown bars for active taunters
function IchaTaunt:RebuildList()
    local success, err = pcall(function()
        self:RebuildListInternal()
    end)
    if not success then
        DEFAULT_CHAT_FRAME:AddMessage("[IchaTaunt ERROR] RebuildList failed: " .. tostring(err))
    end
end

function IchaTaunt:RebuildListInternal()
    -- Declare variables at function scope so they're accessible throughout
    local categoryOrder = IchaTaunt_Categories and IchaTaunt_Categories.CATEGORY_ORDER or {"tanks"}
    local categorizedTaunters = {}

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

    -- Clear existing category headers
    if self.categoryHeaders then
        for _, header in ipairs(self.categoryHeaders) do
            if header and header.Hide then
                header:Hide()
            end
        end
    end
    self.categoryHeaders = {}

    local barIndex = 1

    -- Check if we're in any group
    local inRaid = GetNumRaidMembers and GetNumRaidMembers() > 0
    local inParty = GetNumPartyMembers and GetNumPartyMembers() > 0
    local inGroup = inRaid or inParty

    -- Group taunters by category
    if IchaTaunt_Categories and IchaTauntDB.categories then
        -- Build categorized lists
        for _, category in ipairs(IchaTaunt_Categories.CATEGORY_ORDER) do
            categorizedTaunters[category] = {}
            local members = IchaTaunt_Categories:GetCategoryMembers(category)

            -- Add members in the order they appear in taunterOrder
            for _, name in ipairs(IchaTauntDB.taunterOrder) do
                if members[name] and IchaTauntDB.taunters[name] and (self:IsPlayerInGroup(name) or not inGroup) then
                    table.insert(categorizedTaunters[category], name)
                end
            end
        end
    else
        -- Fallback: all taunters go into "tanks" category
        categorizedTaunters.tanks = {}
        for _, name in ipairs(IchaTauntDB.taunterOrder) do
            if IchaTauntDB.taunters[name] and (self:IsPlayerInGroup(name) or not inGroup) then
                table.insert(categorizedTaunters.tanks, name)
            end
        end
    end

    -- Determine growth direction
    local growUpward = IchaTauntDB.growUpward

    -- Set category order
    if IchaTaunt_Categories and IchaTaunt_Categories.CATEGORY_ORDER then
        categoryOrder = IchaTaunt_Categories.CATEGORY_ORDER
    end

    local globalIndex = 1  -- Global ordering number across all categories

    -- Populate each category frame separately
    for _, category in ipairs(categoryOrder) do
        local members = categorizedTaunters[category] or {}
        local categoryFrame = self.categoryFrames and self.categoryFrames[category]

        if categoryFrame then
            -- Reset yOffset for this category frame
            local yOffset
            if growUpward then
                yOffset = 5  -- Start from bottom, grow upward
            else
                yOffset = -5  -- Start from top, grow downward
            end

            if table.getn(members) > 0 then
                -- Show frame if it has members
                categoryFrame:Show()

                if growUpward then
                    -- When growing upward: create members first, then header (so header appears above)
                    for _, name in ipairs(members) do
                        self:CreateTaunterBar(name, yOffset, globalIndex, growUpward, categoryFrame)
                        yOffset = yOffset + 28  -- Move up for next bar
                        globalIndex = globalIndex + 1
                    end

                    -- Create category header AFTER members (appears above them visually)
                    yOffset = self:CreateCategoryHeader(category, yOffset, growUpward, categoryFrame)
                else
                    -- When growing downward: create header first, then members (normal order)
                    -- Create category header
                    yOffset = self:CreateCategoryHeader(category, yOffset, growUpward, categoryFrame)

                    -- Create bars for members in this category
                    for _, name in ipairs(members) do
                        self:CreateTaunterBar(name, yOffset, globalIndex, growUpward, categoryFrame)
                        yOffset = yOffset - 28  -- Move down for next bar
                        globalIndex = globalIndex + 1
                    end
                end

                -- Set frame height based on this category's content
                local categoryHeight = (table.getn(members) * 28) + 20 + 10
                categoryFrame:SetHeight(math.max(35, categoryHeight))
            else
                -- Hide frame if it has no members AND tracker is locked
                -- Keep visible when unlocked so user can position empty frames
                if self.locked then
                    categoryFrame:Hide()
                else
                    -- Show empty frame with category name when unlocked (for positioning)
                    categoryFrame:Show()
                    categoryFrame:SetHeight(35)

                    -- Add a header so user knows which category this is
                    local yOffset = growUpward and 5 or -5
                    self:CreateCategoryHeader(category, yOffset, growUpward, categoryFrame)
                end
            end
        end
    end

    -- Reposition the entire stack now that all frame heights are final
    self:RepositionStack()

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

    -- Also restore from syncedCooldowns (in-memory cache set by sync messages during session)
    if self.syncedCooldowns then
        for name, spellCooldowns in pairs(self.syncedCooldowns) do
            local nameBase = self:NormalizePlayerName(name)
            -- Find the bar by normalized name
            for barName, bar in pairs(self.taunterBars) do
                if self:NormalizePlayerName(barName) == nameBase and bar.cooldownBars then
                    for spellID, endTime in pairs(spellCooldowns) do
                        if bar.cooldownBars[spellID] and endTime > GetTime() then
                            bar.cooldownBars[spellID].endTime = endTime
                        end
                    end
                    break
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

    -- Store the current order hash for change detection
    local orderHash = ""
    local order = IchaTauntDB.taunterOrder or {}
    for i, name in ipairs(order) do
        orderHash = orderHash .. i .. ":" .. name .. ";"
    end
    self.lastOrderHash = orderHash

    -- Re-apply lock state so frames keep correct mouse/backdrop after rebuild
    self:UpdateLockState()
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
-- Create a category header
function IchaTaunt:CreateCategoryHeader(category, yOffset, growUpward, parentFrame)
    local theme = self:GetTheme()
    local t = theme.tracker

    local parent = parentFrame or self.frame
    local header = CreateFrame("Frame", nil, parent)
    header:SetWidth(280)
    header:SetHeight(18)

    -- Anchor differently based on growth direction
    if growUpward then
        header:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 5, yOffset)
    else
        header:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, yOffset)
    end

    -- Category name text
    local categoryName = IchaTaunt_Categories and IchaTaunt_Categories.CATEGORY_NAMES[category] or category
    header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.text:SetPoint("LEFT", header, "LEFT", 5, 0)
    header.text:SetText("-- " .. categoryName .. " --")

    -- Apply category color
    local categoryColor = IchaTaunt_Categories and IchaTaunt_Categories.CATEGORY_COLORS[category] or {1, 0.82, 0}
    header.text:SetTextColor(unpack(categoryColor))

    -- Store header so we can clean it up later
    if not self.categoryHeaders then
        self.categoryHeaders = {}
    end
    table.insert(self.categoryHeaders, header)

    -- Return next yOffset after header
    if growUpward then
        return yOffset + 20
    else
        return yOffset - 20
    end
end

function IchaTaunt:CreateTaunterBar(name, yOffset, orderNum, growUpward, parentFrame)
    local theme = self:GetTheme()
    local t = theme.tracker

    local parent = parentFrame or self.frame
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetWidth(280)
    bar:SetHeight(26)  -- Reduced from 32 to 26 for tighter spacing

    -- Anchor differently based on growth direction
    if growUpward then
        bar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 5, yOffset)
    else
        bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, yOffset)
    end

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
    -- ONLY show configured spells (from SpellData + customSpells), not all TrackableSpells
    local playerClass = self:GetPlayerClass(name)
    if playerClass then
        local spells = {}

        -- Add built-in taunt spells for this class
        for id, data in pairs(IchaTaunt_SpellData) do
            for _, spellClass in ipairs(data.classes) do
                if spellClass == playerClass then
                    spells[id] = data
                    break
                end
            end
        end

        -- Add custom spells for this class
        if IchaTauntDB and IchaTauntDB.customSpells then
            for id, data in pairs(IchaTauntDB.customSpells) do
                for _, spellClass in ipairs(data.classes) do
                    if spellClass == playerClass then
                        spells[id] = data
                        break
                    end
                end
            end
        end

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
    iconFrame.originalIndex = iconIndex  -- Save original position for cooldown-only mode

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
    local isVisible = false

    if self.categoryFrames then
        -- Check if any category frame is visible
        for _, frame in pairs(self.categoryFrames) do
            if frame and frame:IsVisible() then
                isVisible = true
                break
            end
        end
    elseif self.frame then
        isVisible = self.frame:IsVisible()
    end

    if isVisible then
        self:HideTracker()
    else
        self:ShowTracker()
    end
end

function IchaTaunt:ShowTracker()
    if not self.categoryFrames and not self.frame then
        self:CreateUI()
    end

    if self.categoryFrames then
        for _, frame in pairs(self.categoryFrames) do
            if frame then frame:Show() end
        end
    elseif self.frame then
        self.frame:Show()
    end

    self.forceVisible = true  -- Flag to keep tracker visible even without taunters
    self:RefreshRoster()
    if IchaTauntDB.debugMode then
        print("IchaTaunt: Tracker shown")
    end
end

function IchaTaunt:HideTracker()
    if self.categoryFrames then
        for _, frame in pairs(self.categoryFrames) do
            if frame then frame:Hide() end
        end
        self.forceVisible = false
        if IchaTauntDB.debugMode then
            print("IchaTaunt: Tracker hidden")
        end
    elseif self.frame then
        self.frame:Hide()
        self.forceVisible = false
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
    self:RebuildList()

    if locked then
        print("IchaTaunt: Tracker locked - background hidden, click-through enabled")
    else
        print("IchaTaunt: Tracker unlocked - background visible, draggable")
    end
end

function IchaTaunt:ToggleLock()
    self:SetLocked(not self.locked)
end

function IchaTaunt:UpdateLockState()
    if not self.categoryFrames and not self.frame then return end

    local theme = self:GetTheme()
    local t = theme.tracker

    -- Update all category frames
    if self.categoryFrames then
        for _, frame in pairs(self.categoryFrames) do
            if frame then
                -- Update mouse interaction based on lock state
                if self.locked then
                    -- Locked: disable mouse so frame is click-through
                    frame:EnableMouse(false)
                    -- Hide backdrop when locked
                    frame:SetBackdrop(nil)
                else
                    -- Unlocked: enable mouse for dragging and positioning
                    frame:EnableMouse(true)
                    -- Show backdrop when unlocked
                    frame:SetBackdrop(t.backdrop)
                    frame:SetBackdropColor(unpack(t.bgColor))
                    frame:SetBackdropBorderColor(unpack(t.borderColor))
                end
            end
        end
    elseif self.frame then
        -- Backward compatibility: update single frame
        if self.locked then
            self.frame:EnableMouse(false)  -- Click-through when locked
            self.frame:SetBackdrop(nil)
        else
            self.frame:EnableMouse(true)   -- Enable mouse when unlocked
            self.frame:SetBackdrop(t.backdrop)
            self.frame:SetBackdropColor(unpack(t.bgColor))
            self.frame:SetBackdropBorderColor(unpack(t.borderColor))
        end
    end

    -- Keep options menu lock/unlock button in sync
    self:RefreshLockUnlockButton()
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

-- Shared add-player logic used by all "+" buttons (raid, party, solo). Wrapped in pcall so errors
-- never silently swallow the click.
function IchaTaunt:AddPlayerToTracker(playerName, category, refreshCallback)
    local ok, err = pcall(function()
        if not self:CanControl() then
            DEFAULT_CHAT_FRAME:AddMessage("IchaTaunt: Only raid leader/officers can modify taunter list")
            return
        end

        if not IchaTauntDB then IchaTauntDB = {} end
        if not IchaTauntDB.taunterOrder then IchaTauntDB.taunterOrder = {} end
        if not IchaTauntDB.taunters then IchaTauntDB.taunters = {} end

        local selectedCat = category or "tanks"

        -- If player is already properly tracked in a category, force remove + re-add to fix ghost states
        local existingCat = nil
        if IchaTaunt_Categories and IchaTaunt_Categories.GetPlayerCategory then
            existingCat = IchaTaunt_Categories:GetPlayerCategory(playerName)
        end
        if existingCat then
            -- Clean removal first
            if IchaTaunt_Categories.RemoveFromCategory then
                IchaTaunt_Categories:RemoveFromCategory(playerName, existingCat)
            end
            IchaTauntDB.taunters[playerName] = nil
            self.taunters[playerName] = nil
        end

        -- Remove from order if present (clean up ghost/duplicate entries)
        for i, orderName in ipairs(IchaTauntDB.taunterOrder) do
            if orderName == playerName then
                table.remove(IchaTauntDB.taunterOrder, i)
                break
            end
        end

        -- Add fresh
        table.insert(IchaTauntDB.taunterOrder, playerName)
        IchaTauntDB.taunters[playerName] = true
        self.taunters[playerName] = true

        if IchaTaunt_Categories and IchaTaunt_Categories.AddToCategory then
            IchaTaunt_Categories:AddToCategory(playerName, selectedCat)
        end

        self.order = IchaTauntDB.taunterOrder
        self:AutoBroadcast()

        if refreshCallback then refreshCallback() end

        -- Force a full rebuild so category reassignments are reflected immediately
        -- (RefreshRoster's change detection only checks the player set and order,
        -- not which category each player belongs to)
        self.lastOrderHash = nil
        self:RebuildList()
        self:RepositionStack()

        if existingCat then
            DEFAULT_CHAT_FRAME:AddMessage("IchaTaunt: Re-added " .. playerName .. " to " .. selectedCat .. " (was ghost in " .. existingCat .. ")")
        else
            DEFAULT_CHAT_FRAME:AddMessage("IchaTaunt: Added " .. playerName .. " to " .. selectedCat)
        end
    end)
    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("[IchaTaunt ERROR] AddPlayer failed: " .. tostring(err))
    end
end

-- Check if current player can modify assignments (solo = can always modify). Lua 5.0 / 1.12 safe.
function IchaTaunt:CanControl()
    local inGroup = false
    if GetNumRaidMembers and GetNumRaidMembers() and GetNumRaidMembers() > 0 then inGroup = true end
    if not inGroup and GetNumPartyMembers and GetNumPartyMembers() and GetNumPartyMembers() > 0 then inGroup = true end
    if not inGroup then return true end
    -- 1.12: check leader/officer; use wrapper so pcall never gets nil (Lua 5.0 safe)
    if IsPartyLeader then
        local ok, result = pcall(function() return IsPartyLeader() end)
        if ok and result then return true end
    end
    if IsRaidLeader then
        local ok, result = pcall(function() return IsRaidLeader() end)
        if ok and result then return true end
    end
    if IsRaidOfficer then
        local ok, result = pcall(function() return IsRaidOfficer() end)
        if ok and result then return true end
    end
    -- Fallback: raid roster rank (>= 1 = assistant/leader)
    if GetNumRaidMembers and GetNumRaidMembers() > 0 and GetRaidRosterInfo then
        local myName = UnitName("player")
        for i = 1, GetNumRaidMembers() do
            local n, rank = GetRaidRosterInfo(i)
            if n == myName and rank and rank >= 1 then return true end
        end
    end
    if GetNumPartyMembers and GetNumPartyMembers() > 0 and UnitIsPartyLeader then
        if UnitIsPartyLeader("player") then return true end
    end
    return false
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

    -- CLEARALL - Clear all tracked members (sent by any user running /ichataunt clearall)
    if msg == "CLEARALL" then
        local taunterCount, categoryCount = self:ClearAllTrackedMembers()
        self.clearAllTime = GetTime()
        if IchaTauntDB.debugMode then
            DEFAULT_CHAT_FRAME:AddMessage("=== IchaTaunt: Remote Clear Received ===")
            DEFAULT_CHAT_FRAME:AddMessage("Removed " .. taunterCount .. " players from taunters list")
            DEFAULT_CHAT_FRAME:AddMessage("Removed " .. categoryCount .. " players from categories")
            DEFAULT_CHAT_FRAME:AddMessage("Cleared by: " .. sender)
            DEFAULT_CHAT_FRAME:AddMessage("=== Clear Complete ===")
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

        -- Block ORDER messages for 10 seconds after CLEARALL to prevent re-sync from outdated clients
        if self.clearAllTime and (GetTime() - self.clearAllTime) < 10 then
            if IchaTauntDB.debugMode then
                print("[IchaTaunt Sync] Blocking ORDER message (CLEARALL was " .. math.floor(GetTime() - self.clearAllTime) .. "s ago)")
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

        -- Block TAUNTERS messages for 10 seconds after CLEARALL to prevent re-sync from outdated clients
        if self.clearAllTime and (GetTime() - self.clearAllTime) < 10 then
            if IchaTauntDB.debugMode then
                print("[IchaTaunt Sync] Blocking TAUNTERS message (CLEARALL was " .. math.floor(GetTime() - self.clearAllTime) .. "s ago)")
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

        -- Block ADD messages for 10 seconds after CLEARALL to prevent re-sync from outdated clients
        if self.clearAllTime and (GetTime() - self.clearAllTime) < 10 then
            if IchaTauntDB.debugMode then
                print("[IchaTaunt Sync] Blocking ADD message (CLEARALL was " .. math.floor(GetTime() - self.clearAllTime) .. "s ago)")
            end
            return
        end

        local name = strsub(msg, 5)
        if not IchaTauntDB.taunters then IchaTauntDB.taunters = {} end
        if not IchaTauntDB.taunterOrder then IchaTauntDB.taunterOrder = {} end

        -- Check if already added
        local found = false
        for _, orderName in ipairs(IchaTauntDB.taunterOrder) do
            if orderName == name then found = true break end
        end

        if not found then
            -- Add to taunters
            IchaTauntDB.taunters[name] = true
            self.taunters[name] = true

            -- Add to order
            table.insert(IchaTauntDB.taunterOrder, name)

            -- Add to category (default to tanks if not already in a category)
            if IchaTaunt_Categories then
                local existingCategory = IchaTaunt_Categories:GetPlayerCategory(name)
                if not existingCategory then
                    IchaTaunt_Categories:AddToCategory(name, "tanks")
                end
            end
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

        -- Remove from all categories
        if IchaTaunt_Categories then
            local playerCategory = IchaTaunt_Categories:GetPlayerCategory(name)
            if playerCategory then
                IchaTaunt_Categories:RemoveFromCategory(name, playerCategory)
            end
        end

        -- Remove from taunters (in case not in any category)
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

    -- DTPS:dtps:htps:window - Damage and healing taken per second from sender (they broadcast their own)
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
                -- New format: DTPS:dtps:htps:window (parts[1]=dtps, parts[2]=htps, parts[3]=window)
                -- Old format: DTPS:value:window (parts[1]=value, parts[2]=window)
                IchaTaunt_DPS:ReceiveDTPS(sender, parts[1], parts[2], parts[3])
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

-- Helper function to create game-style close button (same style as +/- buttons)
local function CreateCloseButton(parent, onClickFunc)
    local closeX = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    closeX:SetWidth(22)
    closeX:SetHeight(22)
    closeX:SetText("X")
    closeX:SetScript("OnClick", onClickFunc)
    return closeX
end

-- Two-panel taunter selection UI
local function ShowTaunterPopup()
    -- Use pcall to catch any errors
    local success, errorMsg = pcall(function()
        if not IchaTaunt.taunterUI then
            local theme = IchaTaunt:GetTheme()
            local c = theme.config

            local f = CreateFrame("Frame", "IchaTauntTaunterUI", UIParent)
        f:SetWidth(900)  -- Wider to accommodate 4 groups per row
        f:SetHeight(650)  -- Taller to accommodate 2 rows of groups
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

        -- Close X (top right corner) - game-style red button
        local closeX = CreateCloseButton(f, function()
            f:Hide()
            if IchaTaunt.optionsMenu and IchaTaunt.optionsMenu:IsVisible() then
                IchaTaunt.optionsMenu:Hide()
            end
        end)
        closeX:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

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

        -- CATEGORY SELECTOR (Role dropdown)
        local catLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        catLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -55)
        catLabel:SetText("Add to Role:")
        catLabel:SetTextColor(unpack(c.titleColor))

        -- Category dropdown buttons (pseudo-dropdown using buttons)
        local categoryNames = {"Tanks", "Healers", "Interrupters", "Other"}
        local categoryKeys = {"tanks", "healers", "interrupters", "other"}
        f.selectedCategory = "tanks" -- default

        local catButtons = {}
        local catBtnWidth = 80
        for i, catName in ipairs(categoryNames) do
            local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            btn:SetWidth(catBtnWidth)
            btn:SetHeight(20)
            btn:SetPoint("LEFT", catLabel, "RIGHT", 10 + ((i-1) * (catBtnWidth + 5)), 0)
            btn:SetText(catName)

            local catKey = categoryKeys[i]
            btn:SetScript("OnClick", function()
                f.selectedCategory = catKey
                -- Update button appearance to show selection
                for j, otherBtn in ipairs(catButtons) do
                    local fontString = otherBtn:GetFontString()
                    if fontString then
                        if j == i then
                            fontString:SetTextColor(1, 1, 0)  -- Yellow for selected
                        else
                            fontString:SetTextColor(1, 1, 1)  -- White for unselected
                        end
                    end
                end
                -- Refresh right panel to show selected category
                if f.RefreshPanels then
                    f.RefreshPanels()
                end
            end)

            -- Highlight default selection
            if catKey == "tanks" then
                local fontString = btn:GetFontString()
                if fontString then
                    fontString:SetTextColor(1, 1, 0)  -- Yellow for selected
                end
            end

            table.insert(catButtons, btn)
        end
        f.catButtons = catButtons

        -- RAID GROUPS GRID: Show G1-G8 in 2 rows of 4
        local groupsContainer = CreateFrame("Frame", nil, f)
        groupsContainer:SetWidth(600)
        groupsContainer:SetHeight(480)
        groupsContainer:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -85)

        -- Create 8 group panels (G1-G4 top row, G5-G8 bottom row)
        f.groupPanels = {}
        local groupWidth = 140
        local groupHeight = 230
        local groupSpacing = 10

        for groupNum = 1, 8 do
            local panel = CreateFrame("Frame", nil, groupsContainer)
            panel:SetWidth(groupWidth)
            panel:SetHeight(groupHeight)
            panel:SetBackdrop(c.panelBackdrop)
            panel:SetBackdropColor(unpack(c.panelBgColor))

            -- Position: G1-G4 on top row, G5-G8 on bottom row
            local row = (groupNum <= 4) and 0 or 1
            local col = math.mod(groupNum - 1, 4)
            local xOffset = col * (groupWidth + groupSpacing)
            local yOffset = -row * (groupHeight + groupSpacing)
            panel:SetPoint("TOPLEFT", groupsContainer, "TOPLEFT", xOffset, yOffset)

            -- Group header
            local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            header:SetPoint("TOP", panel, "TOP", 0, -5)
            header:SetText("G" .. groupNum)
            header:SetTextColor(unpack(c.titleColor))
            panel.header = header

            -- Container for player entries
            panel.entries = {}
            panel.groupNum = groupNum

            f.groupPanels[groupNum] = panel
        end

        f.groupsContainer = groupsContainer
        
        -- RIGHT PANEL: Category Members
        local rightPanel = CreateFrame("Frame", nil, f)
        rightPanel:SetWidth(260)
        rightPanel:SetHeight(545)  -- Taller to match new height
        rightPanel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -15, -85)
        rightPanel:SetBackdrop(c.panelBackdrop)
        rightPanel:SetBackdropColor(unpack(c.panelBgColor))

        local rightTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rightTitle:SetPoint("TOP", rightPanel, "TOP", 0, -10)
        rightTitle:SetText("Tanks (use arrows to reorder)")
        rightTitle:SetTextColor(unpack(c.titleColor))
        f.rightTitle = rightTitle
        
        -- Create scroll frame for right panel
        local rightScroll = CreateFrame("ScrollFrame", nil, rightPanel)
        rightScroll:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 10, -30)
        rightScroll:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -10, 10)
        rightScroll:EnableMouseWheel(true)
        rightScroll:SetScript("OnMouseWheel", function()
            local step = 24
            local newValue = this:GetVerticalScroll() - (arg1 * step)
            if newValue < 0 then newValue = 0 end
            local maxVal = this:GetVerticalScrollRange()
            if maxVal and newValue > maxVal then newValue = maxVal end
            this:SetVerticalScroll(newValue)
        end)
        
        local rightScrollChild = CreateFrame("Frame", nil, rightScroll)
        rightScrollChild:SetWidth(230)
        rightScrollChild:SetHeight(1)
        rightScroll:SetScrollChild(rightScrollChild)
        
        f.rightScroll = rightScroll
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

            if f.rightTitle then
                f.rightTitle:SetText("Tracked Players")
            end

            -- Clear existing group panel entries
            if f.groupPanels then
                for _, panel in ipairs(f.groupPanels) do
                    if panel.entries then
                        for _, entry in ipairs(panel.entries) do
                            if entry.Hide then entry:Hide() end
                        end
                        panel.entries = {}
                    end
                end
            end

            if f.rightElements then
                for _, element in pairs(f.rightElements) do
                    if element.Hide then element:Hide() end
                end
            end

            f.rightElements = {}

            -- POPULATE GROUP PANELS with raid members
            local inRaid = GetNumRaidMembers() > 0
            local inParty = GetNumPartyMembers() > 0

            if inRaid then
                -- Get raid members organized by group
                for i = 1, GetNumRaidMembers() do
                    local name, _, subgroup, _, _, classFile = GetRaidRosterInfo(i)
                    if name and classFile and subgroup then
                        local panel = f.groupPanels[subgroup]
                        if panel then
                            -- Show all classes that have trackable spells
                            local hasTrackableSpells = IchaTaunt_TrackableSpells and IchaTaunt_TrackableSpells[classFile]
                            if hasTrackableSpells then
                                local entryIdx = table.getn(panel.entries) + 1
                                local yOffset = -25 - ((entryIdx - 1) * 22)

                                local entry = CreateFrame("Frame", nil, panel)
                                entry:SetWidth(130)
                                entry:SetHeight(20)
                                entry:SetPoint("TOPLEFT", panel, "TOPLEFT", 5, yOffset)

                                -- Player name with class color
                                local nameText = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                                nameText:SetPoint("LEFT", entry, "LEFT", 0, 0)
                                nameText:SetText(name)
                                nameText:SetWidth(100)
                                nameText:SetJustifyH("LEFT")
                                local r, g, b = unpack(IchaTaunt:GetClassColor(classFile))
                                nameText:SetTextColor(r, g, b)

                                -- + button
                                local addBtn = CreateFrame("Button", nil, entry, "UIPanelButtonTemplate")
                                addBtn:SetWidth(18)
                                addBtn:SetHeight(18)
                                addBtn:SetPoint("RIGHT", entry, "RIGHT", 0, 0)
                                addBtn:SetText("+")

                                -- Capture values for closure
                                local playerName = name
                                local playerClass = classFile

                                -- Disable button if not leader in a group
                                local canControl = IchaTaunt:CanControl()
                                if not canControl then
                                    addBtn:Disable()
                                end

                                addBtn:SetScript("OnClick", function()
                                    IchaTaunt:AddPlayerToTracker(playerName, f.selectedCategory or "tanks", RefreshPanels)
                                end)

                                table.insert(panel.entries, entry)
                            end
                        end
                    end
                end
            elseif inParty then
                -- Party mode: show all party members in G1
                local panel = f.groupPanels[1]
                if panel then
                    local entryIdx = 1

                    -- Add party members
                    for i = 1, GetNumPartyMembers() do
                        local name = UnitName("party" .. i)
                        local _, classFile = UnitClass("party" .. i)
                        if name and classFile then
                            local hasTrackableSpells = IchaTaunt_TrackableSpells and IchaTaunt_TrackableSpells[classFile]
                            if hasTrackableSpells then
                                local yOffset = -25 - ((entryIdx - 1) * 22)

                                local entry = CreateFrame("Frame", nil, panel)
                                entry:SetWidth(130)
                                entry:SetHeight(20)
                                entry:SetPoint("TOPLEFT", panel, "TOPLEFT", 5, yOffset)

                                local nameText = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                                nameText:SetPoint("LEFT", entry, "LEFT", 0, 0)
                                nameText:SetText(name)
                                nameText:SetWidth(100)
                                nameText:SetJustifyH("LEFT")
                                local r, g, b = unpack(IchaTaunt:GetClassColor(classFile))
                                nameText:SetTextColor(r, g, b)

                                local addBtn = CreateFrame("Button", nil, entry, "UIPanelButtonTemplate")
                                addBtn:SetWidth(18)
                                addBtn:SetHeight(18)
                                addBtn:SetPoint("RIGHT", entry, "RIGHT", 0, 0)
                                addBtn:SetText("+")

                                local playerName = name

                                addBtn:SetScript("OnClick", function()
                                    IchaTaunt:AddPlayerToTracker(playerName, f.selectedCategory or "tanks", RefreshPanels)
                                end)

                                table.insert(panel.entries, entry)
                                entryIdx = entryIdx + 1
                            end
                        end
                    end

                    -- Add player
                    local playerName = UnitName("player")
                    local _, playerClass = UnitClass("player")
                    if playerName and playerClass then
                        local hasTrackableSpells = IchaTaunt_TrackableSpells and IchaTaunt_TrackableSpells[playerClass]
                        if hasTrackableSpells then
                            local yOffset = -25 - ((entryIdx - 1) * 22)

                            local entry = CreateFrame("Frame", nil, panel)
                            entry:SetWidth(130)
                            entry:SetHeight(20)
                            entry:SetPoint("TOPLEFT", panel, "TOPLEFT", 5, yOffset)

                            local nameText = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                            nameText:SetPoint("LEFT", entry, "LEFT", 0, 0)
                            nameText:SetText(playerName)
                            nameText:SetWidth(100)
                            nameText:SetJustifyH("LEFT")
                            local r, g, b = unpack(IchaTaunt:GetClassColor(playerClass))
                            nameText:SetTextColor(r, g, b)

                            local addBtn = CreateFrame("Button", nil, entry, "UIPanelButtonTemplate")
                            addBtn:SetWidth(18)
                            addBtn:SetHeight(18)
                            addBtn:SetPoint("RIGHT", entry, "RIGHT", 0, 0)
                            addBtn:SetText("+")

                            addBtn:SetScript("OnClick", function()
                                IchaTaunt:AddPlayerToTracker(playerName, f.selectedCategory or "tanks", RefreshPanels)
                            end)

                            table.insert(panel.entries, entry)
                        end
                    end
                end
            else
                -- Solo: show player in G1
                local panel = f.groupPanels[1]
                if panel then
                    local playerName = UnitName("player")
                    local _, playerClass = UnitClass("player")
                    if playerName and playerClass then
                        local hasTrackableSpells = IchaTaunt_TrackableSpells and IchaTaunt_TrackableSpells[playerClass]
                        if hasTrackableSpells then
                            local entry = CreateFrame("Frame", nil, panel)
                            entry:SetWidth(130)
                            entry:SetHeight(20)
                            entry:SetPoint("TOPLEFT", panel, "TOPLEFT", 5, -25)

                            local nameText = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                            nameText:SetPoint("LEFT", entry, "LEFT", 0, 0)
                            nameText:SetText(playerName)
                            nameText:SetWidth(100)
                            nameText:SetJustifyH("LEFT")
                            local r, g, b = unpack(IchaTaunt:GetClassColor(playerClass))
                            nameText:SetTextColor(r, g, b)

                            local addBtn = CreateFrame("Button", nil, entry, "UIPanelButtonTemplate")
                            addBtn:SetWidth(18)
                            addBtn:SetHeight(18)
                            addBtn:SetPoint("RIGHT", entry, "RIGHT", 0, 0)
                            addBtn:SetText("+")

                            addBtn:SetScript("OnClick", function()
                                IchaTaunt:AddPlayerToTracker(playerName, f.selectedCategory or "tanks", RefreshPanels)
                            end)

                            table.insert(panel.entries, entry)
                        end
                    end
                end
            end
            
            -- RIGHT PANEL: Show ALL categories with their members
            yOffset = -5
            local allCatOrder = IchaTaunt_Categories.CATEGORY_ORDER
            local allCatColors = IchaTaunt_Categories.CATEGORY_COLORS
            local allCatNames = IchaTaunt_Categories.CATEGORY_NAMES
            local inGroup = GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
            local canControl = not inGroup or IchaTaunt:CanControl()

            for _, cat in ipairs(allCatOrder) do
                -- Category header
                local header = f.rightScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                header:SetPoint("TOPLEFT", f.rightScrollChild, "TOPLEFT", 0, yOffset)
                header:SetText(allCatNames[cat] or cat)
                local catColor = allCatColors[cat] or {1, 1, 1}
                header:SetTextColor(catColor[1], catColor[2], catColor[3])
                table.insert(f.rightElements, header)
                yOffset = yOffset - 18

                -- Build ordered member list for this category
                local orderedMembers = {}
                if IchaTaunt_Categories then
                    local catMembers = IchaTaunt_Categories:GetCategoryMembers(cat)
                    for _, name in ipairs(IchaTauntDB.taunterOrder or {}) do
                        if catMembers[name] then
                            table.insert(orderedMembers, name)
                        end
                    end
                end

                local totalInCat = table.getn(orderedMembers)

                if totalInCat == 0 then
                    local emptyText = f.rightScrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                    emptyText:SetPoint("TOPLEFT", f.rightScrollChild, "TOPLEFT", 10, yOffset)
                    emptyText:SetText("(empty)")
                    table.insert(f.rightElements, emptyText)
                    yOffset = yOffset - 16
                else
                    for i, name in ipairs(orderedMembers) do
                        local entry = CreateFrame("Frame", nil, f.rightScrollChild)
                        entry:SetWidth(230)
                        entry:SetHeight(20)
                        entry:SetPoint("TOPLEFT", f.rightScrollChild, "TOPLEFT", 0, yOffset)

                        -- Up arrow
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

                        local capturedName = name
                        local capturedPrevName = orderedMembers[i - 1]
                        upBtn:SetScript("OnClick", function()
                            if not capturedPrevName then return end
                            local globalThis, globalPrev = nil, nil
                            for gi, gName in ipairs(IchaTauntDB.taunterOrder) do
                                if gName == capturedName then globalThis = gi end
                                if gName == capturedPrevName then globalPrev = gi end
                            end
                            if globalThis and globalPrev then
                                IchaTauntDB.taunterOrder[globalThis] = capturedPrevName
                                IchaTauntDB.taunterOrder[globalPrev] = capturedName
                                IchaTaunt.order = IchaTauntDB.taunterOrder
                                if GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0 then
                                    if IchaTaunt:CanControl() then IchaTaunt:BroadcastOrder() end
                                end
                                RefreshPanels()
                                IchaTaunt.lastOrderHash = nil
                                IchaTaunt:RebuildList()
                                IchaTaunt:RepositionStack()
                            end
                        end)

                        -- Down arrow
                        local downBtn = CreateFrame("Button", nil, entry)
                        downBtn:SetWidth(16)
                        downBtn:SetHeight(16)
                        downBtn:SetPoint("LEFT", upBtn, "RIGHT", 2, 0)
                        downBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
                        downBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
                        downBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
                        if i == totalInCat or not canControl then
                            downBtn:Disable()
                            downBtn:SetAlpha(0.3)
                        end

                        local capturedNextName = orderedMembers[i + 1]
                        downBtn:SetScript("OnClick", function()
                            if not capturedNextName then return end
                            local globalThis, globalNext = nil, nil
                            for gi, gName in ipairs(IchaTauntDB.taunterOrder) do
                                if gName == capturedName then globalThis = gi end
                                if gName == capturedNextName then globalNext = gi end
                            end
                            if globalThis and globalNext then
                                IchaTauntDB.taunterOrder[globalThis] = capturedNextName
                                IchaTauntDB.taunterOrder[globalNext] = capturedName
                                IchaTaunt.order = IchaTauntDB.taunterOrder
                                if GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0 then
                                    if IchaTaunt:CanControl() then IchaTaunt:BroadcastOrder() end
                                end
                                RefreshPanels()
                                IchaTaunt.lastOrderHash = nil
                                IchaTaunt:RebuildList()
                                IchaTaunt:RepositionStack()
                            end
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

                        -- Remove button (uses this row's category, not the toggle selection)
                        local removeBtn = CreateFrame("Button", nil, entry, "UIPanelButtonTemplate")
                        removeBtn:SetWidth(20)
                        removeBtn:SetHeight(20)
                        removeBtn:SetPoint("RIGHT", entry, "RIGHT", 0, 0)
                        removeBtn:SetText("-")
                        if not canControl then removeBtn:Disable() end

                        local playerName = name
                        local rowCategory = cat
                        removeBtn:SetScript("OnClick", function()
                            if (GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0) and not IchaTaunt:CanControl() then
                                print("IchaTaunt: Only raid leader/officers can modify taunter list")
                                return
                            end
                            if not IchaTauntDB.taunterOrder then IchaTauntDB.taunterOrder = {} end
                            if not IchaTauntDB.taunters then IchaTauntDB.taunters = {} end

                            if IchaTaunt_Categories and IchaTaunt_Categories.RemoveFromCategory then
                                IchaTaunt_Categories:RemoveFromCategory(playerName, rowCategory)
                            end

                            local inAnyCategory = false
                            if IchaTaunt_Categories then
                                for _, c in ipairs({"tanks", "healers", "interrupters", "other"}) do
                                    local members = IchaTaunt_Categories:GetCategoryMembers(c)
                                    if members[playerName] then
                                        inAnyCategory = true
                                        break
                                    end
                                end
                            end
                            if not inAnyCategory then
                                for j, orderName in ipairs(IchaTauntDB.taunterOrder) do
                                    if orderName == playerName then
                                        table.remove(IchaTauntDB.taunterOrder, j)
                                        break
                                    end
                                end
                                IchaTauntDB.taunters[playerName] = nil
                            end

                            IchaTaunt.taunters = IchaTauntDB.taunters or {}
                            IchaTaunt.order = IchaTauntDB.taunterOrder or {}
                            IchaTaunt:AutoBroadcast()
                            RefreshPanels()
                            IchaTaunt.lastOrderHash = nil
                            IchaTaunt:RebuildList()
                            IchaTaunt:RepositionStack()
                        end)

                        table.insert(f.rightElements, entry)
                        yOffset = yOffset - 22
                    end
                end

                yOffset = yOffset - 6
            end

            -- Update right scroll child height
            local rightContentHeight = math.abs(yOffset) + 15
            f.rightScrollChild:SetHeight(math.max(rightContentHeight, 1))
            if f.rightScroll and f.rightScroll.UpdateScrollChildRect then
                f.rightScroll:UpdateScrollChildRect()
            end
        end
        
        -- Try to assign RefreshPanels with error handling
        local success, err = pcall(function()
            f.RefreshPanels = RefreshPanels
        end)
        if not success then
            DEFAULT_CHAT_FRAME:AddMessage("[IchaTaunt ERROR] Failed to assign RefreshPanels: " .. tostring(err))
        end

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

            -- Register events for dynamic roster updates
            f:RegisterEvent("RAID_ROSTER_UPDATE")
            f:RegisterEvent("PARTY_MEMBERS_CHANGED")
            f:SetScript("OnEvent", function()
                if this:IsVisible() and RefreshPanels then
                    RefreshPanels()
                end
            end)

            -- OnUpdate to check for roster changes periodically (handles group reassignments)
            f.lastUpdate = 0
            f.updateInterval = 1.0  -- Check every 1 second
            f:SetScript("OnUpdate", function()
                if not this:IsVisible() then return end
                this.lastUpdate = this.lastUpdate + (arg1 or 0)
                if this.lastUpdate >= this.updateInterval then
                    this.lastUpdate = 0
                    if RefreshPanels then
                        RefreshPanels()
                    end
                end
            end)

            -- Hook into the frame's OnHide to close options menu
            f:SetScript("OnHide", function()
                if IchaTaunt.optionsMenu and IchaTaunt.optionsMenu:IsVisible() then
                    IchaTaunt.optionsMenu:Hide()
                end
            end)

            f:Hide()
            IchaTaunt.taunterUI = f
        end

        -- Refresh panels and show
        if IchaTaunt.taunterUI then
            IchaTaunt.taunterUI.RefreshPanels()
            IchaTaunt.taunterUI:Show()
        end
    end)

    if not success then
        DEFAULT_CHAT_FRAME:AddMessage("[IchaTaunt CRITICAL ERROR] ShowTaunterPopup failed:")
        DEFAULT_CHAT_FRAME:AddMessage(tostring(errorMsg))
    end
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
    f:SetWidth(400)  -- Wider for 2-column layout
    f:SetHeight(385) -- Height for 2 columns with DTPS slider and NET mode checkbox
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

    -- Close X (top right) - game-style red button
    local closeX = CreateCloseButton(f, function() f:Hide() end)
    closeX:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

    -- ========== LEFT COLUMN ==========
    local leftX = 15
    local yOffset = -40

    -- ===== THEME SECTION (Left Column) =====
    local themeSection = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeSection:SetPoint("TOPLEFT", f, "TOPLEFT", leftX, yOffset)
    themeSection:SetText("Theme")
    themeSection:SetTextColor(unpack(c.titleColor))
    f.themeSection = themeSection

    -- Theme buttons
    local themeOrder = {"default", "dark", "elvui"}
    local themeButtons = {}
    yOffset = yOffset - 20

    for i, themeKey in ipairs(themeOrder) do
        local themeData = IchaTaunt_Themes[themeKey]
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetWidth(170)
        btn:SetHeight(20)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", leftX, yOffset)
        btn:SetText(themeData.name)

        local capturedKey = themeKey
        btn:SetScript("OnClick", function()
            IchaTaunt:SetTheme(capturedKey)
            IchaTaunt:RefreshOptionsMenu()
            if IchaTaunt.taunterUI then
                IchaTaunt.taunterUI:Hide()
                IchaTaunt.taunterUI = nil
                ShowTaunterPopup()
                IchaTaunt:ShowOptionsMenu()
            end
        end)

        themeButtons[themeKey] = btn
        yOffset = yOffset - 22
    end
    f.themeButtons = themeButtons

    -- ===== SCALE SECTION (Left Column) =====
    yOffset = yOffset - 10
    local scaleSection = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scaleSection:SetPoint("TOPLEFT", f, "TOPLEFT", leftX, yOffset)
    scaleSection:SetText("Scale")
    scaleSection:SetTextColor(unpack(c.titleColor))
    f.scaleSection = scaleSection

    local scaleValue = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scaleValue:SetPoint("TOPLEFT", f, "TOPLEFT", leftX + 50, yOffset)
    scaleValue:SetText(format("%.0f%%", (IchaTauntDB.scale or 1.0) * 100))
    f.scaleValue = scaleValue

    yOffset = yOffset - 22

    -- Scale +/- buttons
    local scaleDown = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    scaleDown:SetWidth(25)
    scaleDown:SetHeight(20)
    scaleDown:SetPoint("TOPLEFT", f, "TOPLEFT", leftX, yOffset)
    scaleDown:SetText("-")
    scaleDown:SetScript("OnClick", function()
        local newScale = (IchaTauntDB.scale or 1.0) - 0.1
        IchaTaunt:SetScale(newScale)
        IchaTaunt:RefreshOptionsMenu()
    end)

    local scaleUp = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    scaleUp:SetWidth(25)
    scaleUp:SetHeight(20)
    scaleUp:SetPoint("TOPLEFT", f, "TOPLEFT", leftX + 28, yOffset)
    scaleUp:SetText("+")
    scaleUp:SetScript("OnClick", function()
        local newScale = (IchaTauntDB.scale or 1.0) + 0.1
        IchaTaunt:SetScale(newScale)
        IchaTaunt:RefreshOptionsMenu()
    end)

    -- Scale presets (compact)
    local presets = {{label = "50", value = 0.5}, {label = "100", value = 1.0}, {label = "150", value = 1.5}}
    for i, preset in ipairs(presets) do
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetWidth(35)
        btn:SetHeight(20)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", leftX + 56 + ((i-1) * 38), yOffset)
        btn:SetText(preset.label)
        local capturedValue = preset.value
        btn:SetScript("OnClick", function()
            IchaTaunt:SetScale(capturedValue)
            IchaTaunt:RefreshOptionsMenu()
        end)
    end

    -- ===== POSITION SECTION (Left Column) =====
    yOffset = yOffset - 32
    local resetSection = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resetSection:SetPoint("TOPLEFT", f, "TOPLEFT", leftX, yOffset)
    resetSection:SetText("Position")
    resetSection:SetTextColor(unpack(c.titleColor))
    f.resetSection = resetSection

    yOffset = yOffset - 22
    local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBtn:SetWidth(80)
    resetBtn:SetHeight(20)
    resetBtn:SetPoint("TOPLEFT", f, "TOPLEFT", leftX, yOffset)
    resetBtn:SetText("Reset")
    resetBtn:SetScript("OnClick", function()
        IchaTauntDB.position.x = 0
        IchaTauntDB.position.y = 0

        -- Reset all category positions
        if IchaTaunt_Categories and IchaTauntDB.categories then
            for i, category in ipairs(IchaTaunt_Categories.CATEGORY_ORDER) do
                if IchaTauntDB.categories[category] then
                    -- Stack categories vertically with 120px spacing
                    IchaTauntDB.categories[category].position.x = 0
                    IchaTauntDB.categories[category].position.y = -(i - 1) * 120
                end
            end
        end

        -- Apply reset positions to visible frames
        if IchaTaunt.categoryFrames then
            for i, category in ipairs(IchaTaunt_Categories.CATEGORY_ORDER) do
                local frame = IchaTaunt.categoryFrames[category]
                if frame then
                    local catData = IchaTauntDB.categories[category]
                    frame:ClearAllPoints()
                    frame:SetPoint("TOP", UIParent, "TOP", catData.position.x, catData.position.y)
                end
            end
        elseif IchaTaunt.frame then
            IchaTaunt.frame:ClearAllPoints()
            IchaTaunt.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        print("IchaTaunt: All category positions reset")
    end)

    local lockUnlockBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    lockUnlockBtn:SetWidth(80)
    lockUnlockBtn:SetHeight(20)
    lockUnlockBtn:SetPoint("TOPLEFT", f, "TOPLEFT", leftX + 85, yOffset)
    lockUnlockBtn:SetScript("OnClick", function()
        IchaTaunt:ToggleLock()
        IchaTaunt:RefreshLockUnlockButton()
    end)
    f.lockUnlockBtn = lockUnlockBtn
    lockUnlockBtn:SetText(IchaTaunt.locked and "Unlock" or "Lock")

    -- ===== CUSTOM SPELLS (Left Column - Bottom) =====
    yOffset = yOffset - 32
    local customSection = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    customSection:SetPoint("TOPLEFT", f, "TOPLEFT", leftX, yOffset)
    customSection:SetText("Spells")
    customSection:SetTextColor(unpack(c.titleColor))
    f.customSection = customSection

    yOffset = yOffset - 22
    local customSpellsBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    customSpellsBtn:SetWidth(170)
    customSpellsBtn:SetHeight(20)
    customSpellsBtn:SetPoint("TOPLEFT", f, "TOPLEFT", leftX, yOffset)
    customSpellsBtn:SetText("Manage Tracked Spells")
    customSpellsBtn:SetScript("OnClick", function()
        IchaTaunt:ShowCustomSpellsMenu()
    end)

    -- ========== RIGHT COLUMN ==========
    local rightX = 210
    yOffset = -40

    -- ===== DISPLAY OPTIONS (Right Column) =====
    local displaySection = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    displaySection:SetPoint("TOPLEFT", f, "TOPLEFT", rightX, yOffset)
    displaySection:SetText("Display Options")
    displaySection:SetTextColor(unpack(c.titleColor))
    f.displaySection = displaySection

    yOffset = yOffset - 22
    local showInRaidCheck = CreateFrame("CheckButton", "IchaTauntShowInRaidCheck", f, "UICheckButtonTemplate")
    showInRaidCheck:SetWidth(20)
    showInRaidCheck:SetHeight(20)
    showInRaidCheck:SetPoint("TOPLEFT", f, "TOPLEFT", rightX, yOffset)
    showInRaidCheck:SetChecked(IchaTauntDB.showInRaidOnly)
    showInRaidCheck:SetScript("OnClick", function()
        IchaTauntDB.showInRaidOnly = (this:GetChecked() == 1)
        IchaTaunt:RefreshRoster()
    end)
    f.showInRaidCheck = showInRaidCheck
    local showInRaidLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    showInRaidLabel:SetPoint("LEFT", showInRaidCheck, "RIGHT", 2, 0)
    showInRaidLabel:SetText("Only show in raid")

    yOffset = yOffset - 22
    local cdOnlyCheck = CreateFrame("CheckButton", "IchaTauntCDOnlyCheck", f, "UICheckButtonTemplate")
    cdOnlyCheck:SetWidth(20)
    cdOnlyCheck:SetHeight(20)
    cdOnlyCheck:SetPoint("TOPLEFT", f, "TOPLEFT", rightX, yOffset)
    cdOnlyCheck:SetChecked(IchaTauntDB.cooldownOnlyMode)
    cdOnlyCheck:SetScript("OnClick", function()
        IchaTauntDB.cooldownOnlyMode = (this:GetChecked() == 1)
        IchaTaunt:RebuildList()
    end)
    f.cdOnlyCheck = cdOnlyCheck
    local cdOnlyLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cdOnlyLabel:SetPoint("LEFT", cdOnlyCheck, "RIGHT", 2, 0)
    cdOnlyLabel:SetText("Cooldown only mode")

    yOffset = yOffset - 22
    local growUpwardCheck = CreateFrame("CheckButton", "IchaTauntGrowUpwardCheck", f, "UICheckButtonTemplate")
    growUpwardCheck:SetWidth(20)
    growUpwardCheck:SetHeight(20)
    growUpwardCheck:SetPoint("TOPLEFT", f, "TOPLEFT", rightX, yOffset)
    growUpwardCheck:SetChecked(IchaTauntDB.growUpward)
    growUpwardCheck:SetScript("OnClick", function()
        IchaTauntDB.growUpward = (this:GetChecked() == 1)
        IchaTaunt:RebuildList()
    end)
    f.growUpwardCheck = growUpwardCheck
    local growUpwardLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    growUpwardLabel:SetPoint("LEFT", growUpwardCheck, "RIGHT", 2, 0)
    growUpwardLabel:SetText("Grow list upward")

    -- ===== DTPS SECTION (Right Column) =====
    yOffset = yOffset - 32
    local dtpsSection = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dtpsSection:SetPoint("TOPLEFT", f, "TOPLEFT", rightX, yOffset)
    dtpsSection:SetText("DTPS Module")
    dtpsSection:SetTextColor(unpack(c.titleColor))
    f.dtpsSection = dtpsSection

    yOffset = yOffset - 22
    local dtpsCheck = CreateFrame("CheckButton", "IchaTauntDTPSCheck", f, "UICheckButtonTemplate")
    dtpsCheck:SetWidth(20)
    dtpsCheck:SetHeight(20)
    dtpsCheck:SetPoint("TOPLEFT", f, "TOPLEFT", rightX, yOffset)
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
    dtpsLabel:SetPoint("LEFT", dtpsCheck, "RIGHT", 2, 0)
    dtpsLabel:SetText("Show DTPS on bars")

    -- DTPS Window Size slider (3-15 seconds)
    yOffset = yOffset - 24
    local windowLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    windowLabel:SetPoint("TOPLEFT", f, "TOPLEFT", rightX, yOffset)
    windowLabel:SetText("DTPS Window:")

    local currentWindow = 5
    if IchaTaunt_DPS and IchaTaunt_DPS.config then
        currentWindow = IchaTaunt_DPS.config.windowSize or 5
    end

    -- Minus button
    local windowMinus = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    windowMinus:SetWidth(20)
    windowMinus:SetHeight(20)
    windowMinus:SetPoint("LEFT", windowLabel, "RIGHT", 8, 0)
    windowMinus:SetText("-")
    windowMinus:SetScript("OnClick", function()
        local cur = IchaTaunt_DPS and IchaTaunt_DPS.config.windowSize or 5
        local newVal = math.max(3, cur - 1)
        if IchaTaunt_DPS then
            IchaTaunt_DPS:SetWindowSize(newVal)
        end
        if f.windowValue then
            f.windowValue:SetText(newVal .. "s")
        end
    end)

    -- Value display
    local windowValue = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    windowValue:SetPoint("LEFT", windowMinus, "RIGHT", 6, 0)
    windowValue:SetText(currentWindow .. "s")
    windowValue:SetWidth(25)
    windowValue:SetJustifyH("CENTER")
    f.windowValue = windowValue

    -- Plus button
    local windowPlus = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    windowPlus:SetWidth(20)
    windowPlus:SetHeight(20)
    windowPlus:SetPoint("LEFT", windowValue, "RIGHT", 6, 0)
    windowPlus:SetText("+")
    windowPlus:SetScript("OnClick", function()
        local cur = IchaTaunt_DPS and IchaTaunt_DPS.config.windowSize or 5
        local newVal = math.min(15, cur + 1)
        if IchaTaunt_DPS then
            IchaTaunt_DPS:SetWindowSize(newVal)
        end
        if f.windowValue then
            f.windowValue:SetText(newVal .. "s")
        end
    end)

    -- NET mode checkbox (show HTPS when healing wins, DTPS when damage wins)
    yOffset = yOffset - 24
    local netCheck = CreateFrame("CheckButton", "IchaTauntNetModeCheck", f, "UICheckButtonTemplate")
    netCheck:SetWidth(20)
    netCheck:SetHeight(20)
    netCheck:SetPoint("TOPLEFT", f, "TOPLEFT", rightX, yOffset)
    local netEnabled = false
    if IchaTaunt_DPS and IchaTaunt_DPS.config then
        netEnabled = IchaTaunt_DPS.config.showNetDTPS
    end
    netCheck:SetChecked(netEnabled)
    netCheck:SetScript("OnClick", function()
        local enabled = this:GetChecked() == 1
        if IchaTaunt_DPS then
            IchaTaunt_DPS:SetNetMode(enabled)
        end
    end)
    f.netCheck = netCheck
    local netLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    netLabel:SetPoint("LEFT", netCheck, "RIGHT", 2, 0)
    netLabel:SetText("NET mode (HTPS vs DTPS)")

    f:Hide()
    self.optionsMenu = f
end

function IchaTaunt:RefreshLockUnlockButton()
    if not self.optionsMenu or not self.optionsMenu.lockUnlockBtn then return end
    local btn = self.optionsMenu.lockUnlockBtn
    if self.locked then
        btn:SetText("Unlock")
    else
        btn:SetText("Lock")
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
    if f.displaySection then
        f.displaySection:SetTextColor(unpack(c.titleColor))
    end
    if f.customSection then
        f.customSection:SetTextColor(unpack(c.titleColor))
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

    -- Update NET mode checkbox
    if f.netCheck and IchaTaunt_DPS then
        f.netCheck:SetChecked(IchaTaunt_DPS.config.showNetDTPS)
    end

    -- Update DTPS window value display
    if f.windowValue and IchaTaunt_DPS then
        local currentWindow = IchaTaunt_DPS.config.windowSize or 5
        f.windowValue:SetText(currentWindow .. "s")
    end

    -- Update cooldown only mode checkbox
    if f.cdOnlyCheck then
        f.cdOnlyCheck:SetChecked(IchaTauntDB.cooldownOnlyMode)
    end

    -- Update grow upward checkbox
    if f.growUpwardCheck then
        f.growUpwardCheck:SetChecked(IchaTauntDB.growUpward)
    end
end

-- ============================================
-- CUSTOM SPELLS EDITOR
-- ============================================

function IchaTaunt:ShowCustomSpellsMenu()
    print("IchaTaunt DEBUG: ShowCustomSpellsMenu called")
    if not self.customSpellsMenu then
        print("IchaTaunt DEBUG: Creating custom spells menu")
        self:CreateCustomSpellsMenu()
    end

    print("IchaTaunt DEBUG: Refreshing spell lists")
    self:RefreshAvailableSpellsList()
    self:RefreshCustomSpellsList()
    print("IchaTaunt DEBUG: Showing menu")
    self.customSpellsMenu:Show()
end

function IchaTaunt:CreateCustomSpellsMenu()
    local theme = self:GetTheme()
    local c = theme.config

    local f = CreateFrame("Frame", "IchaTauntCustomSpellsMenu", UIParent)
    f:SetWidth(700)  -- v2.0: wider to fit all class buttons
    f:SetHeight(480)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(15)

    -- Apply theme backdrop with increased opacity for better readability
    f:SetBackdrop(c.backdrop)
    local r, g, b, a = unpack(c.bgColor)
    f:SetBackdropColor(r, g, b, math.max(a or 0.9, 0.9))  -- Minimum 90% opacity

    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

    -- Center on screen
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -12)
    title:SetText("Spell Picker")
    title:SetTextColor(unpack(c.titleColor))
    f.title = title

    -- Close X - game-style red button
    local closeX = CreateCloseButton(f, function() f:Hide() end)
    closeX:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

    -- Class selection buttons at top
    local classLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    classLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -40)
    classLabel:SetText("Select Class:")
    classLabel:SetTextColor(unpack(c.titleColor))

    local classButtons = {}
    -- v2.0: All classes with trackable spells
    local classes = {"WARRIOR", "DRUID", "PALADIN", "SHAMAN", "HUNTER", "ROGUE", "PRIEST", "MAGE", "WARLOCK"}
    local classNames = {
        WARRIOR = "War", DRUID = "Dru", PALADIN = "Pal", SHAMAN = "Sha",
        HUNTER = "Hun", ROGUE = "Rog", PRIEST = "Pri", MAGE = "Mag", WARLOCK = "Lock"
    }
    local classColors = {
        WARRIOR = {0.78, 0.61, 0.43},
        DRUID = {1.0, 0.49, 0.04},
        PALADIN = {0.96, 0.55, 0.73},
        SHAMAN = {0.0, 0.44, 0.87},
        HUNTER = {0.67, 0.83, 0.45},
        ROGUE = {1.0, 0.96, 0.41},
        PRIEST = {1.0, 1.0, 1.0},
        MAGE = {0.41, 0.80, 0.94},
        WARLOCK = {0.58, 0.51, 0.79},
    }
    f.selectedClass = "WARRIOR"

    for i, class in ipairs(classes) do
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetWidth(50)
        btn:SetHeight(22)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", 100 + ((i-1) * 55), -36)
        btn:SetText(classNames[class])

        local capturedClass = class
        btn:SetScript("OnClick", function()
            f.selectedClass = capturedClass
            -- Update button highlights
            for cls, b in pairs(classButtons) do
                if cls == f.selectedClass then
                    b:GetFontString():SetTextColor(unpack(classColors[cls]))
                else
                    b:GetFontString():SetTextColor(1, 1, 1)
                end
            end
            -- Refresh available spells list
            IchaTaunt:RefreshAvailableSpellsList()
        end)

        classButtons[class] = btn
    end
    f.classButtons = classButtons
    classButtons["WARRIOR"]:GetFontString():SetTextColor(unpack(classColors["WARRIOR"]))

    -- === LEFT PANEL: Available Spells ===
    local leftLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leftLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -70)
    leftLabel:SetText("Available Spells")
    leftLabel:SetTextColor(unpack(c.titleColor))

    local leftScrollFrame = CreateFrame("ScrollFrame", "IchaTauntAvailableSpellsScroll", f, "UIPanelScrollFrameTemplate")
    leftScrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -90)
    leftScrollFrame:SetWidth(240)
    leftScrollFrame:SetHeight(340)

    local leftScrollChild = CreateFrame("Frame", nil, leftScrollFrame)
    leftScrollChild:SetWidth(220)
    leftScrollChild:SetHeight(1)
    leftScrollFrame:SetScrollChild(leftScrollChild)
    f.leftScrollChild = leftScrollChild
    f.availableSpellRows = {}

    -- === CENTER: Add/Remove Buttons with Cooldown Override ===

    -- Cooldown Override (above Add button for visibility)
    local cdLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cdLabel:SetPoint("TOP", f, "TOP", 0, -140)
    cdLabel:SetText("CD Override:")
    cdLabel:SetTextColor(1, 0.82, 0) -- Gold for visibility

    local cdInput = CreateFrame("EditBox", "IchaTauntSpellCDInput", f, "InputBoxTemplate")
    cdInput:SetWidth(50)
    cdInput:SetHeight(18)
    cdInput:SetPoint("TOP", f, "TOP", 0, -155)
    cdInput:SetAutoFocus(false)
    cdInput:SetMaxLetters(5)
    cdInput:SetNumeric(true)
    cdInput:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText("Cooldown Override")
        GameTooltip:AddLine("Enter custom cooldown in seconds", 1, 1, 1)
        GameTooltip:AddLine("Use for talents that reduce CDs", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Leave blank for default", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    cdInput:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.cdInput = cdInput

    local addBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    addBtn:SetWidth(50)
    addBtn:SetHeight(26)
    addBtn:SetPoint("TOP", f, "TOP", 0, -180)
    addBtn:SetText("Add >>")
    addBtn:Show()  -- Explicitly show the button
    print("IchaTaunt DEBUG: Add button created")
    addBtn:SetScript("OnClick", function()
        print("IchaTaunt DEBUG: Add button clicked")
        if f.selectedAvailableSpell then
            print("IchaTaunt DEBUG: Spell selected - " .. tostring(f.selectedAvailableSpell.name))
            IchaTaunt:AddSpellFromPicker(f.selectedAvailableSpell)
        else
            print("IchaTaunt DEBUG: No spell selected! Click a spell first.")
        end
    end)
    addBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText("Add Spell")
        GameTooltip:AddLine("Add selected spell to your tracker", 1, 1, 1)
        if f.cdInput and f.cdInput:GetText() ~= "" then
            GameTooltip:AddLine("Using override: " .. f.cdInput:GetText() .. "s", 0, 1, 0)
        end
        GameTooltip:Show()
    end)
    addBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local removeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    removeBtn:SetWidth(50)
    removeBtn:SetHeight(26)
    removeBtn:SetPoint("TOP", f, "TOP", 0, -210)
    removeBtn:SetText("<< Rem")
    removeBtn:SetScript("OnClick", function()
        if f.selectedTrackedSpell then
            IchaTaunt:RemoveCustomSpell(f.selectedTrackedSpell)
            IchaTaunt:RefreshCustomSpellsList()
            f.selectedTrackedSpell = nil
        end
    end)
    removeBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText("Remove Spell")
        GameTooltip:AddLine("Remove selected spell from tracker", 1, 1, 1)
        GameTooltip:Show()
    end)
    removeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- === RIGHT PANEL: Tracked Spells ===
    local rightLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rightLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 425, -70)
    rightLabel:SetText("Your Tracked Spells")
    rightLabel:SetTextColor(unpack(c.titleColor))

    local rightScrollFrame = CreateFrame("ScrollFrame", "IchaTauntTrackedSpellsScroll", f, "UIPanelScrollFrameTemplate")
    rightScrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 425, -90)
    rightScrollFrame:SetWidth(260)
    rightScrollFrame:SetHeight(340)

    local rightScrollChild = CreateFrame("Frame", nil, rightScrollFrame)
    rightScrollChild:SetWidth(240)
    rightScrollChild:SetHeight(1)
    rightScrollFrame:SetScrollChild(rightScrollChild)
    f.rightScrollChild = rightScrollChild
    f.trackedSpellRows = {}

    -- Hint text at very bottom
    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("BOTTOM", f, "BOTTOM", 0, 15)
    hint:SetText("Select a spell, optionally set a CD override, then click Add.")
    hint:SetTextColor(0.7, 0.7, 0.7)

    f:Hide()
    self.customSpellsMenu = f
end

-- Add spell from the picker UI
function IchaTaunt:AddSpellFromPicker(spellData)
    if not spellData then
        print("IchaTaunt DEBUG: No spell selected")
        return
    end

    local menu = self.customSpellsMenu
    local cooldownOverride = nil
    if menu and menu.cdInput then
        local cdText = menu.cdInput:GetText()
        if cdText and cdText ~= "" then
            cooldownOverride = tonumber(cdText)
        end
    end

    local cooldown = cooldownOverride or spellData.cooldown
    local class = menu and menu.selectedClass or "WARRIOR"
    local icon = spellData.icon  -- Get icon from spell data

    if IchaTauntDB.debugMode then
        print("IchaTaunt DEBUG: Adding spell - Name: " .. tostring(spellData.name) .. ", ID: " .. tostring(spellData.id) .. ", CD: " .. tostring(cooldown) .. ", Class: " .. tostring(class))
    end

    local success, err = pcall(function()
        self:AddCustomSpell(spellData.name, cooldown, class, spellData.id, icon)
    end)

    if not success then
        print("IchaTaunt ERROR: Failed to add spell - " .. tostring(err))
        return
    end

    self:RefreshCustomSpellsList()
    self:RefreshAvailableSpellsList()

    -- Clear cooldown override input
    if menu and menu.cdInput then
        menu.cdInput:SetText("")
    end
end

-- Refresh the available spells list (left panel)
function IchaTaunt:RefreshAvailableSpellsList()
    print("IchaTaunt DEBUG: RefreshAvailableSpellsList called")
    local f = self.customSpellsMenu
    if not f or not f.leftScrollChild then
        print("IchaTaunt DEBUG: ERROR - Menu or leftScrollChild not found")
        return
    end

    -- Clear existing rows
    for _, row in ipairs(f.availableSpellRows or {}) do
        row:Hide()
        row:SetParent(nil)
    end
    f.availableSpellRows = {}

    local class = f.selectedClass or "WARRIOR"
    print("IchaTaunt DEBUG: Refreshing spells for class: " .. class)

    -- Safety check for trackable spells database
    if not IchaTaunt_GetTrackableSpells then
        local noData = f.leftScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        noData:SetPoint("TOPLEFT", f.leftScrollChild, "TOPLEFT", 5, -10)
        noData:SetText("Spell database not loaded.\nReload UI to fix.")
        noData:SetTextColor(1, 0.5, 0.5)
        local emptyRow = CreateFrame("Frame", nil, f.leftScrollChild)
        emptyRow.text = noData
        table.insert(f.availableSpellRows, emptyRow)
        return
    end

    local spells = IchaTaunt_GetTrackableSpells(class)

    -- Get list of already tracked spells to gray them out
    local trackedIDs = {}
    if IchaTauntDB.customSpells then
        for id, _ in pairs(IchaTauntDB.customSpells) do
            trackedIDs[id] = true
        end
        if IchaTauntDB.debugMode then
            print("IchaTaunt DEBUG: Tracked spell IDs:")
            for id, _ in pairs(trackedIDs) do
                print("  - ID: " .. tostring(id))
            end
        end
    end

    local yOffset = 0
    local lastCategory = nil

    for _, spell in ipairs(spells) do
        -- Add category header if changed
        if spell.category ~= lastCategory then
            lastCategory = spell.category
            local header = CreateFrame("Frame", nil, f.leftScrollChild)
            header:SetWidth(220)
            header:SetHeight(18)
            header:SetPoint("TOPLEFT", f.leftScrollChild, "TOPLEFT", 0, yOffset)

            local headerText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            headerText:SetPoint("LEFT", header, "LEFT", 5, 0)
            headerText:SetText("-- " .. spell.category .. " --")
            headerText:SetTextColor(1, 0.82, 0)

            table.insert(f.availableSpellRows, header)
            yOffset = yOffset - 18
        end

        local isTracked = trackedIDs[spell.id]

        local row = CreateFrame("Button", nil, f.leftScrollChild)
        row:SetWidth(220)
        row:SetHeight(24)
        row:SetPoint("TOPLEFT", f.leftScrollChild, "TOPLEFT", 0, yOffset)

        -- Highlight on hover
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

        -- Icon
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(20)
        icon:SetHeight(20)
        icon:SetPoint("LEFT", row, "LEFT", 5, 0)
        icon:SetTexture(spell.icon)
        if isTracked then
            icon:SetVertexColor(0.5, 0.5, 0.5)
        end

        -- Name
        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameText:SetPoint("LEFT", row, "LEFT", 30, 0)
        nameText:SetWidth(130)
        nameText:SetJustifyH("LEFT")
        nameText:SetText(spell.name)
        if isTracked then
            nameText:SetTextColor(0.5, 0.5, 0.5)
        end

        -- Cooldown
        local cdText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cdText:SetPoint("RIGHT", row, "RIGHT", -5, 0)
        cdText:SetText(IchaTaunt_FormatCooldown(spell.cooldown))
        if isTracked then
            cdText:SetTextColor(0.5, 0.5, 0.5)
        else
            cdText:SetTextColor(0.7, 0.7, 0.7)
        end

        -- Click to select
        local capturedSpell = spell
        local capturedIsTracked = isTracked  -- Capture the value at creation time
        row:SetScript("OnClick", function()
            print("IchaTaunt DEBUG: Clicked spell - " .. tostring(capturedSpell.name) .. ", isTracked: " .. tostring(capturedIsTracked) .. ", ID: " .. tostring(capturedSpell.id))
            if not capturedIsTracked then
                f.selectedAvailableSpell = capturedSpell
                print("IchaTaunt DEBUG: Spell selected successfully")
                -- Update visual selection
                for _, r in ipairs(f.availableSpellRows) do
                    if r.selected then
                        r.selected:Hide()
                    end
                end
                if not row.selected then
                    row.selected = row:CreateTexture(nil, "BACKGROUND")
                    row.selected:SetAllPoints()
                    row.selected:SetTexture(1, 1, 1, 0.2)
                end
                row.selected:Show()
                -- Pre-fill cooldown
                if f.cdInput then
                    f.cdInput:SetText("")
                end
            else
                print("IchaTaunt DEBUG: Spell is already tracked, cannot select")
            end
        end)

        -- Tooltip on hover
        row:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText(spell.name)
            GameTooltip:AddLine("Cooldown: " .. spell.cooldown .. " seconds", 1, 1, 1)
            GameTooltip:AddLine("Category: " .. spell.category, 0.7, 0.7, 0.7)
            if isTracked then
                GameTooltip:AddLine("Already tracked", 1, 0.5, 0.5)
            else
                GameTooltip:AddLine("Click to select, then >> to add", 0.5, 1, 0.5)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        table.insert(f.availableSpellRows, row)
        yOffset = yOffset - 24
    end

    f.leftScrollChild:SetHeight(math.abs(yOffset) + 10)
end

-- Known spell database for cross-class icon lookups
-- This allows looking up spell icons for other classes' abilities
IchaTaunt_KnownSpells = {
    -- Warrior Taunts (from IchaTaunt_SpellData)
    [355] = { name = "Taunt", icon = "Interface\\Icons\\Spell_Nature_Reincarnation" },
    [694] = { name = "Mocking Blow", icon = "Interface\\Icons\\Ability_Warrior_PunishingBlow" },
    [1161] = { name = "Challenging Shout", icon = "Interface\\Icons\\ability_bullrush" },

    -- Druid Taunts
    [6795] = { name = "Growl", icon = "Interface\\Icons\\Ability_Physical_Taunt" },
    [5209] = { name = "Challenging Roar", icon = "Interface\\Icons\\Ability_Druid_ChallangingRoar" },

    -- Shaman Taunts (Turtle WoW)
    [51365] = { name = "Earthshaker Slam", icon = "Interface\\Icons\\earthshaker_slam_11" },

    -- Paladin Taunts (Turtle WoW)
    [51302] = { name = "Hand of Reckoning", icon = "Interface\\Icons\\Spell_Holy_Redemption" },

    -- Common defensive cooldowns that might be tracked
    [871] = { name = "Shield Wall", icon = "Interface\\Icons\\Ability_Warrior_ShieldWall" },
    [12975] = { name = "Last Stand", icon = "Interface\\Icons\\Spell_Holy_AshesToAshes" },
    [498] = { name = "Divine Protection", icon = "Interface\\Icons\\Spell_Holy_Restoration" },
    [642] = { name = "Divine Shield", icon = "Interface\\Icons\\Spell_Holy_DivineIntervention" },
    [1022] = { name = "Blessing of Protection", icon = "Interface\\Icons\\Spell_Holy_SealOfProtection" },
    [22812] = { name = "Barkskin", icon = "Interface\\Icons\\Spell_Nature_StoneClawTotem" },
    [61336] = { name = "Survival Instincts", icon = "Interface\\Icons\\Ability_Druid_SurvivalInstincts" },
    [16188] = { name = "Nature's Swiftness", icon = "Interface\\Icons\\Spell_Nature_RavenForm" },
    [20925] = { name = "Holy Shield", icon = "Interface\\Icons\\Spell_Holy_BlessingOfProtection" },

    -- Common utility abilities
    [2565] = { name = "Shield Block", icon = "Interface\\Icons\\Ability_Defend" },
    [6572] = { name = "Revenge", icon = "Interface\\Icons\\Ability_Warrior_Revenge" },
    [20243] = { name = "Devastate", icon = "Interface\\Icons\\Inv_Sword_11" },
    [6807] = { name = "Maul", icon = "Interface\\Icons\\Ability_Druid_Maul" },
    [779] = { name = "Swipe", icon = "Interface\\Icons\\Inv_Misc_MonsterClaw_04" },
    [9490] = { name = "Demoralizing Shout", icon = "Interface\\Icons\\Ability_Warrior_WarCry" },
    [99] = { name = "Demoralizing Roar", icon = "Interface\\Icons\\Ability_Druid_DemoralizingRoar" },
    [6343] = { name = "Thunder Clap", icon = "Interface\\Icons\\Spell_Nature_ThunderClap" },

    -- Shaman Shocks (all ranks)
    [8042] = { name = "Earth Shock", icon = "Interface\\Icons\\Spell_Nature_EarthShock" },
    [8044] = { name = "Earth Shock", icon = "Interface\\Icons\\Spell_Nature_EarthShock" },
    [8045] = { name = "Earth Shock", icon = "Interface\\Icons\\Spell_Nature_EarthShock" },
    [8046] = { name = "Earth Shock", icon = "Interface\\Icons\\Spell_Nature_EarthShock" },
    [10412] = { name = "Earth Shock", icon = "Interface\\Icons\\Spell_Nature_EarthShock" },
    [10413] = { name = "Earth Shock", icon = "Interface\\Icons\\Spell_Nature_EarthShock" },
    [10414] = { name = "Earth Shock", icon = "Interface\\Icons\\Spell_Nature_EarthShock" },
    [8056] = { name = "Frost Shock", icon = "Interface\\Icons\\Spell_Frost_FrostShock" },
    [8058] = { name = "Frost Shock", icon = "Interface\\Icons\\Spell_Frost_FrostShock" },
    [10472] = { name = "Frost Shock", icon = "Interface\\Icons\\Spell_Frost_FrostShock" },
    [10473] = { name = "Frost Shock", icon = "Interface\\Icons\\Spell_Frost_FrostShock" },
    [8050] = { name = "Flame Shock", icon = "Interface\\Icons\\Spell_Fire_FlameShock" },
    [8052] = { name = "Flame Shock", icon = "Interface\\Icons\\Spell_Fire_FlameShock" },
    [8053] = { name = "Flame Shock", icon = "Interface\\Icons\\Spell_Fire_FlameShock" },
    [10447] = { name = "Flame Shock", icon = "Interface\\Icons\\Spell_Fire_FlameShock" },
    [10448] = { name = "Flame Shock", icon = "Interface\\Icons\\Spell_Fire_FlameShock" },
    [29228] = { name = "Flame Shock", icon = "Interface\\Icons\\Spell_Fire_FlameShock" },

    -- Shaman Totems and abilities
    [8177] = { name = "Grounding Totem", icon = "Interface\\Icons\\Spell_Nature_GroundingTotem" },
    [8143] = { name = "Tremor Totem", icon = "Interface\\Icons\\Spell_Nature_TremorTotem" },
    [5394] = { name = "Healing Stream Totem", icon = "Interface\\Icons\\INV_Spear_04" },
    [8184] = { name = "Fire Resistance Totem", icon = "Interface\\Icons\\Spell_FireResistanceTotem_01" },
    [8181] = { name = "Frost Resistance Totem", icon = "Interface\\Icons\\Spell_FrostResistanceTotem_01" },
    [10595] = { name = "Nature Resistance Totem", icon = "Interface\\Icons\\Spell_Nature_NatureResistanceTotem" },

    -- Paladin abilities
    [20271] = { name = "Judgement", icon = "Interface\\Icons\\Spell_Holy_RighteousFury" },
    [879] = { name = "Exorcism", icon = "Interface\\Icons\\Spell_Holy_Excorcism_02" },
    [24275] = { name = "Hammer of Wrath", icon = "Interface\\Icons\\Ability_ThunderClap" },
    [853] = { name = "Hammer of Justice", icon = "Interface\\Icons\\Spell_Holy_SealOfMight" },
    [26573] = { name = "Consecration", icon = "Interface\\Icons\\Spell_Holy_InnerFire" },
    [19752] = { name = "Divine Intervention", icon = "Interface\\Icons\\Spell_Nature_TimeStop" },
    [633] = { name = "Lay on Hands", icon = "Interface\\Icons\\Spell_Holy_LayOnHands" },

    -- Druid abilities
    [5211] = { name = "Bash", icon = "Interface\\Icons\\Ability_Druid_Bash" },
    [8983] = { name = "Bash", icon = "Interface\\Icons\\Ability_Druid_Bash" },
    [9005] = { name = "Pounce", icon = "Interface\\Icons\\Ability_Druid_SupriseAttack" },
    [22570] = { name = "Maim", icon = "Interface\\Icons\\Ability_Druid_Mangle" },
    [16979] = { name = "Feral Charge", icon = "Interface\\Icons\\Ability_Hunter_Pet_Bear" },
    [17116] = { name = "Nature's Swiftness", icon = "Interface\\Icons\\Spell_Nature_RavenForm" },
    [29166] = { name = "Innervate", icon = "Interface\\Icons\\Spell_Nature_Lightning" },
    [20484] = { name = "Rebirth", icon = "Interface\\Icons\\Spell_Nature_Reincarnation" },

    -- Warrior abilities
    [100] = { name = "Charge", icon = "Interface\\Icons\\Ability_Warrior_Charge" },
    [6552] = { name = "Pummel", icon = "Interface\\Icons\\INV_Gauntlets_04" },
    [72] = { name = "Shield Bash", icon = "Interface\\Icons\\Ability_Warrior_ShieldBash" },
    [20252] = { name = "Intercept", icon = "Interface\\Icons\\Ability_Rogue_Sprint" },
    [676] = { name = "Disarm", icon = "Interface\\Icons\\Ability_Warrior_Disarm" },
    [5246] = { name = "Intimidating Shout", icon = "Interface\\Icons\\Ability_GolemThunderClap" },
    [1719] = { name = "Recklessness", icon = "Interface\\Icons\\Ability_CriticalStrike" },
    [18499] = { name = "Berserker Rage", icon = "Interface\\Icons\\Spell_Nature_AncestralGuardian" },
    [12292] = { name = "Death Wish", icon = "Interface\\Icons\\Spell_Shadow_DeathPact" },

    -- Turtle WoW specific abilities
    [51399] = { name = "Stone Form", icon = "Interface\\Icons\\Spell_Shadow_UnholyStrength" },
    [51398] = { name = "Consecration", icon = "Interface\\Icons\\Spell_Holy_InnerFire" },
}

-- Get spell info by ID (1.12 compatible)
-- Uses the comprehensive spell database for cross-class lookups
function IchaTaunt:GetSpellInfo(spellID)
    if not spellID or spellID <= 0 then return nil, nil, nil end

    -- Method 1: Check the comprehensive spell database (IchaTaunt_SpellDB)
    -- Contains ALL Shaman, Warrior, Druid, and Paladin spells from Turtle WoW
    if IchaTaunt_SpellDB and IchaTaunt_SpellDB[spellID] then
        local data = IchaTaunt_SpellDB[spellID]
        return data.name, nil, data.icon
    end

    -- Method 2: Check our built-in known spell database
    if IchaTaunt_KnownSpells and IchaTaunt_KnownSpells[spellID] then
        local data = IchaTaunt_KnownSpells[spellID]
        return data.name, nil, data.icon
    end

    -- Method 3: Check built-in IchaTaunt_SpellData (taunts)
    if IchaTaunt_SpellData and IchaTaunt_SpellData[spellID] then
        local data = IchaTaunt_SpellData[spellID]
        return data.name, nil, data.icon
    end

    -- Method 4: Try tooltip hyperlink scanning (fallback)
    local tooltipName = "IchaTauntSpellTooltip"
    local tooltip = getglobal(tooltipName)
    if not tooltip then
        tooltip = CreateFrame("GameTooltip", tooltipName, UIParent, "GameTooltipTemplate")
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
        tooltip:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    end

    tooltip:ClearLines()
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")

    local spellName = nil
    local success = pcall(function()
        tooltip:SetHyperlink("spell:" .. spellID)
    end)
    if success then
        local line1 = getglobal(tooltipName .. "TextLeft1")
        if line1 then
            spellName = line1:GetText()
        end
    end

    if not spellName or spellName == "" then
        return nil, nil, nil
    end

    -- Got a name from tooltip, try to find icon in spellbook
    local icon = nil
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(tab)
        for i = offset + 1, offset + numSpells do
            local name = GetSpellName(i, BOOKTYPE_SPELL)
            if name == spellName then
                icon = GetSpellTexture(i, BOOKTYPE_SPELL)
                break
            end
        end
        if icon then break end
    end

    -- Fallback to question mark
    if not icon then
        icon = "Interface\\Icons\\INV_Misc_QuestionMark"
    end

    return spellName, nil, icon
end

-- Try to get spell icon directly by ID using various methods
function IchaTaunt:GetSpellIcon(spellID)
    if not spellID or spellID <= 0 then
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end

    -- First, try known spell database (cross-class support)
    if IchaTaunt_KnownSpells[spellID] then
        return IchaTaunt_KnownSpells[spellID].icon
    end

    -- Then try built-in spell data
    if IchaTaunt_SpellData[spellID] then
        return IchaTaunt_SpellData[spellID].icon
    end

    -- Try GetSpellInfo method
    local name, _, icon = self:GetSpellInfo(spellID)
    if icon and icon ~= "Interface\\Icons\\INV_Misc_QuestionMark" then
        return icon
    end

    -- For many Turtle WoW / 1.12 servers, spell textures follow patterns
    -- If nothing else works, return question mark
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Comprehensive spell icon finder - tries multiple methods
-- Works for cross-class spells using the comprehensive spell database
function IchaTaunt:FindSpellIcon(spellName, spellID)
    local icon = nil

    -- Method 1: Check comprehensive spell database by ID (ALL class spells)
    if spellID and spellID > 0 then
        if IchaTaunt_SpellDB and IchaTaunt_SpellDB[spellID] then
            return IchaTaunt_SpellDB[spellID].icon
        end
        if IchaTaunt_KnownSpells and IchaTaunt_KnownSpells[spellID] then
            return IchaTaunt_KnownSpells[spellID].icon
        end
        if IchaTaunt_SpellData and IchaTaunt_SpellData[spellID] then
            return IchaTaunt_SpellData[spellID].icon
        end
    end

    -- Method 2: Search player's own spellbook by name (works for your own class)
    if spellName then
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, numSpells = GetSpellTabInfo(tab)
            for i = offset + 1, offset + numSpells do
                local name = GetSpellName(i, BOOKTYPE_SPELL)
                if name and strlower(name) == strlower(spellName) then
                    local tex = GetSpellTexture(i, BOOKTYPE_SPELL)
                    if tex then
                        return tex
                    end
                end
            end
        end

        -- Method 3: Check comprehensive spell database by NAME (cross-class support)
        if IchaTaunt_SpellDB then
            for id, data in pairs(IchaTaunt_SpellDB) do
                if strlower(data.name) == strlower(spellName) then
                    return data.icon
                end
            end
        end

        -- Method 4: Check known spell database by NAME
        if IchaTaunt_KnownSpells then
            for id, data in pairs(IchaTaunt_KnownSpells) do
                if strlower(data.name) == strlower(spellName) then
                    return data.icon
                end
            end
        end

        -- Method 5: Check built-in spell data by name
        for id, data in pairs(IchaTaunt_SpellData) do
            if strlower(data.name) == strlower(spellName) then
                return data.icon
            end
        end

        -- Method 6: Try partial name match in comprehensive database
        if IchaTaunt_SpellDB then
            for id, data in pairs(IchaTaunt_SpellDB) do
                if strfind(strlower(spellName), strlower(data.name)) or strfind(strlower(data.name), strlower(spellName)) then
                    return data.icon
                end
            end
        end

        -- Method 7: Try partial name match in built-in spells
        for id, data in pairs(IchaTaunt_SpellData) do
            if strfind(strlower(spellName), strlower(data.name)) or strfind(strlower(data.name), strlower(spellName)) then
                return data.icon
            end
        end

        -- Method 7: Try using GetSpellTexture with spell name directly
        -- (works for some spells on some servers)
        if GetSpellTexture then
            local success, directIcon = pcall(GetSpellTexture, spellName)
            if success and directIcon then
                return directIcon
            end
        end

        -- Method 8: Create a temporary action button to try getting the icon
        -- This is a last resort method that works on many private servers
        if not icon then
            local tempBtn = getglobal("IchaTauntTempActionBtn")
            if not tempBtn then
                tempBtn = CreateFrame("Button", "IchaTauntTempActionBtn", UIParent, "ActionButtonTemplate")
                tempBtn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, -100)
                tempBtn:Hide()
            end

            -- Try to pick up the spell by name
            local success, err = pcall(PickupSpellByName, spellName)

            if success and CursorHasSpell() then
                -- Get cursor icon
                local cursorIcon = GetCursorInfo and GetCursorInfo()
                ClearCursor()
                if cursorIcon then
                    return cursorIcon
                end
            end
            ClearCursor()
        end
    end

    -- Fallback: return a generic ability icon instead of question mark
    -- This looks better than a question mark
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function IchaTaunt:AddCustomSpell(name, cooldown, class, spellID, iconOverride)
    if not IchaTauntDB.customSpells then
        IchaTauntDB.customSpells = {}
    end

    -- Check if spell is already tracked by ID
    if spellID and IchaTauntDB.customSpells[spellID] then
        print("IchaTaunt: '" .. name .. "' is already being tracked")
        return
    end

    -- Check if spell is already tracked by name (for spells without valid IDs)
    for id, data in pairs(IchaTauntDB.customSpells) do
        if data.name == name then
            print("IchaTaunt: '" .. name .. "' is already being tracked")
            return
        end
    end

    -- Use provided spell ID if valid, otherwise generate a negative ID
    local customID
    if spellID and spellID > 0 then
        customID = spellID
    else
        -- Generate a unique negative ID to avoid conflicts with real spell IDs
        customID = -1
        for id, _ in pairs(IchaTauntDB.customSpells) do
            if id <= customID then
                customID = id - 1
            end
        end
    end

    -- Use provided icon or try to find it
    local icon = iconOverride or self:FindSpellIcon(name, spellID)

    IchaTauntDB.customSpells[customID] = {
        name = name,
        cooldown = cooldown,
        icon = icon,
        classes = { class },
        description = "Custom tracked spell",
        isCustom = true,
        originalSpellID = spellID, -- Store original ID for reference
    }

    print("IchaTaunt: Added custom spell '" .. name .. "' (" .. cooldown .. "s cooldown) for " .. class .. (spellID and (" [ID: " .. spellID .. "]") or ""))

    if IchaTauntDB.debugMode then
        print("IchaTaunt DEBUG: Spell added to customSpells[" .. customID .. "]")
        print("IchaTaunt DEBUG: Total custom spells: " .. (IchaTauntDB.customSpells and self:CountTable(IchaTauntDB.customSpells) or 0))
    end

    -- Rebuild tracker to include new spell
    self:RebuildList()
end

function IchaTaunt:CountTable(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

function IchaTaunt:RemoveCustomSpell(spellID)
    if IchaTauntDB.customSpells and IchaTauntDB.customSpells[spellID] then
        local name = IchaTauntDB.customSpells[spellID].name
        IchaTauntDB.customSpells[spellID] = nil
        print("IchaTaunt: Removed custom spell '" .. name .. "'")

        -- Rebuild tracker
        self:RebuildList()
    end
end

function IchaTaunt:RefreshCustomSpellsList()
    local f = self.customSpellsMenu
    if not f or not f.rightScrollChild then return end

    local scrollChild = f.rightScrollChild

    -- Clear existing rows
    for _, row in ipairs(f.trackedSpellRows or {}) do
        row:Hide()
        row:SetParent(nil)
    end
    f.trackedSpellRows = {}

    -- Populate with custom spells
    local yOffset = 0
    local customSpells = IchaTauntDB.customSpells or {}

    for spellID, spellData in pairs(customSpells) do
        local row = CreateFrame("Button", nil, scrollChild)
        row:SetWidth(240)
        row:SetHeight(26)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)

        -- Highlight on hover
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

        -- Spell icon
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(22)
        icon:SetHeight(22)
        icon:SetPoint("LEFT", row, "LEFT", 5, 0)
        icon:SetTexture(spellData.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

        -- Spell name
        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameText:SetPoint("LEFT", row, "LEFT", 32, 0)
        nameText:SetWidth(100)
        nameText:SetJustifyH("LEFT")
        nameText:SetText(spellData.name)

        -- Cooldown (format nicely)
        local cdText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cdText:SetPoint("LEFT", row, "LEFT", 135, 0)
        local cdDisplay = spellData.cooldown
        if cdDisplay >= 3600 then
            cdDisplay = format("%dh", cdDisplay / 3600)
        elseif cdDisplay >= 60 then
            cdDisplay = format("%dm", cdDisplay / 60)
        else
            cdDisplay = cdDisplay .. "s"
        end
        cdText:SetText(cdDisplay)
        cdText:SetTextColor(0.7, 0.7, 0.7)

        -- Class
        local classText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        classText:SetPoint("LEFT", row, "LEFT", 175, 0)
        local classAbbrev = {
            WARRIOR = "War",
            DRUID = "Dru",
            PALADIN = "Pal",
            SHAMAN = "Sha",
            HUNTER = "Hun",
            ROGUE = "Rog",
            PRIEST = "Pri",
            MAGE = "Mag",
            WARLOCK = "Wlk",
        }
        local classColors = {
            WARRIOR = {0.78, 0.61, 0.43},
            DRUID = {1.0, 0.49, 0.04},
            PALADIN = {0.96, 0.55, 0.73},
            SHAMAN = {0.0, 0.44, 0.87},
            HUNTER = {0.67, 0.83, 0.45},
            ROGUE = {1.0, 0.96, 0.41},
            PRIEST = {1.0, 1.0, 1.0},
            MAGE = {0.41, 0.8, 0.94},
            WARLOCK = {0.58, 0.51, 0.79},
        }
        local classKey = spellData.classes and spellData.classes[1] or "ALL"
        classText:SetText(classAbbrev[classKey] or classKey)
        if classColors[classKey] then
            classText:SetTextColor(unpack(classColors[classKey]))
        end

        -- Delete button (X)
        local deleteBtn = CreateFrame("Button", nil, row)
        deleteBtn:SetWidth(18)
        deleteBtn:SetHeight(18)
        deleteBtn:SetPoint("RIGHT", row, "RIGHT", -5, 0)
        local deleteBtnText = deleteBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        deleteBtnText:SetPoint("CENTER", deleteBtn, "CENTER", 0, 0)
        deleteBtnText:SetText("X")
        deleteBtnText:SetTextColor(1, 0.3, 0.3)
        deleteBtn:SetScript("OnEnter", function()
            deleteBtnText:SetTextColor(1, 0.6, 0.6)
            GameTooltip:SetOwner(this, "ANCHOR_TOP")
            GameTooltip:SetText("Remove Spell")
            GameTooltip:Show()
        end)
        deleteBtn:SetScript("OnLeave", function()
            deleteBtnText:SetTextColor(1, 0.3, 0.3)
            GameTooltip:Hide()
        end)

        local capturedID = spellID
        deleteBtn:SetScript("OnClick", function()
            IchaTaunt:RemoveCustomSpell(capturedID)
            IchaTaunt:RefreshCustomSpellsList()
            IchaTaunt:RefreshAvailableSpellsList()
        end)

        -- Click to select for removal
        row:SetScript("OnClick", function()
            f.selectedTrackedSpell = capturedID
            -- Update visual selection
            for _, r in ipairs(f.trackedSpellRows) do
                if r.selected then
                    r.selected:Hide()
                end
            end
            if not row.selected then
                row.selected = row:CreateTexture(nil, "BACKGROUND")
                row.selected:SetAllPoints()
                row.selected:SetTexture(1, 1, 1, 0.2)
            end
            row.selected:Show()
        end)

        -- Tooltip
        row:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText(spellData.name)
            GameTooltip:AddLine("Cooldown: " .. spellData.cooldown .. " seconds", 1, 1, 1)
            if spellID > 0 then
                GameTooltip:AddLine("Spell ID: " .. spellID, 0.7, 0.7, 0.7)
            end
            GameTooltip:AddLine("Click X or select and << to remove", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        table.insert(f.trackedSpellRows, row)
        yOffset = yOffset - 26
    end

    -- Adjust scroll child height
    local totalHeight = math.abs(yOffset) + 10
    if totalHeight < 200 then totalHeight = 200 end
    scrollChild:SetHeight(totalHeight)

    -- Show message if no custom spells
    if yOffset == 0 then
        local noSpells = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        noSpells:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 5, -10)
        noSpells:SetText("No custom spells yet.\nSelect from the left panel\nand click >> to add.")
        noSpells:SetTextColor(0.7, 0.7, 0.7)

        local emptyRow = CreateFrame("Frame", nil, scrollChild)
        emptyRow.text = noSpells
        table.insert(f.trackedSpellRows, emptyRow)
    end
end

SLASH_ICHATAUNT1 = "/ichataunt"
SLASH_ICHATAUNT2 = "/it"
SlashCmdList["ICHATAUNT"] = function(msg)
    local success, err = pcall(function()
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
        IchaTauntDB.stackPosition = {x = 0, y = 0}
        IchaTauntDB.position = {x = 0, y = 0}
        if IchaTaunt.categoryFrames then
            IchaTaunt:RepositionStack()
            print("IchaTaunt: Stack position reset to screen center")
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
    elseif msg == "debug" then
        DEFAULT_CHAT_FRAME:AddMessage("=== IchaTaunt Debug ===")
        if IchaTaunt_TrackableSpells then
            DEFAULT_CHAT_FRAME:AddMessage("TrackableSpells: LOADED")
        else
            DEFAULT_CHAT_FRAME:AddMessage("TrackableSpells: NOT LOADED - THIS IS THE PROBLEM")
        end
        if IchaTaunt_Categories then
            DEFAULT_CHAT_FRAME:AddMessage("Categories: LOADED")
        else
            DEFAULT_CHAT_FRAME:AddMessage("Categories: NOT LOADED")
        end

        -- Show tracked players
        DEFAULT_CHAT_FRAME:AddMessage("--- Tracked Players ---")
        if IchaTaunt.taunters then
            local count = 0
            for name, _ in pairs(IchaTaunt.taunters) do
                DEFAULT_CHAT_FRAME:AddMessage("  - " .. name)
                count = count + 1
            end
            if count == 0 then
                DEFAULT_CHAT_FRAME:AddMessage("  (none in self.taunters)")
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("  self.taunters is nil!")
        end

        -- Show category members
        if IchaTaunt_Categories and IchaTauntDB.categories then
            for _, cat in ipairs(IchaTaunt_Categories.CATEGORY_ORDER) do
                DEFAULT_CHAT_FRAME:AddMessage("--- Category: " .. cat .. " ---")
                if IchaTauntDB.categories[cat] and IchaTauntDB.categories[cat].members then
                    local count = 0
                    for name, _ in pairs(IchaTauntDB.categories[cat].members) do
                        DEFAULT_CHAT_FRAME:AddMessage("  - " .. name)
                        count = count + 1
                    end
                    if count == 0 then
                        DEFAULT_CHAT_FRAME:AddMessage("  (empty)")
                    end
                end
            end
        end

        -- Show custom spells
        DEFAULT_CHAT_FRAME:AddMessage("--- Custom Spells ---")
        if IchaTauntDB.customSpells then
            local count = 0
            for spellID, spellData in pairs(IchaTauntDB.customSpells) do
                DEFAULT_CHAT_FRAME:AddMessage("  [" .. spellID .. "] " .. spellData.name .. " (" .. spellData.cooldown .. "s CD) - " .. spellData.classes[1])
                count = count + 1
            end
            if count == 0 then
                DEFAULT_CHAT_FRAME:AddMessage("  (none)")
            else
                DEFAULT_CHAT_FRAME:AddMessage("  Total: " .. count .. " custom spells")
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("  customSpells table is nil!")
        end

        -- Show TrackableSpells classes
        DEFAULT_CHAT_FRAME:AddMessage("--- TrackableSpells Database ---")
        if IchaTaunt_TrackableSpells then
            for class, spells in pairs(IchaTaunt_TrackableSpells) do
                local count = 0
                for _ in pairs(spells) do count = count + 1 end
                DEFAULT_CHAT_FRAME:AddMessage("  " .. class .. ": " .. count .. " spells")
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("  NOT LOADED!")
        end

        DEFAULT_CHAT_FRAME:AddMessage("=== End Debug ===")
    elseif msg == "dumplog" then
        -- Show instructions for reading log from file
        DEFAULT_CHAT_FRAME:AddMessage("=== IchaTaunt Debug Log ===")
        if IchaTauntDB and IchaTauntDB.debugLog then
            local count = table.getn(IchaTauntDB.debugLog)
            DEFAULT_CHAT_FRAME:AddMessage("Debug log has " .. count .. " entries.")
            DEFAULT_CHAT_FRAME:AddMessage("To read the log:")
            DEFAULT_CHAT_FRAME:AddMessage("1. Type /logout to save the log to disk")
            DEFAULT_CHAT_FRAME:AddMessage("2. Open this file:")
            DEFAULT_CHAT_FRAME:AddMessage("   F:\\TurtleWoW\\WTF\\Account\\ORDINARYJOE\\SavedVariables\\ICHATAUNT.lua")
            DEFAULT_CHAT_FRAME:AddMessage("3. Look for the 'debugLog' section")
        else
            DEFAULT_CHAT_FRAME:AddMessage("Debug log not initialized. Enable debug mode first with: /ichataunt debugmode")
        end
        DEFAULT_CHAT_FRAME:AddMessage("=== End Instructions ===")
    elseif msg == "clearlog" then
        -- Clear debug log buffer
        if IchaTauntDB then
            IchaTauntDB.debugLog = {}
            DEFAULT_CHAT_FRAME:AddMessage("Debug log cleared. Use /logout to save changes.")
        end
    elseif msg == "clearall" then
        -- Clear ALL tracked members from taunters and categories
        DEFAULT_CHAT_FRAME:AddMessage("=== IchaTaunt: Clearing All Tracked Members ===")

        -- Perform the clear
        local taunterCount, categoryCount = IchaTaunt:ClearAllTrackedMembers()

        DEFAULT_CHAT_FRAME:AddMessage("Removed " .. taunterCount .. " players from taunters list")
        DEFAULT_CHAT_FRAME:AddMessage("Removed " .. categoryCount .. " players from categories")

        -- Set flag to block ADD sync messages for 10 seconds
        IchaTaunt.clearAllTime = GetTime()
        DEFAULT_CHAT_FRAME:AddMessage("Blocking incoming ADD sync messages for 10 seconds...")

        -- Broadcast to other users in raid/party
        local inGroup = GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
        if inGroup then
            IchaTaunt:SendSyncMessage("CLEARALL")
            DEFAULT_CHAT_FRAME:AddMessage("Broadcast sent to raid/party - all users will clear their lists.")
        end

        DEFAULT_CHAT_FRAME:AddMessage("All tracked members cleared. Use /logout to save changes.")
        DEFAULT_CHAT_FRAME:AddMessage("=== Clear Complete ===")
    elseif msg == "checkdb" then
        -- Simple check that always works
        DEFAULT_CHAT_FRAME:AddMessage("Checking databases...")
        DEFAULT_CHAT_FRAME:AddMessage("Type: " .. type(IchaTaunt_TrackableSpells))
        DEFAULT_CHAT_FRAME:AddMessage("Type: " .. type(IchaTaunt_Categories))
    elseif msg == "refresh" then
        -- Force refresh the config UI
        if IchaTaunt.taunterUI and IchaTaunt.taunterUI.RefreshPanels then
            DEFAULT_CHAT_FRAME:AddMessage("Forcing panel refresh...")
            IchaTaunt.taunterUI.RefreshPanels()
            DEFAULT_CHAT_FRAME:AddMessage("Refresh complete")
        else
            DEFAULT_CHAT_FRAME:AddMessage("Config UI not open or RefreshPanels not found")
        end
    elseif msg == "debugui" then
        -- Debug the UI state
        DEFAULT_CHAT_FRAME:AddMessage("=== UI Debug ===")
        if IchaTaunt.taunterUI then
            DEFAULT_CHAT_FRAME:AddMessage("taunterUI: EXISTS")
            DEFAULT_CHAT_FRAME:AddMessage("Is Visible: " .. tostring(IchaTaunt.taunterUI:IsVisible()))
            if IchaTaunt.taunterUI.leftScrollChild then
                DEFAULT_CHAT_FRAME:AddMessage("leftScrollChild: EXISTS")
            else
                DEFAULT_CHAT_FRAME:AddMessage("leftScrollChild: NIL")
            end
            if IchaTaunt.taunterUI.rightScrollChild then
                DEFAULT_CHAT_FRAME:AddMessage("rightScrollChild: EXISTS")
            else
                DEFAULT_CHAT_FRAME:AddMessage("rightScrollChild: NIL")
            end
            if IchaTaunt.taunterUI.RefreshPanels then
                DEFAULT_CHAT_FRAME:AddMessage("RefreshPanels: EXISTS")
            else
                DEFAULT_CHAT_FRAME:AddMessage("RefreshPanels: NIL - THIS IS THE PROBLEM")
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("taunterUI: NIL (open /it first)")
        end
    elseif msg == "events" then
        -- Show registered events
        print("IchaTaunt: Registered Events Check")
        print("  Checking if frame is registered for combat events...")
        print("  Frame exists: " .. tostring(IchaTaunt ~= nil))
        if IchaTaunt then
            print("  Frame type: " .. tostring(IchaTaunt:GetObjectType()))
            print("  IsEventRegistered function exists: " .. tostring(IchaTaunt.IsEventRegistered ~= nil))

            -- Test a few key events
            local testEvents = {
                "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE",
                "CHAT_MSG_SPELL_PARTY_DAMAGE",
                "CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF",
                "CHAT_MSG_SPELL_PARTY_BUFF",
            }

            print("  Testing key event registrations:")
            for _, evt in ipairs(testEvents) do
                if IchaTaunt.IsEventRegistered and IchaTaunt:IsEventRegistered(evt) then
                    print("    " .. evt .. ": REGISTERED")
                else
                    print("    " .. evt .. ": NOT REGISTERED or can't check")
                end
            end
        end
        print("  ")
        print("  Try: /it debugmode then have someone cast a spell")
        print("  You should see [IchaTaunt Event] messages in chat")
    elseif msg == "disablebroadcast" or msg == "nobroadcast" or msg == "testmode" then
        -- Toggle broadcast disable for testing
        IchaTauntDB.disableBroadcast = not IchaTauntDB.disableBroadcast
        DEFAULT_CHAT_FRAME:AddMessage("IchaTaunt: Test Mode " .. (IchaTauntDB.disableBroadcast and "ENABLED" or "DISABLED"))
        if IchaTauntDB.disableBroadcast then
            DEFAULT_CHAT_FRAME:AddMessage("  Only combat log detection active (for testing)")
        else
            DEFAULT_CHAT_FRAME:AddMessage("  All detection methods enabled (normal mode)")
        end
    elseif msg == "version" or msg == "ver" then
        print("========================================")
        print("IchaTaunt VERSION CHECK")
        print("File Version: 2.0.DEBUG.BANNER.v5")
        print("If you see this, the new code IS loaded!")
        print("Unconditional print added to StartCooldownFor")
        print("========================================")
    elseif msg == "debugmode" then
        -- Toggle debug mode for combat log
        IchaTauntDB.debugMode = not IchaTauntDB.debugMode
        DEFAULT_CHAT_FRAME:AddMessage("IchaTaunt: Debug Mode " .. (IchaTauntDB.debugMode and "ENABLED" or "DISABLED"))
    elseif msg == "logcombat" or msg == "combatlog" then
        -- Toggle logging of all combat events mentioning tracked players
        IchaTauntDB.logTrackedCombat = not IchaTauntDB.logTrackedCombat
        DEFAULT_CHAT_FRAME:AddMessage("IchaTaunt: Tracked Combat Logging " .. (IchaTauntDB.logTrackedCombat and "ENABLED" or "DISABLED"))
        if IchaTauntDB.logTrackedCombat then
            DEFAULT_CHAT_FRAME:AddMessage("  Will show ALL combat log events for tracked players")
            DEFAULT_CHAT_FRAME:AddMessage("  Use to diagnose why spells aren't being detected")
        end
    elseif msg == "debugall" then
        -- Toggle super debug mode (shows ALL combat events)
        IchaTauntDB.debugAllEvents = not IchaTauntDB.debugAllEvents
        print("IchaTaunt: Debug ALL events " .. (IchaTauntDB.debugAllEvents and "ENABLED" or "DISABLED"))
        print("  WARNING: This will spam your chat with ALL combat log events!")
    elseif msg == "testui" then
        -- Test if the spell menu UI exists
        if IchaTaunt.customSpellsMenu then
            print("IchaTaunt DEBUG: Menu exists")
            print("  Is visible: " .. tostring(IchaTaunt.customSpellsMenu:IsVisible()))
            print("  selectedClass: " .. tostring(IchaTaunt.customSpellsMenu.selectedClass))
            print("  selectedAvailableSpell: " .. tostring(IchaTaunt.customSpellsMenu.selectedAvailableSpell))
            if IchaTaunt.customSpellsMenu.selectedAvailableSpell then
                print("    Spell name: " .. tostring(IchaTaunt.customSpellsMenu.selectedAvailableSpell.name))
            end
        else
            print("IchaTaunt DEBUG: Menu does not exist - open it first with 'Manage Tracked Spells'")
        end
    elseif msg == "testadd" then
        -- Test adding a Hunter spell directly
        print("IchaTaunt DEBUG: Testing direct add of Feign Death")
        IchaTaunt:AddCustomSpell("Feign Death", 30, "HUNTER", 5384, "Interface\\Icons\\Ability_Rogue_FeignDeath")
    elseif strfind(msg, "^lookup ") then
        -- Test spell lookup by name
        local _, _, spellName = strfind(msg, "^lookup (.+)")
        if spellName then
            print("Looking up spell: " .. spellName)
            local spellID, spellData = IchaTaunt_GetSpellByName(spellName)
            if spellID and spellData then
                print("  FOUND - ID: " .. spellID .. ", Name: " .. spellData.name .. ", CD: " .. spellData.cooldown .. "s")
            else
                print("  NOT FOUND in database")
            end
        end
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
        print("/it debug - Show debug info")
        print("/it debugmode - Toggle combat log debug messages")
        print("/it logcombat - Log combat events for tracked players (diagnostic)")
        print("/it debugall - Toggle ALL combat event spam (use carefully!)")
        print("/it lookup <spell name> - Test if a spell is in the database")
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
    end)  -- End of pcall

    if not success then
        DEFAULT_CHAT_FRAME:AddMessage("IchaTaunt ERROR: " .. tostring(err))
    end
end
DEFAULT_CHAT_FRAME:AddMessage("IchaTaunt.lua FULLY LOADED - slash commands registered")
