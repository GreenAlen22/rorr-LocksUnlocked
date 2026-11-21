-- LocksUnlocked
-- Взлом сундуков мини-игрой: удача открывает бесплатно, ошибки дорожают
-- сундук, провал забирает золото и ломает замок.

mods["ReturnsAPI-ReturnsAPI"].auto{
    namespace = "locksunlocked",
    mp        = true
}

local PATH = _ENV["!plugins_mod_folder_path"].."/"

-- Порядок: конфиг и утилиты -> холст (его ловят мини-игры на загрузке) ->
-- сундуки -> сеть -> правила хоста -> эффекты -> мини-игры -> сессия ->
-- интерфейс -> настройки и отладка. Соседей модули берут как LU.X в момент
-- вызова, поэтому порядок важен только для того, что читается на загрузке.
local modules = {
    "core/config",
    "core/util",
    "ui/pixel",
    "ui/sfx",
    "settings/options",
    "core/verb_fix",
    "core/chests",
    "core/net",
    "core/host",
    "core/effects",
    "games/registry",
    "games/pins",
    "games/ring",
    "games/lockpick",
    "games/pressure",
    "games/cipher",
    "games/circuit",
    "games/probe",
    "games/frequency",
    "games/code",
    "core/session",
    "core/rewire",
    "ui/panel",
    "ui/overhead",
    "ui/prompt",
    "debug/commands",
}

-- require молчит дважды: файла нет (предупреждение в лог движка, возврат nil)
-- и файл упал посередине (всё ниже точки падения не объявилось). Первое ловит
-- io.open, второе pcall. Обёртка в Lua-функцию, а не pcall(require, file):
-- иначе ReturnOfModding припишет модуль чужому плагину.
local function load(name)
    local file = (PATH..name..".lua"):gsub("/", "\\")

    local f = io.open(file, "r")
    if not f then
        log.warning("LocksUnlocked: file not found -> "..file)
        return false
    end
    f:close()

    local ok, err = pcall(function() require(file) end)
    if not ok then
        log.warning("LocksUnlocked: FAILED to load "..name.." -> "..tostring(err))
        return false
    end
    return true
end

-- Успешный require ничего не доказывает. Модули общаются через LU, и наличие
-- веток — единственная проверка, что код действительно отработал.
local expected = {
    "Config", "Util", "Pixel", "Sfx", "Chests", "Net", "Host", "Effects", "Games",
    "Session", "Rewire", "Panel", "Overhead", "Prompt", "Options", "VerbFix", "Debug",
}

-- Packet.new, Buff.find и Object.new обязаны выполняться внутри Initialize.
Initialize.add_hotloadable(Callback.Priority.BEFORE, function()
    LU = LU or {}

    local loaded = 0
    for _, name in ipairs(modules) do
        if load(name) then loaded = loaded + 1 end
    end

    local missing = {}
    for _, key in ipairs(expected) do
        if not LU[key] then missing[#missing + 1] = key end
    end

    -- Сколько мини-игр должно зарегистрироваться: по файлам games/ в списке.
    local want_games = 0
    for _, name in ipairs(modules) do
        if name:find("^games/") and name ~= "games/registry" then want_games = want_games + 1 end
    end
    local games = (LU.Games and LU.Games.count()) or 0

    if loaded == #modules and #missing == 0 and games == want_games then
        log.info("LocksUnlocked: initialized ("..loaded.."/"..#modules.." modules, "..games.." games)")
    else
        log.warning("LocksUnlocked: initialized PARTIALLY ("..loaded.."/"..#modules
            .." modules, "..games.." games; missing: "
            ..(#missing > 0 and table.concat(missing, ", ") or "-")..")")
    end
end)
