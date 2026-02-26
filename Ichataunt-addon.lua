-- ICHATAUNT AddOn (Turtle WoW)
-- Drag-sort list, per-caster cooldowns, manual taunter assignment, PallyPower-style sync

local ADDON_NAME = "ICHataunt"
local ICHataunt = CreateFrame("Frame", ADDON_NAME)

ICHataunt.taunters = {}          -- [playerName] = true if manually assigned
ICHataunt.order = {}             -- ordered list of player names
ICHataunt.cooldowns = {}         -- per-player spell cooldown tracking
ICHataunt.frame = nil
ICHataunt.locked = false

-- SavedVariables
ICHatauntDB = ICHatauntDB or {
    showInRaidOnly = true,
    mainTank = nil,
    taunterOrder = {},
    taunters = {},
    position = { x = 300, y = 300 },
}

-- Use external spell configuration
-- All spell data is now in ICHataunt_Spells.lua for easy editing

-- Event Registration
ICHataunt:RegisterEvent("PLAYER_LOGIN")
ICHataunt:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH") -- 1.12 combat log events
ICHataunt:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
ICHataunt:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF") -- Your own spell casts
ICHataunt:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF") -- Your spell effects
ICHataunt:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS") -- Your melee/spell hits
ICHataunt:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES") -- Your misses
ICHataunt:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE")
ICHataunt:RegisterEvent("CHAT_MSG_SPELL_PARTY_DAMAGE")
ICHataunt:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE")
ICHataunt:RegisterEvent("CHAT_MSG_COMBAT_FRIENDLY_DEATH")
ICHataunt:RegisterEvent("RAID_ROSTER_UPDATE")
ICHataunt:RegisterEvent("PARTY_MEMBERS_CHANGED")
ICHataunt:RegisterEvent("CHAT_MSG_ADDON")

ICHataunt:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        ICHataunt:Initialize()
    elseif event == "CHAT_MSG_SPELL_SELF_DAMAGE" or event == "CHAT_MSG_SPELL_SELF_BUFF" or 
           event == "CHAT_MSG_SPELL_AURA_GONE_SELF" or event == "CHAT_MSG_COMBAT_SELF_HITS" or
           event == "CHAT_MSG_COMBAT_SELF_MISSES" or event == "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE" or 
           event == "CHAT_MSG_SPELL_PARTY_DAMAGE" or event == "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE" or
           event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF" or event == "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE" or
           event == "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF" or event == "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE" or
           event == "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS" then
        ICHataunt:HandleCombatMessage(event)
    elseif event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
        ICHataunt:RefreshRoster()
    elseif event == "CHAT_MSG_ADDON" then
        if arg1 and arg2 and arg4 then
            if arg1 == "ICHAT" then
                if strfind(arg2, "^T:") then
                    ICHataunt:ReceiveTaunters(strsub(arg2, 3))
                else
                    ICHataunt:ReceiveOrder(arg2, arg4)
                end
            end
        end
    end
end)

function ICHataunt:Initialize()
    print("ICHATAUNT loaded.")
    -- Ensure ICHatauntDB is properly initialized
    if not ICHatauntDB then
        ICHatauntDB = {
            showInRaidOnly = true,
            mainTank = nil,
            taunterOrder = {},
            taunters = {},
            position = { x = 0, y = 0 },
            debugMode = false,
        }
    else
        if not ICHatauntDB.position then
            ICHatauntDB.position = { x = 0, y = 0 }
        end

    end
    
    -- Add missing fields if they don't exist
    if ICHatauntDB.debugMode == nil then
        ICHatauntDB.debugMode = false
    end
    if ICHatauntDB.debugAllEvents == nil then
        ICHatauntDB.debugAllEvents = false
    end
    if not ICHatauntDB.taunterOrder then
        ICHatauntDB.taunterOrder = {}
    end
    if not ICHatauntDB.taunters then
        ICHatauntDB.taunters = {}
    end
    
    self.taunters = ICHatauntDB.taunters or {}
    self.order = ICHatauntDB.taunterOrder or {}
    self.taunterBars = {}
    
    self:CreateUI()
    
    -- Debug: Show what we have on login
    if ICHatauntDB.taunterOrder then
        local count = 0
        for _ in pairs(ICHatauntDB.taunterOrder) do
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
end

