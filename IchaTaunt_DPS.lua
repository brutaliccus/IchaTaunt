-- IchaTaunt DTPS Module (Damage Taken Per Second)
-- Tracks live incoming damage per second for each taunter (rolling window)
-- Shows current damage rate being taken, not fight average
-- Helps tanks know when to taunt off another tank taking heavy damage

IchaTaunt_DPS = IchaTaunt_DPS or {}

-- Configuration
IchaTaunt_DPS.config = {
    enabled = true,
    windowSize = 5,          -- Seconds of rolling window for live DTPS feed (default 5, range 3-15)
    updateInterval = 0.25,   -- How often to update the display (seconds) - faster updates!
    broadcastInterval = 0.5, -- How often to broadcast our own DTPS (seconds) - faster for better accuracy
    warningThreshold = 1000, -- DTPS threshold for yellow warning
    dangerThreshold = 2000,  -- DTPS threshold for red danger
    showZero = false,        -- Show "0" when no damage taken
    showNetDTPS = false,     -- Show NET DTPS (DTPS - HTPS) instead of just DTPS
}

-- Data storage
IchaTaunt_DPS.damageData = {}   -- [playerName] = { timestamps = {}, damages = {} }
IchaTaunt_DPS.healingData = {}  -- [playerName] = { timestamps = {}, heals = {} }
IchaTaunt_DPS.currentDPS = {}   -- [playerName] = calculated DPS value (local only for self)
IchaTaunt_DPS.currentHPS = {}   -- [playerName] = calculated HPS value (local only for self)
IchaTaunt_DPS.receivedDTPS = {} -- [playerName] = { dtps = N, htps = N, window = N, time = GetTime() } from addon messages
IchaTaunt_DPS.lastUpdate = 0
IchaTaunt_DPS.lastBroadcastTime = 0

-- ============================================
-- INITIALIZATION
-- ============================================

function IchaTaunt_DPS:Initialize()
    -- Create our event frame
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame", "IchaTauntDPSFrame")
        -- Damage events
        self.eventFrame:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS")
        self.eventFrame:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES")
        self.eventFrame:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE")
        self.eventFrame:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS")
        self.eventFrame:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE")
        self.eventFrame:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_PARTY_MISSES")
        self.eventFrame:RegisterEvent("CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS")
        self.eventFrame:RegisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE")
        -- Healing events
        self.eventFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS")  -- HoT ticks on self
        self.eventFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")            -- Direct heals on self
        self.eventFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS") -- HoT ticks on party
        self.eventFrame:RegisterEvent("CHAT_MSG_SPELL_PARTY_BUFF")           -- Direct heals on party
        self.eventFrame:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF")  -- Heals on friendly players

        self.eventFrame:SetScript("OnEvent", function()
            IchaTaunt_DPS:OnEvent(event, arg1)
        end)

        self.eventFrame:SetScript("OnUpdate", function()
            IchaTaunt_DPS:OnUpdate(arg1)
        end)
    end

    -- Load saved settings
    if IchaTauntDB and IchaTauntDB.dpsConfig then
        for k, v in pairs(IchaTauntDB.dpsConfig) do
            self.config[k] = v
        end
    end

    print("IchaTaunt DTPS: Module loaded")
end

-- ============================================
-- EVENT HANDLING
-- ============================================

function IchaTaunt_DPS:OnEvent(event, msg)
    if not self.config.enabled then return end
    if not msg then return end

    -- Check if this is a healing event
    if event == "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS" or event == "CHAT_MSG_SPELL_SELF_BUFF" or
       event == "CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS" or event == "CHAT_MSG_SPELL_PARTY_BUFF" or
       event == "CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF" then
        local playerName, healing = self:ParseHealingMessage(event, msg)
        if playerName and healing and healing > 0 then
            self:RecordHealing(playerName, healing)
        end
    else
        -- Damage event
        local playerName, damage = self:ParseDamageMessage(event, msg)
        if playerName and damage and damage > 0 then
            self:RecordDamage(playerName, damage)
        end
    end
