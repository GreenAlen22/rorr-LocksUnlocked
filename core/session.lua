-- Сессия взлома на машине взломщика: просьба хосту, ввод, мини-игра, лимит
-- времени, отчёты. Одна сессия на машину.
--
-- Ошибки сессия считает сама, чтобы панель отвечала сразу, но правда у хоста:
-- провал и итог приходят событием state, и только тогда сессия закрывается.

LU = LU or {}

local U   = LU.Util
local cfg = LU.Config

local Session = {}

local KIND, EVENT = LU.Net.KIND, LU.Net.EVENT

-- Глагол игры -> клавиша мини-игры.
local KEYS = {
    { "left", "left" }, { "right", "right" }, { "up", "up" }, { "down", "down" },
    { "jump", "act" },
}

local pending = nil   -- { chest_id, player_id, frame }
local cur     = nil   -- открытая сессия, см. start

-- Звуки сессии слышит только взломщик: они звучат из его точки на его машине.
local function sfx(event, p, pitch)
    if p then LU.Sfx.play(event, p, pitch) end
end

local function blocked_input()
    return U.bool(Global.pause) or U.bool(Global.menu_typing)
end

local function input_idx(p)
    return math.max(0, math.floor(U.num(p.input_player_index, 0)))
end

-- Запомнить, какие клавиши зажаты сейчас, не сообщая мини-игре: она узнает о
-- клавише только по новому нажатию.
local function resync_held(player)
    local idx = input_idx(player)
    cur.held = {}
    for _, kv in ipairs(KEYS) do
        if U.bool(gm.input_check(kv[1], idx)) then cur.held[kv[2]] = true end
    end
end

-- Золото локальное (oHUD у каждой машины свой), снимает его машина
-- взломщика.
local function take_gold()
    local hud = Instance.find(gm.constants.oHUD)
    if U.alive(hud) then
        local gold = U.num(hud.gold, 0)
        hud.gold = gold - math.floor(gold * cfg.GOLD_LOSS)
    end
end

local function is_local_player(id)
    for _, p in ipairs(U.local_players()) do
        if p.id == id then return true end
    end
    return false
end

-- ===== Начало и конец =====

local function close()
    cur = nil
end

-- Итог висит на панели RESULT_SEC, потом панель закрывается. Взломщик уже
-- свободен: ввод и невидимость сняты по событию хоста.
local function show_result(kind)
    if not cur then return end
    cur.result = kind
    cur.result_t = cfg.RESULT_SEC
end

local function start(chest, player, rewire)
    local entry = LU.Chests.entry(chest)
    local d = LU.Chests.data(chest)
    local id = LU.Debug and LU.Debug.forced_game
    if not (id and LU.Games.has(id)) then id = LU.Games.pick(LU.Chests.game_index(chest)) end
    local diff = entry.diff
    if rewire > 0 then diff = math.max(1, diff - cfg.REWIRE_DIFF_DOWN) end
    diff = (LU.Debug and LU.Debug.forced_diff) or diff

    cur = {
        chest_id  = chest.id,
        player_id = player.id,
        game_id   = id,
        diff      = diff,
        mistakes  = d.mistakes or 0,
        limit     = cfg.TIME_LIMIT[diff],
        streak    = d.streak or 0,
        msg = nil, msg_kind = nil, msg_arg = nil, flash = 0,
        waiting   = false,
        result = nil, result_t = 0,
        started   = U.frame(),
        last_prog = 0, last_report = U.frame(),
        held      = {},
        rewire    = rewire > 0,
    }
    cur.timer = cur.limit

    -- Клавиша, зажатая до старта, считается уже нажатой: мини-игра узнает о
    -- ней только после нового нажатия. Иначе прыжок, с которым игрок
    -- подбежал к сундуку, сразу стал бы ударом в «Кольце».
    resync_held(player)

    -- Мини-игра живёт много кадров, а обёртки между кадрами не хранят:
    -- сундук и игрок каждый раз заново по id.
    local function report(kind)
        local c, p = U.by_id(cur.chest_id), U.by_id(cur.player_id)
        if c and p then LU.Net.report(c, kind, 0, p) end
    end

    local api = {}
    function api.mistake(reason)
        if not cur or cur.waiting then return end
        cur.mistakes = cur.mistakes + 1
        cur.msg, cur.msg_kind, cur.msg_arg, cur.flash = "why."..reason, "bad", nil, 0.3
        local third = cur.mistakes >= cfg.MAX_MISTAKES
        -- Третья ошибка: ждём провала от хоста, мини-игра встаёт.
        if third then cur.waiting = true end
        report(KIND.MISTAKE)
    end
    function api.say(msg, kind, arg)
        if not cur or cur.waiting then return end
        cur.msg, cur.msg_kind, cur.msg_arg = "say."..msg, kind, arg
        -- «good» говорят ровно шаги вперёд: штифт встал, сектор закрыт, слой,
        -- раунд, ступень давления, частота.
        if kind == "good" then sfx("step", U.by_id(cur.player_id)) end
    end
    function api.tone(dir)
        if not cur or cur.waiting then return end
        sfx("tone", U.by_id(cur.player_id), LU.Sfx.TONE_PITCH[dir])
    end
    function api.win()
        if not cur or cur.waiting then return end
        cur.waiting = true
        report(cur.mistakes == 0 and KIND.CLEAN or KIND.SUCCESS)
    end

    cur.api  = api
    cur.game = LU.Games.make(id, diff, api)
    sfx("start", player)