function ICHataunt:RefreshRoster()
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
        if ICHatauntDB.taunterOrder then
            for _ in pairs(ICHatauntDB.taunterOrder) do
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

function ICHataunt:HandleCombatMessage(eventType)
    -- Parse 1.12 combat log messages for taunt spells
    if arg1 then
        local caster = nil
        local spell = nil
        
        -- Debug: Print all combat messages to see what we're getting
        if ICHatauntDB.debugMode then
            print("[ICHataunt Debug] " .. (eventType or "Unknown") .. ": " .. arg1)
        end
        
        -- Super debug mode - show ALL events
        if ICHatauntDB.debugAllEvents then
            print("[ICHataunt ALL] " .. (eventType or "Unknown") .. ": " .. arg1)
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
        end
        
        if caster and spell then
            -- Clean up caster name (remove realm suffix if present)
            if strfind(caster, "%-") then
                _, _, caster = strfind(caster, "([^%-]+)")
            end
            
            if self.taunters[caster] then
                if ICHatauntDB.debugMode then
                    print("[ICHataunt Debug] Tracked taunter " .. caster .. " used spell: " .. spell)
                end
                
                -- Check if it's a taunt spell by name
                local spellID, spellData = ICHataunt_GetSpellByName(spell)
                if spellID and spellData then
                    -- Check if this was a resist
                    local wasResisted = strfind(arg1, "was resisted") or strfind(arg1, "resists")
                    
                    if wasResisted then
                        if ICHatauntDB.debugMode then
                            print("[ICHataunt] " .. caster .. "'s " .. spell .. " was RESISTED - starting " .. spellData.cooldown .. "s cooldown")
                        end
                        self:StartCooldownFor(caster, spellID, true) -- true = resisted
                    else
                        if ICHatauntDB.debugMode then
                            print("[ICHataunt] " .. caster .. " used " .. spell .. " - starting " .. spellData.cooldown .. "s cooldown")
                        end
                        self:StartCooldownFor(caster, spellID, false) -- false = not resisted
                        -- Clear any existing resist status for this player since they had a successful taunt
                        self:ClearResistFor(caster)
                    end
                elseif ICHatauntDB.debugMode then
                    print("[ICHataunt Debug] Unknown spell: " .. spell)
                end
            end
        end
    end
end

function ICHataunt:GetSpellIDByName(spellName)
    return ICHataunt_GetSpellByName(spellName)
end

function ICHataunt:StartCooldownFor(name, spellID, wasResisted)
    local spellData = ICHataunt_GetSpellData(spellID)
    if not spellData then return end

    local taunterBar = self.taunterBars and self.taunterBars[name]
    if not taunterBar then return end

    local cdBar = taunterBar.cooldownBars and taunterBar.cooldownBars[spellID]
    if not cdBar then return end

    -- Start cooldown
    cdBar.endTime = GetTime() + spellData.cooldown
    
    -- Handle resist status
    if wasResisted then
        self:ShowResistFor(name, spellID, spellData.cooldown)
    end
    
    if ICHatauntDB.debugMode then
        print("ICHataunt: " .. name .. " used " .. spellData.name .. " - " .. spellData.cooldown .. "s cooldown" .. (wasResisted and " (RESISTED)" or ""))
    end
end

function ICHataunt:ShowResistFor(name, spellID, cooldownDuration)
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

function ICHataunt:ClearResistFor(name)
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

function ICHataunt:UpdateResistStatus()
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

function ICHataunt:UpdateCooldownBars()
    local currentTime = GetTime()
    
    -- Update resist status first
    self:UpdateResistStatus()
    
    for name, taunterBar in pairs(self.taunterBars) do
        for spellID, iconFrame in pairs(taunterBar.cooldownBars) do
            local timeLeft = iconFrame.endTime - currentTime
            
            if timeLeft > 0 then
                -- On cooldown - show overlay and countdown
                local percent = timeLeft / iconFrame.spellData.cooldown
                
                -- Show cooldown overlay and bar
                iconFrame.cooldownOverlay:Show()
                iconFrame.cooldownBar:Show()
                iconFrame.cooldownBar:SetHeight(26 * percent) -- Fill from bottom (updated for new icon size)
                
                -- Show countdown text
                if timeLeft >= 1 then
                    iconFrame.timerText:SetText(format("%.0f", timeLeft))
                else
                    iconFrame.timerText:SetText(format("%.1f", timeLeft))
                end
                
            else
                -- Ready - hide cooldown elements
                iconFrame.cooldownOverlay:Hide()
                iconFrame.cooldownBar:Hide()
                iconFrame.timerText:SetText("")
            end
        end
    end
