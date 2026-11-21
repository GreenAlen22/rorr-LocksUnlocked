-- Холст мини-игр 240x135 и примитивы для них.
--
-- Рисовать каждый пиксель отдельным прямоугольником нельзя: кольцо в несколько
-- сотен точек — несколько сотен вызовов в движок за кадр. Поэтому холст —
-- поверхность в натуральную величину: игра рисует на ней обычными примитивами
-- GameMaker, а panel растягивает её целым множителем без сглаживания.

LU = LU or {}

local P = {}

P.W, P.H = 240, 135
P.TAU = math.pi * 2

-- Цвет #rrggbb в формате GameMaker (0xbbggrr).
local function hex(s)
    local r = tonumber(s:sub(2, 3), 16)
    local g = tonumber(s:sub(4, 5), 16)
    local b = tonumber(s:sub(6, 7), 16)
    return b * 65536 + g * 256 + r
end

-- Серые — под ванильные панели меню. sUIPanelDark держится на трёх тонах:
-- тело #20232d, кант #393940, обводка #1a1a1a. Холст мини-игры темнее тела,
-- детали внутри — на ступенях между ними, поэтому экран и рамка читаются
-- одним устройством. gold совпадает с
-- жёлтым текстом игры (#EFD27B, oChest4_Draw_73.gml).
P.C = {
    bg = hex("#14151b"), panel = hex("#20232d"), dark = hex("#18191f"), dim = hex("#2f323d"),
    line = hex("#4b4e5c"), steel = hex("#8b8f9e"), light = hex("#c9ccd6"), white = hex("#f1f3f8"),
    gold = hex("#efd27b"), red = hex("#cf6666"), blue = hex("#7c88b8"), orange = hex("#f3a556"),
    green = hex("#8bc45a"), cyan = hex("#5fd3e6"), purple = hex("#b07cd8"),
    -- Блик лазера в Зонде и фон экрана в Частоте.
    beam = hex("#ffb3b3"), scope = hex("#10151f"),
    -- Тона самой ванильной панели: для рамки экрана и тени текста.
    rim = hex("#393940"), ink = hex("#1a1a1a"),
}

-- ===== Случайность и геометрия =====

function P.rnd(a, b) return a + math.random() * (b - a) end
function P.rint(n) return math.random(0, math.max(1, n) - 1) end
function P.clamp(v, a, b) return math.max(a, math.min(b, v)) end

function P.angdiff(a, b)
    local d = (a - b) % P.TAU
    if d > math.pi then d = d - P.TAU end
    return d
end

-- ===== Примитивы, в координатах холста =====

local alpha = 1
function P.alpha(a) alpha = a; gm.draw_set_alpha(a) end

local floor = math.floor
local function rnd(v) return floor(v + 0.5) end

-- Залитый прямоугольник. В GameMaker правый нижний угол включительный.
function P.R(x, y, w, h, c)
    x, y, w, h = rnd(x), rnd(y), rnd(w), rnd(h)
    if w <= 0 or h <= 0 then return end
    gm.draw_rectangle_color(x, y, x + w - 1, y + h - 1, c, c, c, c, false)
end

function P.P(x, y, c) P.R(x, y, 1, 1, c) end

function P.box(x, y, w, h, c)
    P.R(x, y, w, 1, c); P.R(x, y + h - 1, w, 1, c)
    P.R(x, y, 1, h, c); P.R(x + w - 1, y, 1, h, c)
end

function P.line(x0, y0, x1, y1, c)
    gm.draw_line_color(rnd(x0), rnd(y0), rnd(x1), rnd(y1), c, c)
end

-- Дуга окружности ломаной. Полный круг — контур движка.
function P.ring(cx, cy, r, c, a0, a1)
    if r <= 0 then return end
    if a0 == nil then
        gm.draw_circle_color(rnd(cx), rnd(cy), r, c, c, true)
        return
    end
    local n = math.max(4, math.ceil(r * math.abs(a1 - a0) / 3))
    gm.draw_primitive_begin(3)                                   -- pr_linestrip
    for i = 0, n do
        local a = a0 + (a1 - a0) * i / n
        gm.draw_vertex_color(cx + math.cos(a) * r, cy + math.sin(a) * r, c, alpha)
    end
    gm.draw_primitive_end()
end

-- Толстая дуга от r0 до r1 — лента треугольников.
function P.thickArc(cx, cy, r0, r1, a0, a1, c)
    local n = math.max(4, math.ceil(r1 * math.abs(a1 - a0) / 3))
    gm.draw_primitive_begin(5)                                   -- pr_trianglestrip
    for i = 0, n do
        local a = a0 + (a1 - a0) * i / n
        local ca, sa = math.cos(a), math.sin(a)
        gm.draw_vertex_color(cx + ca * r0, cy + sa * r0, c, alpha)
        gm.draw_vertex_color(cx + ca * (r1 + 1), cy + sa * (r1 + 1), c, alpha)
    end
    gm.draw_primitive_end()
end

function P.disc(cx, cy, r, c)
    gm.draw_circle_color(rnd(cx), rnd(cy), r, c, c, false)
end

-- Ломаная по точкам { x1, y1, x2, y2, ... } одним примитивом.
function P.polyline(pts, c)
    gm.draw_primitive_begin(3)                                   -- pr_linestrip
    for i = 1, #pts - 1, 2 do gm.draw_vertex_color(rnd(pts[i]), rnd(pts[i + 1]), c, alpha) end
    gm.draw_primitive_end()
end

-- Битмап раскладывается в прямоугольники один раз: подряд идущие клетки
-- строки — в полосу, одинаковые полосы соседних строк — в один блок. Символ
-- «Кода» так стоит 3–7 вызовов вместо 20–49, а их на экране до трёх десятков.
local bmp_cache = {}
local function bmp_rects(rows, rot)
    local by_rot = bmp_cache[rows]
    if not by_rot then by_rot = {}; bmp_cache[rows] = by_rot end
    if by_rot[rot] then return by_rot[rot] end

    local n = #rows
    local cell = {}
    for Y = 0, n - 1 do cell[Y] = {} end
    for sy = 0, n - 1 do
        local row = rows[sy + 1]
        for sx = 0, n - 1 do
            if row:sub(sx + 1, sx + 1) == "#" then
                local X, Y = sx, sy
                if     rot == 1 then X, Y = n - 1 - sy, sx
                elseif rot == 2 then X, Y = n - 1 - sx, n - 1 - sy
                elseif rot == 3 then X, Y = sy, n - 1 - sx end
                cell[Y][X] = true
            end
        end
    end

    local rects, open = {}, {}
    for Y = 0, n - 1 do
        local now, X = {}, 0
        while X < n do
            if cell[Y][X] then
                local x0 = X
                while X < n and cell[Y][X] do X = X + 1 end
                local key = x0 * 16 + (X - x0)
                local r = open[key]
                if r then r[4] = r[4] + 1 else r = { x0, Y, X - x0, 1 }; rects[#rects + 1] = r end
                now[key] = r
            else
                X = X + 1
            end
        end
        open = now
    end
    by_rot[rot] = rects
    return rects
end

-- Битмап 7x7 из строк '#'/'.', s — размер клетки, rot — четверти оборота по
-- часовой.
function P.bmp(rows, x, y, c, s, rot)
    s, rot = s or 1, rot or 0
    for _, r in ipairs(bmp_rects(rows, rot)) do
        P.R(x + r[1] * s, y + r[2] * s, r[3] * s, r[4] * s, c)
    end
end

-- Неподвижный слой: рамки, сетка точек. Рисуется на свою поверхность один раз
-- и дальше ложится на холст одним вызовом — сетка «Зонда» иначе стоила бы
-- ~400 вызовов в движок за кадр. Слой обязан быть одинаковым при любой
-- сложности: id один на игру. Вызывать только между begin и finish.
local layers = {}
function P.layer(id, fn)
    local s = layers[id]
    if s == nil or not LU.Util.bool(gm.surface_exists(s)) then
        s = gm.surface_create(P.W, P.H)
        layers[id] = s
        -- Цель поверхностей у GameMaker — стек: после reset рисуем снова на холст.
        gm.surface_set_target(s)
        gm.gpu_set_colorwriteenable(true, true, true, true)
        gm.draw_clear_alpha(0, 0)
        local ok, err = pcall(fn)
        -- Цель снимается и при ошибке: иначе стек целей разъедется, и
        -- холст и HUD игры лягут не туда. Ошибку — дальше, панель её запишет.
        gm.gpu_set_colorwriteenable(true, true, true, false)
        gm.surface_reset_target()
        if not ok then
            gm.surface_free(s)
            layers[id] = nil
            error(err, 0)
        end
    end
    gm.draw_surface(s, 0, 0)
end

P.ARROW = { "...#...", "..###..", ".#####.", "#######", "..###..", "..###..", "..###.." }
P.SYM = {
    { "..###..", ".#####.", "#######", "#######", "#######", ".#####.", "..###.." },
    { "#######", "#######", "##...##", "##...##", "##...##", "#######", "#######" },
    { "...#...", "..###..", "..###..", ".#####.", ".#####.", "#######", "#######" },
    { "...#...", "..###..", ".#####.", "#######", ".#####.", "..###..", "...#..." },
    { "##...##", "###.###", ".#####.", "..###..", ".#####.", "###.###", "##...##" },
    { "#.#.#.#", "#.#.#.#", "#.#.#.#", "#.#.#.#", "#.#.#.#", "#.#.#.#", "#.#.#.#" },
}
P.SYMC = { P.C.red, P.C.green, P.C.cyan, P.C.orange, P.C.white, P.C.purple }

-- ===== Кадр холста =====

-- surface_create может вернуть и число, и ссылку движка, поэтому сравнений с
-- числом нет: только nil и surface_exists.
local surf = nil

-- Начать рисовать на холсте. Поверхность движок может потерять в любой момент
-- (сворачивание окна), поэтому проверка каждый кадр.
function P.begin()
    if surf == nil or not LU.Util.bool(gm.surface_exists(surf)) then
        surf = gm.surface_create(P.W, P.H)
    end
    gm.surface_set_target(surf)
    gm.draw_clear_alpha(P.C.bg, 1)
    -- Альфа холста остаётся 1: полупрозрачные полосы мини-игр смешиваются с
    -- фоном холста, а не делают дыру в панели.
    gm.gpu_set_colorwriteenable(true, true, true, false)
    gm.draw_set_circle_precision(64)
    P.alpha(1)
end

-- Закончить и нарисовать холст в HUD с целым множителем k.
function P.finish(ox, oy, k)
    P.alpha(1)
    gm.draw_set_circle_precision(24)
    gm.gpu_set_colorwriteenable(true, true, true, true)
    gm.surface_reset_target()
    local filter = gm.gpu_get_texfilter()
    gm.gpu_set_texfilter(false)
    gm.draw_surface_ext(surf, ox, oy, k, k, 0, 16777215, 1)
    gm.gpu_set_texfilter(filter)
end

LU.Pixel = P
