-- Код: подобрать код из символов. Золотая рамка — символ на своём месте,
-- синяя — такой есть, но в другой ячейке, тёмная — такого нет. Первые
-- попытки бесплатные, дальше каждая неудачная — ошибка.

local px = LU.Pixel
local R, Pt, box, bmp = px.R, px.P, px.box, px.bmp
local C, W, SYM, SYMC = px.C, px.W, px.SYM, px.SYMC

local CELL = 13

LU.Games.register("code", function(diff, api)
    local len   = ({ 3, 3, 4, 4 })[diff]
    local kinds = ({ 4, 5, 5, 6 })[diff]
    local free  = ({ 2, 2, 3, 3 })[diff]   -- бесплатных попыток
    local rep   = diff >= 3                -- с сундуков за 100 и 500 символы повторяются

    -- Символы — номера с нуля: индекс в SYM на единицу больше.
    local code = {}
    local function has(t, v)
        for _, s in ipairs(t) do if s == v then return true end end
        return false
    end
    while #code < len do
        local s = px.rint(kinds)
        if rep or not has(code, s) then code[#code + 1] = s end
    end

    local guess, hist = {}, {}
    for i = 1, len do guess[i] = 0 end
    local slot, wrong, best = 1, 0, 0

    -- 2 — на месте, 1 — есть в другой ячейке, 0 — нет.
    local function feedback(gs)
        local fb, left = {}, {}
        for i = 1, len do
            if gs[i] == code[i] then
                fb[i] = 2
            else
                fb[i] = 0
                left[code[i]] = (left[code[i]] or 0) + 1
            end
        end
        for i = 1, len do
            if fb[i] == 0 and (left[gs[i]] or 0) > 0 then
                fb[i] = 1
                left[gs[i]] = left[gs[i]] - 1
            end
        end
        return fb
    end

    local x0 = math.floor(W / 2 - (len * CELL + (len - 1) * 3) / 2 + 0.5)

    local game = {}

    function game.update() end

    function game.key(k, down)
        if not down then return end
        if k == "left" then slot = (slot - 2) % len + 1
        elseif k == "right" then slot = slot % len + 1
        elseif k == "up" then guess[slot] = (guess[slot] + 1) % kinds
        elseif k == "down" then guess[slot] = (guess[slot] + kinds - 1) % kinds
        elseif k == "act" then
            local fb, g, hits = feedback(guess), {}, 0
            for i = 1, len do
                g[i] = guess[i]
                if fb[i] == 2 then hits = hits + 1 end
            end
            hist[#hist + 1] = { g = g, fb = fb }
            best = math.max(best, hits)
            if hits == len then api.win() return end
            wrong = wrong + 1
            if wrong > free then
                api.mistake("code")
            elseif free - wrong > 0 then
                api.say("code_free", "info", free - wrong)
            else
                api.say("code_last", "info")
            end
        end
    end

    -- Лучшая попытка: сколько символов стояло на своих местах.
    function game.progress() return best / len end

    function game.draw()
        -- Пять последних попыток сверху.
        local first = math.max(1, #hist - 4)
        for ri = first, #hist do
            local h = hist[ri]
            local y = 6 + (ri - first) * 16
            for i = 1, len do
                local s, f = h.g[i], h.fb[i]
                local x = x0 + (i - 1) * (CELL + 3)
                local bc = C.dim
                if f == 2 then bc = C.gold elseif f == 1 then bc = C.blue end
                R(x, y, CELL, CELL, C.dark); box(x, y, CELL, CELL, bc); box(x + 1, y + 1, CELL - 2, CELL - 2, bc)
                bmp(SYM[s + 1], x + 3, y + 3, f == 0 and C.line or SYMC[s + 1])
            end
        end

        -- Набираемый код и курсор.
        local y = 94
        for i = 1, len do
            local s = guess[i]
            local x = x0 + (i - 1) * (CELL + 3)
            R(x, y, CELL, CELL, C.panel); box(x, y, CELL, CELL, C.line)
            bmp(SYM[s + 1], x + 3, y + 3, SYMC[s + 1])
            if i == slot then
                box(x - 2, y - 2, CELL + 4, CELL + 4, C.gold)
                R(x + 5, y - 5, 3, 1, C.gold); Pt(x + 6, y - 6, C.gold)
                R(x + 5, y + CELL + 4, 3, 1, C.gold); Pt(x + 6, y + CELL + 5, C.gold)
            end
        end

        -- Слева все символы, что бывают в коде; снизу бесплатные попытки.
        for i = 0, kinds - 1 do bmp(SYM[i + 1], 10, 8 + i * 11, SYMC[i + 1]) end
        for i = 0, free - 1 do
            R(W / 2 - free * 5 + i * 10 + 2, 122, 6, 4, i < free - wrong and C.green or C.dim)
        end
    end

    return game
end, { "left", "right", "up", "down", "jump" })