end

function ICHataunt:GetPlayerClass(name)
    -- Get class for a player name
    for i = 1, GetNumRaidMembers() do
        local raidName, _, _, _, _, classFile = GetRaidRosterInfo(i)
        if raidName == name then return classFile end
    end
    
    for i = 1, GetNumPartyMembers() do
        local partyName = UnitName("party" .. i)
        if partyName == name then
            return UnitClass("party" .. i)
        end
    end
    
    if UnitName("player") == name then
        return UnitClass("player")
    end
    
    return nil
end

function ICHataunt:GetClassColor(class)
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
function ICHataunt:CreateUI()
    if self.frame then return end

    local f = CreateFrame("Frame", "ICHatauntFrame", UIParent)
    f:SetWidth(300)
    f:SetHeight(100)
    f:SetFrameStrata("MEDIUM")  -- Ensure tracker is visible above background elements
    
    -- Load position relative to screen center  
    local relativeX = ICHatauntDB.position.x or 0
    local relativeY = ICHatauntDB.position.y or 0
    local screenWidth = GetScreenWidth() or 1024
    local screenHeight = GetScreenHeight() or 768
    

    
    -- More lenient bounds checking - allow more positioning freedom
    local maxOffsetX = (screenWidth / 2) - 50   -- Allow frame closer to edge
    local maxOffsetY = (screenHeight / 2) - 25  -- Allow frame closer to edge
    
    if math.abs(relativeX) > maxOffsetX or math.abs(relativeY) > maxOffsetY then
        relativeX = 0
        relativeY = 0
        ICHatauntDB.position.x = 0
        ICHatauntDB.position.y = 0
    end
    
    -- Set position relative to screen center
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", relativeX, relativeY)
    
    -- Clean, borderless design - no backdrop
    
    -- Make it draggable
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() if not ICHataunt.locked then this:StartMoving() end end)
    f:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        
        -- Save position relative to screen center for consistent loading
        local frameX, frameY = this:GetCenter()
        local screenCenterX = GetScreenWidth() / 2
        local screenCenterY = GetScreenHeight() / 2
        
        local relativeX = frameX - screenCenterX
        local relativeY = frameY - screenCenterY
        
        ICHatauntDB.position.x = relativeX
        ICHatauntDB.position.y = relativeY
        

    end)

    self.frame = f
    self.taunterBars = {}
    self.updateTimer = 0
    
    -- Start update cycle
    f:SetScript("OnUpdate", function()
        ICHataunt:UpdateCooldownBars()
    end)
    
    -- Additional safety check - if frame is way off screen, center it
    local centerX, centerY = f:GetCenter()
    if centerX and centerY then
        if centerX < 100 or centerX > (screenWidth - 100) or centerY < 50 or centerY > (screenHeight - 50) then
            f:ClearAllPoints()
            f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            ICHatauntDB.position.x = 0
            ICHatauntDB.position.y = 0
        end
    end
end

-- Creates countdown bars for active taunters
function ICHataunt:RebuildList()
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
    
    -- Use the exact order from ICHatauntDB.taunterOrder
    local orderedTaunters = {}
    for _, name in ipairs(ICHatauntDB.taunterOrder) do
        if self:IsPlayerInGroup(name) and ICHatauntDB.taunters[name] then
            table.insert(orderedTaunters, name)
        end
    end
    
    -- Create bars for each taunter in order
    for i, name in ipairs(orderedTaunters) do
        self:CreateTaunterBar(name, yOffset, i)
        yOffset = yOffset - 28  -- Reduced from 36 to 28 for tighter spacing
        barIndex = barIndex + 1
    end
    
    -- Restore saved cooldown states
    for name, spellCooldowns in pairs(savedCooldowns) do
        if self.taunterBars[name] and self.taunterBars[name].cooldownBars then
            for spellID, endTime in pairs(spellCooldowns) do
                if self.taunterBars[name].cooldownBars[spellID] then
                    self.taunterBars[name].cooldownBars[spellID].endTime = endTime
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
end

