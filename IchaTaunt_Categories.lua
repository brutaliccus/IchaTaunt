-- IchaTaunt Categories Module
-- Handles category-based organization: Tanks, Healers, Interrupters, Other
-- Each category can have its own linked/unlinkable window

IchaTaunt_Categories = {}

-- Category definitions
IchaTaunt_Categories.CATEGORY_ORDER = {"tanks", "healers", "interrupters", "other"}
IchaTaunt_Categories.CATEGORY_NAMES = {
    tanks = "Tanks",
    healers = "Healers",
    interrupters = "Interrupters",
    other = "Other",
}
IchaTaunt_Categories.CATEGORY_COLORS = {
    tanks = {0.8, 0.4, 0.2},      -- Orange-brown
    healers = {0.2, 0.8, 0.2},    -- Green
    interrupters = {0.6, 0.4, 0.8}, -- Purple
    other = {0.6, 0.6, 0.6},      -- Gray
}

-- Initialize category data in SavedVariables
function IchaTaunt_Categories:InitializeDB()
    IchaTauntDB.categories = IchaTauntDB.categories or {}

    for _, cat in ipairs(self.CATEGORY_ORDER) do
        IchaTauntDB.categories[cat] = IchaTauntDB.categories[cat] or {
            enabled = true,
            members = {},      -- {playerName = true}
            position = {x = 0, y = 0},
            linked = true,     -- true = attached to main frame
            collapsed = false, -- true = header only, no bars
        }
    end

    -- Migrate old taunters to "tanks" category if categories are empty
    if IchaTauntDB.taunters then
        local hasAnyCategoryMembers = false
        for _, cat in ipairs(self.CATEGORY_ORDER) do
            if next(IchaTauntDB.categories[cat].members) then
                hasAnyCategoryMembers = true
                break
            end
        end

        if not hasAnyCategoryMembers then
            -- Migrate existing taunters to tanks
            for name, _ in pairs(IchaTauntDB.taunters) do
                IchaTauntDB.categories.tanks.members[name] = true
            end
        end
    end
end

-- Get all members in a category
function IchaTaunt_Categories:GetCategoryMembers(category)
    if not IchaTauntDB.categories or not IchaTauntDB.categories[category] then
        return {}
    end
    return IchaTauntDB.categories[category].members or {}
end

-- Add a player to a category
function IchaTaunt_Categories:AddToCategory(playerName, category)
    if not IchaTauntDB.categories[category] then return false end

    -- Remove from all other categories first
    for _, cat in ipairs(self.CATEGORY_ORDER) do
        if IchaTauntDB.categories[cat].members then
            IchaTauntDB.categories[cat].members[playerName] = nil
        end
    end

    -- Add to specified category
    IchaTauntDB.categories[category].members[playerName] = true

    -- Also add to the main taunters list (for backward compatibility)
    IchaTauntDB.taunters[playerName] = true

    return true
end

-- Remove a player from a category
function IchaTaunt_Categories:RemoveFromCategory(playerName, category)
    if not IchaTauntDB.categories[category] then return false end

    IchaTauntDB.categories[category].members[playerName] = nil

    -- Check if player is in any category; if not, remove from main taunters list
    local inAnyCategory = false
    for _, cat in ipairs(self.CATEGORY_ORDER) do
        if IchaTauntDB.categories[cat].members and IchaTauntDB.categories[cat].members[playerName] then
            inAnyCategory = true
            break
        end
    end

    if not inAnyCategory then
        IchaTauntDB.taunters[playerName] = nil
        -- Also remove from taunterOrder
        local newOrder = {}
        for _, name in ipairs(IchaTauntDB.taunterOrder or {}) do
            if name ~= playerName then
                table.insert(newOrder, name)
            end
        end
        IchaTauntDB.taunterOrder = newOrder
    end

    return true
end

-- Get which category a player is in
function IchaTaunt_Categories:GetPlayerCategory(playerName)
    for _, cat in ipairs(self.CATEGORY_ORDER) do
        if IchaTauntDB.categories[cat] and IchaTauntDB.categories[cat].members then
            if IchaTauntDB.categories[cat].members[playerName] then
                return cat
            end
        end
    end
    return nil
end

-- Check if a category is enabled
function IchaTaunt_Categories:IsCategoryEnabled(category)
    if not IchaTauntDB.categories or not IchaTauntDB.categories[category] then
        return false
    end
    return IchaTauntDB.categories[category].enabled
end

-- Toggle category enabled state
function IchaTaunt_Categories:SetCategoryEnabled(category, enabled)
    if not IchaTauntDB.categories[category] then return end
    IchaTauntDB.categories[category].enabled = enabled
end

-- Check if a category is collapsed
function IchaTaunt_Categories:IsCategoryCollapsed(category)
    if not IchaTauntDB.categories or not IchaTauntDB.categories[category] then
        return false
    end
    return IchaTauntDB.categories[category].collapsed
end

-- Toggle category collapsed state
function IchaTaunt_Categories:SetCategoryCollapsed(category, collapsed)
    if not IchaTauntDB.categories[category] then return end
    IchaTauntDB.categories[category].collapsed = collapsed
end

-- Check if a category is linked to main frame
function IchaTaunt_Categories:IsCategoryLinked(category)
    if not IchaTauntDB.categories or not IchaTauntDB.categories[category] then
        return true -- default to linked
    end
    return IchaTauntDB.categories[category].linked
end

-- Set category link state
function IchaTaunt_Categories:SetCategoryLinked(category, linked)
    if not IchaTauntDB.categories[category] then return end
    IchaTauntDB.categories[category].linked = linked
end

-- Get ordered list of players by category
function IchaTaunt_Categories:GetOrderedByCategory()
    local result = {}

    for _, cat in ipairs(self.CATEGORY_ORDER) do
        if self:IsCategoryEnabled(cat) then
            local members = self:GetCategoryMembers(cat)
            local catPlayers = {}

            -- Use taunterOrder to maintain ordering within categories
            for _, name in ipairs(IchaTauntDB.taunterOrder or {}) do
                if members[name] then
                    table.insert(catPlayers, name)
                end
            end

            if table.getn(catPlayers) > 0 then
                result[cat] = catPlayers
            end
        end
    end

    return result
end

-- Count members in a category
function IchaTaunt_Categories:CountCategoryMembers(category)
    local count = 0
    local members = self:GetCategoryMembers(category)
    for _ in pairs(members) do
        count = count + 1
    end
    return count
end

-- Get the display name for a category
function IchaTaunt_Categories:GetCategoryDisplayName(category)
    return self.CATEGORY_NAMES[category] or category
end

-- Get the color for a category
function IchaTaunt_Categories:GetCategoryColor(category)
    return self.CATEGORY_COLORS[category] or {0.8, 0.8, 0.8}
end
