--[[
    GoldLedger: Tracker.lua
    Patterns: Observer, State

    Отслеживает изменения голды через WoW-ивенты:
    - PLAYER_LOGIN → запоминает начальный баланс
    - PLAYER_MONEY → вычисляет дельту, логирует через Data
    - Контекстные ивенты → определяет источник (вендор, АХ, почта и т.д.)
    - Callback система для уведомления UI об изменениях
]]

local ADDON_NAME, ns = ...
local GoldLedger = ns.GoldLedger
local L = ns.L

local Tracker = {}
GoldLedger:RegisterModule("Tracker", Tracker)

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------
local lastGold = 0          -- Последнее известное количество голды (copper)
local isReady = false       -- Готов ли трекер (после PLAYER_LOGIN)
local sessionIncome = 0     -- Доход за текущую сессию (copper)
local sessionExpense = 0    -- Расход за текущую сессию (copper)
local repairPending = false -- Флаг: была вызвана RepairAllItems()

-------------------------------------------------------------------------------
-- State Pattern: контекст источника транзакции
-- Отслеживаем какой UI открыт, чтобы определить откуда пришли деньги
-------------------------------------------------------------------------------
local currentSource = "unknown"

-- Таблица: WoW event → source key
local SOURCE_EVENTS = {
    -- Vendor
    MERCHANT_SHOW           = "vendor",
    MERCHANT_CLOSED         = "clear",

    -- Auction House
    AUCTION_HOUSE_SHOW      = "ah",
    AUCTION_HOUSE_CLOSED    = "clear",

    -- Mail
    MAIL_SHOW               = "mail",
    MAIL_CLOSED             = "clear",

    -- Trade
    TRADE_SHOW              = "trade",
    TRADE_CLOSED            = "clear",

    -- Quest
    QUEST_TURNED_IN         = "quest",

    -- Loot
    LOOT_OPENED             = "loot",
    LOOT_CLOSED             = "clear",
}

--- Возвращает текущий определённый источник
--- @return string source key
function Tracker:GetCurrentSource()
    return currentSource
end

--- Locale key для источника
--- @param source string
--- @return string
function Tracker:GetSourceLocaleKey(source)
    local map = {
        vendor  = "SRC_VENDOR",
        repair  = "SRC_REPAIR",
        ah      = "SRC_AH",
        mail    = "SRC_MAIL",
        quest   = "SRC_QUEST",
        loot    = "SRC_LOOT",
        trade   = "SRC_TRADE",
        unknown = "SRC_UNKNOWN",
    }
    return map[source] or "SRC_UNKNOWN"
end

-------------------------------------------------------------------------------
-- Observer: callbacks при изменении голды
-------------------------------------------------------------------------------
local changeCallbacks = {}

--- Регистрирует callback на изменение голды
--- @param callback function(amount, entryType, newTotal, source)
function Tracker:OnGoldChanged(callback)
    table.insert(changeCallbacks, callback)
end

--- Уведомляет всех подписчиков об изменении
local function NotifyChange(amount, entryType, newTotal, source)
    for _, callback in ipairs(changeCallbacks) do
        callback(amount, entryType, newTotal, source)
    end
end

-------------------------------------------------------------------------------
-- Gold Detection
-------------------------------------------------------------------------------

function Tracker:GetCurrentGold()
    return GetMoney() or 0
end

function Tracker:GetLastGold()
    return lastGold
end

--- Статистика текущей сессии
--- @return table {income, expense, net}
function Tracker:GetSessionStats()
    return {
        income = sessionIncome,
        expense = sessionExpense,
        net = sessionIncome - sessionExpense,
    }
end

--- Обрабатывает изменение голды
local function ProcessGoldChange()
    if not isReady then return end

    local currentGold = GetMoney()
    local delta = currentGold - lastGold

    if delta == 0 then
        lastGold = currentGold
        return
    end

    local absAmount = math.abs(delta)
    local entryType = delta > 0 and "income" or "expense"
    local source = currentSource

    -- Детект ремонта: если у вендора, расход и был вызван RepairAllItems()
    if source == "vendor" and entryType == "expense" and repairPending then
        source = "repair"
        repairPending = false
    end

    -- Детект АХ-почты: если у почтового ящика, проверяем отправителя
    if source == "mail" and entryType == "income" then
        local numItems = GetInboxNumItems()
        for i = 1, numItems do
            local _, _, sender = GetInboxHeaderInfo(i)
            if sender and (sender == "Auction House" or sender == "Аукционный дом") then
                source = "ah"
                GoldLedger:Debug("Tracker", "AH mail detected from:", sender)
                break
            end
        end
    end

    -- Обновляем статистику сессии
    if entryType == "income" then
        sessionIncome = sessionIncome + absAmount
    else
        sessionExpense = sessionExpense + absAmount
    end

    -- Квест-контекст сбрасывается сразу после одной транзакции
    if currentSource == "quest" then
        currentSource = "unknown"
    end

    -- Debug
    GoldLedger:Debug("Tracker",
        entryType, "| source:", source,
        "| delta:", delta,
        "| before:", lastGold,
        "| after:", currentGold
    )

    -- Логируем через Data
    local Data = GoldLedger:GetModule("Data")
    if Data then
        Data:AddEntry(delta, source)
    end

    -- Уведомляем подписчиков
    NotifyChange(absAmount, entryType, currentGold, source)

    lastGold = currentGold
end

-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------

function Tracker:OnEnable()
    lastGold = GetMoney()
    isReady = true

    GoldLedger:Debug("Tracker", "Ready | starting gold:", lastGold)

    -- Хук на RepairAllItems() для отделения ремонта от покупок у вендора
    hooksecurefunc("RepairAllItems", function()
        repairPending = true
        GoldLedger:Debug("Tracker", "RepairAllItems() called — repair pending")
    end)

    -- Подписка на изменение голды
    GoldLedger:RegisterEvent("PLAYER_MONEY", function()
        ProcessGoldChange()
    end)

    -- Подписка на контекстные ивенты для определения источника
    for event, sourceKey in pairs(SOURCE_EVENTS) do
        GoldLedger:RegisterEvent(event, function()
            if sourceKey == "clear" then
                currentSource = "unknown"
            else
                currentSource = sourceKey
            end
            GoldLedger:Debug("Tracker", "Context →", currentSource, "(from " .. event .. ")")
        end)
    end
end
