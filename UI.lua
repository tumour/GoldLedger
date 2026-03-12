--[[
    GoldLedger: UI.lua
    Patterns: Strategy (форматирование), Observer (подписка на изменения)

    Компоненты:
    - Gold Formatter: стратегия форматирования (полный / краткий / цветной)
    - Minimap Button: перетаскиваемая кнопка на краю миникарты
    - Main Frame: окно с итогами и списком транзакций с источниками
]]

local ADDON_NAME, ns = ...
local GoldLedger = ns.GoldLedger
local L = ns.L

local UI = {}
GoldLedger:RegisterModule("UI", UI)

-------------------------------------------------------------------------------
-- Custom Goal Input Dialog (вместо StaticPopup — совместимость с AhUI)
-------------------------------------------------------------------------------
local goalDialog

local function CreateGoalDialog()
    local f = CreateFrame("Frame", "GoldLedgerGoalDialog", UIParent, "BackdropTemplate")
    f:SetSize(280, 130)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)

    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.1, 0.1, 0.12, 0.95)
    f:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)

    -- Заголовок
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -12)
    title:SetText(L["GOAL_INPUT_TEXT"])
    title:SetTextColor(1, 0.84, 0)

    -- EditBox
    local editBox = CreateFrame("EditBox", "GoldLedgerGoalEditBox", f, "InputBoxTemplate")
    editBox:SetSize(140, 22)
    editBox:SetPoint("TOP", title, "BOTTOM", 0, -10)
    editBox:SetAutoFocus(true)
    editBox:SetNumeric(true)
    editBox:SetMaxLetters(10)

    -- Кнопка OK
    local okBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    okBtn:SetSize(80, 22)
    okBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -4, 10)
    okBtn:SetText(ACCEPT)

    -- Кнопка Отмена
    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(80, 22)
    cancelBtn:SetPoint("BOTTOMLEFT", f, "BOTTOM", 4, 10)
    cancelBtn:SetText(CANCEL)

    -- Кнопка Сброс
    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetSize(80, 22)
    clearBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 34)
    clearBtn:SetText(L["GOAL_CLEAR_BTN"])

    -- Логика
    local function AcceptGoal()
        local text = editBox:GetText()
        local amount = tonumber(text)
        if amount and amount > 0 then
            local Data = GoldLedger:GetModule("Data")
            if Data then
                Data:SetGoal(amount * 10000)
                print("|cff00ff00GoldLedger:|r " .. L["GOAL_SET"]:format(amount .. L["GOLD_ABBR"]))
            end
        end
        f:Hide()
    end

    okBtn:SetScript("OnClick", AcceptGoal)
    editBox:SetScript("OnEnterPressed", AcceptGoal)
    editBox:SetScript("OnEscapePressed", function() f:Hide() end)
    cancelBtn:SetScript("OnClick", function() f:Hide() end)

    clearBtn:SetScript("OnClick", function()
        local Data = GoldLedger:GetModule("Data")
        if Data then
            Data:ClearGoal()
            print("|cff00ff00GoldLedger:|r " .. L["GOAL_CLEARED"])
        end
        f:Hide()
    end)

    f:SetScript("OnHide", function()
        if UI.RefreshGoal then UI:RefreshGoal() end
    end)

    f.editBox = editBox
    table.insert(UISpecialFrames, "GoldLedgerGoalDialog")

    goalDialog = f
    f:Hide()
    return f
end

local function ShowGoalDialog()
    if not goalDialog then CreateGoalDialog() end

    local Data = GoldLedger:GetModule("Data")
    if Data then
        local current = Data:GetGoal()
        if current > 0 then
            goalDialog.editBox:SetText(tostring(math.floor(current / 10000)))
        else
            goalDialog.editBox:SetText("")
        end
    end

    goalDialog:Show()
    goalDialog.editBox:HighlightText()
    goalDialog.editBox:SetFocus()
end

-------------------------------------------------------------------------------
-- Strategy Pattern: Gold Formatting
-------------------------------------------------------------------------------
local GoldFormatter = {}