function ICHataunt:IsPlayerInGroup(name)
    -- Check if player is in current raid/party
    for i = 1, GetNumRaidMembers() do
        local raidName = GetRaidRosterInfo(i)
        if raidName == name then return true end
    end
    
    for i = 1, GetNumPartyMembers() do
        local partyName = UnitName("party" .. i)
        if partyName == name then return true end
    end
    
    if UnitName("player") == name then return true end
    return false
end

-- Create clean taunter row: Order | Name | Icons
function ICHataunt:CreateTaunterBar(name, yOffset, orderNum)
    local parent = self.frame
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetWidth(280)
    bar:SetHeight(26)  -- Reduced from 32 to 26 for tighter spacing
    bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, yOffset)

    -- Order number (left aligned)
    bar.orderText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bar.orderText:SetPoint("LEFT", bar, "LEFT", 5, 0)
    bar.orderText:SetText(orderNum)
    bar.orderText:SetTextColor(1, 0.82, 0) -- Gold color

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

    -- Resist text (big red text over the name)
    bar.resistText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    bar.resistText:SetPoint("CENTER", bar.nameText, "CENTER", 0, 10) -- Position above the name
    bar.resistText:SetText("RESIST!")
    bar.resistText:SetTextColor(1, 0, 0) -- Bright red
    bar.resistText:SetFont("Fonts\\FRIZQT__.TTF", 16, "THICKOUTLINE") -- Large, bold font with thick outline
    bar.resistText:Hide() -- Initially hidden

    -- Initialize resist status tracking
    bar.resistStatus = {}

    -- Spell icons container
    bar.cooldownBars = {}
    
    -- Get spells for this player's class
    local playerClass = self:GetPlayerClass(name)
    if playerClass then
        local spells = ICHataunt_GetSpellsByClass(playerClass)
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
function ICHataunt:CreateSpellIcon(parent, spellID, spellData, iconIndex)
    -- Position icons after name text
    local xOffset = 120 + (iconIndex * 28) -- 26px icons + 2px spacing
    
    local iconFrame = CreateFrame("Frame", nil, parent)
    iconFrame:SetWidth(26)  -- Reduced from 32 to 26
    iconFrame:SetHeight(26)  -- Reduced from 32 to 26
    iconFrame:SetPoint("LEFT", parent, "LEFT", xOffset, 0)
    
    -- Main spell icon
    iconFrame.icon = iconFrame:CreateTexture(nil, "BACKGROUND")
    iconFrame.icon:SetAllPoints(true)
    iconFrame.icon:SetTexture(spellData.icon)
    
    -- Cooldown overlay (starts invisible)
    iconFrame.cooldownOverlay = iconFrame:CreateTexture(nil, "ARTWORK")
    iconFrame.cooldownOverlay:SetAllPoints(true)
    iconFrame.cooldownOverlay:SetTexture(0, 0, 0, 0.7) -- Dark overlay
    iconFrame.cooldownOverlay:Hide()
    
    -- Cooldown progress bar (vertical fill from bottom)
    iconFrame.cooldownBar = iconFrame:CreateTexture(nil, "OVERLAY")
    iconFrame.cooldownBar:SetPoint("BOTTOMLEFT", iconFrame, "BOTTOMLEFT", 0, 0)
    iconFrame.cooldownBar:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 0, 0)
    iconFrame.cooldownBar:SetHeight(26)  -- Updated to match new icon size
    iconFrame.cooldownBar:SetTexture(0.8, 0.1, 0.1, 0.8) -- Red cooldown bar
    iconFrame.cooldownBar:Hide()
    
    -- Timer text overlay
    iconFrame.timerText = iconFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    iconFrame.timerText:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
    iconFrame.timerText:SetText("")
    iconFrame.timerText:SetTextColor(1, 1, 1)
    iconFrame.timerText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    
    -- No border - clean icons without extra visual elements
    
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
function ICHataunt:ToggleTracker()
    if self.frame and self.frame:IsVisible() then
        self:HideTracker()
    else
        self:ShowTracker()
    end
end

function ICHataunt:ShowTracker()
    if not self.frame then
        self:CreateUI()
    end
    self.frame:Show()
    self.forceVisible = true  -- Flag to keep tracker visible even without taunters
    self:RefreshRoster()
    if ICHatauntDB.debugMode then
        print("ICHataunt: Tracker shown")
    end
