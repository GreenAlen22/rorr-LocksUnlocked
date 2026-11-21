-- Правила хоста: замок, ошибки, цена, награда, провал, сторож.
--
-- Всё здесь исполняется только на хосте (или офлайн). Решение уходит всем
-- пакетом state через LU.Net.state; кто взламывает, хост сам в данные не
-- пишет — это делает apply_state, иначе он не увидит прежнего взломщика.

LU = LU or {}

local U   = LU.Util
local cfg = LU.Config

local Host = {}

local KIND  = LU.Net.KIND
local EVENT = LU.Net.EVENT

-- Серии по ключу игрока. Живут весь забег, через этапы.
local streaks = {}

function Host.streak(player)
    return streaks[U.player_key(player)] or 0
end

local function set_streak(player, n)
    streaks[U.player_key(player)] = math.max(0, math.min(255, n))
end

-- Минуты забега: директор считает секунды в time_start
-- (oDirectorControl_Alarm_0.gml:9).
local function run_minutes()
    local dir = Instance.find(gm.constants.oDirectorControl)
    if not U.alive(dir) then return 0 end
    return U.num(dir.time_start, 0) / 60
end

-- Полная наценка провала: начальная цена × множитель цен × процент, который
-- растёт со временем забега. Ошибка берёт треть.
function Host.markup(entry)
    local pct = math.min(cfg.MARKUP_MAX,
        cfg.MARKUP_START + cfg.MARKUP_STEP * math.floor(run_minutes() / cfg.MARKUP_EVERY_MIN))
    return entry.base * U.num(gm.cost_get_base_gold_price_scale(), 1) * pct
end

local function release(chest, d)
    d.progress = 0
    local picker = U.by_id(d.picker_id)
    if picker then LU.Effects.host_show(picker) end
end

-- Открыть как взлом Robomando (scr_ror_init_survivor_robomando.gml:255-268):
-- сообщение 14 с успехом 2 открывает у клиентов без оплаты, затем
-- interactable_set_active у себя. Через него срабатывают фейерверки, Locked
-- Jewel, ON_INTERACTABLE_ACTIVATE, а флаг hack_double читают сундуки в
-- item_drop.
local function open_free(chest, picker, double)
    if Net.online then
        chest:net_send_instance_message(14, picker.id, 1, 2)
    end
    chest:interactable_set_active(chest, picker, 1, true, double)
end

local function reward(chest, d, entry, picker, clean)
    local streak = Host.streak(picker)
    local double_chance = math.min(cfg.DOUBLE_CAP, streak * cfg.STREAK_STEP)

    if clean then
        local up = cfg.UPGRADE_CHANCE[entry.diff]
        if entry.upgrade then
            if math.random() < up then d.upgrade = entry.upgrade end
        else
            -- Тира выше у сундука нет: шанс уходит в двойной.
            double_chance = double_chance + up
        end
    end

    -- Перепрошивка со Скипетром не теряет ванильный шанс двойного.
    if (d.rewire or 0) == 2 then double_chance = double_chance + cfg.REWIRE_SCEPTER_DOUBLE end

    local double = math.random() < double_chance
    -- Бочка снаряжения hack_double в item_drop не передаёт
    -- (oBarrelEquipment_Alarm_0.gml), её второй предмет выдаёт пост-хук ниже.
    if entry.obj == "oBarrelEquipment" then d.barrel_double = double end
    -- Адаптивный сундук открывается в два нажатия, и второе, выбор предмета,
    -- снова зовёт interactable_set_active с hack_double = false
    -- (pInteractable_Collision_oP.gml, interactable_set_active.gml). Флаг
    -- подставляет пре-хук item_drop_object ниже.
    if entry.obj == "oChest4" then d.adaptive_double = double end

    open_free(chest, picker, double)
    set_streak(picker, streak + 1)
end