function GoldFormatter.Full(copper)
    copper = math.abs(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100

    local parts = {}
    if gold > 0 then
        table.insert(parts, gold .. L["GOLD_ABBR"])
    end
    if silver > 0 then
        table.insert(parts, silver .. L["SILVER_ABBR"])
    end
    if cop > 0 or #parts == 0 then
        table.insert(parts, cop .. L["COPPER_ABBR"])
    end
    return table.concat(parts, " ")
end

function GoldFormatter.Short(copper)
    copper = math.abs(copper)
    local gold = copper / 10000
    if gold >= 1 then
        return ("%.1f%s"):format(gold, L["GOLD_ABBR"])
    else
        return ("%.0f%s"):format(copper / 100, L["SILVER_ABBR"])
    end
end

function GoldFormatter.Colored(copper, entryType)
    local text = GoldFormatter.Full(copper)
    if entryType == "income" then
        return "|cff00ff00+" .. text .. "|r"
    else
        return "|cffff4444-" .. text .. "|r"
    end
end

UI.GoldFormatter = GoldFormatter

-------------------------------------------------------------------------------
-- Source colors: цвет тега по источнику
-------------------------------------------------------------------------------
local SOURCE_COLORS = {
    vendor  = { 0.60, 0.80, 1.00 },  -- голубой
    repair  = { 0.85, 0.55, 0.30 },  -- медный/коричневый
    ah      = { 1.00, 0.84, 0.00 },  -- золотой
    mail    = { 0.80, 0.60, 1.00 },  -- фиолетовый
    quest   = { 1.00, 1.00, 0.40 },  -- жёлтый
    loot    = { 0.40, 1.00, 0.40 },  -- зелёный
    trade   = { 1.00, 0.60, 0.40 },  -- оранжевый
    unknown = { 0.55, 0.55, 0.55 },  -- серый
}

-------------------------------------------------------------------------------
-- Colors
-------------------------------------------------------------------------------
local COLORS = {
    FRAME_BG    = { 0.08, 0.08, 0.10, 0.94 },
    TITLE_BG    = { 0.12, 0.12, 0.15, 1 },
    BORDER      = { 0.25, 0.25, 0.30, 1 },
    ROW_ALT     = { 0.14, 0.14, 0.18, 0.5 },
    SEPARATOR   = { 0.30, 0.30, 0.35, 0.6 },
    INCOME      = { 0.30, 1.00, 0.30 },
    EXPENSE     = { 1.00, 0.35, 0.35 },
    BALANCE_POS = { 1.00, 0.84, 0.00 },
    BALANCE_NEG = { 1.00, 0.35, 0.35 },
    LABEL       = { 0.65, 0.65, 0.70 },
    HEADER      = { 1.00, 0.84, 0.00 },
    GOAL_BG     = { 0.12, 0.12, 0.16 },
    GOAL_FILL   = { 0.20, 0.60, 1.00 },
    GOAL_DONE   = { 0.30, 1.00, 0.30 },
}

-------------------------------------------------------------------------------
-- Minimap Button
-------------------------------------------------------------------------------
local minimapButton

local function CreateMinimapButton()
    local button = CreateFrame("Button", "GoldLedgerMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(56, 56)
    border:SetPoint("TOPLEFT")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(24, 24)
    background:SetPoint("CENTER")

    -- Позиционирование на краю миникарты
    local function UpdatePosition(angle)
        local rad = math.rad(angle)
        local radius = (Minimap:GetWidth() / 2) + 10
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER",
            math.cos(rad) * radius,
            math.sin(rad) * radius
        )
    end

    -- Dragging
    local isDragging = false
    button:RegisterForDrag("LeftButton")

    button:SetScript("OnDragStart", function() isDragging = true end)

    button:SetScript("OnDragStop", function()
        isDragging = false
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        local angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
        GoldLedgerDB.settings.minimapPos = angle
        UpdatePosition(angle)
    end)

    button:SetScript("OnUpdate", function()
        if isDragging then
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            UpdatePosition(math.deg(math.atan2(cy / scale - my, cx / scale - mx)))
        end
    end)

    button:SetScript("OnClick", function() UI:ToggleMainFrame() end)

    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L["TOOLTIP_TITLE"], 1, 0.84, 0)

        local Data = GoldLedger:GetModule("Data")
        if Data then
            local today = Data:GetDailySummary()
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["TOOLTIP_TODAY"], 1, 1, 1)
            GameTooltip:AddDoubleLine(L["HEADER_INCOME"], GoldFormatter.Full(today.income),
                COLORS.LABEL[1], COLORS.LABEL[2], COLORS.LABEL[3],
                COLORS.INCOME[1], COLORS.INCOME[2], COLORS.INCOME[3])
            GameTooltip:AddDoubleLine(L["HEADER_EXPENSE"], GoldFormatter.Full(today.expense),
                COLORS.LABEL[1], COLORS.LABEL[2], COLORS.LABEL[3],
                COLORS.EXPENSE[1], COLORS.EXPENSE[2], COLORS.EXPENSE[3])

            local month = Data:GetMonthlySummary()
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["TOOLTIP_MONTH"], 1, 1, 1)
            GameTooltip:AddDoubleLine(L["HEADER_INCOME"], GoldFormatter.Full(month.income),
                COLORS.LABEL[1], COLORS.LABEL[2], COLORS.LABEL[3],
                COLORS.INCOME[1], COLORS.INCOME[2], COLORS.INCOME[3])
            GameTooltip:AddDoubleLine(L["HEADER_EXPENSE"], GoldFormatter.Full(month.expense),
                COLORS.LABEL[1], COLORS.LABEL[2], COLORS.LABEL[3],
                COLORS.EXPENSE[1], COLORS.EXPENSE[2], COLORS.EXPENSE[3])
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["TOOLTIP_HINT"], 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local settings = GoldLedgerDB and GoldLedgerDB.settings
    UpdatePosition(settings and settings.minimapPos or 225)

    minimapButton = button
end

-------------------------------------------------------------------------------
-- Helpers: UI creation
-------------------------------------------------------------------------------

local function MakeSeparator(parent, yOffset)
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    sep:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
    sep:SetColorTexture(COLORS.SEPARATOR[1], COLORS.SEPARATOR[2], COLORS.SEPARATOR[3], COLORS.SEPARATOR[4])
    return sep
end

local function MakeSectionHeader(parent, text, yOffset)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, yOffset)
    label:SetText(text)
    label:SetTextColor(COLORS.HEADER[1], COLORS.HEADER[2], COLORS.HEADER[3])
    return label
end

local function MakeStatRow(parent, labelText, yOffset)
    local row = {}

    row.label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, yOffset)
    row.label:SetText(labelText)
    row.label:SetTextColor(COLORS.LABEL[1], COLORS.LABEL[2], COLORS.LABEL[3])

    row.value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.value:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -14, yOffset)
    row.value:SetJustifyH("RIGHT")

    function row:SetValue(text, r, g, b)
        self.value:SetText(text)
        if r then self.value:SetTextColor(r, g, b) end
    end

    return row
end

-------------------------------------------------------------------------------
-- Main Frame
-------------------------------------------------------------------------------
local mainFrame
local FRAME_WIDTH = 380
local FRAME_HEIGHT = 758
local activeFilter = "all"   -- Текущий фильтр источника транзакций
local activeChartPeriod = "7d" -- Текущий период графика: "7d", "30d", "all"
local CHART_HEIGHT = 100
local CHART_PADDING_LEFT = 14
local CHART_PADDING_RIGHT = 14

-------------------------------------------------------------------------------
-- Forward declarations
-------------------------------------------------------------------------------
local UpdateEntryRows
local UpdateChart

