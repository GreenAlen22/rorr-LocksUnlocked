-- Взломщик: невидимость, реген, исходящий урон, заморозка ввода, шум.
--
-- Невидимость — свой бафф по образцу дымовой шашки Бандита
-- (scr_ror_init_buffs.gml:296-329): на наложении actor_no_targetting_add, на
-- снятии _remove, при отрисовке полупрозрачность. Сама шашка не годится: она
-- подбрасывает героя на наложении и на снятии в воздухе (с Rusty Jetpack —
-- за радиус взлома), на снятии взрывается уроном Бандита и
-- пока висит, делает героя неуязвимым. Бафф синхронизирует сама игра, его
-- вешает и снимает только хост. Всё остальное каждая машина делает сама по
-- набору взломщиков из состояний сундуков.

LU = LU or {}

local U   = LU.Util
local cfg = LU.Config

local Effects = {}

local SMOKE = Buff.new("pickingHidden")
SMOKE.show_icon = false
SMOKE.is_debuff = false

-- От лица самого героя: функция читает dead у self (scr_actor_team_utils.gml:38),
-- как у шашки, которая зовёт её из баффа.
Callback.add(SMOKE.on_apply, function(actor)
    actor:actor_no_targetting_add(actor)
end)

Callback.add(SMOKE.on_remove, function(actor)
    actor:actor_no_targetting_remove(actor)
end)

-- Как у шашки: приоритет PRE рисуется до тела и гасит его наполовину.
SMOKE.effect_display = EffectDisplay.func(function(actor_unwrapped)
    local a = Instance.wrap(actor_unwrapped)
    a.image_alpha = U.num(a.image_alpha, 1) * 0.5
end, EffectDisplay.DrawPriority.PRE)

-- Дольше любого взлома: три лимита по 40 с плюс отмена. Снимает бафф хост,
-- срок — страховка на случай, если снять не успеет.
local SMOKE_FRAMES = 5 * 60 * 60

local pickers     = {}   -- id игрока -> id сундука, на этой машине
local hidden      = {}   -- хост: id игрока -> бафф висит наш
local noise_until = {}   -- хост: id игрока -> кадр, когда вернуть бафф

function Effects.is_picking(actor)
    if actor == nil then return false end
    return pickers[actor.id] ~= nil
end

-- ===== Заморозка ввода =====

-- control зовётся на каждый глагол каждого игрока каждый кадр, поэтому хук
-- включён, только пока кто-то взламывает.
--
-- Post, а не pre с return false: отменённая функция ничего не возвращает, и
-- step_player.gml:130-148 читал в прыжке случайное значение — персонаж
-- прыгал посреди взлома. Ответ подменяется только в post-хуке.
local control_hook = Hook.add_post(gm.constants.control, function(self, other, result, args)
    if self and pickers[self.id] then result.value = false end
end)
control_hook:toggle(false)

local function refresh_control()
    control_hook:toggle(next(pickers) ~= nil)
end

function Effects.on_state(chest, prev_picker_id, picker)
    local new_id = picker and picker.id or nil
    if prev_picker_id and prev_picker_id ~= new_id then
        pickers[prev_picker_id] = nil
        local prev = U.by_id(prev_picker_id)
        if prev then prev:queue_recalculate_stats() end
    end
    if picker and pickers[new_id] ~= chest.id then
        pickers[new_id] = chest.id
        picker:queue_recalculate_stats()
    end
    refresh_control()
end

-- ===== Реген и урон =====

-- Реген идёт на каждой машине для её копии каждого игрока
-- (step_actor.gml:6-7), поэтому и гасится на каждой.
RecalculateStats.add(function(actor, api)
    if pickers[actor.id] then api.hp_regen_mult(0) end
end)

-- Дроны и турели бьют от своего имени (pDrone1_Step_2.gml:13,
-- oEngiTurret_Step_0.gml:48), поэтому проходят. Предметы игрока — от имени
-- игрока и гасятся вместе с его атаками.
DamageCalculate.add(function(api)
    local parent = api.parent
    if parent == nil then return end
    if type(parent) == "number" then
        if not Instance.exists(parent) then return end
        parent = Instance.wrap(parent)
    end
    if pickers[parent.id] then api.damage_mult(0) end
end)

-- ===== Хост: невидимость и шум =====

function Effects.host_hide(p)
    if not SMOKE or hidden[p.id] then return end
    p:buff_apply(SMOKE, SMOKE_FRAMES)
    hidden[p.id] = true
end

function Effects.host_show(p)
    noise_until[p.id] = nil
    if SMOKE and hidden[p.id] then p:buff_remove(SMOKE) end
    hidden[p.id] = nil
end

-- Ошибка шумит: бафф снимается (ванильный звук снятия слышат все), у игрока
-- снова есть метка цели, и враги рядом берут её, как при ванильной провокации
-- (oArtiSnap_Collision_pActor.gml:13). Через NOISE_SEC бафф возвращается.
function Effects.host_noise(p, diff)
    if SMOKE and hidden[p.id] then
        p:buff_remove(SMOKE)
        hidden[p.id] = nil
    end
    noise_until[p.id] = U.frame() + math.floor(cfg.NOISE_SEC * 60)

    local marker = p.target_marker
    if type(marker) == "number" then marker = U.by_id(marker) end
    if not U.alive(marker) then return end

    local team = U.num(p.team, -1)
    for _, a in ipairs(p:get_collisions_circle(gm.constants.pActor, cfg.NOISE_RADIUS[diff])) do
        if U.num(a.team, team) ~= team and not U.bool(a.dead) then
            a.target = marker.id
        end
    end
end

Callback.add(Callback.POST_STEP, function()
    if not Net.host then return end
    local now = U.frame()
    for id, t in pairs(noise_until) do
        if now >= t or now < t - 600 then
            noise_until[id] = nil
            local p = U.by_id(id)
            if p and pickers[id] then Effects.host_hide(p) end
        end
    end
end)

-- Игрок переживает смену этапа вместе с баффами, а замок — нет: бафф,
-- повешенный на прошлом этапе, хост снимает сам, иначе взломщик остался бы
-- невидимым на весь срок баффа.
Callback.add(Callback.ON_STAGE_START, function()
    if Net.host and SMOKE then
        for id in pairs(hidden) do
            local p = U.by_id(id)
            if p then p:buff_remove(SMOKE) end
        end
    end
    pickers, hidden, noise_until = {}, {}, {}
    refresh_control()
end)

LU.Effects = Effects
