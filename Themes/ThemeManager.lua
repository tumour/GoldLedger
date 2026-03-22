--[[
    GoldLedger: Themes/ThemeManager.lua
    Pattern: Registry

    Система тем:
    - Реестр тем (RegisterTheme/GetTheme)
    - API для доступа к цветам (GetColor/C)
    - Переключение тем с уничтожением и пересозданием UI
]]

local ADDON_NAME, ns = ...
local GoldLedger = ns.GoldLedger

local Themes = {}
GoldLedger:RegisterModule("Themes", Themes)

-------------------------------------------------------------------------------
-- Registry
-------------------------------------------------------------------------------
local registry = {}     -- { [id] = themeTable }
local activeTheme = nil -- resolved theme table
local activeId = nil

--- Регистрирует тему в реестре (вызывается из файлов тем)
--- @param id string Уникальный ID темы (например "classic_dark")
--- @param theme table Таблица с цветами и метаданными
function Themes:RegisterTheme(id, theme)
    registry[id] = theme
end

-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------

function Themes:OnInitialize()
    local settings = GoldLedgerDB and GoldLedgerDB.settings
    local themeId = settings and settings.theme or "dashboard_cards"

    if not registry[themeId] then
        themeId = "dashboard_cards"
    end

    activeTheme = registry[themeId]
    activeId = themeId
end

-------------------------------------------------------------------------------
-- API: доступ к цветам
-------------------------------------------------------------------------------

--- Возвращает цветовую таблицу по ключу
--- @param key string Имя цвета (например "FRAME_BG")
--- @return table {r, g, b [, a]}
function Themes:GetColor(key)
    return activeTheme[key]
end

--- Распаковывает цвет для SetTextColor / SetBackdropColor
--- @param key string Имя цвета
--- @return number, number, number, number|nil r, g, b, a
function Themes:C(key)
    local c = activeTheme[key]
    if not c then return 1, 1, 1, 1 end
    return c[1], c[2], c[3], c[4]
end

--- Возвращает SOURCE_COLORS из текущей темы
--- @return table
function Themes:GetSourceColors()
    return activeTheme.SOURCE_COLORS
end

--- Возвращает текстуру фона из текущей темы
--- @return string
function Themes:GetBgTexture()
    return activeTheme.BG_TEXTURE or "Interface\\Tooltips\\UI-Tooltip-Background"
end

--- Возвращает текстуру рамки из текущей темы
--- @return string
function Themes:GetEdgeTexture()
    return activeTheme.EDGE_TEXTURE or "Interface\\Tooltips\\UI-Tooltip-Border"
end

--- Возвращает ID текущей темы
--- @return string
function Themes:GetActiveId()
    return activeId
end

--- Возвращает имя текущей темы
--- @return string
function Themes:GetActiveName()
    return activeTheme and activeTheme.name or activeId
end

-------------------------------------------------------------------------------
-- Switching
-------------------------------------------------------------------------------

--- Переключает тему и пересоздаёт UI
--- @param themeId string ID темы
--- @return boolean success
function Themes:SetTheme(themeId)
    local theme = registry[themeId]
    if not theme then return false end

    -- Сохраняем в настройки
    if GoldLedgerDB and GoldLedgerDB.settings then
        GoldLedgerDB.settings.theme = themeId
    end

    activeTheme = theme
    activeId = themeId

    -- Уведомляем UI о пересоздании
    local UI = GoldLedger:GetModule("UI")
    if UI and UI.ApplyTheme then
        UI:ApplyTheme()
    end

    return true
end

--- Возвращает список доступных тем для UI
--- @return table[] { {id=string, name=string}, ... }
function Themes:GetAvailableThemes()
    local list = {}
    for id, theme in pairs(registry) do
        list[#list + 1] = { id = id, name = theme.name or id }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end
