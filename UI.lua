--[[
    GoldLedger: UI.lua
    Dashboard Cards layout — горизонтальная компоновка с карточками

    Компоненты:
    - Gold Formatter: стратегия форматирования (полный / краткий / цветной)
    - Minimap Button: перетаскиваемая кнопка на краю миникарты
    - Main Frame: карточки + график + транзакции
]]

local ADDON_NAME, ns = ...
local GoldLedger = ns.GoldLedger
local L = ns.L

local UI = {}
GoldLedger:RegisterModule("UI", UI)

-------------------------------------------------------------------------------
-- Theme helpers (must be before any UI creation functions)
-------------------------------------------------------------------------------

local function T(key)
    local Themes = GoldLedger:GetModule("Themes")
    return Themes:GetColor(key)
end

local function TC(key)
    local Themes = GoldLedger:GetModule("Themes")
    return Themes:C(key)
end

local function GetSourceColors()
    local Themes = GoldLedger:GetModule("Themes")
    return Themes:GetSourceColors()
end

local function GetBackdrop()
    local Themes = GoldLedger:GetModule("Themes")
    return {
        bgFile = Themes:GetBgTexture(),
        edgeFile = Themes:GetEdgeTexture(),
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    }
end

local function GetSmallBackdrop()
    local Themes = GoldLedger:GetModule("Themes")
    return {
        bgFile = Themes:GetBgTexture(),
        edgeFile = Themes:GetEdgeTexture(),
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    }
end

-------------------------------------------------------------------------------
-- Custom Goal Input Dialog
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

    f:SetBackdrop(GetBackdrop())
    f:SetBackdropColor(TC("FRAME_BG"))
    f:SetBackdropBorderColor(TC("BORDER"))

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -12)
    title:SetText(L["GOAL_INPUT_TEXT"])
    title:SetTextColor(TC("GOLD_TEXT"))

    local editBox = CreateFrame("EditBox", "GoldLedgerGoalEditBox", f, "InputBoxTemplate")
    editBox:SetSize(140, 22)
    editBox:SetPoint("TOP", title, "BOTTOM", 0, -10)
    editBox:SetAutoFocus(true)
    editBox:SetNumeric(true)
    editBox:SetMaxLetters(10)

    local okBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    okBtn:SetSize(80, 22)
    okBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -4, 10)
    okBtn:SetText(ACCEPT)

    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(80, 22)
    cancelBtn:SetPoint("BOTTOMLEFT", f, "BOTTOM", 4, 10)
    cancelBtn:SetText(CANCEL)

    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetSize(80, 22)
    clearBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 34)
    clearBtn:SetText(L["GOAL_CLEAR_BTN"])

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
    local Themes = GoldLedger:GetModule("Themes")
    local c
    if entryType == "income" then
        c = Themes:GetColor("INCOME")
        return ("|cff%02x%02x%02x+%s|r"):format(c[1]*255, c[2]*255, c[3]*255, text)
    else
        c = Themes:GetColor("EXPENSE")
        return ("|cff%02x%02x%02x-%s|r"):format(c[1]*255, c[2]*255, c[3]*255, text)
    end
end

UI.GoldFormatter = GoldFormatter

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

    local function UpdatePosition(angle)
        local rad = math.rad(angle)
        local radius = (Minimap:GetWidth() / 2) + 10
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER",
            math.cos(rad) * radius,
            math.sin(rad) * radius
        )
    end

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

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L["TOOLTIP_TITLE"], 1, 0.84, 0)

        local Data = GoldLedger:GetModule("Data")
        if Data then
            local today = Data:GetDailySummary()
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["TOOLTIP_TODAY"], 1, 1, 1)
            GameTooltip:AddDoubleLine(L["HEADER_INCOME"], GoldFormatter.Full(today.income),
                T("LABEL")[1], T("LABEL")[2], T("LABEL")[3],
                T("INCOME")[1], T("INCOME")[2], T("INCOME")[3])
            GameTooltip:AddDoubleLine(L["HEADER_EXPENSE"], GoldFormatter.Full(today.expense),
                T("LABEL")[1], T("LABEL")[2], T("LABEL")[3],
                T("EXPENSE")[1], T("EXPENSE")[2], T("EXPENSE")[3])

            local month = Data:GetMonthlySummary()
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["TOOLTIP_MONTH"], 1, 1, 1)
            GameTooltip:AddDoubleLine(L["HEADER_INCOME"], GoldFormatter.Full(month.income),
                T("LABEL")[1], T("LABEL")[2], T("LABEL")[3],
                T("INCOME")[1], T("INCOME")[2], T("INCOME")[3])
            GameTooltip:AddDoubleLine(L["HEADER_EXPENSE"], GoldFormatter.Full(month.expense),
                T("LABEL")[1], T("LABEL")[2], T("LABEL")[3],
                T("EXPENSE")[1], T("EXPENSE")[2], T("EXPENSE")[3])
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
    sep:SetColorTexture(TC("SEPARATOR"))
    return sep
end

--- Создаёт карточку (card) внутри родителя
local function MakeCard(parent, titleText, width, height)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(width, height)
    card:SetBackdrop(GetSmallBackdrop())
    card:SetBackdropColor(TC("CARD_BG"))
    card:SetBackdropBorderColor(TC("CARD_BORDER"))

    local cardTitle = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cardTitle:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -6)
    cardTitle:SetText(titleText)
    cardTitle:SetTextColor(TC("CARD_TITLE"))

    card.titleText = cardTitle
    return card
end

