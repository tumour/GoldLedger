--[[
    GoldLedger Theme: Dashboard Cards
    Тёмный фон с синими/фиолетовыми акцентами, яркие неоновые данные
]]

local ADDON_NAME, ns = ...
local Themes = ns.GoldLedger:GetModule("Themes")

Themes:RegisterTheme("dashboard_cards", {
    name = "Dashboard Cards",

    -- Textures
    BG_TEXTURE   = "Interface\\Tooltips\\UI-Tooltip-Background",
    EDGE_TEXTURE = "Interface\\Tooltips\\UI-Tooltip-Border",

    -- Frame chrome — очень тёмный с синим подтоном
    FRAME_BG     = { 0.04, 0.05, 0.10, 0.96 },
    TITLE_BG     = { 0.06, 0.08, 0.15, 1 },
    BORDER       = { 0.15, 0.20, 0.40, 0.8 },
    ROW_ALT      = { 0.08, 0.10, 0.18, 0.35 },
    SEPARATOR    = { 0.15, 0.20, 0.35, 0.4 },
    SCROLL_BG    = { 0.03, 0.04, 0.08, 0.4 },
    CHART_BG     = { 0.02, 0.03, 0.06, 0.5 },
    CHART_GUIDE  = { 0.15, 0.20, 0.30, 0.3 },

    -- Cards — заметно светлее фона, с фиолетовым оттенком
    CARD_BG      = { 0.08, 0.09, 0.18, 0.85 },
    CARD_BORDER  = { 0.22, 0.26, 0.50, 0.5 },
    CARD_TITLE   = { 0.35, 0.42, 0.70 },

    -- Text
    LABEL        = { 0.55, 0.58, 0.72 },
    HEADER       = { 0.60, 0.78, 1.00 },
    TEXT_DIM     = { 0.40, 0.44, 0.58 },
    TEXT_MUTED   = { 0.32, 0.36, 0.48 },
    TEXT_TIME    = { 0.42, 0.46, 0.60 },
    TEXT_HINT    = { 0.55, 0.60, 0.75 },
    DAY_LABEL    = { 0.38, 0.42, 0.55 },
    GOLD_TEXT    = { 1.00, 0.88, 0.30 },
    TEXT_WHITE   = { 0.92, 0.94, 1.00 },
    ZERO_VALUE   = { 0.28, 0.32, 0.42 },

    -- Data colors — яркие неоновые
    INCOME       = { 0.20, 0.83, 0.46 },
    EXPENSE      = { 0.98, 0.44, 0.52 },
    BALANCE_POS  = { 0.45, 0.85, 1.00 },
    BALANCE_NEG  = { 0.98, 0.44, 0.52 },

    -- Goal bar — фиолетовый
    GOAL_BG      = { 0.08, 0.09, 0.16 },
    GOAL_FILL    = { 0.39, 0.40, 0.95 },
    GOAL_DONE    = { 0.20, 0.83, 0.46 },

    -- Buttons — с фиолетовым оттенком
    BTN_BG          = { 0.10, 0.12, 0.22, 1 },
    BTN_BG_HOVER    = { 0.16, 0.18, 0.32, 1 },
    BTN_BORDER      = { 0.25, 0.28, 0.48, 1 },
    BTN_ACTIVE      = { 0.24, 0.26, 0.55, 0.7 },
    BTN_INACTIVE    = { 0.10, 0.12, 0.22, 0.5 },

    -- Filter buttons
    FILTER_INACTIVE_BG   = { 0.06, 0.08, 0.14, 0.4 },
    FILTER_INACTIVE_TEXT = { 0.32, 0.36, 0.50 },

    -- Accent button — индиго/фиолетовый
    ACCENT_BTN_BG       = { 0.20, 0.22, 0.50, 1 },
    ACCENT_BTN_BG_HOVER = { 0.28, 0.30, 0.60, 1 },
    ACCENT_BTN_BORDER   = { 0.35, 0.38, 0.70, 1 },
    ACCENT_BTN_TEXT     = { 0.65, 0.70, 1.00 },

    -- Source colors — яркие насыщенные
    SOURCE_COLORS = {
        vendor  = { 0.45, 0.72, 1.00 },
        repair  = { 0.92, 0.55, 0.30 },
        ah      = { 1.00, 0.82, 0.25 },
        mail    = { 0.70, 0.50, 0.95 },
        quest   = { 0.95, 0.88, 0.30 },
        loot    = { 0.30, 0.88, 0.45 },
        trade   = { 1.00, 0.50, 0.30 },
        unknown = { 0.45, 0.48, 0.58 },
    },
})