end

-- ===== Просьба =====

local function send_request(chest, player, rewire)
    pending = { chest_id = chest.id, player_id = player.id, frame = U.frame(), rewire = rewire }
    LU.Net.report(chest, KIND.REQUEST, rewire, player)
end

function Session.request(player)
    if cur or pending then return end
    local chest = LU.Chests.near(player)
    if not chest or not LU.Chests.can_pick(chest) then
        sfx("deny", player)
        return
    end
    send_request(chest, player, 0)
end

-- Перепрошивка Робомандо (core/rewire.lua): true — взлом запрошен, ванильный
-- навык не нужен. false — цели нет, пусть ванильный навык ответит ошибкой и
-- коротким откатом.
function Session.rewire(player, boosted)
    if cur or pending then return false end
    local chest = LU.Chests.near(player, true)
    if not chest then return false end
    send_request(chest, player, boosted and 2 or 1)
    return true
end

function Session.on_state(chest, prev_picker_id, picker, event)
    -- Ответ на просьбу: GRANT этому игроку — старт, любое другое состояние
    -- этого сундука — сундук не наш.
    if pending and chest.id == pending.chest_id then
        local player = U.by_id(pending.player_id)
        local mine = picker and picker.id == pending.player_id and event == EVENT.GRANT
        local rewire = pending.rewire
        pending = nil
        if mine and player then
            start(chest, player, rewire)
        else
            sfx("deny", player)
        end
        return
    end

    -- Ответ хоста опоздал, а сессии уже нет: машина сдалась по своему
    -- таймауту. Разрешение, пришедшее после GRANT_TIMEOUT, иначе заморозило
    -- бы игрока без панели до сторожа хоста; провал, пришедший после трёх
    -- секунд ожидания, иначе не забрал бы золото.
    if not cur then
        if event == EVENT.GRANT and picker and is_local_player(picker.id) then
            LU.Net.report(chest, KIND.CANCEL, 0, picker)
        elseif event == EVENT.FAIL and prev_picker_id and is_local_player(prev_picker_id)
               and (LU.Chests.data(chest).rewire or 0) == 0 then
            take_gold()
        end
        return
    end

    if chest.id ~= cur.chest_id or cur.result then return end

    if event == EVENT.MISTAKE then
        cur.mistakes = math.max(cur.mistakes, LU.Chests.data(chest).mistakes or 0)
    elseif event == EVENT.FAIL then
        -- Провал Перепрошивки золото не забирает.
        if not cur.rewire then take_gold() end
        show_result("fail")
    elseif event == EVENT.SUCCESS then
        show_result(cur.mistakes == 0 and "clean" or "ok")
    elseif event == EVENT.CANCEL then
        show_result("cancel")
    elseif not picker or picker.id ~= cur.player_id then
        close()
    end
end

-- ===== Кадр =====

local function cancel(chest, player)
    if chest then LU.Net.report(chest, KIND.CANCEL, 0, player) end
    sfx("cancel", player)
    close()
end