--- Создаёт строку label + value внутри карточки
local function MakeCardRow(parent, labelText, yOffset)
    local row = {}

    row.label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    row.label:SetText(labelText)
    row.label:SetTextColor(TC("LABEL"))

    row.value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.value:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, yOffset)
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
local FRAME_WIDTH = 720
local FRAME_HEIGHT = 520
local activeFilter = "all"
local activeChartPeriod = "7d"
local CHART_HEIGHT = 100
local CHART_PADDING_LEFT = 8
local CHART_PADDING_RIGHT = 8

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
            btn.bg:SetColorTexture(TC("FILTER_INACTIVE_BG"))
            btn.text:SetTextColor(TC("FILTER_INACTIVE_TEXT"))
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

    f:SetBackdrop(GetBackdrop())
    f:SetBackdropColor(TC("FRAME_BG"))
    f:SetBackdropBorderColor(TC("BORDER"))

    ---------------------------------------------------------------------------
    -- Title bar
    ---------------------------------------------------------------------------
    local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetHeight(26)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    local Themes = GoldLedger:GetModule("Themes")
    titleBar:SetBackdrop({ bgFile = Themes:GetBgTexture() })
    titleBar:SetBackdropColor(TC("TITLE_BG"))

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
    charsBtn:SetBackdrop(GetSmallBackdrop())
    charsBtn:SetBackdropColor(TC("BTN_BG"))
    charsBtn:SetBackdropBorderColor(TC("BTN_BORDER"))
    local charsBtnText = charsBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    charsBtnText:SetPoint("CENTER")
    charsBtnText:SetText(L["HEADER_CHARACTERS"])
    charsBtn:SetScript("OnClick", function() UI:ToggleCharsFrame() end)
    charsBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(TC("BTN_BG_HOVER")) end)
    charsBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(TC("BTN_BG")) end)

    -- Кнопка "Экспорт"
    local exportBtn = CreateFrame("Button", nil, titleBar, "BackdropTemplate")
    exportBtn:SetSize(65, 18)
    exportBtn:SetPoint("RIGHT", charsBtn, "LEFT", -4, 0)
    exportBtn:SetBackdrop(GetSmallBackdrop())
    exportBtn:SetBackdropColor(TC("BTN_BG"))
    exportBtn:SetBackdropBorderColor(TC("BTN_BORDER"))
    local exportBtnText = exportBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    exportBtnText:SetPoint("CENTER")
    exportBtnText:SetText(L["EXPORT_BUTTON"])
    exportBtn:SetScript("OnClick", function() UI:ShowExportFrame() end)
    exportBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(TC("BTN_BG_HOVER")) end)
    exportBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(TC("BTN_BG")) end)

    -- Кнопка "Настройки" (⚙)
    local settingsBtn = CreateFrame("Button", nil, titleBar, "BackdropTemplate")
    settingsBtn:SetSize(22, 18)
    settingsBtn:SetPoint("RIGHT", exportBtn, "LEFT", -4, 0)
    settingsBtn:SetBackdrop(GetSmallBackdrop())
    settingsBtn:SetBackdropColor(TC("BTN_BG"))
    settingsBtn:SetBackdropBorderColor(TC("BTN_BORDER"))
    local settingsBtnText = settingsBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    settingsBtnText:SetPoint("CENTER")
    settingsBtnText:SetText("|TInterface\\Buttons\\UI-OptionsButton:14:14|t")
    settingsBtn:SetScript("OnClick", function() UI:ToggleSettingsFrame() end)
    settingsBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(TC("BTN_BG_HOVER"))
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["SETTINGS_BUTTON"], 1, 1, 1)
        GameTooltip:Show()
    end)
    settingsBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(TC("BTN_BG"))
        GameTooltip:Hide()
    end)

    table.insert(UISpecialFrames, "GoldLedgerMainFrame")

    ---------------------------------------------------------------------------
    -- Row 1: Stat cards (On Hand, Today, Session, Month)
    ---------------------------------------------------------------------------
    local CARD_W = 166
    local CARD_H = 80
    local CARD_GAP = 8
    local cardsY = -38

    -- On Hand card
    local cardOnHand = MakeCard(f, L["HEADER_ON_HAND"], CARD_W, CARD_H)
    cardOnHand:SetPoint("TOPLEFT", f, "TOPLEFT", 10, cardsY)

    f.onHandValue = cardOnHand:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.onHandValue:SetPoint("TOP", cardOnHand, "TOP", 0, -24)
    f.onHandValue:SetJustifyH("CENTER")
    f.onHandValue:SetTextColor(TC("GOLD_TEXT"))

    -- Today card
    local cardToday = MakeCard(f, L["HEADER_TODAY"], CARD_W, CARD_H)
    cardToday:SetPoint("LEFT", cardOnHand, "RIGHT", CARD_GAP, 0)

    f.todayIncome  = MakeCardRow(cardToday, L["HEADER_INCOME"], -22)
    f.todayExpense = MakeCardRow(cardToday, L["HEADER_EXPENSE"], -36)
    f.todayBalance = MakeCardRow(cardToday, L["HEADER_BALANCE"], -52)

    -- Session card
    local cardSession = MakeCard(f, L["HEADER_SESSION"], CARD_W, CARD_H)
    cardSession:SetPoint("LEFT", cardToday, "RIGHT", CARD_GAP, 0)

    f.sessionIncome  = MakeCardRow(cardSession, L["HEADER_INCOME"], -22)
    f.sessionExpense = MakeCardRow(cardSession, L["HEADER_EXPENSE"], -36)
    f.sessionNet     = MakeCardRow(cardSession, L["HEADER_NET"], -52)

    -- Month card
    local cardMonth = MakeCard(f, L["HEADER_MONTH"], CARD_W, CARD_H)
    cardMonth:SetPoint("LEFT", cardSession, "RIGHT", CARD_GAP, 0)

    f.monthIncome  = MakeCardRow(cardMonth, L["HEADER_INCOME"], -22)
    f.monthExpense = MakeCardRow(cardMonth, L["HEADER_EXPENSE"], -36)
    f.monthBalance = MakeCardRow(cardMonth, L["HEADER_BALANCE"], -52)

    ---------------------------------------------------------------------------
    -- Row 2: Chart (left) + Goal (right)
    ---------------------------------------------------------------------------
    local row2Y = cardsY - CARD_H - CARD_GAP
    local CHART_CARD_W = 460
    local GOAL_CARD_W = FRAME_WIDTH - CHART_CARD_W - 10 - 10 - CARD_GAP  -- remaining width

    -- Chart card
    local chartCard = MakeCard(f, L["HEADER_CHART"], CHART_CARD_W, 160)
    chartCard:SetPoint("TOPLEFT", f, "TOPLEFT", 10, row2Y)

    -- Chart period buttons (inside chart card)
    local CHART_PERIODS = {
        { key = "7d",  label = L["CHART_7D"] },
        { key = "30d", label = L["CHART_30D"] },
        { key = "all", label = L["CHART_ALL"] },
    }
    f.chartPeriodButtons = {}

    local periodX = -6
    for i = #CHART_PERIODS, 1, -1 do
        local pInfo = CHART_PERIODS[i]
        local btn = CreateFrame("Button", nil, chartCard)
        btn:SetNormalFontObject("GameFontHighlightSmall")
        btn:SetText(pInfo.label)
        btn:SetSize(btn:GetFontString():GetStringWidth() + 12, 16)
        btn:SetPoint("TOPRIGHT", chartCard, "TOPRIGHT", periodX, -5)
        periodX = periodX - btn:GetWidth() - 4

        local btnBg = btn:CreateTexture(nil, "BACKGROUND")
        btnBg:SetAllPoints()
        btnBg:SetColorTexture(TC("BTN_INACTIVE"))
        btn.bg = btnBg

        btn:SetScript("OnClick", function()
            activeChartPeriod = pInfo.key
            for _, b in ipairs(f.chartPeriodButtons) do
                if b.periodKey == activeChartPeriod then
                    b.bg:SetColorTexture(TC("BTN_ACTIVE"))
                else
                    b.bg:SetColorTexture(TC("BTN_INACTIVE"))
                end
            end
            UpdateChart()
        end)

        btn.periodKey = pInfo.key
        if pInfo.key == activeChartPeriod then
            btnBg:SetColorTexture(TC("BTN_ACTIVE"))
        end

        table.insert(f.chartPeriodButtons, btn)
    end

    -- Legend (inside chart card)
    local legendIncome = chartCard:CreateTexture(nil, "ARTWORK")
    legendIncome:SetSize(8, 8)
    legendIncome:SetPoint("TOPLEFT", chartCard, "TOPLEFT", 8, -22)
    legendIncome:SetColorTexture(T("INCOME")[1], T("INCOME")[2], T("INCOME")[3], 0.9)

    local legendIncomeText = chartCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    legendIncomeText:SetPoint("LEFT", legendIncome, "RIGHT", 3, 0)
    legendIncomeText:SetText(L["HEADER_INCOME"])
    legendIncomeText:SetTextColor(TC("LABEL"))

    local legendExpense = chartCard:CreateTexture(nil, "ARTWORK")
    legendExpense:SetSize(8, 8)
    legendExpense:SetPoint("LEFT", legendIncomeText, "RIGHT", 8, 0)
    legendExpense:SetColorTexture(T("EXPENSE")[1], T("EXPENSE")[2], T("EXPENSE")[3], 0.9)

    local legendExpenseText = chartCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    legendExpenseText:SetPoint("LEFT", legendExpense, "RIGHT", 3, 0)
    legendExpenseText:SetText(L["HEADER_EXPENSE"])
    legendExpenseText:SetTextColor(TC("LABEL"))

    -- Chart container (inside chart card)
    local chartContainer = CreateFrame("Frame", nil, chartCard)
    chartContainer:SetHeight(CHART_HEIGHT)
    chartContainer:SetPoint("TOPLEFT", chartCard, "TOPLEFT", CHART_PADDING_LEFT, -34)
    chartContainer:SetPoint("TOPRIGHT", chartCard, "TOPRIGHT", -CHART_PADDING_RIGHT, -34)

    local chartBg = chartContainer:CreateTexture(nil, "BACKGROUND")
    chartBg:SetAllPoints()
    chartBg:SetColorTexture(TC("CHART_BG"))

    local guide = chartContainer:CreateTexture(nil, "ARTWORK")
    guide:SetHeight(1)
    guide:SetPoint("BOTTOMLEFT", chartContainer, "BOTTOMLEFT", 0, CHART_HEIGHT * 0.5)
    guide:SetPoint("BOTTOMRIGHT", chartContainer, "BOTTOMRIGHT", 0, CHART_HEIGHT * 0.5)
    guide:SetColorTexture(TC("CHART_GUIDE"))

    f.chartMaxLabel = chartContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.chartMaxLabel:SetPoint("TOPRIGHT", chartContainer, "TOPRIGHT", -2, -2)
    f.chartMaxLabel:SetTextColor(TC("TEXT_DIM"))

    f.chartDayLabels = {}
    f.chartContainer = chartContainer
    f.chartBars = {}
    f.chartHitFrames = {}

    -- Goal card (right of chart)
    local goalCard = MakeCard(f, L["HEADER_GOAL"], GOAL_CARD_W, 160)
    goalCard:SetPoint("LEFT", chartCard, "RIGHT", CARD_GAP, 0)

    -- Goal progress bar
    f.goalBarBg = goalCard:CreateTexture(nil, "ARTWORK")
    f.goalBarBg:SetHeight(20)
    f.goalBarBg:SetPoint("TOPLEFT", goalCard, "TOPLEFT", 10, -30)
    f.goalBarBg:SetPoint("TOPRIGHT", goalCard, "TOPRIGHT", -10, -30)
    f.goalBarBg:SetColorTexture(TC("GOAL_BG"))

    f.goalBarFill = goalCard:CreateTexture(nil, "ARTWORK", nil, 1)
    f.goalBarFill:SetHeight(20)
    f.goalBarFill:SetPoint("TOPLEFT", f.goalBarBg, "TOPLEFT", 0, 0)
    f.goalBarFill:SetWidth(1)
    f.goalBarFill:SetColorTexture(TC("GOAL_FILL"))

    f.goalText = goalCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.goalText:SetPoint("CENTER", f.goalBarBg, "CENTER", 0, 0)
    f.goalText:SetTextColor(TC("TEXT_WHITE"))

    f.goalEta = goalCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.goalEta:SetPoint("TOP", f.goalBarBg, "BOTTOM", 0, -4)
    f.goalEta:SetTextColor(TC("TEXT_DIM"))

    -- Goal click area
    local goalClickArea = CreateFrame("Button", nil, goalCard)
    goalClickArea:SetPoint("TOPLEFT", f.goalBarBg, "TOPLEFT", 0, 0)
    goalClickArea:SetPoint("BOTTOMRIGHT", f.goalBarBg, "BOTTOMRIGHT", 0, 0)
    goalClickArea:SetScript("OnClick", function() ShowGoalDialog() end)
    goalClickArea:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["HEADER_GOAL"], 1, 0.84, 0)
        GameTooltip:AddLine(L["GOAL_CLICK_HINT"], 1, 1, 1)
        GameTooltip:Show()
    end)
    goalClickArea:SetScript("OnLeave", function() GameTooltip:Hide() end)

    ---------------------------------------------------------------------------
    -- Row 3: Recent Transactions
    ---------------------------------------------------------------------------
    local row3Y = row2Y - 160 - CARD_GAP

    -- Transactions card (full width)
    local txCard = MakeCard(f, L["HEADER_RECENT"], FRAME_WIDTH - 20, FRAME_HEIGHT - math.abs(row3Y) - 14)
    txCard:SetPoint("TOPLEFT", f, "TOPLEFT", 10, row3Y)

    -- Кнопка "Сводка" справа от заголовка
    local breakdownBtn = CreateFrame("Button", nil, txCard, "BackdropTemplate")
    breakdownBtn:SetSize(80, 20)
    breakdownBtn:SetPoint("TOPRIGHT", txCard, "TOPRIGHT", -8, -4)
    breakdownBtn:SetBackdrop(GetSmallBackdrop())
    breakdownBtn:SetBackdropColor(TC("ACCENT_BTN_BG"))
    breakdownBtn:SetBackdropBorderColor(TC("ACCENT_BTN_BORDER"))
    local breakdownBtnText = breakdownBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    breakdownBtnText:SetPoint("CENTER")
    breakdownBtnText:SetText(L["BREAKDOWN_BUTTON"])
    breakdownBtnText:SetTextColor(TC("ACCENT_BTN_TEXT"))
    breakdownBtn:SetScript("OnClick", function() UI:ToggleBreakdownFrame() end)
    breakdownBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(TC("ACCENT_BTN_BG_HOVER")) end)
    breakdownBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(TC("ACCENT_BTN_BG")) end)

    -- Filter buttons
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

    local filterY = -22
    local xOff = 0
    local maxRowWidth = FRAME_WIDTH - 48

    for _, info in ipairs(FILTER_SOURCES) do
        local btn = CreateFrame("Button", nil, txCard)
        btn:SetHeight(18)

        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btnText:SetText(L[info.localeKey])
        btnText:SetPoint("CENTER", 0, 0)

        local textW = btnText:GetStringWidth()
        if textW < 5 then textW = 24 end
        btn:SetWidth(textW + 12)

        if xOff + btn:GetWidth() > maxRowWidth and xOff > 0 then
            xOff = 0
            filterY = filterY - 20
        end

        btn:SetPoint("TOPLEFT", txCard, "TOPLEFT", 10 + xOff, filterY)

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()

        btn.text = btnText
        btn.bg = bg
        btn.key = info.key
        local sc = GetSourceColors()
        btn.color = sc[info.key] or { 1, 1, 1 }

        btn:SetScript("OnClick", function()
            activeFilter = info.key
            UpdateFilterButtons()
            UpdateEntryRows()
        end)

        f.filterButtons[#f.filterButtons + 1] = btn
        xOff = xOff + btn:GetWidth() + 3
    end

    local scrollY = filterY - 22

    -- Scroll frame for transactions
    local scrollFrame = CreateFrame("ScrollFrame", "GoldLedgerScrollFrame", txCard, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", txCard, "TOPLEFT", 4, scrollY)
    scrollFrame:SetPoint("BOTTOMRIGHT", txCard, "BOTTOMRIGHT", -24, 4)

    local scrollBg = txCard:CreateTexture(nil, "BACKGROUND", nil, -1)
    scrollBg:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", -2, 2)
    scrollBg:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 20, -2)
    scrollBg:SetColorTexture(TC("SCROLL_BG"))

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(FRAME_WIDTH - 60)
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
-- Transaction rows
-------------------------------------------------------------------------------
local ROW_HEIGHT = 20
local MAX_VISIBLE = 50

local function CreateEntryRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -((index - 1) * ROW_HEIGHT))

    if index % 2 == 0 then
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(TC("ROW_ALT"))
    end

    row.timeText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.timeText:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.timeText:SetWidth(42)
    row.timeText:SetJustifyH("LEFT")
    row.timeText:SetTextColor(TC("TEXT_TIME"))

    row.sourceTag = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.sourceTag:SetPoint("LEFT", row.timeText, "RIGHT", 4, 0)
    row.sourceTag:SetWidth(55)
    row.sourceTag:SetJustifyH("LEFT")

    row.amountText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.amountText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.amountText:SetJustifyH("RIGHT")

    function row:SetEntry(entry)
        self.timeText:SetText(date(L["TIME_FORMAT"], entry.timestamp))
        self.amountText:SetText(GoldFormatter.Colored(entry.amount, entry.type))

        local source = entry.source or "unknown"
        local Tracker = GoldLedger:GetModule("Tracker")
        local localeKey = Tracker and Tracker:GetSourceLocaleKey(source) or "SRC_UNKNOWN"
        local sc = GetSourceColors()
        local color = sc[source] or sc.unknown
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

    if chartWidth < 10 then return end

    local barGroupWidth = chartWidth / totalBars
    local barWidth = math.max(2, (barGroupWidth - 2) / 2)
    local todayKey = date("%Y-%m-%d")

    mainFrame.chartMaxLabel:SetText(GoldFormatter.Short(maxVal))

    local labelStep = math.max(1, math.ceil(totalBars / 6))

    for _, lbl in pairs(mainFrame.chartDayLabels) do
        lbl:Hide()
    end

    for i, dayData in ipairs(chartData) do
        if not mainFrame.chartBars[i] then
            local incBar = container:CreateTexture(nil, "ARTWORK")
            local expBar = container:CreateTexture(nil, "ARTWORK")
            mainFrame.chartBars[i] = { income = incBar, expense = expBar }
        end

        if not mainFrame.chartDayLabels[i] then
            local dayLabel = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            dayLabel:SetTextColor(TC("DAY_LABEL"))
            mainFrame.chartDayLabels[i] = dayLabel
        end

        local bars = mainFrame.chartBars[i]
        local xOffset = (i - 1) * barGroupWidth

        local incHeight = dayData.income > 0 and math.max(2, (dayData.income / maxVal) * CHART_HEIGHT) or 0
        bars.income:ClearAllPoints()
        bars.income:SetSize(barWidth, incHeight)
        bars.income:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", xOffset + 1, 0)
        bars.income:SetShown(dayData.income > 0)

        local expHeight = dayData.expense > 0 and math.max(2, (dayData.expense / maxVal) * CHART_HEIGHT) or 0
        bars.expense:ClearAllPoints()
        bars.expense:SetSize(barWidth, expHeight)
        bars.expense:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", xOffset + 1 + barWidth, 0)
        bars.expense:SetShown(dayData.expense > 0)

        local isToday = dayData.dateKey == todayKey
        local alpha = isToday and 1 or 0.5
        local inc = T("INCOME")
        local exp = T("EXPENSE")
        bars.income:SetColorTexture(inc[1], inc[2], inc[3], alpha)
        bars.expense:SetColorTexture(exp[1], exp[2], exp[3], alpha)

        local lbl = mainFrame.chartDayLabels[i]
        if i == 1 or i % labelStep == 0 then
            lbl:ClearAllPoints()
            lbl:SetPoint("TOP", container, "BOTTOMLEFT", xOffset + barGroupWidth / 2, -1)
            lbl:SetText(dayData.label)
            lbl:Show()
        else
            lbl:Hide()
        end

        if not mainFrame.chartHitFrames[i] then
            local hit = CreateFrame("Frame", nil, container)
            hit:EnableMouse(true)
            hit:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(self.tipDate or "", 1, 1, 1)
                if self.tipIncome and self.tipIncome > 0 then
                    GameTooltip:AddLine(L["HEADER_INCOME"] .. ": " .. GoldFormatter.Full(self.tipIncome), TC("INCOME"))
                end
                if self.tipExpense and self.tipExpense > 0 then
                    GameTooltip:AddLine(L["HEADER_EXPENSE"] .. ": " .. GoldFormatter.Full(self.tipExpense), TC("EXPENSE"))
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
        mainFrame.goalText:SetTextColor(TC("TEXT_DIM"))
        mainFrame.goalEta:SetText("")
        return
    end

    local barWidth = mainFrame.goalBarBg:GetWidth()
    if barWidth < 1 then barWidth = 1 end
    local fillWidth = math.max(1, barWidth * goalInfo.progress)

    mainFrame.goalBarFill:SetWidth(fillWidth)
    mainFrame.goalBarFill:Show()

    if goalInfo.progress >= 1 then
        mainFrame.goalBarFill:SetColorTexture(TC("GOAL_DONE"))
        mainFrame.goalText:SetText(L["GOAL_REACHED"])
        mainFrame.goalText:SetTextColor(TC("GOAL_DONE"))
        mainFrame.goalEta:SetText("")
    else
        mainFrame.goalBarFill:SetColorTexture(TC("GOAL_FILL"))
        local pct = math.floor(goalInfo.progress * 100)
        mainFrame.goalText:SetText(
            GoldFormatter.Short(goalInfo.current) .. " / " ..
            GoldFormatter.Short(goalInfo.goal) .. " (" .. pct .. "%)")
        mainFrame.goalText:SetTextColor(TC("TEXT_WHITE"))

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

    -- On Hand
    local currentGold = GetMoney() or 0
    mainFrame.onHandValue:SetText(GoldFormatter.Full(currentGold))

    -- Today
    local today = Data:GetDailySummary()
    mainFrame.todayIncome:SetValue(GoldFormatter.Full(today.income), TC("INCOME"))
    mainFrame.todayExpense:SetValue(GoldFormatter.Full(today.expense), TC("EXPENSE"))

    local todayNet = today.income - today.expense
    local tc = todayNet >= 0 and T("BALANCE_POS") or T("BALANCE_NEG")
    mainFrame.todayBalance:SetValue(
        (todayNet >= 0 and "+" or "-") .. GoldFormatter.Full(math.abs(todayNet)),
        tc[1], tc[2], tc[3])

    -- Month
    local month = Data:GetMonthlySummary()
    mainFrame.monthIncome:SetValue(GoldFormatter.Full(month.income), TC("INCOME"))
    mainFrame.monthExpense:SetValue(GoldFormatter.Full(month.expense), TC("EXPENSE"))

    local monthNet = month.income - month.expense
    local mc = monthNet >= 0 and T("BALANCE_POS") or T("BALANCE_NEG")
    mainFrame.monthBalance:SetValue(
        (monthNet >= 0 and "+" or "-") .. GoldFormatter.Full(math.abs(monthNet)),
        mc[1], mc[2], mc[3])

    -- Session
    local TrackerMod = GoldLedger:GetModule("Tracker")
    if TrackerMod then
        local session = TrackerMod:GetSessionStats()
        mainFrame.sessionIncome:SetValue(GoldFormatter.Full(session.income), TC("INCOME"))
        mainFrame.sessionExpense:SetValue(GoldFormatter.Full(session.expense), TC("EXPENSE"))

        local sc = session.net >= 0 and T("BALANCE_POS") or T("BALANCE_NEG")
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

    f:SetBackdrop(GetBackdrop())
    f:SetBackdropColor(TC("FRAME_BG"))
    f:SetBackdropBorderColor(TC("BORDER"))

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetHeight(26)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    local Themes = GoldLedger:GetModule("Themes")
    titleBar:SetBackdrop({ bgFile = Themes:GetBgTexture() })
    titleBar:SetBackdropColor(TC("TITLE_BG"))

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    title:SetText("|cffffd700" .. L["HEADER_CHARACTERS"] .. "|r")

    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Подзаголовок
    local subHeader = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subHeader:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -36)
    subHeader:SetText(L["CHAR_MONTH_LABEL"])
    subHeader:SetTextColor(TC("LABEL"))

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "GoldLedgerCharsScrollFrame", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -52)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 44)

    local scrollBg = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    scrollBg:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", -2, 2)
    scrollBg:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 20, -2)
    scrollBg:SetColorTexture(TC("SCROLL_BG"))

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(300)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    f.scrollChild = scrollChild
    f.charRows = {}

    -- Итого по аккаунту
    MakeSeparator(f, -340)

    f.totalLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.totalLabel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 14)
    f.totalLabel:SetText(L["HEADER_ACCOUNT_TOTAL"])
    f.totalLabel:SetTextColor(TC("HEADER"))

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
                bg:SetColorTexture(TC("ROW_ALT"))
            end

            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
            row.nameText:SetJustifyH("LEFT")

            row.detailText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.detailText:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 4)
            row.detailText:SetJustifyH("LEFT")
            row.detailText:SetTextColor(TC("LABEL"))

            row.netText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.netText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            row.netText:SetJustifyH("RIGHT")

            charsFrame.charRows[i] = row
        end

        row.nameText:SetText(charInfo.name)

        local detail = L["HEADER_INCOME"] .. ": " .. GoldFormatter.Short(charInfo.monthIncome) ..
                       "  " .. L["HEADER_EXPENSE"] .. ": " .. GoldFormatter.Short(charInfo.monthExpense)
        row.detailText:SetText(detail)

        local netColor = charInfo.monthNet >= 0 and T("BALANCE_POS") or T("BALANCE_NEG")
        local netSign = charInfo.monthNet >= 0 and "+" or "-"
        row.netText:SetText(netSign .. GoldFormatter.Full(math.abs(charInfo.monthNet)))
        row.netText:SetTextColor(netColor[1], netColor[2], netColor[3])

        row:Show()
    end

    for i = #chars + 1, #charsFrame.charRows do
        charsFrame.charRows[i]:Hide()
    end

    scrollChild:SetHeight(math.max(1, #chars * CHAR_ROW_HEIGHT))

    local totalNet = 0
    for _, charInfo in ipairs(chars) do
        totalNet = totalNet + charInfo.monthNet
    end
    local tc = totalNet >= 0 and T("BALANCE_POS") or T("BALANCE_NEG")
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

    f:SetBackdrop(GetBackdrop())
    f:SetBackdropColor(TC("FRAME_BG"))
    f:SetBackdropBorderColor(TC("BORDER"))

    local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetHeight(26)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    local Themes = GoldLedger:GetModule("Themes")
    titleBar:SetBackdrop({ bgFile = Themes:GetBgTexture() })
    titleBar:SetBackdropColor(TC("TITLE_BG"))

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    title:SetText("|cffffd700" .. L["EXPORT_TITLE"] .. "|r")

    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -36)
    hint:SetText(L["EXPORT_HINT"])
    hint:SetTextColor(TC("TEXT_HINT"))

    local scrollFrame = CreateFrame("ScrollFrame", "GoldLedgerExportScrollFrame", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -52)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 8)

    local scrollBg = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    scrollBg:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", -2, 2)
    scrollBg:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 20, -2)
    scrollBg:SetColorTexture(TC("CHART_BG"))

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
-- Source Breakdown Popup
-------------------------------------------------------------------------------
local breakdownFrame
local activeBreakdownPeriod = "today"
local UpdateBreakdownData