function Host.handle(chest, sender, kind, value)
    local entry = LU.Chests.entry(chest)
    if not entry or not U.alive(sender) then return end
    local d = LU.Chests.data(chest)

    if kind == KIND.REQUEST then
        -- value — чем просят: 0 клавиша взлома, 1 Перепрошивка, 2 она же со
        -- Скипетром (core/rewire.lua).
        local rewire = math.max(0, math.min(2, math.floor(U.num(value, 0))))
        if LU.Chests.can_pick(chest, rewire > 0) and not U.bool(sender.dead) then
            d.beat   = U.frame()
            d.streak = Host.streak(sender)
            d.rewire = rewire
            LU.Effects.host_hide(sender)
            LU.Net.state(chest, EVENT.GRANT, sender)
        else
            -- Отказ: просивший увидит, что сундук не его.
            LU.Net.state(chest, EVENT.NONE, U.by_id(d.picker_id))
        end
        return
    end

    -- Всё остальное — только от того, кто держит замок.
    if d.picker_id ~= sender.id then return end
    d.beat = U.frame()

    if kind == KIND.PROGRESS then
        d.progress = math.max(0, math.min(100, value))
        LU.Net.state(chest, EVENT.NONE, sender)

    elseif kind == KIND.MISTAKE then
        d.mistakes = (d.mistakes or 0) + 1
        -- Ошибка Перепрошивки не шумит и цену не поднимает.
        if (d.rewire or 0) == 0 then
            LU.Chests.set_cost(chest, U.num(chest.cost, 0) + math.ceil(Host.markup(entry) / 3))
            LU.Effects.host_noise(sender, entry.diff)
        end

        if d.mistakes >= cfg.MAX_MISTAKES then
            d.broken = true
            set_streak(sender, math.floor(Host.streak(sender) / 2))
            d.streak = Host.streak(sender)
            release(chest, d)
            LU.Net.state(chest, EVENT.FAIL, nil)
        else
            LU.Net.state(chest, EVENT.MISTAKE, sender)
        end

    elseif kind == KIND.SUCCESS or kind == KIND.CLEAN then
        -- Чистый — только если на сундуке нет ни одной ошибки, в том числе
        -- с прошлых попыток: проверяет хост, а не слово взломщика.
        local clean = (kind == KIND.CLEAN) and (d.mistakes or 0) == 0
        reward(chest, d, entry, sender, clean)
        d.streak = Host.streak(sender)
        release(chest, d)
        LU.Net.state(chest, EVENT.SUCCESS, nil)

    elseif kind == KIND.CANCEL then
        release(chest, d)
        LU.Net.state(chest, EVENT.CANCEL, nil)
    end
end

-- ===== Выпадение =====

-- item_drop идёт в Alarm сундука, self — сам сундук, и только на хосте
-- (item_drop.gml:3-6). Первый аргумент — индекс весов сундука, не тир.
Hook.add_pre(gm.constants.item_drop, function(self, other, result, args)
    if not LU.Chests.info(self) then return end
    local d = LU.Chests.data(self)
    if d.upgrade then
        args[1].value = d.upgrade
        d.upgrade = nil
    end
end)

Hook.add_post(gm.constants.item_drop, function(self, other, result, args)
    if not LU.Chests.info(self) then return end
    local d = LU.Chests.data(self)
    if d.barrel_double then
        -- Флаг снять до вызова: этот же хук сработает и на втором выпадении.
        d.barrel_double = nil
        self:item_drop(3)
    end
end)

-- Предмет рулетки выпадает в Alarm 3 адаптивного сундука, только на хосте:
-- item_drop_object(item_id, …, hack_double) (oChest4_Alarm_3.gml). Пятый
-- аргумент — флаг двойного.
Hook.add_pre(gm.constants.item_drop_object, function(self, other, result, args)
    if not LU.Chests.info(self) then return end
    local d = LU.Chests.data(self)
    if d.adaptive_double then
        d.adaptive_double = nil
        if args[5] then args[5].value = true end
    end
end)

-- ===== Замок не даёт купить =====

-- На каждой машине: пока сундук или дрона взламывают, их нельзя ни купить,
-- ни нажать. Отказ до нажатия, а не после: прошедшее нажатие запускает
-- фейерверки.
Hook.add_post(gm.constants.interactable_check_cost, function(self, other, result, args)
    if self and LU.Chests.locked()[self.id] then result.value = false end
end)

-- ===== Сторож =====

-- Взломщик вышел из игры, умер или замолчал — замок освобождается, иначе
-- сундук и невидимость останутся за ним навсегда.
local tick = 0
Callback.add(Callback.POST_STEP, function()
    if not Net.host then return end
    tick = tick + 1
    if tick < 30 then return end
    tick = 0

    local now = U.frame()
    for id in pairs(LU.Chests.locked()) do
        local chest = U.by_id(id)
        if not chest then
            LU.Chests.locked()[id] = nil
        else
            local d = LU.Chests.data(chest)
            local picker = U.by_id(d.picker_id)
            local silent = now < (d.beat or 0) or now - (d.beat or 0) > cfg.WATCHDOG
            if not picker or U.bool(picker.dead) or silent then
                release(chest, d)
                LU.Net.state(chest, EVENT.CANCEL, nil)
            end
        end
    end
end)

Callback.add(Callback.ON_GAME_START, function()
    streaks = {}
    tick = 0
end)

LU.Host = Host
