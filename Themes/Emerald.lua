--[[
    GoldLedger Theme: Emerald
    Тёмный фон с зелёными/изумрудными акцентами
]]

local ADDON_NAME, ns = ...
local Themes = ns.GoldLedger:GetModule("Themes")

Themes:RegisterTheme("emerald", {
    name = "Emerald",

    -- Textures
    BG_TEXTURE   = "Interface\\Tooltips\\UI-Tooltip-Background",
    EDGE_TEXTURE = "Interface\\Tooltips\\UI-Tooltip-Border",

    -- Frame chrome — тёмный с зелёным подтоном
    FRAME_BG     = { 0.04, 0.07, 0.05, 0.96 },
    TITLE_BG     = { 0.06, 0.12, 0.08, 1 },
    BORDER       = { 0.15, 0.32, 0.20, 0.8 },
    ROW_ALT      = { 0.06, 0.12, 0.08, 0.35 },
    SEPARATOR    = { 0.12, 0.25, 0.16, 0.4 },
    SCROLL_BG    = { 0.03, 0.06, 0.04, 0.4 },
    CHART_BG     = { 0.02, 0.05, 0.03, 0.5 },
    CHART_GUIDE  = { 0.12, 0.22, 0.14, 0.3 },

    -- Cards
    CARD_BG      = { 0.06, 0.12, 0.08, 0.85 },
    CARD_BORDER  = { 0.18, 0.38, 0.24, 0.5 },
    CARD_TITLE   = { 0.35, 0.60, 0.40 },

    -- Text
    LABEL        = { 0.55, 0.68, 0.58 },
    HEADER       = { 0.50, 0.85, 0.55 },
    TEXT_DIM     = { 0.40, 0.52, 0.42 },
    TEXT_MUTED   = { 0.32, 0.44, 0.35 },
    TEXT_TIME    = { 0.42, 0.55, 0.45 },
    TEXT_HINT    = { 0.55, 0.68, 0.58 },
    DAY_LABEL    = { 0.38, 0.50, 0.40 },
    GOLD_TEXT    = { 1.00, 0.90, 0.35 },
    TEXT_WHITE   = { 0.90, 0.96, 0.91 },
    ZERO_VALUE   = { 0.28, 0.38, 0.30 },

    -- Data colors
    INCOME       = { 0.30, 0.92, 0.45 },
    EXPENSE      = { 0.95, 0.40, 0.40 },
    BALANCE_POS  = { 0.50, 0.95, 0.60 },
    BALANCE_NEG  = { 0.95, 0.40, 0.40 },

    -- Goal bar — изумрудный
    GOAL_BG      = { 0.06, 0.12, 0.08 },
    GOAL_FILL    = { 0.18, 0.72, 0.38 },
    GOAL_DONE    = { 0.30, 0.92, 0.45 },

    -- Buttons
    BTN_BG          = { 0.08, 0.16, 0.10, 1 },
    BTN_BG_HOVER    = { 0.12, 0.24, 0.15, 1 },
    BTN_BORDER      = { 0.20, 0.38, 0.24, 1 },
    BTN_ACTIVE      = { 0.14, 0.40, 0.22, 0.7 },
    BTN_INACTIVE    = { 0.08, 0.16, 0.10, 0.5 },

    -- Filter buttons
    FILTER_INACTIVE_BG   = { 0.05, 0.10, 0.06, 0.4 },
    FILTER_INACTIVE_TEXT = { 0.30, 0.44, 0.33 },

    -- Accent button — яркий изумруд
    ACCENT_BTN_BG       = { 0.10, 0.30, 0.16, 1 },
    ACCENT_BTN_BG_HOVER = { 0.14, 0.40, 0.22, 1 },
    ACCENT_BTN_BORDER   = { 0.22, 0.55, 0.30, 1 },
    ACCENT_BTN_TEXT     = { 0.45, 0.90, 0.55 },

    -- Source colors
    SOURCE_COLORS = {
        vendor  = { 0.45, 0.80, 0.95 },
        repair  = { 0.92, 0.55, 0.30 },
        ah      = { 1.00, 0.85, 0.30 },
        mail    = { 0.70, 0.55, 0.90 },
        quest   = { 0.95, 0.90, 0.35 },
        loot    = { 0.35, 0.92, 0.50 },
        trade   = { 1.00, 0.55, 0.35 },
        unknown = { 0.45, 0.55, 0.48 },
    },
})