local function step_session(dt)
    -- Вспышка гаснет и под итогом: на хосте третья ошибка и провал приходят в
    -- одном кадре, и рамка иначе горела бы весь RESULT_SEC.
    cur.flash = math.max(0, cur.flash - dt)

    if cur.result then
        cur.result_t = cur.result_t - dt
        if cur.result_t <= 0 then close() end
        return
    end

    local chest  = U.by_id(cur.chest_id)
    local player = U.by_id(cur.player_id)
    if not player or not chest then close() return end

    -- Ждём итога от хоста. Сообщение об открытии (14) может прийти раньше
    -- пакета state, поэтому открытый сундук здесь — не повод отменять.
    if cur.waiting then
        cur.wait_t = (cur.wait_t or 0) + dt
        if cur.wait_t > 3 then close() end
        return
    end

    if U.num(chest.active, 0) ~= 0 or U.bool(player.dead)
       or U.dist(player, chest) > cfg.CANCEL_DIST then
        cancel(chest, player)
        return
    end

    -- Кадр старта пропускается: нажатие, открывшее сессию, иначе тут же
    -- прочиталось бы как отмена.
    --
    -- Клавиши — по состоянию, а не по событиям нажатия и отпускания: событие
    -- отпускания теряется, если игрок отпустил клавишу на паузе или в чате,
    -- и удержание в Отмычке, Зонде и Частоте залипало бы.
    --
    -- Пауза и чат по сети игру не останавливают (oPauseMenu_Other_10.gml:29),
    -- поэтому закрытый ввод — не нажатие и не отпускание. Зажатые клавиши
    -- отпускаются молча: Давление не судит такое отпускание. После паузы
    -- зажатые клавиши запоминаются тоже молча, как на старте: иначе прыжок,
    -- который игрок держал, закрывая меню, стал бы ударом в Кольце.
    if cur.started ~= U.frame() then
        local idx = input_idx(player)
        if blocked_input() then
            for k in pairs(cur.held) do
                cur.held[k] = nil
                cur.game.key(k, false, true)
            end
            cur.blocked = true
        elseif cur.blocked then
            cur.blocked = false
            resync_held(player)
        else
            if U.bool(gm.input_check_pressed(LU.Options.verb, idx)) then
                cancel(chest, player)
                return
            end
            for _, kv in ipairs(KEYS) do
                local k  = kv[2]
                local on = U.bool(gm.input_check(kv[1], idx))
                if on ~= (cur.held[k] == true) then
                    cur.held[k] = on or nil
                    cur.game.key(k, on)
                    if not cur or cur.waiting then return end
                end
            end
        end
    end

    cur.game.update(dt)
    if not cur or cur.waiting then return end

    -- Время вышло — та же ошибка, что и в мини-игре, с тем же шумом.
    cur.timer = cur.timer - dt
    if cur.timer <= 0 then
        cur.timer = cur.limit
        cur.tick_sec = nil
        cur.api.mistake("time")
        if not cur or cur.waiting then return end
    end

    -- Последние секунды тикают: раз на каждую целую секунду остатка. Пока
    -- мини-игра просит тишины (Шифр показывает порядок тонами), тик молчит:
    -- тот же звук на той же высоте прозвучал бы как стрелка «вправо».
    local sec = math.ceil(cur.timer)
    if sec <= LU.Sfx.TICK_FROM and sec ~= cur.tick_sec then
        cur.tick_sec = sec
        if not (cur.game.quiet and cur.game.quiet()) then sfx("tick", player) end
    end

    -- Прогресс для полосы над взломщиком и он же — сердцебиение для сторожа
    -- хоста.
    local prog = math.floor(math.max(0, math.min(1, cur.game.progress())) * 100)
    local now = U.frame()
    if math.abs(prog - cur.last_prog) >= 10 or now - cur.last_report >= cfg.HEARTBEAT or now < cur.last_report then
        cur.last_prog, cur.last_report = prog, now
        LU.Net.report(chest, KIND.PROGRESS, prog, player)
    end
end

Callback.add(Callback.ON_STEP, function()
    if not LU.Options then return end
    local dt = (U.bool(Global.__frameskip) and 2 or 1) / 60

    if pending then
        local now = U.frame()
        if now - pending.frame > cfg.GRANT_TIMEOUT or now < pending.frame then
            sfx("deny", U.by_id(pending.player_id))
            pending = nil
        end
    end

    if cur then
        step_session(dt)
        return
    end

    if pending or blocked_input() then return end
    for _, p in ipairs(U.local_players()) do
        if not U.bool(p.dead) and U.bool(gm.input_check_pressed(LU.Options.verb, input_idx(p))) then
            Session.request(p)
            if pending or cur then return end
        end
    end
end)

Callback.add(Callback.ON_STAGE_START, function()
    pending, cur = nil, nil
end)

function Session.active()
    return cur ~= nil
end

-- Для панели: всё, что она рисует, одной таблицей.
function Session.view()
    return cur
end

LU.Session = Session
