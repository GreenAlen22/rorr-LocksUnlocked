-- Отмычка: стрелки ведут отмычку по дуге, удержание действия или «вверх»
-- проворачивает замок. Чем ближе отмычка к нужной точке, тем дальше он
-- поворачивается; упёршийся замок ломает отмычку.

local px = LU.Pixel
local R, box, ring, disc, line = px.R, px.box, px.ring, px.disc, px.line
local C, W, TAU = px.C, px.W, px.TAU

LU.Games.register("lockpick", function(diff, api)
    local stages = ({ 1, 2, 2, 3 })[diff]
    local zone   = ({ 13, 10, 7, 5 })[diff]      -- градусы, где замок идёт до конца
    local fall   = ({ 55, 45, 38, 32 })[diff]    -- за сколько градусов поворот сходит на нет
    local brk    = ({ 0.8, 1.0, 1.25, 1.5 })[diff]

    local cx, cy = W / 2, 80
    local stage, sweet, pick = 0, px.rnd(-80, 80), 0
    local turn, strain, pause, turning = 0, 0, 0, false
    local held = {}

    local game = {}

    function game.key(k, down) held[k] = down or nil end

    function game.update(dt)
        turning = (held.up or held.act) and true or false
        if not turning then
            if held.left then pick = pick - 75 * dt end
            if held.right then pick = pick + 75 * dt end
            pick = px.clamp(pick, -88, 88)
        end
        if pause > 0 then
            pause = pause - dt
            turn = math.max(0, turn - dt * 3)
            strain = math.max(0, strain - dt)
            return
        end
        if turning then
            local d = math.abs(pick - sweet)
            local allowed = d <= zone and 1 or px.clamp(1 - (d - zone) / fall, 0, 0.9)
            if turn < allowed then
                turn = math.min(allowed, turn + dt * 1.5)
            elseif allowed < 1 then
                strain = strain + dt * brk
            end
            if turn >= 1 then
                stage = stage + 1
                if stage >= stages then api.win() return end
                api.say("layer", "good")
                turn, strain, sweet, pause = 0, 0, px.rnd(-80, 80), 0.5
            end
            if strain >= 1 then
                api.mistake("pick_broke")
                strain, pause = 0, 0.7
            end
        else
            turn = math.max(0, turn - dt * 2.5)
            strain = math.max(0, strain - dt * 0.6)
        end
    end

    function game.progress() return stage / stages end

    function game.draw()
        ring(cx, cy, 56, C.dim, math.pi, TAU)
        disc(cx, cy, 31, C.panel); ring(cx, cy, 31, C.line)
        disc(cx, cy, 23, C.dim); ring(cx, cy, 23, C.line)

        -- Скважина поворачивается вместе с замком.
        local ra = turn * math.pi / 2
        local ux, uy = math.sin(ra), -math.cos(ra)
        disc(math.floor(cx + ux * 5 + 0.5), math.floor(cy + uy * 5 + 0.5), 3, C.dark)
        for k = -9, 5 do R(cx - ux * k - 1, cy - uy * k - 1, 3, 3, C.dark) end

        local shake = turning and strain > 0.05 and pause <= 0
        local jx = shake and (px.rint(3) - 1) or 0
        local jy = shake and (px.rint(3) - 1) or 0
        local col = strain > 0.66 and C.red or (strain > 0.33 and C.orange or C.light)
        local pa = -math.pi / 2 + pick * math.pi / 180
        local ca, sa = math.cos(pa), math.sin(pa)
        line(cx + ca * 6 + jx, cy + sa * 6 + jy, cx + ca * 58 + jx, cy + sa * 58 + jy, col)
        line(cx + ca * 6 + jx + 1, cy + sa * 6 + jy, cx + ca * 58 + jx + 1, cy + sa * 58 + jy, col)

        R(cx - 30, 120, 60, 4, C.dark); R(cx - 30, 120, 60 * px.clamp(strain, 0, 1), 4, col)
        box(cx - 31, 119, 62, 6, C.line)
        for i = 0, stages - 1 do R(8 + i * 8, 8, 6, 6, i < stage and C.gold or C.dim) end
    end

    return game
end, { "left", "right", "jump" })
