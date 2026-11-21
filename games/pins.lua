-- Штифты: штифты ходят вверх-вниз, действие ставит выбранный, когда его верх
-- на золотой линии.

local px = LU.Pixel
local R, Pt, box, line = px.R, px.P, px.box, px.line
local C, W, TAU = px.C, px.W, px.TAU

LU.Games.register("pins", function(diff, api)
    local n    = ({ 3, 4, 5, 6 })[diff]
    local fq   = ({ 0.55, 0.75, 0.95, 1.2 })[diff]
    local band = ({ 7, 5, 4, 3 })[diff]
    local drop = diff >= 3   -- с сундуков за 100 и 500 ошибка роняет вставший штифт

    local colW, gap = 12, 5
    local total = n * colW + (n - 1) * gap
    local x0 = math.floor(W / 2 - total / 2 + 0.5)
    local TOP, SHEAR, LOW, HIGH, PLUG = 16, 58, 44, 80, 94

    local pins = {}
    for i = 1, n do pins[i] = { ph = px.rnd(0, TAU), f = fq * px.rnd(0.8, 1.25), set = false } end
    local cur = 1

    local function yk(p)
        if p.set then return SHEAR end
        return math.floor(LOW + (HIGH - LOW) * (0.5 + 0.5 * math.sin(p.ph)) + 0.5)
    end

    local function next_unset(dir)
        for k = 1, n do
            local i = ((cur - 1 + dir * k) % n) + 1
            if not pins[i].set then return i end
        end
        return cur
    end

    local function all_set()
        for _, p in ipairs(pins) do if not p.set then return false end end
        return true
    end

    local game = {}

    function game.update(dt)
        for _, p in ipairs(pins) do
            if not p.set then p.ph = p.ph + p.f * TAU * dt end
        end
    end

    function game.key(k, down)
        if not down then return end
        if k == "left" then cur = next_unset(-1)
        elseif k == "right" then cur = next_unset(1)
        elseif k == "act" or k == "up" then
            local p = pins[cur]
            if p.set then return end
            if math.abs(yk(p) - SHEAR) <= band / 2 then
                p.set = true
                if all_set() then api.win() return end
                api.say("pin_set", "good")
                cur = next_unset(1)
            else
                api.mistake("pin")
                if drop then
                    local s = {}
                    for _, q in ipairs(pins) do if q.set then s[#s + 1] = q end end
                    if #s > 0 then
                        local q = s[math.random(1, #s)]
                        q.set = false
                        q.ph = px.rnd(0, TAU)
                    end
                end
            end
        end
    end

    function game.progress()
        local c = 0
        for _, p in ipairs(pins) do if p.set then c = c + 1 end end
        return c / n
    end

    function game.draw()
        R(x0 - 9, TOP - 5, total + 18, PLUG - TOP + 20, C.panel)
        box(x0 - 9, TOP - 5, total + 18, PLUG - TOP + 20, C.line)
        px.alpha(0.25); R(x0 - 6, SHEAR - band / 2, total + 12, band, C.gold); px.alpha(1)

        for i, p in ipairs(pins) do
            local pxx = x0 + (i - 1) * (colW + gap)
            local y = yk(p)
            local drv = y - 10
            R(pxx, TOP, colW, PLUG - TOP, C.dark)
            local side = 0
            for yy = TOP, drv - 2, 2 do
                line(pxx + 2 + side * 7, yy, pxx + 2 + (1 - side) * 7, math.min(yy + 2, drv - 1), C.steel)
                side = 1 - side
            end
            R(pxx + 1, drv, colW - 2, 10, C.light); R(pxx + 1, drv, colW - 2, 1, C.white)
            R(pxx + colW - 2, drv, 1, 10, C.steel)
            R(pxx + 1, y, colW - 2, PLUG - y, p.set and C.gold or C.cyan)
            R(pxx + 1, y, colW - 2, 1, C.white)
            if i == cur and not p.set then box(pxx - 2, TOP - 3, colW + 4, PLUG - TOP + 6, C.gold) end
        end

        for x = x0 - 6, x0 + total + 5, 2 do Pt(x, SHEAR, C.gold) end
        R(x0 - 9, PLUG + 3, total + 18, 12, C.dark)
        local tip = x0 + (cur - 1) * (colW + gap) + colW / 2
        line(2, PLUG + 9, tip, PLUG + 9, C.light)
        line(2, PLUG + 10, tip, PLUG + 10, C.steel)
        line(tip, PLUG + 9, tip + 2, PLUG + 5, C.light)
    end

    return game
end, { "left", "right", "jump" })
