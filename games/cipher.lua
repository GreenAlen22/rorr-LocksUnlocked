-- Шифр: замок по очереди подсвечивает стрелки, игрок повторяет. Каждый раунд
-- добавляет по стрелке.

local px = LU.Pixel
local R, box, ring, disc, bmp = px.R, px.box, px.ring, px.disc, px.bmp
local C, W = px.C, px.W

LU.Games.register("cipher", function(diff, api)
    local start  = ({ 3, 3, 4, 4 })[diff]
    local rounds = ({ 2, 3, 3, 4 })[diff]
    local show   = ({ 0.55, 0.45, 0.36, 0.3 })[diff]   -- секунды на вспышку

    -- Порядок — и поворот стрелки: up 0, right 1, down 2, left 3.
    local DIR = { "up", "right", "down", "left" }
    local cx, cy, PS = math.floor(W / 2 + 0.5), 64, 24
    local pos = {
        up = { cx - 12, cy - 40 }, right = { cx + 16, cy - 12 },
        down = { cx - 12, cy + 16 }, left = { cx - 40, cy - 12 },
    }

    local seq = {}
    for i = 1, start do seq[i] = DIR[px.rint(4) + 1] end
    local round = 0
    local phase, i, lit, timer = "show", 1, nil, 0.7
    local input, pressed, pt, told = 0, nil, 0, false

    local function replay(delay)
        phase, i, lit, timer, input = "show", 1, nil, delay, 0
    end

    local game = {}

    function game.update(dt)
        if not told then
            api.say(phase == "show" and "watch" or "your_turn", "info")
            told = true
        end
        pt = math.max(0, pt - dt)
        if phase ~= "show" then return end
        timer = timer - dt
        if timer > 0 then return end
        if lit then
            lit = nil
            i = i + 1
            if i > #seq then
                phase, told = "input", false
                return
            end
            timer = show * 0.45
        else
            lit = seq[i]
            timer = show
            api.tone(lit)
        end
    end

    function game.key(k, down)
        if not down or phase ~= "input" or not pos[k] then return end
        pressed, pt = k, 0.18
        -- Нажатая стрелка звучит своим тоном, как при показе: так порядок
        -- запоминается и на слух.
        api.tone(k)
        if k == seq[input + 1] then
            input = input + 1
            if input >= #seq then
                round = round + 1
                if round >= rounds then api.win() return end
                seq[#seq + 1] = DIR[px.rint(4) + 1]
                replay(0.8)
                api.say("round", "good")
            end
        else
            api.mistake("arrow")
            replay(1.0)
        end
    end

    function game.progress() return round / rounds end

    -- Пока идёт показ, тик последних секунд молчит: он звучит тем же звуком.
    function game.quiet() return phase == "show" end

    function game.draw()
        disc(cx, cy, 50, C.panel); ring(cx, cy, 50, C.line)
        for ri, d in ipairs(DIR) do
            local x, y = pos[d][1], pos[d][2]
            local on = C.dim
            if lit == d then on = C.cyan elseif pressed == d and pt > 0 then on = C.gold end
            R(x, y, PS, PS, on); box(x, y, PS, PS, C.line)
            bmp(px.ARROW, x + 5, y + 5, on == C.dim and C.blue or C.dark, 2, ri - 1)
        end
        disc(cx, cy, 8, C.dark); ring(cx, cy, 8, C.line)

        local n = #seq
        for k = 0, n - 1 do
            R(cx - n * 3 + k * 6 + 1, 122, 4, 4, (phase == "input" and k < input) and C.gold or C.line)
        end
        for k = 0, rounds - 1 do R(8 + k * 8, 8, 6, 6, k < round and C.gold or C.dim) end
    end

    return game
end, { "up", "right", "down", "left" })
