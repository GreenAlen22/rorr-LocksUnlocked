-- Вид со стороны: над взломщиком полоса прогресса и метки ошибок, у сундука
-- кольцо шума на ошибке. Видят все, кроме самого взломщика: у него панель.
--
-- Рисуется носителем на глубине -16000: из ON_DRAW полосу перекрыли бы
-- тайлы этапа.

LU = LU or {}

local U   = LU.Util
local cfg = LU.Config
local C   = LU.Pixel.C

local Overhead = {}

local EVENT = LU.Net.EVENT

local carrier = Object.new("overhead")
carrier:set_sprite(-1)
carrier:set_depth(-16000)

local rings = {}   -- { x, y, r, max }

-- Нулевая ширина — пусто: перевёрнутый прямоугольник GameMaker рисует
-- полоской, и пустая полоса прогресса не была бы пустой.
local function rect(x, y, w, h, col)
    if w <= 0 or h <= 0 then return end
    gm.draw_rectangle_color(x, y, x + w - 1, y + h - 1, col, col, col, col, false)
end

-- Событие у сундука видно и слышно всем рядом, на каждой машине.
function Overhead.on_event(chest, picker, event)
    if event == EVENT.SUCCESS then
        -- Чистота — по ошибкам на сундуке, их только что записал пакет хоста.
        local clean = (LU.Chests.data(chest).mistakes or 0) == 0
        LU.Sfx.play(clean and "clean" or "open", chest)
        return
    end
    if event ~= EVENT.MISTAKE and event ~= EVENT.FAIL then return end
    LU.Sfx.play(event == EVENT.FAIL and "fail" or "mistake", chest)
    -- Ошибка Перепрошивки не шумит: врагов нет, и кольца шума тоже.
    if (LU.Chests.data(chest).rewire or 0) ~= 0 then return end
    local entry = LU.Chests.entry(chest)
    local max = entry and cfg.NOISE_RADIUS[entry.diff] or 200
    rings[#rings + 1] = { x = chest.x, y = chest.y - 8, r = 0, max = max }
end

local function draw_picker(p, d)
    local w = 28
    local x = math.floor(p.x - w / 2)
    local y = math.floor(U.num(p.bbox_top, p.y - 16) - 14)
    rect(x - 1, y - 1, w + 2, 5, C.bg)
    rect(x, y, w, 3, C.dark)
    rect(x, y, math.floor(w * (d.progress or 0) / 100), 3, C.cyan)
    for i = 1, cfg.MAX_MISTAKES do
        rect(x + w / 2 - 13 + (i - 1) * 9, y + 5, 7, 3, i <= (d.mistakes or 0) and C.red or C.dim)
    end
end

Callback.add(carrier.on_draw, function(inst)
    local own = LU.Session.view()
    for id in pairs(LU.Chests.locked()) do
        local chest = U.by_id(id)
        if chest then
            local d = LU.Chests.data(chest)
            local p = U.by_id(d.picker_id)
            if p and not (own and own.player_id == p.id) then draw_picker(p, d) end
        end
    end

    -- Кольцо дорастает до радиуса шума: игрок видит, докуда услышали.
    local keep = {}
    for _, r in ipairs(rings) do
        r.r = r.r + r.max / 36
        if r.r < r.max then
            gm.draw_set_alpha(math.max(0, 1 - r.r / r.max) * 0.8)
            gm.draw_circle_color(r.x, r.y, r.r, C.red, C.red, true)
            gm.draw_circle_color(r.x, r.y, r.r + 1, C.red, C.red, true)
            keep[#keep + 1] = r
        end
    end
    gm.draw_set_alpha(1)
    rings = keep
end)

-- Носитель заводится заново на каждом этапе: смена комнаты уносит инстансы.
Callback.add(Callback.ON_STEP, function()
    if not U.bool(Global.__run_exists) then return end
    local ok, n = pcall(function() return Instance.count(carrier) end)
    if not ok or U.num(n, 0) > 0 then return end
    pcall(function() carrier:create(0, 0) end)
end)

Callback.add(Callback.ON_STAGE_START, function()
    rings = {}
end)

LU.Overhead = Overhead
