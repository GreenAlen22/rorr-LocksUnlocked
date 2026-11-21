-- Мелочи, которые нужны всем модулям.

LU = LU or {}

local U = {}

-- GML-булевы приходят числами, а в Lua 0 истинно: `if inst.active then`
-- проходит всегда. Любой флаг игры — только через это.
function U.bool(v)
    if type(v) == "number" then return v > 0.5 end
    return v and true or false
end

function U.num(v, default)
    local n = tonumber(v)
    if n == nil then return default end
    return n
end

-- Живой ли инстанс. Обёртка держит адрес, а не id: после уничтожения
-- Instance.exists(обёртка) может ответить «да» про чужой объект, въехавший в
-- ту же память. Числовой id движок проверяет честно.
function U.alive(inst)
    if inst == nil or inst == Instance.INVALID then return false end
    local id = (type(inst) == "number") and inst or inst.id
    if type(id) ~= "number" then return false end
    return Instance.exists(id) and true or false
end

-- Свежая обёртка по id, сохранённому между кадрами, или nil.
function U.by_id(id)
    if type(id) ~= "number" then return nil end
    if not Instance.exists(id) then return nil end
    return Instance.wrap(id)
end

-- Игроки, которыми управляют с этой машины. Онлайн — один свой; офлайн за
-- одним экраном их может быть несколько, и все свои.
function U.local_players()
    local out = {}
    if Net.online then
        local p = Player.get_local()
        if U.alive(p) and p.object_index == gm.constants.oP then out[1] = p end
        return out
    end
    for _, p in ipairs(Instance.find_all(gm.constants.oP)) do
        if U.alive(p) then out[#out + 1] = p end
    end
    return out
end

-- Ключ игрока, одинаковый на всех машинах. Онлайн — m_id (id инстанса у
-- каждой машины свой). Офлайн у всех oP m_id = 0, там различаем по инстансу.
function U.player_key(p)
    if Net.online then return math.floor(U.num(p.m_id, 0)) end
    return p.id
end

function U.frame()
    return U.num(Global._current_frame, 0)
end

function U.dist(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

LU.Util = U