local function CreateBreakdownFrame()
    local Data = GoldLedger:GetModule("Data")
    local Tracker = GoldLedger:GetModule("Tracker")

    local f = CreateFrame("Frame", "GoldLedgerBreakdownFrame", UIParent, "BackdropTemplate")
    f:SetSize(380, 380)
    f:SetPoint("CENTER", UIParent, "CENTER", -200, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)

    f:SetBackdrop(GetBackdrop())
    f:SetBackdropColor(TC("FRAME_BG"))
    f:SetBackdropBorderColor(TC("BORDER"))

    local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetHeight(26)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    local Themes = GoldLedger:GetModule("Themes")
    titleBar:SetBackdrop({ bgFile = Themes:GetBgTexture() })
    titleBar:SetBackdropColor(TC("TITLE_BG"))

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    title:SetText("|cffffd700" .. L["HEADER_BREAKDOWN"] .. "|r")

    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Period buttons
    local periods = {
        { key = "today", label = L["BREAKDOWN_TODAY"] },
        { key = "week",  label = L["BREAKDOWN_WEEK"] },
        { key = "month", label = L["BREAKDOWN_MONTH"] },
        { key = "all",   label = L["BREAKDOWN_ALL"] },
    }

    local periodBtns = {}
    local btnX = -14
    for i = #periods, 1, -1 do
        local info = periods[i]
        local btn = CreateFrame("Button", nil, f, "BackdropTemplate")
        btn:SetSize(60, 18)
        btn:SetPoint("TOPRIGHT", f, "TOPRIGHT", btnX, -36)
        btn:SetBackdrop(GetSmallBackdrop())
        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btnText:SetPoint("CENTER")
        btnText:SetText(info.label)
        btn.key = info.key
        periodBtns[info.key] = btn
        btnX = btnX - 64

        btn:SetScript("OnClick", function()
            activeBreakdownPeriod = info.key
            UpdateBreakdownData()
        end)
    end

    f.periodBtns = periodBtns

    -- Column headers
    local colY = -60

    local srcHeader = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    srcHeader:SetPoint("TOPLEFT", f, "TOPLEFT", 18, colY)
    srcHeader:SetText(L["BREAKDOWN_SOURCE"])
    srcHeader:SetTextColor(TC("LABEL"))

    local incHeader = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    incHeader:SetPoint("TOPRIGHT", f, "TOP", 40, colY)
    incHeader:SetText(L["HEADER_INCOME"])
    incHeader:SetTextColor(TC("LABEL"))
    incHeader:SetJustifyH("RIGHT")

    local expHeader = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    expHeader:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, colY)
    expHeader:SetText(L["HEADER_EXPENSE"])
    expHeader:SetTextColor(TC("LABEL"))
    expHeader:SetJustifyH("RIGHT")

    MakeSeparator(f, colY - 14)

    -- Source rows
    local BD_ROW_HEIGHT = 26
    local rowY = colY - 20
    f.sourceRows = {}

    for idx, src in ipairs(Data.ALL_SOURCES) do
        local sc = GetSourceColors()
        local color = sc[src] or sc.unknown
        local localeKey = Tracker:GetSourceLocaleKey(src)

        if idx % 2 == 0 then
            local rowBg = f:CreateTexture(nil, "BACKGROUND")
            rowBg:SetPoint("TOPLEFT", f, "TOPLEFT", 6, rowY + 2)
            rowBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, rowY + 2)
            rowBg:SetHeight(BD_ROW_HEIGHT)
            rowBg:SetColorTexture(TC("ROW_ALT"))
        end

        local srcName = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        srcName:SetPoint("TOPLEFT", f, "TOPLEFT", 18, rowY - 4)
        srcName:SetText(L[localeKey])
        srcName:SetTextColor(color[1], color[2], color[3])

        local incVal = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        incVal:SetPoint("TOPRIGHT", f, "TOP", 40, rowY - 4)
        incVal:SetJustifyH("RIGHT")

        local expVal = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        expVal:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, rowY - 4)
        expVal:SetJustifyH("RIGHT")

        f.sourceRows[src] = { income = incVal, expense = expVal }
        rowY = rowY - BD_ROW_HEIGHT
    end

    MakeSeparator(f, rowY + 2)

    local totalLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    totalLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 18, rowY - 8)
    totalLabel:SetText(L["BREAKDOWN_TOTAL"])
    totalLabel:SetTextColor(TC("HEADER"))

    f.totalIncome = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.totalIncome:SetPoint("TOPRIGHT", f, "TOP", 40, rowY - 8)
    f.totalIncome:SetJustifyH("RIGHT")

    f.totalExpense = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.totalExpense:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, rowY - 8)
    f.totalExpense:SetJustifyH("RIGHT")

    table.insert(UISpecialFrames, "GoldLedgerBreakdownFrame")

    breakdownFrame = f
    f:Hide()
    return f
