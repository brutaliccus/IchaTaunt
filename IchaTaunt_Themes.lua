-- IchaTaunt Theme Configuration
-- This file contains all visual theme definitions
-- You can add custom themes here

IchaTaunt_Themes = {
    -- Default WoW Theme
    ["default"] = {
        name = "Default WoW",
        tracker = {
            backdrop = {
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 }
            },
            bgColor = { 0.1, 0.1, 0.1, 0.8 },
            borderColor = { 0.6, 0.6, 0.6, 1 },
            orderTextColor = { 1, 0.82, 0 },
            timerTextColor = { 1, 1, 1 },
            resistTextColor = { 1, 0, 0 },
            cooldownBarColor = { 0.8, 0.1, 0.1, 0.8 },
            cooldownOverlayAlpha = 0.7,
            iconBorder = true,
            iconBorderColor = { 0.3, 0.3, 0.3, 1 },
        },
        config = {
            backdrop = {
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true, tileSize = 32, edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 }
            },
            panelBackdrop = {
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 8, edgeSize = 16,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            },
            bgColor = { 0, 0, 0, 0.5 },
            panelBgColor = { 0, 0, 0, 0.3 },
            titleColor = { 1, 0.82, 0 },
        },
    },

    -- Dark Theme
    ["dark"] = {
        name = "Dark",
        tracker = {
            backdrop = {
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 }
            },
            bgColor = { 0.05, 0.05, 0.05, 0.95 },
            borderColor = { 0.2, 0.2, 0.2, 1 },
            orderTextColor = { 0.9, 0.7, 0.3 },
            timerTextColor = { 1, 1, 1 },
            resistTextColor = { 1, 0.2, 0.2 },
            cooldownBarColor = { 0.6, 0.1, 0.1, 0.9 },
            cooldownOverlayAlpha = 0.8,
            iconBorder = true,
            iconBorderColor = { 0.15, 0.15, 0.15, 1 },
        },
        config = {
            backdrop = {
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 }
            },
            panelBackdrop = {
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 8, edgeSize = 12,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            },
            bgColor = { 0.05, 0.05, 0.05, 0.95 },
            panelBgColor = { 0.08, 0.08, 0.08, 0.9 },
            titleColor = { 0.9, 0.7, 0.3 },
        },
    },

    -- ElvUI Style Theme
    ["elvui"] = {
        name = "ElvUI Style",
        tracker = {
            backdrop = {
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false, tileSize = 0, edgeSize = 1,
                insets = { left = 0, right = 0, top = 0, bottom = 0 }
            },
            bgColor = { 0.1, 0.1, 0.1, 0.9 },
            borderColor = { 0, 0, 0, 1 },
            orderTextColor = { 0.84, 0.75, 0.65 },
            timerTextColor = { 1, 1, 1 },
            resistTextColor = { 0.84, 0.2, 0.2 },
            cooldownBarColor = { 0.84, 0.2, 0.2, 0.9 },
            cooldownOverlayAlpha = 0.75,
            iconBorder = true,
            iconBorderColor = { 0, 0, 0, 1 },
        },
        config = {
            backdrop = {
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false, tileSize = 0, edgeSize = 2,
                insets = { left = 0, right = 0, top = 0, bottom = 0 }
            },
            panelBackdrop = {
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false, tileSize = 0, edgeSize = 1,
                insets = { left = 0, right = 0, top = 0, bottom = 0 }
            },
            bgColor = { 0.1, 0.1, 0.1, 0.95 },
            panelBgColor = { 0.06, 0.06, 0.06, 0.9 },
            titleColor = { 0.84, 0.75, 0.65 },
        },
    },
}

-- Helper function to list available themes
function IchaTaunt_GetThemeList()
    local themes = {}
    for key, data in pairs(IchaTaunt_Themes) do
        table.insert(themes, { key = key, name = data.name })
    end
    return themes
end