end

function IchaTaunt_DPS:OnUpdate(elapsed)
    if not self.config.enabled then return end

    self.lastUpdate = self.lastUpdate + (elapsed or 0)

    if self.lastUpdate >= self.config.updateInterval then
        self.lastUpdate = 0
        self:CalculateAllDPS()
        self:BroadcastOwnDTPS()
        self:UpdateDisplays()
    end
end

-- Broadcast our own DTPS/HTPS so other tanks see it (we're the only one with our combat log)
-- Only broadcast when in combat (no need when just vibing)
function IchaTaunt_DPS:BroadcastOwnDTPS()
    if not IchaTaunt or not IchaTaunt.SendSyncMessage then return end
    if not IchaTauntDB or not IchaTauntDB.taunters then return end
    local me = UnitName("player")
    if not IchaTauntDB.taunters[me] then return end
    if GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 then return end
    if not UnitAffectingCombat("player") then return end
    local interval = self.config.broadcastInterval or 0.5
    if (GetTime() - self.lastBroadcastTime) < interval then return end
    self.lastBroadcastTime = GetTime()
    local dtps = self:GetDPS(me)
    local htps = self:GetHPS(me)
    -- Format: DTPS:dtpsValue:htpsValue:windowSize
    local msg = "DTPS:" .. format("%.1f", dtps) .. ":" .. format("%.1f", htps) .. ":" .. tostring(self.config.windowSize or 5)
    IchaTaunt:SendSyncMessage(msg)
end

-- Receive DTPS/HTPS from another tank (they broadcast their own; sender = player name)
function IchaTaunt_DPS:ReceiveDTPS(sender, dtpsValue, htpsValue, window)
    if not sender or not dtpsValue then return end
    -- Handle both old format (2 params) and new format (3 params)
    if not htpsValue then
        -- Old format: DTPS:value:window
        htpsValue = 0
        window = window or 5
    else
        -- New format: DTPS:dtps:htps:window
        window = window or htpsValue  -- In case someone passes old 2-param format
        if not tonumber(window) then
            window = 5
        end
    end
    self.receivedDTPS[sender] = {
        dtps = tonumber(dtpsValue) or 0,
        htps = tonumber(htpsValue) or 0,
        window = tonumber(window) or 5,
        time = GetTime()
    }
end

-- ============================================
-- DAMAGE PARSING (1.12 Combat Log)
-- ============================================

function IchaTaunt_DPS:ParseDamageMessage(event, msg)
    local playerName = nil
    local damage = 0

    -- Self damage events
    if event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS" or
       event == "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE" then
        playerName = UnitName("player")
        damage = self:ExtractDamage(msg)

    -- Party/Raid damage events
    elseif event == "CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS" or
           event == "CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE" then
        playerName, damage = self:ExtractPartyDamage(msg)

    -- PvP damage (for completeness)
    elseif event == "CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS" or
           event == "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE" then
        playerName = UnitName("player")
        damage = self:ExtractDamage(msg)
    end

    -- Only track damage to players we're monitoring
    if playerName and IchaTauntDB and IchaTauntDB.taunters and IchaTauntDB.taunters[playerName] then
        return playerName, damage
    end

    return nil, 0
end

function IchaTaunt_DPS:ExtractDamage(msg)
    -- Pattern: "Creature hits you for X damage"
    -- Pattern: "Creature crits you for X damage"
    -- Pattern: "Creature's Spell hits you for X damage"
    -- Pattern: "Creature's Spell crits you for X damage"

    local damage = 0

    -- Try various patterns
    local patterns = {
        "hits you for (%d+)",
        "crits you for (%d+)",
        "hit you for (%d+)",
        "crit you for (%d+)",
    }

    for _, pattern in ipairs(patterns) do
        local _, _, dmgStr = strfind(msg, pattern)
        if dmgStr then
            damage = tonumber(dmgStr) or 0
            break
        end
    end

    return damage
end

function IchaTaunt_DPS:ExtractPartyDamage(msg)
    -- Pattern: "Creature hits PlayerName for X damage"
    -- Pattern: "Creature crits PlayerName for X damage"
    -- Pattern: "Creature's Spell hits PlayerName for X damage"

    local playerName = nil
    local damage = 0

    -- Try to extract player name and damage
    local patterns = {
        "hits (.+) for (%d+)",
        "crits (.+) for (%d+)",
        "hit (.+) for (%d+)",
        "crit (.+) for (%d+)",
    }

    for _, pattern in ipairs(patterns) do
        local _, _, name, dmgStr = strfind(msg, pattern)
        if name and dmgStr then
            playerName = name
            damage = tonumber(dmgStr) or 0
            break
        end
    end

    return playerName, damage
end

-- ============================================
-- HEALING PARSING (1.12 Combat Log)
-- ============================================

function IchaTaunt_DPS:ParseHealingMessage(event, msg)
    local playerName = nil
    local healing = 0

    -- Self healing events
    if event == "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS" or event == "CHAT_MSG_SPELL_SELF_BUFF" then
        playerName = UnitName("player")
        healing = self:ExtractHealing(msg)

    -- Party/Raid healing events
    elseif event == "CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS" or event == "CHAT_MSG_SPELL_PARTY_BUFF" or
           event == "CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF" then
        playerName, healing = self:ExtractPartyHealing(msg)
    end

    -- Only track healing to players we're monitoring
    if playerName and IchaTauntDB and IchaTauntDB.taunters and IchaTauntDB.taunters[playerName] then
        return playerName, healing
    end

    return nil, 0
end

function IchaTaunt_DPS:ExtractHealing(msg)
    -- Pattern: "You gain X health from Spell"
    -- Pattern: "Spell heals you for X"
    local healing = 0

    local patterns = {
        "You gain (%d+)",
        "heals you for (%d+)",
        "heal you for (%d+)",
    }

    for _, pattern in ipairs(patterns) do
        local _, _, healStr = strfind(msg, pattern)
        if healStr then
            healing = tonumber(healStr) or 0
            break
        end
    end

    return healing
end

function IchaTaunt_DPS:ExtractPartyHealing(msg)
    -- Pattern: "PlayerName gains X health from Spell"
    -- Pattern: "Spell heals PlayerName for X"
    local playerName = nil
    local healing = 0

    local patterns = {
        "(.+) gains (%d+)",
        "heals (.+) for (%d+)",
        "heal (.+) for (%d+)",
    }

    for _, pattern in ipairs(patterns) do
        local _, _, name, healStr = strfind(msg, pattern)
        if name and healStr then
            playerName = name
            healing = tonumber(healStr) or 0
            break
        end
    end

    return playerName, healing
end

-- ============================================
-- DAMAGE TRACKING
-- ============================================

function IchaTaunt_DPS:RecordDamage(playerName, damage)
    local currentTime = GetTime()

    -- Initialize data structure for this player if needed
    if not self.damageData[playerName] then
        self.damageData[playerName] = {
            timestamps = {},
            damages = {},
        }
    end

    local data = self.damageData[playerName]

    -- Add new damage event
    table.insert(data.timestamps, currentTime)
    table.insert(data.damages, damage)

    -- Prune old data (older than window size)
    self:PruneOldData(playerName)

    if IchaTauntDB and IchaTauntDB.debugMode then
        print("[IchaTaunt DTPS] " .. playerName .. " took " .. damage .. " damage")
    end
end

function IchaTaunt_DPS:RecordHealing(playerName, healing)
    local currentTime = GetTime()

    -- Initialize data structure for this player if needed
    if not self.healingData[playerName] then
        self.healingData[playerName] = {
            timestamps = {},
            heals = {},
        }
    end

    local data = self.healingData[playerName]

    -- Add new healing event
    table.insert(data.timestamps, currentTime)
    table.insert(data.heals, healing)

    -- Prune old data (older than window size)
    self:PruneOldHealingData(playerName)

    if IchaTauntDB and IchaTauntDB.debugMode then
        print("[IchaTaunt HTPS] " .. playerName .. " healed for " .. healing)
    end
end

function IchaTaunt_DPS:PruneOldData(playerName)
    local data = self.damageData[playerName]
    if not data then return end

    local currentTime = GetTime()
    local cutoffTime = currentTime - self.config.windowSize

    -- Remove entries older than the window
    while data.timestamps[1] and data.timestamps[1] < cutoffTime do
        table.remove(data.timestamps, 1)
        table.remove(data.damages, 1)
    end
end

function IchaTaunt_DPS:PruneOldHealingData(playerName)
    local data = self.healingData[playerName]
    if not data then return end

    local currentTime = GetTime()
    local cutoffTime = currentTime - self.config.windowSize

    -- Remove entries older than the window
    while data.timestamps[1] and data.timestamps[1] < cutoffTime do
        table.remove(data.timestamps, 1)
        table.remove(data.heals, 1)
    end
end

-- ============================================
-- DPS CALCULATION
-- ============================================

function IchaTaunt_DPS:CalculateAllDPS()
    local currentTime = GetTime()

    -- Calculate DPS and HPS for all tracked players
    if IchaTauntDB and IchaTauntDB.taunters then
        for playerName, _ in pairs(IchaTauntDB.taunters) do
            self:CalculateDPS(playerName)
            self:CalculateHPS(playerName)
        end
    end

    -- Clean up data for players no longer tracked
    for playerName, _ in pairs(self.damageData) do
        if not IchaTauntDB or not IchaTauntDB.taunters or not IchaTauntDB.taunters[playerName] then
            self.damageData[playerName] = nil
            self.currentDPS[playerName] = nil
        end
    end

    for playerName, _ in pairs(self.healingData) do
        if not IchaTauntDB or not IchaTauntDB.taunters or not IchaTauntDB.taunters[playerName] then
            self.healingData[playerName] = nil
            self.currentHPS[playerName] = nil
        end
    end
end

function IchaTaunt_DPS:CalculateDPS(playerName)
    local data = self.damageData[playerName]

    -- Check if we have data (WoW 1.12 compatible - no # operator)
    local hasData = false
    if data and data.damages then
        for _ in pairs(data.damages) do
            hasData = true
            break
        end
    end
    
    if not hasData then
        self.currentDPS[playerName] = 0
        return
    end

    -- Prune old data first
    self:PruneOldData(playerName)

    -- Sum all damage in the rolling window (live feed)
    local totalDamage = 0
    local damageCount = 0
    for _, dmg in ipairs(data.damages) do
        totalDamage = totalDamage + dmg
        damageCount = damageCount + 1
    end

    -- Calculate live DTPS (damage taken per second over rolling window)
    -- This gives a real-time feed of current incoming damage rate, not fight average
    local dps = 0
    if damageCount > 0 then
        -- Use actual time span if we have data, otherwise use window size
        local timeSpan = self.config.windowSize
        if data.timestamps and data.timestamps[1] then
            -- Find last timestamp (WoW 1.12 compatible - iterate to find last)
            local lastTimestamp = nil
            local maxIndex = 0
            for i, timestamp in ipairs(data.timestamps) do
                if timestamp then
                    lastTimestamp = timestamp
                    maxIndex = i
                end
            end
            
            if lastTimestamp and maxIndex > 1 then
                local actualSpan = lastTimestamp - data.timestamps[1]
                if actualSpan > 0.1 then -- Use actual span if meaningful
                    timeSpan = math.min(actualSpan, self.config.windowSize)
                end
            end
        end
        dps = totalDamage / timeSpan
    end
    self.currentDPS[playerName] = dps
end

function IchaTaunt_DPS:GetDPS(playerName)
    local me = UnitName("player")
    if playerName == me then
        return self.currentDPS[playerName] or 0
    end
    -- For other players, use their broadcasted DTPS (discard if older than 5 sec)
    local r = self.receivedDTPS[playerName]
    if r and (GetTime() - r.time) < 5 then
        return r.dtps or 0
    end
    -- Match by normalized name (sender may be "Icabod-Realm", bar key "Icabod")
    if IchaTaunt and IchaTaunt.NormalizePlayerName then
        local nameBase = IchaTaunt:NormalizePlayerName(playerName)
        for k, v in pairs(self.receivedDTPS) do
            if v and (GetTime() - v.time) < 5 and IchaTaunt:NormalizePlayerName(k) == nameBase then
                return v.dtps or 0
            end
        end
    end
    return 0
end

-- ============================================
-- HPS CALCULATION
-- ============================================

function IchaTaunt_DPS:CalculateHPS(playerName)
    local data = self.healingData[playerName]

    -- Check if we have data (WoW 1.12 compatible - no # operator)
    local hasData = false
    if data and data.heals then
        for _ in pairs(data.heals) do
            hasData = true
            break
        end
    end

    if not hasData then
        self.currentHPS[playerName] = 0
        return
    end

    -- Prune old data first
    self:PruneOldHealingData(playerName)

    -- Sum all healing in the rolling window (live feed)
    local totalHealing = 0
    local healCount = 0
    for _, heal in ipairs(data.heals) do
        totalHealing = totalHealing + heal
        healCount = healCount + 1
    end

    -- Calculate live HTPS (healing taken per second over rolling window)
    local hps = 0
    if healCount > 0 then
        -- Use actual time span if we have data, otherwise use window size
        local timeSpan = self.config.windowSize
        if data.timestamps and data.timestamps[1] then
            -- Find last timestamp (WoW 1.12 compatible - iterate to find last)
            local lastTimestamp = nil
            local maxIndex = 0
            for i, timestamp in ipairs(data.timestamps) do
                if timestamp then
                    lastTimestamp = timestamp
                    maxIndex = i
                end
            end

            if lastTimestamp and maxIndex > 1 then
                local actualSpan = lastTimestamp - data.timestamps[1]
                if actualSpan > 0.1 then -- Use actual span if meaningful
                    timeSpan = math.min(actualSpan, self.config.windowSize)
                end
            end
        end
        hps = totalHealing / timeSpan
    end
    self.currentHPS[playerName] = hps
end

function IchaTaunt_DPS:GetHPS(playerName)
    local me = UnitName("player")
    if playerName == me then
        return self.currentHPS[playerName] or 0
    end
    -- For other players, use their broadcasted HTPS (discard if older than 5 sec)
    local r = self.receivedDTPS[playerName]
    if r and (GetTime() - r.time) < 5 then
        return r.htps or 0
    end
    -- Match by normalized name (sender may be "Icabod-Realm", bar key "Icabod")
    if IchaTaunt and IchaTaunt.NormalizePlayerName then
        local nameBase = IchaTaunt:NormalizePlayerName(playerName)
        for k, v in pairs(self.receivedDTPS) do
            if v and (GetTime() - v.time) < 5 and IchaTaunt:NormalizePlayerName(k) == nameBase then
                return v.htps or 0
            end
        end
    end
    return 0
end

-- ============================================
-- DISPLAY
-- ============================================

function IchaTaunt_DPS:UpdateDisplays()
    -- This will be called by the main addon to update the tracker bars
    if IchaTaunt and IchaTaunt.taunterBars then
        for playerName, bar in pairs(IchaTaunt.taunterBars) do
            self:UpdateBarDPS(bar, playerName)
        end
    end
end

function IchaTaunt_DPS:UpdateBarDPS(bar, playerName)
    if not bar then return end

    -- Create DTPS text if it doesn't exist
    if not bar.dpsText then
        bar.dpsText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        bar.dpsText:SetPoint("RIGHT", bar, "RIGHT", -5, 0)
        bar.dpsText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    end

    -- Hide DTPS/HTPS when player is out of combat (combat is over)
    if not UnitAffectingCombat("player") then
        bar.dpsText:Hide()
        return
    end

    local dtps = self:GetDPS(playerName)
    local htps = self:GetHPS(playerName)

    -- Calculate display value based on mode
    local displayValue, displayLabel
    if self.config.showNetDTPS then
        -- NET DTPS mode: show (HTPS - DTPS)
        -- Positive = healing outpacing damage (good) -> show as HTPS
        -- Negative = damage outpacing healing (bad) -> show as DTPS
        displayValue = htps - dtps
        if displayValue >= 0 then
            displayLabel = "HTPS"
        else
            displayLabel = "DTPS"
            displayValue = -displayValue  -- Make it positive for display
        end
    else
        -- Normal mode: show just DTPS
        displayValue = dtps
        displayLabel = "DTPS"
    end

    -- Update display
    if dtps > 0 or htps > 0 or self.config.showZero then
        local displayText = self:FormatDPS(displayValue) .. " " .. displayLabel
        bar.dpsText:SetText(displayText)

        -- Color based on thresholds
        if self.config.showNetDTPS then
            -- In NET mode, label tells us which is winning
            if displayLabel == "HTPS" then
                -- Healing is greater - show green
                bar.dpsText:SetTextColor(0.3, 1, 0.3)
            else
                -- Damage is greater - use normal thresholds
                local r, g, b = self:GetDPSColor(displayValue)
                bar.dpsText:SetTextColor(r, g, b)
            end
        else
            -- Normal DTPS mode - use standard color thresholds
            local r, g, b = self:GetDPSColor(displayValue)
            bar.dpsText:SetTextColor(r, g, b)
        end
        bar.dpsText:Show()
    else
        bar.dpsText:Hide()
    end
end

function IchaTaunt_DPS:FormatDPS(dps)
    if dps >= 1000 then
        return format("%.1fk", dps / 1000)
    else
        return format("%.0f", dps)
    end
end

function IchaTaunt_DPS:GetDPSColor(dps)
    if dps >= self.config.dangerThreshold then
        -- Red - danger, needs taunt
        return 1, 0.2, 0.2
    elseif dps >= self.config.warningThreshold then
        -- Yellow/Orange - warning
        return 1, 0.8, 0
    else
        -- Green - safe
        return 0.3, 1, 0.3
    end
end

-- ============================================
-- CONFIGURATION
-- ============================================

function IchaTaunt_DPS:SetEnabled(enabled)
    self.config.enabled = enabled

    -- Save to DB
    if IchaTauntDB then
        IchaTauntDB.dpsConfig = IchaTauntDB.dpsConfig or {}
        IchaTauntDB.dpsConfig.enabled = enabled
    end

    if enabled then
        print("IchaTaunt DTPS: Enabled")
    else
        print("IchaTaunt DTPS: Disabled")
        -- Hide all DTPS texts
        if IchaTaunt and IchaTaunt.taunterBars then
            for _, bar in pairs(IchaTaunt.taunterBars) do
                if bar.dpsText then
                    bar.dpsText:Hide()
                end
            end
        end
    end
end

function IchaTaunt_DPS:SetThresholds(warning, danger)
    self.config.warningThreshold = warning or 1000
    self.config.dangerThreshold = danger or 2000

    -- Save to DB
    if IchaTauntDB then
        IchaTauntDB.dpsConfig = IchaTauntDB.dpsConfig or {}
        IchaTauntDB.dpsConfig.warningThreshold = self.config.warningThreshold
        IchaTauntDB.dpsConfig.dangerThreshold = self.config.dangerThreshold
    end

    print("IchaTaunt DTPS: Thresholds set - Warning: " .. self.config.warningThreshold .. ", Danger: " .. self.config.dangerThreshold)
end

function IchaTaunt_DPS:SetWindowSize(seconds)
    self.config.windowSize = seconds or 5

    -- Save to DB
    if IchaTauntDB then
        IchaTauntDB.dpsConfig = IchaTauntDB.dpsConfig or {}
        IchaTauntDB.dpsConfig.windowSize = self.config.windowSize
    end

    print("IchaTaunt DTPS: Window size set to " .. self.config.windowSize .. " seconds")
end

function IchaTaunt_DPS:SetNetMode(enabled)
    self.config.showNetDTPS = enabled

    -- Save to DB
    if IchaTauntDB then
        IchaTauntDB.dpsConfig = IchaTauntDB.dpsConfig or {}
        IchaTauntDB.dpsConfig.showNetDTPS = enabled
    end

    if enabled then
        print("IchaTaunt DTPS: NET mode enabled (shows HTPS when healing wins, DTPS when damage wins)")
    else
        print("IchaTaunt DTPS: Normal DTPS mode")
    end

    -- Force immediate update
    self:UpdateDisplays()
end

-- ============================================
-- SLASH COMMANDS (handled by main addon)
-- ============================================

function IchaTaunt_DPS:HandleCommand(args)
    if not args or args == "" or args == "help" then
        print("IchaTaunt DTPS Commands:")
        print("  /it dtps - Toggle DTPS display on/off")
        print("  /it dtps on - Enable DTPS display")
        print("  /it dtps off - Disable DTPS display")
        print("  /it dtps net - Toggle NET mode (shows DTPS - HTPS)")
        print("  /it dtps net on - Enable NET mode")
        print("  /it dtps net off - Disable NET mode")
        print("  /it dtps window <seconds> - Set rolling window (default 5, range 3-15)")
        print("  /it dtps warn <value> - Set warning threshold (yellow)")
        print("  /it dtps danger <value> - Set danger threshold (red)")
        print("  /it dtps status - Show current settings")
        print("  Note: DTPS shows current incoming damage rate over rolling window, not fight average")
        print("  Note: NET mode shows HTPS (green) when healing wins, DTPS (red/yellow) when damage wins")
        return
    end

    if args == "on" then
        self:SetEnabled(true)
    elseif args == "off" then
        self:SetEnabled(false)
    elseif args == "net" then
        -- Toggle NET mode
        self:SetNetMode(not self.config.showNetDTPS)
    elseif args == "net on" then
        self:SetNetMode(true)
    elseif args == "net off" then
        self:SetNetMode(false)
    elseif args == "status" then
        print("IchaTaunt DTPS Status:")
        print("  Enabled: " .. (self.config.enabled and "Yes" or "No"))
        print("  NET Mode: " .. (self.config.showNetDTPS and "Yes" or "No"))
        print("  Window: " .. self.config.windowSize .. " seconds")
        print("  Update interval: " .. self.config.updateInterval .. " seconds")
        print("  Broadcast interval: " .. self.config.broadcastInterval .. " seconds")
        print("  Warning threshold: " .. self.config.warningThreshold)
        print("  Danger threshold: " .. self.config.dangerThreshold)
    elseif strfind(args, "^window") then
        local _, _, val = strfind(args, "^window (%d+)")
        if val then
            self:SetWindowSize(tonumber(val))
        end
    elseif strfind(args, "^warn") then
        local _, _, val = strfind(args, "^warn (%d+)")
        if val then
            self:SetThresholds(tonumber(val), self.config.dangerThreshold)
        end
    elseif strfind(args, "^danger") then
        local _, _, val = strfind(args, "^danger (%d+)")
        if val then
            self:SetThresholds(self.config.warningThreshold, tonumber(val))
        end
    else
        -- Toggle
        self:SetEnabled(not self.config.enabled)
    end
end

-- ============================================
-- RESET / CLEAR
-- ============================================

function IchaTaunt_DPS:Reset()
    self.damageData = {}
    self.healingData = {}
    self.currentDPS = {}
    self.currentHPS = {}
    print("IchaTaunt DTPS: Data reset")
end

function IchaTaunt_DPS:ClearPlayer(playerName)
    self.damageData[playerName] = nil
    self.healingData[playerName] = nil
    self.currentDPS[playerName] = nil
    self.currentHPS[playerName] = nil
end