end

UpdateBreakdownData = function()
    if not breakdownFrame or not breakdownFrame:IsShown() then return end

    local Data = GoldLedger:GetModule("Data")
    local sourceTotals, grandTotals = Data:GetSourceBreakdown(activeBreakdownPeriod)

    for key, btn in pairs(breakdownFrame.periodBtns) do
        if key == activeBreakdownPeriod then
            btn:SetBackdropColor(TC("BTN_ACTIVE"))
        else
            btn:SetBackdropColor(TC("BTN_INACTIVE"))
        end
        btn:SetBackdropBorderColor(TC("BTN_BORDER"))
    end

    for src, row in pairs(breakdownFrame.sourceRows) do
        local data = sourceTotals[src] or { income = 0, expense = 0 }

        if data.income > 0 then
            row.income:SetText("+" .. GoldFormatter.Short(data.income))
            row.income:SetTextColor(TC("INCOME"))
        else
            row.income:SetText("0")
            row.income:SetTextColor(TC("ZERO_VALUE"))
        end

        if data.expense > 0 then
            row.expense:SetText("-" .. GoldFormatter.Short(data.expense))
            row.expense:SetTextColor(TC("EXPENSE"))
        else
            row.expense:SetText("0")
            row.expense:SetTextColor(TC("ZERO_VALUE"))
        end
    end

    if grandTotals.income > 0 then
        breakdownFrame.totalIncome:SetText("+" .. GoldFormatter.Short(grandTotals.income))
        breakdownFrame.totalIncome:SetTextColor(TC("INCOME"))
    else
        breakdownFrame.totalIncome:SetText("0")
        breakdownFrame.totalIncome:SetTextColor(TC("ZERO_VALUE"))
    end

    if grandTotals.expense > 0 then
        breakdownFrame.totalExpense:SetText("-" .. GoldFormatter.Short(grandTotals.expense))
        breakdownFrame.totalExpense:SetTextColor(TC("EXPENSE"))
    else
        breakdownFrame.totalExpense:SetText("0")
        breakdownFrame.totalExpense:SetTextColor(TC("ZERO_VALUE"))
    end
