--[[
    GoldLedger: Core.lua
    Patterns: Module, Observer (Event Bus), Singleton

    Ядро аддона:
    - Module system для регистрации и доступа к модулям
    - Event bus с dispatch-таблицей (Observer pattern)
    - Slash-команды /gl и /goldledger
    - Инициализация при ADDON_LOADED
]]

local ADDON_NAME, ns = ...
local L = ns.L

-------------------------------------------------------------------------------
-- Singleton: глобальный namespace аддона
-------------------------------------------------------------------------------
local GoldLedger = {}
GoldLedger.name = ADDON_NAME
GoldLedger.version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "1.0.0"

-- Export to global and namespace
_G.GoldLedger = GoldLedger
ns.GoldLedger = GoldLedger

-------------------------------------------------------------------------------
-- Module Pattern: регистрация и доступ к модулям
-------------------------------------------------------------------------------
local modules = {}

--- Регистрирует модуль в системе
--- @param name string Имя модуля
--- @param module table Таблица модуля
function GoldLedger:RegisterModule(name, module)
    if modules[name] then
        error(("GoldLedger: Module '%s' already registered"):format(name))
    end
    modules[name] = module
    module.name = name
    return module
end

--- Возвращает зарегистрированный модуль
--- @param name string Имя модуля
--- @return table|nil
function GoldLedger:GetModule(name)
    return modules[name]
end

--- Вызывает метод на всех модулях (если метод существует)
--- @param method string Имя метода
--- @param ... any Аргументы
function GoldLedger:CallModules(method, ...)
    for _, mod in pairs(modules) do
        if type(mod[method]) == "function" then
            mod[method](mod, ...)
        end
    end
end

-------------------------------------------------------------------------------
-- Observer Pattern: Event Bus с dispatch-таблицей
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local eventHandlers = {} -- { [event] = { callback1, callback2, ... } }

--- Регистрирует обработчик WoW-ивента
--- @param event string WoW event name
--- @param callback function Обработчик
function GoldLedger:RegisterEvent(event, callback)
    if not eventHandlers[event] then
        eventHandlers[event] = {}
        eventFrame:RegisterEvent(event)
    end
    table.insert(eventHandlers[event], callback)
end

--- Снимает все обработчики ивента
--- @param event string WoW event name
function GoldLedger:UnregisterEvent(event)
    eventHandlers[event] = nil
    eventFrame:UnregisterEvent(event)
end

-- Центральный dispatch: один OnEvent для всех ивентов
eventFrame:SetScript("OnEvent", function(_, event, ...)
    local handlers = eventHandlers[event]
    if handlers then
        for _, callback in ipairs(handlers) do
            callback(event, ...)
        end
    end
end)

-------------------------------------------------------------------------------
-- Initialization: ADDON_LOADED
-------------------------------------------------------------------------------
GoldLedger:RegisterEvent("ADDON_LOADED", function(event, loadedAddon)
    if loadedAddon ~= ADDON_NAME then return end

    -- Инициализация SavedVariables с defaults
    GoldLedger:CallModules("OnInitialize")

    -- Приветственное сообщение
    print(L["ADDON_LOADED"])

    -- Больше не нужен этот ивент
    GoldLedger:UnregisterEvent("ADDON_LOADED")
end)

-- PLAYER_LOGIN: модули могут подключиться к игровым данным
GoldLedger:RegisterEvent("PLAYER_LOGIN", function()
    GoldLedger:CallModules("OnEnable")
    GoldLedger:UnregisterEvent("PLAYER_LOGIN")
end)

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
SLASH_GOLDLEDGER1 = "/gl"
SLASH_GOLDLEDGER2 = "/goldledger"

SlashCmdList["GOLDLEDGER"] = function(msg)
    local cmd = strtrim(msg):lower()

    if cmd == "reset" then
        local Data = GoldLedger:GetModule("Data")
        if Data then
            Data:ResetCharacterData()
            print("|cff00ff00GoldLedger:|r " .. L["RESET_CONFIRM"])
        end
    elseif cmd == "debug" then
        GoldLedger:SetDebug(not debugMode)
    elseif cmd == "dump" then
        local Data = GoldLedger:GetModule("Data")
        if Data then
            GoldLedger:DumpTable("Daily", Data:GetDailySummary())
            GoldLedger:DumpTable("Monthly", Data:GetMonthlySummary())
            GoldLedger:DumpTable("Settings", Data:GetSettings())
            print("|cff888888[GL:Dump]|r Entries: " .. #Data:GetRecentEntries(999))
        end
    elseif cmd == "settings" or cmd == "config" then
        local UI = GoldLedger:GetModule("UI")
        if UI then UI:ToggleSettingsFrame() end
    elseif cmd == "help" then
        print("|cff00ff00GoldLedger:|r " .. L["SLASH_HELP"])
    elseif cmd:sub(1, 4) == "goal" then
        local arg = strtrim(cmd:sub(5))
        local Data = GoldLedger:GetModule("Data")
        if Data then
            if arg == "clear" or arg == "reset" then
                Data:ClearGoal()
                print("|cff00ff00GoldLedger:|r " .. L["GOAL_CLEARED"])
            elseif tonumber(arg) and tonumber(arg) > 0 then
                local goldAmount = tonumber(arg)
                Data:SetGoal(goldAmount * 10000)
                print("|cff00ff00GoldLedger:|r " .. L["GOAL_SET"]:format(goldAmount .. L["GOLD_ABBR"]))
            else
                print("|cff00ff00GoldLedger:|r " .. L["GOAL_USAGE"])
            end
        end
    else
        -- Default: toggle main window
        local UI = GoldLedger:GetModule("UI")
        if UI then
            UI:ToggleMainFrame()
        end
    end
end

-------------------------------------------------------------------------------
-- Debug System
-------------------------------------------------------------------------------
local debugMode = false

--- Включает/выключает debug-режим
function GoldLedger:SetDebug(enabled)
    debugMode = enabled
    print("|cff00ff00GoldLedger:|r debug " .. (enabled and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
end

--- Выводит debug-сообщение в чат (только если debug включён)
--- @param module string Имя модуля
--- @param ... any Аргументы для конкатенации
function GoldLedger:Debug(module, ...)
    if not debugMode then return end

    local args = {...}
    local parts = {}
    for i = 1, #args do
        parts[i] = tostring(args[i])
    end

    print(("|cff888888[GL:%s]|r %s"):format(module, table.concat(parts, " ")))
end

--- Дамп таблицы в чат (debug-режим)
--- @param label string Название
--- @param tbl table Таблица для вывода
function GoldLedger:DumpTable(label, tbl)
    if not debugMode then return end

    print("|cff888888[GL:Dump]|r " .. label .. ":")
    if type(tbl) ~= "table" then
        print("  " .. tostring(tbl))
        return
    end
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            print(("  %s = {%d items}"):format(tostring(k), #v > 0 and #v or 0))
        else
            print(("  %s = %s"):format(tostring(k), tostring(v)))
        end
    end
end

-------------------------------------------------------------------------------
-- Utility: передаём L в namespace для удобства
-------------------------------------------------------------------------------
GoldLedger.L = L
