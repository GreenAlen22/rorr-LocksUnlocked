-- Зонд: провести зонд стрелками через лазерные стенки к ядру справа. Проём в
-- каждой стенке ездит вверх-вниз; задел луч — ошибка и возврат за последнюю
-- пройденную стенку.

local px = LU.Pixel
local R, Pt, box, disc = px.R, px.P, px.box, px.disc
local C, W, H, TAU = px.C, px.W, px.H, px.TAU

local FX0, FX1, FY0, FY1 = 10, W - 10, 14, H - 12
local CY = (FY0 + FY1) / 2
local SPEED = 44   -- пикселей холста в секунду

LU.Games.register("probe", function(diff, api)
    local ng  = ({ 3, 4, 5, 6 })[diff]
    local gap = ({ 32, 26, 21, 17 })[diff]         -- высота проёма
    local gs  = ({ 0.35, 0.45, 0.55, 0.68 })[diff] -- скорость проёмов, кругов в секунду
    local AMP = (FY1 - FY0) / 2 - gap / 2 - 3

    local gates = {}
    for i = 0, ng - 1 do
        gates[i + 1] = {
            x  = math.floor(FX0 + 40 + i * ((FX1 - FX0 - 72) / (ng - 1)) + 0.5),
            ph = px.rnd(0, TAU),
            f  = gs * px.rnd(0.8, 1.3),
        }
    end

    local x, y = FX0 + 10, CY
    local cpx, cpy, inv, time = x, y, 0, 0
    local held = {}

    local function gap_y(q) return CY + math.sin(time * q.f * TAU + q.ph) * AMP end

    local game = {}

    function game.key(k, down) held[k] = down or nil end

    function game.update(dt)
        time = time + dt
        inv = math.max(0, inv - dt)
        local dx = (held.right and 1 or 0) - (held.left and 1 or 0)
        local dy = (held.down and 1 or 0) - (held.up and 1 or 0)
        x = px.clamp(x + dx * SPEED * dt, FX0 + 3, FX1 - 3)
        y = px.clamp(y + dy * SPEED * dt, FY0 + 3, FY1 - 3)
        for _, q in ipairs(gates) do
            if x > q.x + 4 and cpx < q.x + 4 then cpx, cpy = q.x + 7, y end
            if inv <= 0 and math.abs(x - q.x) <= 3 then
                local c = gap_y(q)
                if y - 2 < c - gap / 2 or y + 2 > c + gap / 2 then
                    x, y, inv = cpx, cpy, 0.8
                    api.mistake("beam")
                    return
                end
            end
        end
        if x >= FX1 - 14 then api.win() end
    end

    -- Сколько стенок за спиной: точка возврата стоит за последней пройденной.
    function game.progress()
        local passed = 0
        for _, q in ipairs(gates) do
            if cpx > q.x then passed = passed + 1 end
        end
        return passed / (ng + 1)
    end

    function game.draw()
        px.layer("probe", function()
            R(FX0, FY0, FX1 - FX0, FY1 - FY0, C.dark)
            box(FX0 - 1, FY0 - 1, FX1 - FX0 + 2, FY1 - FY0 + 2, C.line)
            for gx = FX0 + 4, FX1 - 1, 8 do
                for gy = FY0 + 4, FY1 - 1, 8 do Pt(gx, gy, C.dim) end
            end
            R(FX0 + 2, CY - 7, 3, 14, C.blue)
        end)
        disc(FX1 - 9, CY, 4 + (math.sin(time * 6) > 0 and 1 or 0), C.gold)
        for _, q in ipairs(gates) do
            local c = gap_y(q)
            local top, bot = c - gap / 2, c + gap / 2
            R(q.x - 1, FY0, 3, top - FY0, C.red); R(q.x, FY0, 1, top - FY0, C.beam)
            R(q.x - 1, bot, 3, FY1 - bot, C.red); R(q.x, bot, 1, FY1 - bot, C.beam)
            R(q.x - 3, top - 2, 7, 2, C.light); R(q.x - 3, bot, 7, 2, C.light)
        end
        if inv <= 0 or math.floor(inv * 12) % 2 == 0 then
            R(x - 2, y - 2, 5, 5, C.cyan); Pt(x, y, C.white)
        end
    end

    return game
end, { "left", "right", "up", "down" })