end

function ICHataunt:HideTracker()
    if self.frame then
        self.frame:Hide()
        self.forceVisible = false  -- Clear force visible flag
        if ICHatauntDB.debugMode then
            print("ICHataunt: Tracker hidden")
        end
    end
end

-- Debug functions to catch all combat events
function ICHataunt:RegisterAllCombatEvents()
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

function ICHataunt:UnregisterAllCombatEvents()
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

-- Sync
function ICHataunt:BroadcastOrder()
    local serialized = ""
    for i, name in ipairs(self.order) do
        if i > 1 then serialized = serialized .. "," end
        serialized = serialized .. name
    end
    SendAddonMessage("ICHAT", serialized, "RAID")
end

function ICHataunt:ReceiveOrder(msg, sender)
    if sender == UnitName("player") then return end
    self.order = {}
    for name in gfind(msg, "([^,]+)") do
        table.insert(self.order, name)
    end
    ICHatauntDB.taunterOrder = self.order
    self:RebuildList()
end

function ICHataunt:ReceiveTaunters(msg)
    local list = {}
    for name in gfind(msg, "([^,]+)") do 
        list[name] = true 
    end
    ICHatauntDB.taunters = list
    self.taunters = list
    self:RefreshRoster()
end

-- Two-panel taunter selection UI
local function ShowTaunterPopup()
    if not ICHataunt.taunterUI then
        local f = CreateFrame("Frame", "ICHatauntTaunterUI", UIParent)
        f:SetWidth(600)
        f:SetHeight(400)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        f:SetFrameStrata("DIALOG")  -- Ensure config window appears above other UI elements
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", 
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() this:StartMoving() end)
        f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

        -- Title
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", f, "TOP", 0, -15)
        title:SetText("ICHataunt - Select Taunters")
        
        local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        subtitle:SetPoint("TOP", title, "BOTTOM", 0, -5)
        subtitle:SetText("Check players who should be tracked as taunters")

        -- LEFT PANEL: Raid/Party Members
        local leftPanel = CreateFrame("Frame", nil, f)
        leftPanel:SetWidth(260)
        leftPanel:SetHeight(300)
        leftPanel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -60)
        leftPanel:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 16,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        leftPanel:SetBackdropColor(0, 0, 0, 0.3)
        
        local leftTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        leftTitle:SetPoint("TOP", leftPanel, "TOP", 0, -10)
        leftTitle:SetText("Raid/Party")
        leftTitle:SetTextColor(1, 0.82, 0)
        
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
        rightPanel:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 16,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        rightPanel:SetBackdropColor(0, 0, 0, 0.3)
        
        local rightTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rightTitle:SetPoint("TOP", rightPanel, "TOP", 0, -10)
        rightTitle:SetText("Taunt Order")
        rightTitle:SetTextColor(1, 0.82, 0)
        
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
                local tauntClasses = ICHataunt_GetAllTauntClasses()
                if tauntClasses[class] then
                    local entry = CreateFrame("Frame", nil, f.leftScrollChild)
                    entry:SetWidth(240)
                    entry:SetHeight(20)
                    entry:SetPoint("TOPLEFT", f.leftScrollChild, "TOPLEFT", 0, yOffset)
                    
                    -- Player name with class color
                    local nameText = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    nameText:SetPoint("LEFT", entry, "LEFT", 0, 0)
                    nameText:SetText(name)
                    local r, g, b = unpack(ICHataunt:GetClassColor(class))
                    nameText:SetTextColor(r, g, b)
                    
                    -- + button
                    local addBtn = CreateFrame("Button", nil, entry, "UIPanelButtonTemplate")
                    addBtn:SetWidth(20)
                    addBtn:SetHeight(20)
                    addBtn:SetPoint("RIGHT", entry, "RIGHT", 0, 0)
                    addBtn:SetText("+")
                    
                    -- Capture the name value locally to avoid closure issues
                    local playerName = name
                    addBtn:SetScript("OnClick", function()
                        -- Ensure ICHatauntDB exists and has proper structure
                        if not ICHatauntDB then
                            ICHatauntDB = {
                                taunterOrder = {},
                                taunters = {},
                                showInRaidOnly = true,
                                position = { x = 0, y = 0 }
                            }
                        end
                        if not ICHatauntDB.taunterOrder then
                            ICHatauntDB.taunterOrder = {}
                        end
                        if not ICHatauntDB.taunters then
                            ICHatauntDB.taunters = {}
                        end
                        
                        -- Add to taunt order if not already there
                        local found = false
                        for _, orderName in ipairs(ICHatauntDB.taunterOrder) do
                            if orderName == playerName then
                                found = true
                                break
                            end
                        end
                        
                        if not found then
                            table.insert(ICHatauntDB.taunterOrder, playerName)
                            ICHatauntDB.taunters[playerName] = true
                            -- Safely update local references
                            ICHataunt.taunters = ICHatauntDB.taunters or {}
                            ICHataunt.order = ICHatauntDB.taunterOrder or {}
                            
                            -- Safely refresh UI
                            if RefreshPanels then
                                RefreshPanels()
                            end
                            if ICHataunt.RefreshRoster then
                                ICHataunt:RefreshRoster()
                            end
                            if ICHatauntDB.debugMode then
                                print("ICHataunt: Added " .. playerName .. " to taunt order")
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
            
            -- RIGHT PANEL: Show taunt order with - buttons
            yOffset = -5
            for i, name in ipairs(ICHatauntDB.taunterOrder) do
                local entry = CreateFrame("Frame", nil, f.rightScrollChild)
                entry:SetWidth(240)
                entry:SetHeight(20)
                entry:SetPoint("TOPLEFT", f.rightScrollChild, "TOPLEFT", 0, yOffset)
                
                -- Order number
                local orderText = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                orderText:SetPoint("LEFT", entry, "LEFT", 0, 0)
                orderText:SetText(i .. ".")
                orderText:SetTextColor(1, 0.82, 0)
                
                -- Player name with class color
                local nameText = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                nameText:SetPoint("LEFT", orderText, "RIGHT", 10, 0)
                nameText:SetText(name)
                local class = ICHataunt:GetPlayerClass(name)
                if class then
                    local r, g, b = unpack(ICHataunt:GetClassColor(class))
                    nameText:SetTextColor(r, g, b)
                else
                    nameText:SetTextColor(1, 1, 1)
                end
                
                -- - button
                local removeBtn = CreateFrame("Button", nil, entry, "UIPanelButtonTemplate")
                removeBtn:SetWidth(20)
                removeBtn:SetHeight(20)
                removeBtn:SetPoint("RIGHT", entry, "RIGHT", 0, 0)
                removeBtn:SetText("-")
                
                -- Capture the name value locally to avoid closure issues
                local playerName = name
                removeBtn:SetScript("OnClick", function()
                    -- Ensure ICHatauntDB exists and has proper structure
                    if not ICHatauntDB then
                        ICHatauntDB = {
                            taunterOrder = {},
                            taunters = {},
                            showInRaidOnly = true,
                            position = { x = 0, y = 0 }
                        }
                    end
                    if not ICHatauntDB.taunterOrder then
                        ICHatauntDB.taunterOrder = {}
                    end
                    if not ICHatauntDB.taunters then
                        ICHatauntDB.taunters = {}
                    end
                    
                    -- Remove from taunt order
                    for j, orderName in ipairs(ICHatauntDB.taunterOrder) do
                        if orderName == playerName then
                            table.remove(ICHatauntDB.taunterOrder, j)
                            break
                        end
                    end
                    
                    -- Remove from taunters if not in order anymore
                    local stillInOrder = false
                    if ICHatauntDB.taunterOrder then
                        for _, orderName in ipairs(ICHatauntDB.taunterOrder) do
                            if orderName == playerName then
                                stillInOrder = true
                                break
                            end
                        end
                    end
                    if not stillInOrder then
                        -- Debug output to trace the error
                        if ICHatauntDB.debugMode then
                            print("Debug: Attempting to remove " .. tostring(playerName) .. " from taunters")
                            print("Debug: ICHatauntDB exists: " .. tostring(ICHatauntDB ~= nil))
                            if ICHatauntDB then
                                print("Debug: ICHatauntDB.taunters exists: " .. tostring(ICHatauntDB.taunters ~= nil))
                            end
                        end
                        
                        -- Ensure taunters table exists before modifying
                        if not ICHatauntDB or not ICHatauntDB.taunters then
                            if not ICHatauntDB then
                                ICHatauntDB = {}
                            end
                            ICHatauntDB.taunters = {}
                            if ICHatauntDB.debugMode then
                                print("Debug: Recreated taunters table")
                            end
                        end
                        
                        -- Safe removal
                        if ICHatauntDB.taunters then
                            ICHatauntDB.taunters[playerName] = nil
                            if ICHatauntDB.debugMode then
                                print("Debug: Successfully removed " .. tostring(playerName))
                            end
                        end
                    end
                    
                    -- Safely update local references
                    ICHataunt.taunters = ICHatauntDB.taunters or {}
                    ICHataunt.order = ICHatauntDB.taunterOrder or {}
                    
                    -- Safely refresh UI
                    if RefreshPanels then
                        RefreshPanels()
                    end
                    if ICHataunt.RefreshRoster then
                        ICHataunt:RefreshRoster()
                    end
                    
                    if ICHatauntDB.debugMode then
                        print("ICHataunt: Removed " .. playerName .. " from taunt order")
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

        -- Close button
        local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        close:SetWidth(80)
        close:SetHeight(22)
        close:SetPoint("BOTTOM", f, "BOTTOM", 0, 15)
        close:SetText("Close")
        close:SetScript("OnClick", function()
            f:Hide()
        end)

        f:Hide()
        ICHataunt.taunterUI = f
    end
    
    -- Refresh panels and show
    ICHataunt.taunterUI.RefreshPanels()
    ICHataunt.taunterUI:Show()
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
            ICHataunt:ShowTracker()
        elseif action == "hide" then
            ICHataunt:HideTracker()
        else
            ICHataunt:ToggleTracker()
        end
    elseif msg == "show" then
        ICHataunt:ShowTracker()
    elseif msg == "hide" then
        ICHataunt:HideTracker()
    elseif msg == "toggle" then
        ICHataunt:ToggleTracker()
    elseif msg == "test" then
        -- Test cooldown on yourself
        local playerName = UnitName("player")
        local playerClass = UnitClass("player")
        local spells = ICHataunt_GetSpellsByClass(playerClass)
        for spellID in pairs(spells) do
            ICHataunt:StartCooldownFor(playerName, spellID, false)
            print("ICHataunt: Testing cooldown for " .. playerName)
            break -- Just test first spell
        end
    elseif msg == "testresist" then
        -- Test resist on yourself
        local playerName = UnitName("player")
        local playerClass = UnitClass("player")
        local spells = ICHataunt_GetSpellsByClass(playerClass)
        for spellID in pairs(spells) do
            ICHataunt:StartCooldownFor(playerName, spellID, true)
            print("ICHataunt: Testing RESIST for " .. playerName)
            break -- Just test first spell
        end
    elseif msg == "debug" then
        ICHatauntDB.debugMode = not ICHatauntDB.debugMode
        print("ICHataunt: Debug mode " .. (ICHatauntDB.debugMode and "enabled" or "disabled"))
    elseif msg == "debugall" then
        ICHatauntDB.debugAllEvents = not ICHatauntDB.debugAllEvents
        if ICHatauntDB.debugAllEvents then
            ICHataunt:RegisterAllCombatEvents()
        else
            ICHataunt:UnregisterAllCombatEvents()
        end
        print("ICHataunt: Debug ALL events " .. (ICHatauntDB.debugAllEvents and "enabled" or "disabled"))
    elseif msg == "reset" or msg == "center" then
        -- Reset position to screen center
        ICHatauntDB.position.x = 0
        ICHatauntDB.position.y = 0
        if ICHataunt.frame then
            ICHataunt.frame:ClearAllPoints()
            ICHataunt.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            print("ICHataunt: Position reset to screen center")
        else
            print("ICHataunt: Position will be reset when tracker is next shown")
        end
    elseif msg == "help" then
        print("ICHataunt Commands:")
        print("/it - Open config window")
        print("/it bar show - Show tracker bar")
        print("/it bar hide - Hide tracker bar")
        print("/it config - Open taunter selection")
        print("/it reset - Reset tracker position to center")
        print("/it test - Test cooldown (for debugging)")
        print("/it testresist - Test resist (for debugging)")
        print("/it debug - Toggle debug mode (shows combat messages)")
        print("/it help - Show this help")
    else
        print("ICHataunt: Unknown command. Use '/it help' for help.")
    end
end