end

-------------------------------------------------------------------------------
-- Settings frame (forward declaration)
-------------------------------------------------------------------------------
local settingsFrame

-------------------------------------------------------------------------------
-- Theme switching: destroy-and-recreate
-------------------------------------------------------------------------------

function UI:ApplyTheme()
    local frames = { mainFrame, charsFrame, exportFrame, breakdownFrame, goalDialog }
    for _, frame in ipairs(frames) do
        if frame then frame:Hide(); frame:SetParent(nil) end
    end
    if settingsFrame then settingsFrame:Hide() end

    mainFrame = nil
    charsFrame = nil
    exportFrame = nil
    breakdownFrame = nil
    goalDialog = nil

    if minimapButton then
        minimapButton:Hide()
        minimapButton = nil
    end
    CreateMinimapButton()
end

-------------------------------------------------------------------------------
-- Settings Popup
-------------------------------------------------------------------------------

-- Settings: создаём фрейм один раз, обновляем содержимое через RefreshSettings
local settingsElements = {}  -- хранит ссылки на элементы для обновления
local RefreshSettings  -- forward declaration

local function CreateSettingsFrame()
    if settingsFrame then return end

    local f = CreateFrame("Frame", "GoldLedgerSettingsFrame", UIParent, "BackdropTemplate")
    f:SetSize(320, 300)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetClampedToScreen(true)

    f:SetBackdrop(GetBackdrop())

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetHeight(26)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    settingsElements.titleBar = titleBar

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    settingsElements.title = title

    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local y = -40

    -- Theme label
    local themeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    themeLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 14, y)
    settingsElements.themeLabel = themeLabel

    -- Theme buttons (3 max)
    y = y - 20
    settingsElements.themeBtns = {}
    for i = 1, 3 do
        local tbtn = CreateFrame("Button", nil, f, "BackdropTemplate")
        tbtn:SetSize(90, 22)
        tbtn:SetPoint("TOPLEFT", f, "TOPLEFT", 14 + (i - 1) * 96, y)
        tbtn:SetBackdrop(GetSmallBackdrop())
        local tbtnText = tbtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tbtnText:SetPoint("CENTER")
        tbtn.text = tbtnText
        tbtn:Hide()
        settingsElements.themeBtns[i] = tbtn
    end

    y = y - 36

    -- Minimap label
    local minimapLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    minimapLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 14, y)
    settingsElements.minimapLabel = minimapLabel

    local minimapCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    minimapCheck:SetPoint("LEFT", minimapLabel, "RIGHT", 6, 0)
    minimapCheck:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        GoldLedgerDB.settings.showMinimap = checked
        if minimapButton then
            if checked then minimapButton:Show() else minimapButton:Hide() end
        end
    end)
    settingsElements.minimapCheck = minimapCheck

    y = y - 36

    -- Language label
    local langLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    langLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 14, y)
    settingsElements.langLabel = langLabel

    -- Language buttons (3)
    y = y - 20
    settingsElements.langBtns = {}
    local langIds = { "auto", "enUS", "ruRU" }
    local langLabelsFixed = { nil, "English", "Русский" } -- auto label обновляется
    for i = 1, 3 do
        local btn = CreateFrame("Button", nil, f, "BackdropTemplate")
        btn:SetSize(90, 22)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", 14 + (i - 1) * 96, y)
        btn:SetBackdrop(GetSmallBackdrop())
        local lbText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbText:SetPoint("CENTER")
        btn.text = lbText
        btn.langId = langIds[i]
        btn:SetScript("OnClick", function()
            GoldLedgerDB.settings.language = langIds[i]
            local localeArg = langIds[i] == "auto" and nil or langIds[i]
            L:SetLocale(localeArg)
            C_Timer.After(0, function()
                UI:ApplyTheme()
                RefreshSettings()
            end)
        end)
        settingsElements.langBtns[i] = btn
    end

    y = y - 36

    -- Reset session button
    local resetBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
    resetBtn:SetSize(140, 24)
    resetBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 14, y)
    resetBtn:SetBackdrop(GetSmallBackdrop())
    local resetText = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    resetText:SetPoint("CENTER")
    resetBtn.text = resetText
    resetBtn:SetScript("OnClick", function()
        local Tracker = GoldLedger:GetModule("Tracker")
        Tracker:ResetSession()
        UI:ApplyTheme()
        settingsFrame:Hide()
    end)
    settingsElements.resetBtn = resetBtn

    table.insert(UISpecialFrames, "GoldLedgerSettingsFrame")

    settingsFrame = f
    f:Hide()
