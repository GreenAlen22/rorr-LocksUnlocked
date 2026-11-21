-- Схема: повернуть плитки так, чтобы ток прошёл от оранжевого входа слева к
-- золотому выходу справа. Фитиль внизу догорает — искра, ошибка, фитиль
-- снова полный.

local px = LU.Pixel
local R, Pt, box = px.R, px.P, px.box
local C, W = px.C, px.W

-- Стороны плитки битами; поворот по часовой сдвигает их по кругу.
local N, E, S, Wd = 1, 2, 4, 8
local DIRS = { { N, -1, 0, S }, { E, 0, 1, Wd }, { S, 1, 0, N }, { Wd, 0, -1, E } }
local FILL = { N | S, E | Wd, N | E, E | S, S | Wd, Wd | N }
local TS = 18

local function rot(m) return ((m << 1) | (m >> 3)) & 15 end

LU.Games.register("circuit", function(diff, api)
    local cols = ({ 4, 5, 5, 6 })[diff]
    local rows = ({ 3, 3, 4, 4 })[diff]
    local fuse = ({ 9, 7, 6, 5 })[diff]   -- секунды фитиля

    -- Сначала прокладывается заведомо рабочий путь слева направо, остальное
    -- заполняется случайными плитками, потом всё прокручивается.
    local g = {}
    for y = 1, rows do
        g[y] = {}
        for x = 1, cols do g[y][x] = 0 end
    end
    local r0 = px.rint(rows) + 1
    local r = r0
    for c = 1, cols do
        local tg = px.rint(rows) + 1
        if tg == r then
            g[r][c] = Wd | E
        else
            local dn = tg > r
            g[r][c] = Wd | (dn and S or N)
            for rr = math.min(r, tg) + 1, math.max(r, tg) - 1 do g[rr][c] = N | S end
            g[tg][c] = (dn and N or S) | E
            r = tg
        end
    end
    local r1 = r
    for y = 1, rows do
        for x = 1, cols do
            if g[y][x] == 0 then g[y][x] = FILL[px.rint(#FILL) + 1] end
        end
    end

    -- Какие плитки под током (ключ y*16+x) и дошёл ли ток до выхода.
    local function trace()
        local lit, ok = {}, false
        if (g[r0][1] & Wd) == 0 then return lit, ok end
        local st = { { r0, 1 } }
        lit[r0 * 16 + 1] = true
        while #st > 0 do
            local cell = table.remove(st)
            local y, x = cell[1], cell[2]
            local m = g[y][x]
            for _, d in ipairs(DIRS) do
                if (m & d[1]) ~= 0 then
                    local ny, nx = y + d[2], x + d[3]
                    if nx > cols then
                        if d[1] == E and y == r1 then ok = true end
                    elseif ny >= 1 and ny <= rows and nx >= 1 and (g[ny][nx] & d[4]) ~= 0 then
                        local key = ny * 16 + nx
                        if not lit[key] then
                            lit[key] = true
                            st[#st + 1] = { ny, nx }
                        end
                    end
                end
            end
        end
        return lit, ok
    end

    for y = 1, rows do
        for x = 1, cols do
            for _ = 1, px.rint(4) do g[y][x] = rot(g[y][x]) end
        end
    end
    -- Вход крутится, пока схема не перестанет быть собранной с самого начала.
    -- Больше двух оборотов не нужно: западная сторона есть у плитки в двух
    -- положениях из четырёх.
    while select(2, trace()) do g[r0][1] = rot(g[r0][1]) end

    local lit = trace()
    local cr, cc, ft = r0, 1, fuse
    local gx, gy = math.floor(W / 2 - cols * TS / 2 + 0.5), 14

    local game = {}

    function game.update(dt)
        ft = ft - dt
        if ft <= 0 then
            ft = fuse
            api.mistake("spark")
        end
    end

    function game.key(k, down)
        if not down then return end
        if k == "left" then cc = math.max(1, cc - 1)
        elseif k == "right" then cc = math.min(cols, cc + 1)
        elseif k == "up" then cr = math.max(1, cr - 1)
        elseif k == "down" then cr = math.min(rows, cr + 1)
        elseif k == "act" then
            g[cr][cc] = rot(g[cr][cc])
            local ok
            lit, ok = trace()
            if ok then api.win() end
        end
    end

    -- Как далеко вправо дошёл ток.
    function game.progress()
        local far = 0
        for key in pairs(lit) do far = math.max(far, key % 16) end
        return far / (cols + 1)
    end

    function game.draw()
        R(gx - 4, gy - 4, cols * TS + 8, rows * TS + 8, C.panel)
        box(gx - 4, gy - 4, cols * TS + 8, rows * TS + 8, C.line)
        for y = 1, rows do
            for x = 1, cols do
                local X, Y = gx + (x - 1) * TS, gy + (y - 1) * TS
                local m = g[y][x]
                local col = lit[y * 16 + x] and C.cyan or C.steel
                R(X, Y, TS, TS, C.dark); box(X, Y, TS, TS, C.dim)
                if (m & N) ~= 0 then R(X + 7, Y, 4, 11, col) end
                if (m & E) ~= 0 then R(X + 7, Y + 7, 11, 4, col) end
                if (m & S) ~= 0 then R(X + 7, Y + 7, 4, 11, col) end
                if (m & Wd) ~= 0 then R(X, Y + 7, 11, 4, col) end
            end
        end
        R(gx - 12, gy + (r0 - 1) * TS + 5, 8, 8, C.orange); R(gx - 4, gy + (r0 - 1) * TS + 7, 4, 4, C.orange)
        R(gx + cols * TS + 4, gy + (r1 - 1) * TS + 5, 8, 8, C.gold); R(gx + cols * TS, gy + (r1 - 1) * TS + 7, 4, 4, C.gold)
        local sx, sy = gx + (cc - 1) * TS, gy + (cr - 1) * TS
        box(sx, sy, TS, TS, C.gold); box(sx + 1, sy + 1, TS - 2, TS - 2, C.gold)

        local fy, fw = gy + rows * TS + 10, cols * TS
        local left = px.clamp(ft / fuse, 0, 1)
        R(gx, fy, fw, 3, C.dim); R(gx, fy, fw * left, 3, left < 0.3 and C.red or C.orange)
        Pt(gx + fw * left, fy - 1 - px.rint(2), px.rint(2) == 1 and C.white or C.gold)
    end

    return game
end, { "left", "right", "up", "down", "jump" })
