-- Звуки взлома: какое событие чем звучит. Одна таблица на весь мод.
-- Почти всё ванильное, свои два файла лежат в assets/sounds.

LU = LU or {}

local U = LU.Util

local Sfx = {}

-- Sound.new бросает исключение на плохом пути (log.error), поэтому в pcall:
-- без звука мод работает, а одна строка в логе скажет, какого нет.
local function load(id, file)
    local ok, snd = pcall(function() return Sound.new(id, "~/assets/sounds/"..file) end)
    if ok and snd then return snd.value end
    log.warning("LocksUnlocked: sound "..file.." not loaded: "..tostring(snd))
    return nil
end

local LOCK_BREAK = load("lockBreak", "lockBreak.ogg")
local TIME_TICK  = load("timeTick", "timeTick.ogg")

Sfx.EVENTS = {
    start   = gm.constants.wSniperScan,           -- панель открылась
    deny    = gm.constants.wError,                -- взломать нельзя
    mistake = gm.constants.wEnforcer_ShieldBlock, -- ошибка, у сундука
    fail    = LOCK_BREAK,                         -- замок сломан, у сундука
    open    = gm.constants.wRoboRewire,           -- вскрыто с ошибками, у сундука
    clean   = gm.constants.wUI_Trials_Success,    -- вскрыто чисто, у сундука
    cancel  = gm.constants.wUI_Tab,               -- взлом брошен
    step    = gm.constants.wUI_SliderTick,        -- шаг мини-игры
    tick    = TIME_TICK,                          -- последние секунды лимита
    tone    = TIME_TICK,                          -- вспышка и нажатие в Шифре
}

-- Высота тона Шифра по стрелке — как на странице сравнения.
Sfx.TONE_PITCH = { up = 0.75, right = 1.0, down = 1.25, left = 1.5 }

-- Сколько последних секунд лимита тикают.
Sfx.TICK_FROM = 5

-- sound_play игры звучит из точки инстанса: у сундука — для всех рядом, у
-- взломщика — у него.
function Sfx.play(event, inst, pitch)
    local snd = Sfx.EVENTS[event]
    if snd == nil or not U.alive(inst) then return end
    inst:sound_play(snd, 1, pitch or 1)
end

LU.Sfx = Sfx