end

RefreshSettings = function()
    if not settingsFrame then CreateSettingsFrame() end
    local f = settingsFrame
    local Themes = GoldLedger:GetModule("Themes")

    -- Обновить цвета фрейма
    f:SetBackdropColor(TC("FRAME_BG"))
    f:SetBackdropBorderColor(TC("BORDER"))

    -- Title bar
    settingsElements.titleBar:SetBackdrop({ bgFile = Themes:GetBgTexture() })
    settingsElements.titleBar:SetBackdropColor(TC("TITLE_BG"))
    settingsElements.title:SetText("|cffffd700" .. L["HEADER_SETTINGS"] .. "|r")

    -- Theme label
    settingsElements.themeLabel:SetText(L["SETTINGS_THEME"])
    settingsElements.themeLabel:SetTextColor(TC("LABEL"))

    -- Theme buttons
    local availableThemes = Themes:GetAvailableThemes()
    local currentThemeId = Themes:GetActiveId()
    for i, tbtn in ipairs(settingsElements.themeBtns) do
        local themeInfo = availableThemes[i]
        if themeInfo then
            tbtn.text:SetText(themeInfo.name)
            tbtn:SetScript("OnClick", function()
                C_Timer.After(0, function()
                    Themes:SetTheme(themeInfo.id)
                    RefreshSettings()
                end)
            end)
            if themeInfo.id == currentThemeId then
                tbtn:SetBackdropColor(TC("BTN_ACTIVE"))
                tbtn:SetBackdropBorderColor(TC("ACCENT_BTN_BORDER"))
                tbtn.text:SetTextColor(TC("TEXT_WHITE"))
            else
                tbtn:SetBackdropColor(TC("BTN_BG"))
                tbtn:SetBackdropBorderColor(TC("BTN_BORDER"))
                tbtn.text:SetTextColor(TC("LABEL"))
            end
            tbtn:Show()
        else
            tbtn:Hide()
        end
    end

    -- Minimap
    settingsElements.minimapLabel:SetText(L["SETTINGS_MINIMAP"])
    settingsElements.minimapLabel:SetTextColor(TC("LABEL"))
    settingsElements.minimapCheck:SetChecked(GoldLedgerDB.settings.showMinimap ~= false)

    -- Language
    settingsElements.langLabel:SetText(L["SETTINGS_LANGUAGE"])
    settingsElements.langLabel:SetTextColor(TC("LABEL"))

    local currentLang = GoldLedgerDB.settings.language or "auto"
    local langLabels = { L["SETTINGS_LANG_AUTO"], "English", "Русский" }
    for i, btn in ipairs(settingsElements.langBtns) do
        btn.text:SetText(langLabels[i])
        if btn.langId == currentLang then
            btn:SetBackdropColor(TC("BTN_ACTIVE"))
            btn:SetBackdropBorderColor(TC("ACCENT_BTN_BORDER"))
            btn.text:SetTextColor(TC("TEXT_WHITE"))
        else
            btn:SetBackdropColor(TC("BTN_BG"))
            btn:SetBackdropBorderColor(TC("BTN_BORDER"))
            btn.text:SetTextColor(TC("LABEL"))
        end
    end

    -- Reset session button
    settingsElements.resetBtn.text:SetText(L["SETTINGS_RESET_SESSION"])
    settingsElements.resetBtn:SetBackdropColor(TC("BTN_BG"))
    settingsElements.resetBtn:SetBackdropBorderColor(TC("BTN_BORDER"))
    settingsElements.resetBtn.text:SetTextColor(TC("EXPENSE"))
end

function UI:ToggleSettingsFrame()
    if not settingsFrame then
        CreateSettingsFrame()
    end
    RefreshSettings()
    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        settingsFrame:Show()
    end
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function UI:ToggleBreakdownFrame()
    if not breakdownFrame then
        CreateBreakdownFrame()
    end
    if breakdownFrame:IsShown() then
        breakdownFrame:Hide()
    else
        breakdownFrame:Show()
        UpdateBreakdownData()
    end
end

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

    if GoldLedgerDB and GoldLedgerDB.settings and GoldLedgerDB.settings.showMinimap == false then
        if minimapButton then minimapButton:Hide() end
    end

    local Tracker = GoldLedger:GetModule("Tracker")
    if Tracker then
        Tracker:OnGoldChanged(function()
            UpdateSummaries()
        end)
    end
end