-------------------------------------------------------------------------------
-- Filter buttons update
-------------------------------------------------------------------------------
local function UpdateFilterButtons()
    if not mainFrame or not mainFrame.filterButtons then return end
    for _, btn in ipairs(mainFrame.filterButtons) do
        if btn.key == activeFilter then
            btn.bg:SetColorTexture(btn.color[1], btn.color[2], btn.color[3], 0.3)
            btn.text:SetTextColor(btn.color[1], btn.color[2], btn.color[3])
        else
            btn.bg:SetColorTexture(0.1, 0.1, 0.12, 0.5)
            btn.text:SetTextColor(0.4, 0.4, 0.45)
        end
    end
end

local function CreateMainFrame()
    local f = CreateFrame("Frame", "GoldLedgerMainFrame", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)

    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(COLORS.FRAME_BG[1], COLORS.FRAME_BG[2], COLORS.FRAME_BG[3], COLORS.FRAME_BG[4])
    f:SetBackdropBorderColor(COLORS.BORDER[1], COLORS.BORDER[2], COLORS.BORDER[3], COLORS.BORDER[4])

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetHeight(26)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    titleBar:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
    titleBar:SetBackdropColor(COLORS.TITLE_BG[1], COLORS.TITLE_BG[2], COLORS.TITLE_BG[3], COLORS.TITLE_BG[4])

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    title:SetText("|cffffd700GoldLedger|r")

    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Кнопка "Персонажи"
    local charsBtn = CreateFrame("Button", nil, titleBar, "BackdropTemplate")
    charsBtn:SetSize(76, 18)
    charsBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, -1)
    charsBtn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    charsBtn:SetBackdropColor(0.15, 0.15, 0.2, 1)
    charsBtn:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
    local charsBtnText = charsBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    charsBtnText:SetPoint("CENTER")
    charsBtnText:SetText(L["HEADER_CHARACTERS"])
    charsBtn:SetScript("OnClick", function() UI:ToggleCharsFrame() end)
    charsBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.25, 0.25, 0.3, 1) end)
    charsBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.15, 0.15, 0.2, 1) end)

    -- Кнопка "Экспорт"
    local exportBtn = CreateFrame("Button", nil, titleBar, "BackdropTemplate")
    exportBtn:SetSize(65, 18)
    exportBtn:SetPoint("RIGHT", charsBtn, "LEFT", -4, 0)
    exportBtn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    exportBtn:SetBackdropColor(0.15, 0.15, 0.2, 1)
    exportBtn:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
    local exportBtnText = exportBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    exportBtnText:SetPoint("CENTER")
    exportBtnText:SetText(L["EXPORT_BUTTON"])
    exportBtn:SetScript("OnClick", function() UI:ShowExportFrame() end)
    exportBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.25, 0.25, 0.3, 1) end)
    exportBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.15, 0.15, 0.2, 1) end)

    table.insert(UISpecialFrames, "GoldLedgerMainFrame")

    ---------------------------------------------------------------------------
    -- Layout: Sections
    ---------------------------------------------------------------------------
    local y = -38

    -- === На руках (текущая голда) ===
    local onHandLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    onHandLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 14, y)
    onHandLabel:SetText(L["HEADER_ON_HAND"])
    onHandLabel:SetTextColor(COLORS.LABEL[1], COLORS.LABEL[2], COLORS.LABEL[3])

    f.onHandValue = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.onHandValue:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, y)
    f.onHandValue:SetJustifyH("RIGHT")
    f.onHandValue:SetTextColor(1, 0.84, 0) -- золотой цвет

    y = y - 18
    MakeSeparator(f, y) ; y = y - 10

    -- === Сегодня ===
    MakeSectionHeader(f, L["HEADER_TODAY"], y)
    y = y - 18
    f.todayIncome  = MakeStatRow(f, L["HEADER_INCOME"], y)   ; y = y - 16
    f.todayExpense = MakeStatRow(f, L["HEADER_EXPENSE"], y)   ; y = y - 16
    f.todayBalance = MakeStatRow(f, L["HEADER_BALANCE"], y)   ; y = y - 10
    MakeSeparator(f, y) ; y = y - 10

    -- === Сессия ===
    MakeSectionHeader(f, L["HEADER_SESSION"], y)
    y = y - 18
    f.sessionIncome  = MakeStatRow(f, L["HEADER_INCOME"], y)   ; y = y - 16
    f.sessionExpense = MakeStatRow(f, L["HEADER_EXPENSE"], y)   ; y = y - 16
    f.sessionNet     = MakeStatRow(f, L["HEADER_NET"], y)       ; y = y - 10
    MakeSeparator(f, y) ; y = y - 10

    -- === Этот месяц ===
    MakeSectionHeader(f, L["HEADER_MONTH"], y)
    y = y - 18
    f.monthIncome  = MakeStatRow(f, L["HEADER_INCOME"], y)   ; y = y - 16
    f.monthExpense = MakeStatRow(f, L["HEADER_EXPENSE"], y)   ; y = y - 16
    f.monthBalance = MakeStatRow(f, L["HEADER_BALANCE"], y)   ; y = y - 10
    MakeSeparator(f, y) ; y = y - 10

    -- === Цель накопления ===
    MakeSectionHeader(f, L["HEADER_GOAL"], y)
    y = y - 16

    f.goalBarBg = f:CreateTexture(nil, "ARTWORK")
    f.goalBarBg:SetHeight(14)
    f.goalBarBg:SetPoint("TOPLEFT", f, "TOPLEFT", 18, y)
    f.goalBarBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, y)
    f.goalBarBg:SetColorTexture(COLORS.GOAL_BG[1], COLORS.GOAL_BG[2], COLORS.GOAL_BG[3], 1)

    f.goalBarFill = f:CreateTexture(nil, "ARTWORK", nil, 1)
    f.goalBarFill:SetHeight(14)
    f.goalBarFill:SetPoint("TOPLEFT", f.goalBarBg, "TOPLEFT", 0, 0)
    f.goalBarFill:SetWidth(1)
    f.goalBarFill:SetColorTexture(COLORS.GOAL_FILL[1], COLORS.GOAL_FILL[2], COLORS.GOAL_FILL[3], 0.8)

    f.goalText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.goalText:SetPoint("CENTER", f.goalBarBg, "CENTER", 0, 0)
    f.goalText:SetTextColor(1, 1, 1)

    f.goalEta = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.goalEta:SetPoint("TOPLEFT", f.goalBarBg, "BOTTOMLEFT", 0, -2)
    f.goalEta:SetTextColor(0.5, 0.5, 0.55)

    -- Кликабельная зона поверх бара: нажать → ввод цели
    local goalClickArea = CreateFrame("Button", nil, f)
    goalClickArea:SetPoint("TOPLEFT", f.goalBarBg, "TOPLEFT", 0, 0)
    goalClickArea:SetPoint("BOTTOMRIGHT", f.goalBarBg, "BOTTOMRIGHT", 0, 0)
    goalClickArea:SetScript("OnClick", function()
        ShowGoalDialog()
    end)
    goalClickArea:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["HEADER_GOAL"], 1, 0.84, 0)
        GameTooltip:AddLine(L["GOAL_CLICK_HINT"], 1, 1, 1)
        GameTooltip:Show()
    end)
    goalClickArea:SetScript("OnLeave", function() GameTooltip:Hide() end)

    y = y - 32
    MakeSeparator(f, y) ; y = y - 10

    -- === График по дням ===
    -- Заголовок
    MakeSectionHeader(f, L["HEADER_CHART"], y)

    -- Кнопки переключения периода (справа от заголовка)
    local CHART_PERIODS = {
        { key = "7d",  label = L["CHART_7D"] },
        { key = "30d", label = L["CHART_30D"] },
        { key = "all", label = L["CHART_ALL"] },
    }
    f.chartPeriodButtons = {}

    local periodX = -14
    for i = #CHART_PERIODS, 1, -1 do
        local pInfo = CHART_PERIODS[i]
        local btn = CreateFrame("Button", nil, f)
        btn:SetNormalFontObject("GameFontHighlightSmall")
        btn:SetText(pInfo.label)
        btn:SetSize(btn:GetFontString():GetStringWidth() + 12, 16)
        btn:SetPoint("TOPRIGHT", f, "TOPRIGHT", periodX, y - 1)
        periodX = periodX - btn:GetWidth() - 4

        local btnBg = btn:CreateTexture(nil, "BACKGROUND")
        btnBg:SetAllPoints()
        btnBg:SetColorTexture(0.2, 0.2, 0.25, 0.6)
        btn.bg = btnBg

        btn:SetScript("OnClick", function()
            activeChartPeriod = pInfo.key
            -- Обновить подсветку кнопок
            for _, b in ipairs(f.chartPeriodButtons) do
                if b.periodKey == activeChartPeriod then
                    b.bg:SetColorTexture(0.3, 0.5, 0.3, 0.8)
                else
                    b.bg:SetColorTexture(0.2, 0.2, 0.25, 0.6)
                end
            end
            UpdateChart()
        end)

        btn.periodKey = pInfo.key
        -- Начальная подсветка
        if pInfo.key == activeChartPeriod then
            btnBg:SetColorTexture(0.3, 0.5, 0.3, 0.8)
        end

        table.insert(f.chartPeriodButtons, btn)
    end

    y = y - 18

    -- Легенда (под заголовком, слева)
    local legendIncome = f:CreateTexture(nil, "ARTWORK")
    legendIncome:SetSize(8, 8)
    legendIncome:SetPoint("TOPLEFT", f, "TOPLEFT", 14, y - 2)
    legendIncome:SetColorTexture(COLORS.INCOME[1], COLORS.INCOME[2], COLORS.INCOME[3], 0.9)

    local legendIncomeText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    legendIncomeText:SetPoint("LEFT", legendIncome, "RIGHT", 3, 0)
    legendIncomeText:SetText(L["HEADER_INCOME"])
    legendIncomeText:SetTextColor(COLORS.LABEL[1], COLORS.LABEL[2], COLORS.LABEL[3])

    local legendExpense = f:CreateTexture(nil, "ARTWORK")
    legendExpense:SetSize(8, 8)
    legendExpense:SetPoint("LEFT", legendIncomeText, "RIGHT", 8, 0)
    legendExpense:SetColorTexture(COLORS.EXPENSE[1], COLORS.EXPENSE[2], COLORS.EXPENSE[3], 0.9)

    local legendExpenseText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    legendExpenseText:SetPoint("LEFT", legendExpense, "RIGHT", 3, 0)
    legendExpenseText:SetText(L["HEADER_EXPENSE"])
    legendExpenseText:SetTextColor(COLORS.LABEL[1], COLORS.LABEL[2], COLORS.LABEL[3])

    y = y - 14

    -- Контейнер графика (отступ сверху для метки макс.)
    local chartContainer = CreateFrame("Frame", nil, f)
    chartContainer:SetHeight(CHART_HEIGHT)
    chartContainer:SetPoint("TOPLEFT", f, "TOPLEFT", CHART_PADDING_LEFT, y)
    chartContainer:SetPoint("TOPRIGHT", f, "TOPRIGHT", -CHART_PADDING_RIGHT, y)

    -- Фон графика
    local chartBg = chartContainer:CreateTexture(nil, "BACKGROUND")
    chartBg:SetAllPoints()
    chartBg:SetColorTexture(0.04, 0.04, 0.06, 0.7)

    -- Горизонтальные направляющие (50%)
    local guide = chartContainer:CreateTexture(nil, "ARTWORK")
    guide:SetHeight(1)
    guide:SetPoint("BOTTOMLEFT", chartContainer, "BOTTOMLEFT", 0, CHART_HEIGHT * 0.5)
    guide:SetPoint("BOTTOMRIGHT", chartContainer, "BOTTOMRIGHT", 0, CHART_HEIGHT * 0.5)
    guide:SetColorTexture(0.2, 0.2, 0.25, 0.4)

    -- Метка максимума (правый верхний угол графика)
    f.chartMaxLabel = chartContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.chartMaxLabel:SetPoint("TOPRIGHT", chartContainer, "TOPRIGHT", -2, -2)
    f.chartMaxLabel:SetTextColor(0.5, 0.5, 0.5)

    f.chartDayLabels = {}
    f.chartContainer = chartContainer
    f.chartBars = {}
    f.chartHitFrames = {}

    y = y - CHART_HEIGHT - 14  -- место для подписей дней
    MakeSeparator(f, y) ; y = y - 10

    -- === Последние транзакции ===
    MakeSectionHeader(f, L["HEADER_RECENT"], y)
    y = y - 18

    -- Filter buttons (фильтр по источнику, с автопереносом строк)
    f.filterButtons = {}
    local FILTER_SOURCES = {
        { key = "all",     localeKey = "FILTER_ALL" },
        { key = "vendor",  localeKey = "SRC_VENDOR" },
        { key = "repair",  localeKey = "SRC_REPAIR" },
        { key = "ah",      localeKey = "SRC_AH" },
        { key = "mail",    localeKey = "SRC_MAIL" },
        { key = "quest",   localeKey = "SRC_QUEST" },
        { key = "loot",    localeKey = "SRC_LOOT" },
        { key = "trade",   localeKey = "SRC_TRADE" },
        { key = "unknown", localeKey = "SRC_UNKNOWN" },
    }

    local xOff = 0
    local rowY = y
    local maxRowWidth = FRAME_WIDTH - 28  -- 14px отступ с каждой стороны

    for _, info in ipairs(FILTER_SOURCES) do
        local btn = CreateFrame("Button", nil, f)
        btn:SetHeight(18)

        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btnText:SetText(L[info.localeKey])
        btnText:SetPoint("CENTER", 0, 0)

        local textW = btnText:GetStringWidth()
        if textW < 5 then textW = 24 end
        btn:SetWidth(textW + 12)

        -- Перенос на новую строку если не влезает
        if xOff + btn:GetWidth() > maxRowWidth and xOff > 0 then
            xOff = 0
            rowY = rowY - 20
        end

        btn:SetPoint("TOPLEFT", f, "TOPLEFT", 14 + xOff, rowY)

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()

        btn.text = btnText
        btn.bg = bg
        btn.key = info.key
        btn.color = SOURCE_COLORS[info.key] or { 1, 1, 1 }

        btn:SetScript("OnClick", function()
            activeFilter = info.key
            UpdateFilterButtons()
            UpdateEntryRows()
        end)

        f.filterButtons[#f.filterButtons + 1] = btn
        xOff = xOff + btn:GetWidth() + 3
    end

    y = rowY - 22

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "GoldLedgerScrollFrame", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 6, y)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 8)

    -- Фон для scroll-области
    local scrollBg = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    scrollBg:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", -2, 2)
    scrollBg:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 20, -2)
    scrollBg:SetColorTexture(0.05, 0.05, 0.07, 0.6)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(FRAME_WIDTH - 40)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    f.scrollChild = scrollChild
    f.entryRows = {}

    f.noDataLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    f.noDataLabel:SetPoint("TOP", scrollChild, "TOP", 0, -20)
    f.noDataLabel:SetText(L["NO_DATA"])

    mainFrame = f
    f:Hide()
    return f
