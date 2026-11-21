-- Сеть: два пакета на весь мод.
--
--   report — взломщик -> хост: просьба начать, ошибка, удача, отмена, прогресс;
--   state  — хост -> все: полное состояние сундука и событие, которое его
--            поменяло.
--
-- Хост — единственный, кто решает. Хост истинен и офлайн, поэтому отчёт идёт
-- «хост — сразу у себя, клиент — пакетом», а не «клиент шлёт». Свой send_to_all
-- хост у себя не получает: state он применяет сам.

LU = LU or {}

local U = LU.Util

local NetM = {}

NetM.KIND  = { REQUEST = 1, MISTAKE = 2, SUCCESS = 3, CLEAN = 4, CANCEL = 5, PROGRESS = 6 }
NetM.EVENT = { NONE = 0, GRANT = 1, MISTAKE = 2, SUCCESS = 3, FAIL = 4, CANCEL = 5 }

-- Пакеты заводятся при загрузке, все сразу: номер пакета согласуется по имени
-- при подключении, и пакет, созданный позже, уйдёт под чужим номером.
local pkt_report = Packet.new("report")
local pkt_state  = Packet.new("state")

pkt_report:set_serializers(
    function(buffer, chest, kind, value)
        buffer:write_instance(chest)
        buffer:write_byte(kind)
        buffer:write_byte(value)
    end,
    function(buffer, player)
        -- Сначала весь буфер, потом решения: недочитанный хвост достанется
        -- следующему пакету в очереди, в том числе чужого мода.
        local chest = buffer:read_instance()
        local kind  = buffer:read_byte()
        local value = buffer:read_byte()
        if not Net.host then return end
        if not U.alive(chest) or not U.alive(player) then return end
        LU.Host.handle(chest, player, kind, value)
    end
)

-- Взломщика нет — на его место пишется сам сундук, а флаг говорит, что это
-- заглушка: поля пишутся всегда, иначе приёмник собьёт выравнивание.
pkt_state:set_serializers(
    function(buffer, chest, picker, mistakes, broken, cost, progress, streak, rewire, event)
        buffer:write_instance(chest)
        buffer:write_bool(picker ~= nil)
        buffer:write_instance(picker or chest)
        buffer:write_byte(mistakes)
        buffer:write_bool(broken)
        buffer:write_int(cost)
        buffer:write_byte(progress)
        buffer:write_byte(streak)
        buffer:write_byte(rewire)
        buffer:write_byte(event)
    end,
    function(buffer, player)
        local chest      = buffer:read_instance()
        local has_picker = buffer:read_bool()
        local picker     = buffer:read_instance()
        local mistakes   = buffer:read_byte()
        local broken     = buffer:read_bool()
        local cost       = buffer:read_int()
        local progress   = buffer:read_byte()
        local streak     = buffer:read_byte()
        local rewire     = buffer:read_byte()
        local event      = buffer:read_byte()
        if Net.host then return end
        if not U.alive(chest) then return end
        if not has_picker or not U.alive(picker) then picker = nil end
        NetM.apply(chest, picker, mistakes, broken, cost, progress, streak, rewire, event)
    end
)

-- Одинаково на хосте и у клиентов: записать состояние и развести событие.
function NetM.apply(chest, picker, mistakes, broken, cost, progress, streak, rewire, event)
    local prev = LU.Chests.apply_state(chest, picker, mistakes, broken, cost, progress, streak, rewire)
    NetM.on_event(chest, prev, picker, event)
end

function NetM.on_event(chest, prev_picker_id, picker, event)
    if LU.Effects  then LU.Effects.on_state(chest, prev_picker_id, picker) end
    if LU.Session  then LU.Session.on_state(chest, prev_picker_id, picker, event) end
    if LU.Overhead then LU.Overhead.on_event(chest, picker, event) end
end

-- Отчёт хосту. sender нужен только хосту-игроку: у клиента отправителя
-- называет сам пакет.
function NetM.report(chest, kind, value, sender)
    if Net.host then
        LU.Host.handle(chest, sender, kind, value or 0)
    else
        pkt_report:send_to_host(chest, kind, value or 0)
    end
end

-- Только хост. picker — новый взломщик или nil; остальное хост уже записал в
-- данные сундука.
function NetM.state(chest, event, picker)
    local d        = LU.Chests.data(chest)
    local mistakes = d.mistakes or 0
    local broken   = d.broken and true or false
    local cost     = math.floor(U.num(chest.cost, 0))
    local progress = d.progress or 0
    local streak   = math.min(255, d.streak or 0)
    local rewire   = d.rewire or 0

    if Net.online then
        pkt_state:send_to_all(chest, picker, mistakes, broken, cost, progress, streak, rewire, event)
    end
    NetM.apply(chest, picker, mistakes, broken, cost, progress, streak, rewire, event)
end

LU.Net = NetM
