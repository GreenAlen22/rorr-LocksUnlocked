-- Частота: подогнать голубую волну под оранжевую — влево-вправо частота,
-- вверх-вниз размах — и нажать действие, когда они совпали.

local px = LU.Pixel
local R, Pt, box = px.R, px.P, px.box
local C, W, TAU = px.C, px.W, px.TAU

local SX0, SX1, SY0, SY1 = 16, W - 16, 12, 104
local MID = (SY0 + SY1) / 2
local AMP = (SY1 - SY0) / 2 - 4
local FMIN, FMAX, AMIN, AMAX = 1, 4.5, 0.15, 1

LU.Games.register("frequency", function(diff, api)
    local stages = ({ 1, 2, 2, 3 })[diff]
    local tol    = ({ 0.1, 0.08, 0.065, 0.05 })[diff]
    local drift  = diff >= 3   -- с сундуков за 100 и 500 цель плывёт
    local jitter = diff >= 4   -- на 500 цель ещё и дрожит

    local stage, time, cool, pf, pa = 0, 0, 0, 2.7, 0.55
    local held = {}

    local function new_target()
        local o
        repeat
            o = { f = px.rnd(1.3, 4.1), a = px.rnd(0.3, 0.95), ph = px.rnd(0, TAU) }
        until not (math.abs(o.f - pf) < 0.8 and math.abs(o.a - pa) < 0.25)
        return o
    end
    local tg = new_target()

    -- 0 — волны совпали; сравнивается с допуском tol.
    local function score()
        return math.max(math.abs(pf - tg.f) / (FMAX - FMIN), math.abs(pa - tg.a) / (AMAX - AMIN) * 0.8)
    end

    -- Шаг 2 пикселя: ломаная одним примитивом, ~100 вершин вместо 200 отрезков.
    local function wave(f, a, col, jit)
        local pts = {}
        for x = SX0, SX1 - 1, 2 do
            local u = (x - SX0) / (SX1 - SX0)
            local y = MID - math.sin(u * TAU * f + time * 2.2) * a * AMP
            if jit then y = y + px.rint(3) - 1 end
            pts[#pts + 1] = x
            pts[#pts + 1] = y
        end
        px.polyline(pts, col)
    end

    local game = {}

    function game.update(dt)
        time = time + dt
        cool = math.max(0, cool - dt)
        if held.left then pf = pf - 0.9 * dt end
        if held.right then pf = pf + 0.9 * dt end
        if held.up then pa = pa + 0.55 * dt end
        if held.down then pa = pa - 0.55 * dt end
        pf, pa = px.clamp(pf, FMIN, FMAX), px.clamp(pa, AMIN, AMAX)
        if drift then
            tg.f = px.clamp(tg.f + math.sin(time * 0.8 + tg.ph) * 0.18 * dt, FMIN + 0.2, FMAX - 0.2)
            tg.a = px.clamp(tg.a + math.cos(time * 0.6 + tg.ph) * 0.08 * dt, AMIN + 0.1, AMAX - 0.05)
        end
    end

    function game.key(k, down)
        held[k] = down or nil
        if not down or k ~= "act" or cool > 0 then return end
        if score() <= tol then
            stage = stage + 1
            if stage >= stages then api.win() return end
            api.say("freq_ok", "good")
            tg, cool = new_target(), 0.3
        else
            api.mistake("wave")
        end
    end

    function game.progress() return stage / stages end

    function game.draw()
        px.layer("frequency", function()
            R(SX0 - 3, SY0 - 3, SX1 - SX0 + 6, SY1 - SY0 + 6, C.panel)
            box(SX0 - 3, SY0 - 3, SX1 - SX0 + 6, SY1 - SY0 + 6, C.line)
            R(SX0, SY0, SX1 - SX0, SY1 - SY0, C.scope)
            for x = SX0, SX1 - 1, 16 do
                for y = SY0, SY1 - 1, 4 do Pt(x, y, C.dim) end
            end
            for x = SX0, SX1 - 1, 2 do Pt(x, MID, C.dim) end
        end)

        local match = score() <= tol
        wave(tg.f, tg.a, match and C.gold or C.orange, jitter)
        wave(pf, pa, match and C.white or C.cyan, false)

        -- Полоска «насколько близко».
        local cl = px.clamp(1 - score() / 0.35, 0, 1)
        for i = 0, 9 do
            local col = C.dim
            if match then col = C.gold elseif i < cl * 10 then col = C.cyan end
            R(W / 2 - 30 + i * 6, 116, 5, 5, col)
        end
        for i = 0, stages - 1 do R(8 + i * 8, 116, 6, 6, i < stage and C.gold or C.dim) end
    end

    return game
end, { "left", "right", "up", "down", "jump" })