end

-------------------------------------------------------------------------------
-- Transaction rows with source tags
-------------------------------------------------------------------------------
local ROW_HEIGHT = 20
local MAX_VISIBLE = 50

local function CreateEntryRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -((index - 1) * ROW_HEIGHT))

    -- Чередующийся фон
    if index % 2 == 0 then
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(COLORS.ROW_ALT[1], COLORS.ROW_ALT[2], COLORS.ROW_ALT[3], COLORS.ROW_ALT[4])
    end

    -- Время (слева)
    row.timeText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.timeText:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.timeText:SetWidth(42)
    row.timeText:SetJustifyH("LEFT")
    row.timeText:SetTextColor(0.6, 0.6, 0.6)

    -- Тег источника (после времени)
    row.sourceTag = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.sourceTag:SetPoint("LEFT", row.timeText, "RIGHT", 4, 0)
    row.sourceTag:SetWidth(55)
    row.sourceTag:SetJustifyH("LEFT")

    -- Сумма (справа)
    row.amountText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.amountText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.amountText:SetJustifyH("RIGHT")

    --- Обновляет строку данными
    function row:SetEntry(entry)
        self.timeText:SetText(date(L["TIME_FORMAT"], entry.timestamp))
        self.amountText:SetText(GoldFormatter.Colored(entry.amount, entry.type))

        -- Источник с цветом
        local source = entry.source or "unknown"
        local Tracker = GoldLedger:GetModule("Tracker")
        local localeKey = Tracker and Tracker:GetSourceLocaleKey(source) or "SRC_UNKNOWN"
        local color = SOURCE_COLORS[source] or SOURCE_COLORS.unknown
        self.sourceTag:SetText(L[localeKey])
        self.sourceTag:SetTextColor(color[1], color[2], color[3])
    end

    return row
