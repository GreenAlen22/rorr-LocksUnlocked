-- Давление: держать действие, давление растёт с ускорением; отпустить в
-- зелёной зоне.

local px = LU.Pixel
local R, Pt, box, ring, disc = px.R, px.P, px.box, px.ring, px.disc
local C, W, TAU = px.C, px.W, px.TAU

LU.Games.register("pressure", function(diff, api)
    local stages = ({ 3, 3, 4, 5 })[diff]
    local bh     = ({ 0.2, 0.16, 0.12, 0.09 })[diff]
    local rate   = ({ 0.42, 0.5, 0.6, 0.72 })[diff]
    local moving = diff >= 3   -- с сундуков за 100 и 500 зона плавает

    local gx, gy, gh, gw = math.floor(W / 2 - 9 + 0.5), 14, 100, 18
    local stage, p, hold, cool, time, puff = 0, 0, false, 0, 0, 0

    local function new_band() return { base = px.rnd(0.38, 0.84), ph = px.rnd(0, TAU) } end
    local band = new_band()

    local function band_c()
        if not moving then return band.base end
        return px.clamp(band.base + 0.13 * math.sin(time * 1.3 + band.ph), 0.3, 0.9)
    end

    local game = {}

    function game.update(dt)
        time = time + dt
        cool = math.max(0, cool - dt)
        puff = math.max(0, puff - dt)
        if hold then
            p = p + rate * (0.55 + 1.3 * p) * dt
            if p >= 1 then
                p, hold, cool = 1, false, 0.5
                api.mistake("overheat")
            end
        else
            p = math.max(0, p - dt * 1.6)
        end
    end

    function game.key(k, down, silent)
        if k ~= "act" then return end
        if down then
            if cool <= 0 then hold = true end
            return
        end
        if not hold then return end
        -- Ввод закрыли пауза или чат: удержание снимается без оценки.
        if silent then hold = false return end
        hold, cool = false, 0.35
        if math.abs(p - band_c()) <= bh / 2 then
            stage = stage + 1
            puff = 0.5
            if stage >= stages then api.win() return end
            api.say("pressure_ok", "good")
            band = new_band()
        else
            api.mistake("zone")
        end
    end

    function game.progress() return stage / stages end

    function game.draw()
        R(gx - 40, gy + gh - 12, 37, 6, C.steel); R(gx - 40, gy + gh - 12, 37, 1, C.light)
        R(gx + gw + 3, gy + 20, 37, 6, C.steel); R(gx + gw + 3, gy + 20, 37, 1, C.light)
        disc(gx - 44, gy + gh - 9, 6, C.dim); ring(gx - 44, gy + gh - 9, 6, C.line)
        R(gx - 4, gy - 4, gw + 8, gh + 8, C.panel); box(gx - 4, gy - 4, gw + 8, gh + 8, C.line)
        R(gx, gy, gw, gh, C.dark)

        local c = band_c()
        local by = gy + gh * (1 - (c + bh / 2))
        px.alpha(0.45); R(gx, by, gw, gh * bh, C.green); px.alpha(1)
        R(gx - 3, by, 2, gh * bh, C.green); R(gx + gw + 1, by, 2, gh * bh, C.green)

        local fh = gh * p
        local col = C.orange
        if p > c + bh / 2 then col = C.red elseif p > c - bh / 2 then col = C.gold end
        R(gx + 3, gy + gh - fh, gw - 6, fh, col)
        R(gx, gy + gh - fh, gw, 1, C.white)
        for i = 1, 9 do R(gx, gy + gh * i / 10, 3, 1, C.line) end
        for i = 0, stages - 1 do disc(gx + gw + 14, gy + gh - 6 - i * 12, 3, i < stage and C.gold or C.dim) end
        if puff > 0 then
            for _ = 1, 6 do Pt(gx + 3 + px.rint(gw - 6), gy - 6 - px.rint(8), C.white) end
        end
    end

    return game
end, { "jump" })
