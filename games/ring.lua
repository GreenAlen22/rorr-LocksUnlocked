-- Кольцо: метка бежит по кругу, действие внутри сектора закрывает его.

local px = LU.Pixel
local R, ring, disc, thickArc, line = px.R, px.ring, px.disc, px.thickArc, px.line
local C, W, TAU = px.C, px.W, px.TAU

LU.Games.register("ring", function(diff, api)
    local n   = ({ 3, 4, 5, 6 })[diff]
    local wid = ({ 44, 35, 28, 22 })[diff] * math.pi / 180
    local spd = ({ 0.42, 0.55, 0.7, 0.85 })[diff] * TAU
    local rev = diff >= 2                    -- с 50–60 разворот после попадания
    local acc = diff >= 4 and 1.1 or 1       -- с 500 ещё и ускорение

    local cx, cy, RR = W / 2, 69, 44
    local off = px.rnd(0, TAU)
    local sec = TAU / n
    local m = wid / 2 + 0.12

    local segs = {}
    for i = 1, n do segs[i] = { a = off + (i - 1) * sec + px.rnd(m, sec - m), done = false } end

    local a, dir, v = px.rnd(0, TAU), 1, spd

    local function done_count()
        local c = 0
        for _, s in ipairs(segs) do if s.done then c = c + 1 end end
        return c
    end

    local game = {}

    function game.update(dt) a = a + dir * v * dt end

    function game.key(k, down)
        if not down or k ~= "act" then return end
        local hit
        for _, s in ipairs(segs) do
            if not s.done and math.abs(px.angdiff(a, s.a)) <= wid / 2 then hit = s break end
        end
        if hit then
            hit.done = true
            if done_count() == n then api.win() return end
            api.say("ring_hit", "good")
            if rev then dir = -dir end
            v = v * acc
        else
            api.mistake("ring")
        end
    end

    function game.progress() return done_count() / n end

    function game.draw()
        disc(cx, cy, RR + 10, C.panel); ring(cx, cy, RR + 10, C.line)
        thickArc(cx, cy, RR - 3, RR + 3, 0, TAU, C.dark)
        for _, s in ipairs(segs) do
            thickArc(cx, cy, RR - 3, RR + 3, s.a - wid / 2, s.a + wid / 2, s.done and C.gold or C.cyan)
        end
        ring(cx, cy, RR + 4, C.line); ring(cx, cy, RR - 4, C.line)
        local ca, sa = math.cos(a), math.sin(a)
        local nx, ny = -sa, ca
        for o = -1, 1 do
            line(cx + ca * (RR - 9) + nx * o, cy + sa * (RR - 9) + ny * o,
                 cx + ca * (RR + 8) + nx * o, cy + sa * (RR + 8) + ny * o, C.white)
        end
        disc(cx, cy, 13, C.dim); ring(cx, cy, 13, C.line)
        for i, s in ipairs(segs) do
            R(cx - (n * 4 - 1) / 2 + (i - 1) * 4, cy - 1, 3, 3, s.done and C.gold or C.line)
        end
    end

    return game
end, { "jump" })