end

UpdateEntryRows = function()
    if not mainFrame then return end

    local Data = GoldLedger:GetModule("Data")
    if not Data then return end

    local allEntries = Data:GetRecentEntries(MAX_VISIBLE)
    local scrollChild = mainFrame.scrollChild

    -- Фильтруем по источнику
    local entries = {}
    if activeFilter == "all" then
        entries = allEntries
    else
        for _, entry in ipairs(allEntries) do
            if (entry.source or "unknown") == activeFilter then
                entries[#entries + 1] = entry
            end
        end
    end

    mainFrame.noDataLabel:SetShown(#entries == 0)

    for i, entry in ipairs(entries) do
        local row = mainFrame.entryRows[i]
        if not row then
            row = CreateEntryRow(scrollChild, i)
            mainFrame.entryRows[i] = row
        end
        row:SetEntry(entry)
        row:Show()
    end

    for i = #entries + 1, #mainFrame.entryRows do
        mainFrame.entryRows[i]:Hide()
    end

    scrollChild:SetHeight(math.max(1, #entries * ROW_HEIGHT))
end

-------------------------------------------------------------------------------
-- Chart update
-------------------------------------------------------------------------------
UpdateChart = function()
    if not mainFrame or not mainFrame:IsShown() then return end

    local Data = GoldLedger:GetModule("Data")
    if not Data then return end

    local chartData, maxVal, totalBars = Data:GetChartData(activeChartPeriod)
    local container = mainFrame.chartContainer
    local chartWidth = container:GetWidth()

    -- Если ширина ещё 0 (первый кадр), отложим
    if chartWidth < 10 then return end

    local barGroupWidth = chartWidth / totalBars
    local barWidth = math.max(2, (barGroupWidth - 2) / 2) -- 2 бара + gap
    local todayKey = date("%Y-%m-%d")

    -- Метка максимума
    mainFrame.chartMaxLabel:SetText(GoldFormatter.Short(maxVal))

    -- Шаг подписей: показываем ~6 подписей
    local labelStep = math.max(1, math.ceil(totalBars / 6))

    -- Скрыть старые подписи
    for _, lbl in pairs(mainFrame.chartDayLabels) do
        lbl:Hide()
    end

    for i, dayData in ipairs(chartData) do
        -- Создаём бары если нужно
        if not mainFrame.chartBars[i] then
            local incBar = container:CreateTexture(nil, "ARTWORK")
            local expBar = container:CreateTexture(nil, "ARTWORK")
            mainFrame.chartBars[i] = { income = incBar, expense = expBar }
        end

        -- Подписи дней
        if not mainFrame.chartDayLabels[i] then
            local dayLabel = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            dayLabel:SetTextColor(0.45, 0.45, 0.50)
            mainFrame.chartDayLabels[i] = dayLabel
        end

        local bars = mainFrame.chartBars[i]
        local xOffset = (i - 1) * barGroupWidth

        -- Income bar (левый)
        local incHeight = dayData.income > 0 and math.max(2, (dayData.income / maxVal) * CHART_HEIGHT) or 0
        bars.income:ClearAllPoints()
        bars.income:SetSize(barWidth, incHeight)
        bars.income:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", xOffset + 1, 0)
        bars.income:SetShown(dayData.income > 0)

        -- Expense bar (правый)
        local expHeight = dayData.expense > 0 and math.max(2, (dayData.expense / maxVal) * CHART_HEIGHT) or 0
        bars.expense:ClearAllPoints()
        bars.expense:SetSize(barWidth, expHeight)
        bars.expense:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", xOffset + 1 + barWidth, 0)
        bars.expense:SetShown(dayData.expense > 0)

        -- Подсветка: сегодня яркий, остальные приглушённые
        local isToday = dayData.dateKey == todayKey
        local alpha = isToday and 1 or 0.5
        bars.income:SetColorTexture(COLORS.INCOME[1], COLORS.INCOME[2], COLORS.INCOME[3], alpha)
        bars.expense:SetColorTexture(COLORS.EXPENSE[1], COLORS.EXPENSE[2], COLORS.EXPENSE[3], alpha)

        -- Подпись дня: показывать 1 и каждый labelStep-й
        local lbl = mainFrame.chartDayLabels[i]
        if i == 1 or i % labelStep == 0 then
            lbl:ClearAllPoints()
            lbl:SetPoint("TOP", container, "BOTTOMLEFT", xOffset + barGroupWidth / 2, -1)
            lbl:SetText(dayData.label)
            lbl:Show()
        else
            lbl:Hide()
        end

        -- Hit frame для tooltip
        if not mainFrame.chartHitFrames[i] then
            local hit = CreateFrame("Frame", nil, container)
            hit:EnableMouse(true)
            hit:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(self.tipDate or "", 1, 1, 1)
                if self.tipIncome and self.tipIncome > 0 then
                    GameTooltip:AddLine(L["HEADER_INCOME"] .. ": " .. GoldFormatter.Full(self.tipIncome), COLORS.INCOME[1], COLORS.INCOME[2], COLORS.INCOME[3])
                end
                if self.tipExpense and self.tipExpense > 0 then
                    GameTooltip:AddLine(L["HEADER_EXPENSE"] .. ": " .. GoldFormatter.Full(self.tipExpense), COLORS.EXPENSE[1], COLORS.EXPENSE[2], COLORS.EXPENSE[3])
                end
                GameTooltip:Show()
            end)
            hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
            mainFrame.chartHitFrames[i] = hit
        end

        local hit = mainFrame.chartHitFrames[i]
        hit:ClearAllPoints()
        hit:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", xOffset, 0)
        hit:SetSize(barGroupWidth, CHART_HEIGHT)
        hit.tipDate = dayData.dateKey or dayData.label
        hit.tipIncome = dayData.income
        hit.tipExpense = dayData.expense
        hit:Show()
    end

    -- Скрыть лишние бары и hit frames
    for i = #chartData + 1, #mainFrame.chartBars do
        mainFrame.chartBars[i].income:Hide()
        mainFrame.chartBars[i].expense:Hide()
    end
    for i = #chartData + 1, #mainFrame.chartHitFrames do
        mainFrame.chartHitFrames[i]:Hide()
    end
end

-------------------------------------------------------------------------------
-- Goal update
-------------------------------------------------------------------------------
local function UpdateGoal()
    if not mainFrame or not mainFrame:IsShown() then return end

    local Data = GoldLedger:GetModule("Data")
    if not Data then return end

    local goalInfo = Data:GetGoalProgress()

    if not goalInfo then
        mainFrame.goalBarFill:SetWidth(1)
        mainFrame.goalBarFill:Hide()
        mainFrame.goalText:SetText(L["GOAL_NONE"])
        mainFrame.goalText:SetTextColor(0.5, 0.5, 0.55)
        mainFrame.goalEta:SetText("")
        return
    end

    local barWidth = mainFrame.goalBarBg:GetWidth()
    if barWidth < 1 then barWidth = 1 end
    local fillWidth = math.max(1, barWidth * goalInfo.progress)

    mainFrame.goalBarFill:SetWidth(fillWidth)
    mainFrame.goalBarFill:Show()

    if goalInfo.progress >= 1 then
        mainFrame.goalBarFill:SetColorTexture(
            COLORS.GOAL_DONE[1], COLORS.GOAL_DONE[2], COLORS.GOAL_DONE[3], 0.8)
        mainFrame.goalText:SetText(L["GOAL_REACHED"])
        mainFrame.goalText:SetTextColor(0.3, 1.0, 0.3)
        mainFrame.goalEta:SetText("")
    else
        mainFrame.goalBarFill:SetColorTexture(
            COLORS.GOAL_FILL[1], COLORS.GOAL_FILL[2], COLORS.GOAL_FILL[3], 0.8)
        local pct = math.floor(goalInfo.progress * 100)
        mainFrame.goalText:SetText(
            GoldFormatter.Short(goalInfo.current) .. " / " ..
            GoldFormatter.Short(goalInfo.goal) .. " (" .. pct .. "%)")
        mainFrame.goalText:SetTextColor(1, 1, 1)

        if goalInfo.estDays then
            mainFrame.goalEta:SetText(L["GOAL_REMAINING"]:format(goalInfo.estDays))
        else
            mainFrame.goalEta:SetText("")
        end
    end
end

-------------------------------------------------------------------------------
-- Summary update
-------------------------------------------------------------------------------
local function UpdateSummaries()
    if not mainFrame or not mainFrame:IsShown() then return end

    local Data = GoldLedger:GetModule("Data")
    if not Data then return end

    -- On Hand (текущая голда)
    local currentGold = GetMoney() or 0
    mainFrame.onHandValue:SetText(GoldFormatter.Full(currentGold))

    -- Today
    local today = Data:GetDailySummary()
    mainFrame.todayIncome:SetValue(GoldFormatter.Full(today.income),
        COLORS.INCOME[1], COLORS.INCOME[2], COLORS.INCOME[3])
    mainFrame.todayExpense:SetValue(GoldFormatter.Full(today.expense),
        COLORS.EXPENSE[1], COLORS.EXPENSE[2], COLORS.EXPENSE[3])

    local todayNet = today.income - today.expense
    local tc = todayNet >= 0 and COLORS.BALANCE_POS or COLORS.BALANCE_NEG
    mainFrame.todayBalance:SetValue(
        (todayNet >= 0 and "+" or "-") .. GoldFormatter.Full(math.abs(todayNet)),
        tc[1], tc[2], tc[3])

    -- Month
    local month = Data:GetMonthlySummary()
    mainFrame.monthIncome:SetValue(GoldFormatter.Full(month.income),
        COLORS.INCOME[1], COLORS.INCOME[2], COLORS.INCOME[3])
    mainFrame.monthExpense:SetValue(GoldFormatter.Full(month.expense),
        COLORS.EXPENSE[1], COLORS.EXPENSE[2], COLORS.EXPENSE[3])

    local monthNet = month.income - month.expense
    local mc = monthNet >= 0 and COLORS.BALANCE_POS or COLORS.BALANCE_NEG
    mainFrame.monthBalance:SetValue(
        (monthNet >= 0 and "+" or "-") .. GoldFormatter.Full(math.abs(monthNet)),
        mc[1], mc[2], mc[3])

    -- Session
    local TrackerMod = GoldLedger:GetModule("Tracker")
    if TrackerMod then
        local session = TrackerMod:GetSessionStats()
        mainFrame.sessionIncome:SetValue(GoldFormatter.Full(session.income),
            COLORS.INCOME[1], COLORS.INCOME[2], COLORS.INCOME[3])
        mainFrame.sessionExpense:SetValue(GoldFormatter.Full(session.expense),
            COLORS.EXPENSE[1], COLORS.EXPENSE[2], COLORS.EXPENSE[3])

        local sc = session.net >= 0 and COLORS.BALANCE_POS or COLORS.BALANCE_NEG
        mainFrame.sessionNet:SetValue(
            (session.net >= 0 and "+" or "-") .. GoldFormatter.Full(math.abs(session.net)),
            sc[1], sc[2], sc[3])
    end

    -- Goal
    UpdateGoal()

    -- Chart
    UpdateChart()

    -- Entries
    UpdateFilterButtons()
    UpdateEntryRows()
end

-------------------------------------------------------------------------------
-- Characters Popup
-------------------------------------------------------------------------------
local charsFrame

local function CreateCharsFrame()
    local f = CreateFrame("Frame", "GoldLedgerCharsFrame", UIParent, "BackdropTemplate")
    f:SetSize(340, 380)
    f:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)

    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(COLORS.FRAME_BG[1], COLORS.FRAME_BG[2], COLORS.FRAME_BG[3], COLORS.FRAME_BG[4])
    f:SetBackdropBorderColor(COLORS.BORDER[1], COLORS.BORDER[2], COLORS.BORDER[3], COLORS.BORDER[4])

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetHeight(26)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    titleBar:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
    titleBar:SetBackdropColor(COLORS.TITLE_BG[1], COLORS.TITLE_BG[2], COLORS.TITLE_BG[3], COLORS.TITLE_BG[4])

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    title:SetText("|cffffd700" .. L["HEADER_CHARACTERS"] .. "|r")

    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Подзаголовок "За месяц"
    local subHeader = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subHeader:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -36)
    subHeader:SetText(L["CHAR_MONTH_LABEL"])
    subHeader:SetTextColor(COLORS.LABEL[1], COLORS.LABEL[2], COLORS.LABEL[3])

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "GoldLedgerCharsScrollFrame", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -52)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 44)

    local scrollBg = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    scrollBg:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", -2, 2)
    scrollBg:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 20, -2)
    scrollBg:SetColorTexture(0.05, 0.05, 0.07, 0.6)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(300)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    f.scrollChild = scrollChild
    f.charRows = {}

    -- Итого по аккаунту (внизу)
    MakeSeparator(f, -340)

    f.totalLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.totalLabel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 14)
    f.totalLabel:SetText(L["HEADER_ACCOUNT_TOTAL"])
    f.totalLabel:SetTextColor(COLORS.HEADER[1], COLORS.HEADER[2], COLORS.HEADER[3])

    f.totalValue = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.totalValue:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 14)
    f.totalValue:SetJustifyH("RIGHT")

    table.insert(UISpecialFrames, "GoldLedgerCharsFrame")

    charsFrame = f
    f:Hide()
    return f
