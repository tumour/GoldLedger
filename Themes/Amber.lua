--[[
    GoldLedger Theme: Warcraft
    Классический стиль интерфейса WoW — тёмный камень, золотые рамки, пергаментные тона
]]

local ADDON_NAME, ns = ...
local Themes = ns.GoldLedger:GetModule("Themes")

Themes:RegisterTheme("amber", {
    name = "Warcraft",

    -- Textures — стандартные WoW
    BG_TEXTURE   = "Interface\\Tooltips\\UI-Tooltip-Background",
    EDGE_TEXTURE = "Interface\\Tooltips\\UI-Tooltip-Border",

    -- Frame chrome — тёмный камень/кожа как в WoW окнах
    FRAME_BG     = { 0.07, 0.07, 0.07, 0.95 },
    TITLE_BG     = { 0.15, 0.12, 0.08, 1 },
    BORDER       = { 0.45, 0.35, 0.18, 0.9 },
    ROW_ALT      = { 0.14, 0.12, 0.08, 0.30 },
    SEPARATOR    = { 0.40, 0.32, 0.16, 0.35 },
    SCROLL_BG    = { 0.05, 0.05, 0.04, 0.4 },
    CHART_BG     = { 0.04, 0.04, 0.03, 0.5 },
    CHART_GUIDE  = { 0.25, 0.20, 0.12, 0.25 },

    -- Cards — пергаментный оттенок
    CARD_BG      = { 0.12, 0.10, 0.07, 0.80 },
    CARD_BORDER  = { 0.50, 0.40, 0.20, 0.6 },
    CARD_TITLE   = { 0.80, 0.65, 0.30 },

    -- Text — как в стандартном WoW UI
    LABEL        = { 0.78, 0.70, 0.55 },
    HEADER       = { 1.00, 0.82, 0.00 },       -- |cffffd100 — стандартный золотой WoW
    TEXT_DIM     = { 0.60, 0.55, 0.42 },
    TEXT_MUTED   = { 0.50, 0.45, 0.35 },
    TEXT_TIME    = { 0.62, 0.56, 0.42 },
    TEXT_HINT    = { 0.72, 0.65, 0.50 },
    DAY_LABEL    = { 0.55, 0.48, 0.35 },
    GOLD_TEXT    = { 1.00, 0.82, 0.00 },        -- стандартный WoW gold
    TEXT_WHITE   = { 1.00, 1.00, 1.00 },
    ZERO_VALUE   = { 0.40, 0.36, 0.28 },

    -- Data colors — как в WoW (зелёный доход, красный расход)
    INCOME       = { 0.00, 1.00, 0.00 },        -- стандартный WoW зелёный
    EXPENSE      = { 1.00, 0.10, 0.10 },        -- стандартный WoW красный
    BALANCE_POS  = { 1.00, 0.82, 0.00 },
    BALANCE_NEG  = { 1.00, 0.10, 0.10 },

    -- Goal bar — золотой как полоска XP
    GOAL_BG      = { 0.08, 0.07, 0.05 },
    GOAL_FILL    = { 0.80, 0.60, 0.00 },
    GOAL_DONE    = { 0.00, 1.00, 0.00 },

    -- Buttons — тёмная кожа с золотыми рамками
    BTN_BG          = { 0.15, 0.12, 0.08, 1 },
    BTN_BG_HOVER    = { 0.25, 0.20, 0.12, 1 },
    BTN_BORDER      = { 0.50, 0.40, 0.20, 1 },
    BTN_ACTIVE      = { 0.35, 0.28, 0.10, 0.8 },
    BTN_INACTIVE    = { 0.12, 0.10, 0.07, 0.5 },

    -- Filter buttons
    FILTER_INACTIVE_BG   = { 0.08, 0.07, 0.05, 0.4 },
    FILTER_INACTIVE_TEXT = { 0.48, 0.42, 0.30 },

    -- Accent button — золотой акцент
    ACCENT_BTN_BG       = { 0.28, 0.22, 0.08, 1 },
    ACCENT_BTN_BG_HOVER = { 0.40, 0.30, 0.10, 1 },
    ACCENT_BTN_BORDER   = { 0.65, 0.50, 0.15, 1 },
    ACCENT_BTN_TEXT     = { 1.00, 0.82, 0.00 },

    -- Source colors — яркие, как цвета качества предметов в WoW
    SOURCE_COLORS = {
        vendor  = { 0.50, 0.75, 1.00 },         -- голубой
        repair  = { 0.90, 0.50, 0.25 },         -- оранжевый
        ah      = { 1.00, 0.82, 0.00 },         -- золотой
        mail    = { 0.64, 0.21, 0.93 },         -- epic purple
        quest   = { 1.00, 1.00, 0.00 },         -- жёлтый как квест
        loot    = { 0.00, 1.00, 0.00 },         -- зелёный
        trade   = { 1.00, 0.50, 0.00 },         -- оранжевый legendary
        unknown = { 0.62, 0.62, 0.62 },         -- серый poor
    },
})
