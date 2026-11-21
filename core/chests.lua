-- Сундуки: какой можно взломать, его данные и мини-игра.
--
-- Данные сундука на каждой машине свои (Instance.get_data). Хост пишет
-- авторитетные значения и рассылает пакетом state; каждая машина, включая
-- хост, кладёт их сюда через apply_state. Кто взламывает, пишет только
-- apply_state: так все машины видят смену взломщика одинаково.

LU = LU or {}

local U   = LU.Util
local cfg = LU.Config

local Chests = {}

-- object_index -> запись CHESTS. gm.constants по имени: промах даёт nil, и
-- такой сундук просто не попадёт в таблицу, поэтому промах пишем в лог.
local by_object = {}
for _, entry in ipairs(cfg.CHESTS) do
    local idx = gm.constants[entry.obj]
    if idx then
        by_object[idx] = entry
    else
        log.warning("LocksUnlocked: unknown chest object "..entry.obj)
    end
end

-- Сундуки этой машины, у которых сейчас есть взломщик: id сундука -> true.
local locked = {}

function Chests.info(inst)
    if not U.alive(inst) then return nil end
    return by_object[U.num(inst.object_index, -1)]
end

function Chests.data(inst)
    return Instance.get_data(inst, "lu")
end

-- Прочее, что взламывает только Перепрошивка Робомандо: всё платное за
-- золото, кроме святилищ, — то же правило, что у ванильной
-- (_survivor_robomando_interactable_is_hackable,
-- scr_ror_init_survivor_robomando.gml:1-4), но без проверки active: запись
-- нужна и пока цель открывается. Сложность — по базовой цене.
local function extra_entry(inst)
    if U.num(inst.cost_type, -1) ~= 0 or U.num(inst.cost, 0) <= 0 then return nil end
    local obj = U.num(inst.object_index, -1)
    if U.bool(gm.object_is_ancestor(obj, gm.constants.pInteractableShrine)) then return nil end
    local scale = U.num(gm.cost_get_base_gold_price_scale(), 1)
    local base = U.num(inst.cost, 0) / (scale > 0 and scale or 1)
    local diff = #cfg.EXTRA_DIFF_COST + 1
    for i, top in ipairs(cfg.EXTRA_DIFF_COST) do
        if base <= top then diff = i break end
    end
    return { obj = tostring(gm.object_get_name(obj)), base = base, diff = diff, extra = true }
end

-- Запись цели взлома: сундук из таблицы или прочее платное (extra = true),
-- которое открывает только Перепрошивка.
function Chests.entry(inst)
    if not U.alive(inst) then return nil end
    return Chests.info(inst) or extra_entry(inst)
end

-- rewire — взлом Перепрошивкой: ей доступно и прочее платное.
function Chests.can_pick(inst, rewire)
    local entry = Chests.entry(inst)
    if not entry or (entry.extra and not rewire) then return false end
    if U.num(inst.cost, 0) <= 0 then return false end
    if U.num(inst.cost_type, -1) ~= 0 then return false end
    if U.num(inst.active, -1) ~= 0 then return false end
    local d = Chests.data(inst)
    if d.broken or d.picker_id then return false end
    return true
end

-- Мини-игра от позиции сундука. Хост ставит сундук и рассылает его
-- координаты, так что у всех машин число одно, без пакета. Отмена её не
-- перебрасывает.
function Chests.game_index(inst)
    local h = (math.floor(inst.x) * 73856093) ~ (math.floor(inst.y) * 19349663)
    return (h % 9) + 1
end

-- Ближайший сундук из таблицы в круге, как ищет цель взлом Robomando. Для
-- Перепрошивки — ближайшая цель, которую можно взломать прямо сейчас:
-- занятый сундук рядом не должен заслонять свободного дрона.
function Chests.near(player, rewire)
    local best, best_d
    for _, inst in ipairs(player:get_collisions_circle(gm.constants.pInteractable, cfg.PICK_RADIUS)) do
        local fits
        if rewire then fits = Chests.can_pick(inst, true) else fits = Chests.info(inst) ~= nil end
        if fits then
            local d = U.dist(player, inst)
            if not best_d or d < best_d then best, best_d = inst, d end
        end
    end
    return best
end

-- Цену подпись над сундуком кэширует строкой (interactable_init_cost.gml:31-104):
-- без пересборки на сундуке висит старое число.
function Chests.set_cost(inst, cost)
    inst.cost = math.floor(cost)
    inst:interactable_cache_strings()
end

-- rewire: 0 — обычный взлом, 1 — Перепрошивка, 2 — она же со Скипетром.
-- Остаётся на цели и после конца взлома: опоздавший провал по нему решает,
-- забирать ли золото.
function Chests.apply_state(inst, picker, mistakes, broken, cost, progress, streak, rewire)
    local d = Chests.data(inst)
    local prev = d.picker_id

    d.picker_id = picker and picker.id or nil
    d.mistakes  = mistakes
    d.progress  = progress
    d.streak    = streak
    d.rewire    = rewire

    if d.picker_id then locked[inst.id] = true else locked[inst.id] = nil end

    if U.num(inst.cost, 0) ~= cost then Chests.set_cost(inst, cost) end

    -- text у каждой машины свой (interactable_init_name переводит на месте),
    -- поэтому дописываем здесь, а не пакетом. Ванильная подсказка покажет
    -- «Открыть сундук (замок сломан)».
    if broken and not d.broken_text then
        d.broken_text = true
        inst.text = tostring(inst.text).." "..gm.translate("locksunlocked.prompt.broken")
    end
    d.broken = broken and true or nil

    return prev
end

function Chests.locked()
    return locked
end

Callback.add(Callback.ON_STAGE_START, function()
    locked = {}
end)

LU.Chests = Chests