end

local CHAR_ROW_HEIGHT = 40

local function UpdateCharactersList()
    if not charsFrame or not charsFrame:IsShown() then return end

    local Data = GoldLedger:GetModule("Data")
    if not Data then return end

    local chars = Data:GetAllCharactersSummary()
    local scrollChild = charsFrame.scrollChild

    for i, charInfo in ipairs(chars) do
        local row = charsFrame.charRows[i]
        if not row then
            row = CreateFrame("Frame", nil, scrollChild)
            row:SetHeight(CHAR_ROW_HEIGHT)
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -((i - 1) * CHAR_ROW_HEIGHT))
            row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -((i - 1) * CHAR_ROW_HEIGHT))

            if i % 2 == 0 then
                local bg = row:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(COLORS.ROW_ALT[1], COLORS.ROW_ALT[2], COLORS.ROW_ALT[3], COLORS.ROW_ALT[4])
            end

            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
            row.nameText:SetJustifyH("LEFT")

            row.detailText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.detailText:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 4)
            row.detailText:SetJustifyH("LEFT")
            row.detailText:SetTextColor(COLORS.LABEL[1], COLORS.LABEL[2], COLORS.LABEL[3])

            row.netText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.netText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            row.netText:SetJustifyH("RIGHT")

            charsFrame.charRows[i] = row
        end

        row.nameText:SetText(charInfo.name)

        local detail = L["HEADER_INCOME"] .. ": " .. GoldFormatter.Short(charInfo.monthIncome) ..
                       "  " .. L["HEADER_EXPENSE"] .. ": " .. GoldFormatter.Short(charInfo.monthExpense)
        row.detailText:SetText(detail)

        local netColor = charInfo.monthNet >= 0 and COLORS.BALANCE_POS or COLORS.BALANCE_NEG
        local netSign = charInfo.monthNet >= 0 and "+" or "-"
        row.netText:SetText(netSign .. GoldFormatter.Full(math.abs(charInfo.monthNet)))
        row.netText:SetTextColor(netColor[1], netColor[2], netColor[3])

        row:Show()
    end

    for i = #chars + 1, #charsFrame.charRows do
        charsFrame.charRows[i]:Hide()
    end

    scrollChild:SetHeight(math.max(1, #chars * CHAR_ROW_HEIGHT))

    -- Итого по аккаунту
    local totalNet = 0
    for _, charInfo in ipairs(chars) do
        totalNet = totalNet + charInfo.monthNet
    end
    local tc = totalNet >= 0 and COLORS.BALANCE_POS or COLORS.BALANCE_NEG
    charsFrame.totalValue:SetText(
        (totalNet >= 0 and "+" or "-") .. GoldFormatter.Full(math.abs(totalNet)))
    charsFrame.totalValue:SetTextColor(tc[1], tc[2], tc[3])
end

-------------------------------------------------------------------------------
-- Export Popup
-------------------------------------------------------------------------------
local exportFrame

local function CreateExportFrame()
    local f = CreateFrame("Frame", "GoldLedgerExportFrame", UIParent, "BackdropTemplate")
    f:SetSize(500, 350)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(100)
    f:SetClampedToScreen(true)

    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(COLORS.FRAME_BG[1], COLORS.FRAME_BG[2], COLORS.FRAME_BG[3], COLORS.FRAME_BG[4])
    f:SetBackdropBorderColor(COLORS.BORDER[1], COLORS.BORDER[2], COLORS.BORDER[3], COLORS.BORDER[4])

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetHeight(26)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    titleBar:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
    titleBar:SetBackdropColor(COLORS.TITLE_BG[1], COLORS.TITLE_BG[2], COLORS.TITLE_BG[3], COLORS.TITLE_BG[4])

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    title:SetText("|cffffd700" .. L["EXPORT_TITLE"] .. "|r")

    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Hint
    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -36)
    hint:SetText(L["EXPORT_HINT"])
    hint:SetTextColor(0.7, 0.7, 0.7)

    -- ScrollFrame + EditBox
    local scrollFrame = CreateFrame("ScrollFrame", "GoldLedgerExportScrollFrame", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -52)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 8)

    local scrollBg = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    scrollBg:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", -2, 2)
    scrollBg:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 20, -2)
    scrollBg:SetColorTexture(0.04, 0.04, 0.06, 0.8)

    local editBox = CreateFrame("EditBox", "GoldLedgerExportEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(460)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        f:Hide()
    end)

    scrollFrame:SetScrollChild(editBox)

    f.editBox = editBox

    table.insert(UISpecialFrames, "GoldLedgerExportFrame")

    exportFrame = f
    f:Hide()
    return f
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function UI:ToggleCharsFrame()
    if not charsFrame then
        CreateCharsFrame()
    end
    if charsFrame:IsShown() then
        charsFrame:Hide()
    else
        charsFrame:Show()
        UpdateCharactersList()
    end
end

function UI:ShowExportFrame()
    if not exportFrame then
        CreateExportFrame()
    end

    local Data = GoldLedger:GetModule("Data")
    if Data then
        local csv = Data:GetExportCSV()
        exportFrame.editBox:SetText(csv)
    end

    exportFrame:Show()
    exportFrame.editBox:HighlightText()
    exportFrame.editBox:SetFocus()
end

function UI:RefreshGoal()
    UpdateGoal()
end

function UI:ToggleMainFrame()
    if not mainFrame then
        CreateMainFrame()
    end
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        UpdateSummaries()
    end
end

-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------

function UI:OnEnable()
    CreateMinimapButton()

    local Tracker = GoldLedger:GetModule("Tracker")
    if Tracker then
        Tracker:OnGoldChanged(function()
            UpdateSummaries()
        end)
    end
end
