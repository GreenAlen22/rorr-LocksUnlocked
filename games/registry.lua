-- Список мини-игр и их контракт.
--
-- Мини-игра — файл games/<id>.lua, который зовёт
-- LU.Games.register(id, make, controls).
-- make(diff, api) -> game, diff 1..4 (сложность сундука).
--
--   game.update(dt)       dt в секундах
--   game.key(k, down, silent)  k: "left" "right" "up" "down" "act"; down =
--                         нажата/отпущена. Отпускание может прийти без нажатия
--                         (клавиша была зажата до старта) — игра его просто
--                         пропускает. silent — отпускание из-за паузы или
--                         чата: удержание снять, но не оценивать.
--   game.draw()           рисует в координатах холста LU.Pixel (240x135)
--   game.progress()       0..1 — для полосы над взломщиком
--   game.quiet()          необязательно: true — тик последних секунд молчит
--
--   api.mistake(reason)   ошибка; reason — ключ locksunlocked.why.<reason>
--   api.say(msg, kind, arg)  строка панели; msg — ключ locksunlocked.say.<msg>,
--                         kind: good | info; arg — на место %s, если есть
--   api.win()             пройдено
--   api.tone(dir)         тон стрелки dir: "up" "right" "down" "left" (Шифр)
--
-- Звук шага играет сама сессия на say(..., "good"), игре звать его не нужно.

LU = LU or {}

local Games = {}

-- Порядок важен: Chests.game_index даёт номер в этом списке, и он одинаков на
-- всех машинах.
Games.IDS = { "pins", "ring", "lockpick", "pressure", "cipher", "circuit", "probe", "frequency", "code" }

local makers = {}
local verbs  = {}

-- controls — глаголы ввода, чьи значки встают по порядку на места %s в строке
-- locksunlocked.game.<id>.controls: игрок видит свои клавиши, а не наши.
function Games.register(id, make, controls)
    makers[id] = make
    verbs[id]  = controls or {}
end

function Games.verbs(id)
    return verbs[id] or {}
end

function Games.has(id)
    return makers[id] ~= nil
end

function Games.count()
    local n = 0
    for _, id in ipairs(Games.IDS) do
        if makers[id] then n = n + 1 end
    end
    return n
end

-- Мини-игра по номеру сундука. Если такой игры в сборке нет, берётся
-- следующая по списку: номер у всех машин один, значит, и замена одна.
function Games.pick(index)
    local n = #Games.IDS
    for k = 0, n - 1 do
        local id = Games.IDS[((index - 1 + k) % n) + 1]
        if makers[id] then return id end
    end
    return nil
end

function Games.make(id, diff, api)
    local make = makers[id]
    if not make then return nil end
    return make(diff, api)
end

LU.Games = Games
