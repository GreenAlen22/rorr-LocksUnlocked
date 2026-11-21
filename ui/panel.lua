-- Панель взлома в HUD.
--
--   [Серия x2]        [ Название ]        Сложность (иконка)
--   ┌──────────────── экран мини-игры ─────────────────┐
--   └──────────────────────────────────────────────────┘
--   ✕ ✕ ✕  полоса времени
--                     сообщение
--        управление и отмена, с переносом по ширине
--
-- Всё из ванили: тело — sUIPanelDark, плашка названия —
-- sUIPanelDarkTitleHousing (обе растягиваются по девяти частям, как меню
-- результатов и всплывающие окна), иконки сложности — из выбора сложности,
-- метки ошибок и знак итога — sLockedInSmall.
-- Размеры — от экрана и масштаба HUD; панель стоит сверху по центру.

LU = LU or {}

local U   = LU.Util
local px  = LU.Pixel
local cfg = LU.Config
local C   = px.C

local Panel = {}

local WHITE = 16777215
local PAD, GAP, LINE = 10, 4, 13
local HEAD_H, PLATE_H = 24, 22   -- плашку можно сжать до 20: её края 11 и 9 (data.win)
local MARK_W, MARK_H = 14, 11    -- шаг и высота метки ошибки
local ICON_W = 28                -- место под самую широкую иконку, Monsoon 27
local EDGE = 8                   -- отступ панели от краёв HUD

-- Ресурсы игры. Промах в имени даёт nil — тогда этот кусок не рисуется, а в
-- логе одна строка, а не ошибка каждый кадр.
local SPR = {
    panel = gm.constants.sUIPanelDark, plate = gm.constants.sUIPanelDarkTitleHousing,
    mark  = gm.constants.sLockedInSmall,
}
-- Лёгкий, средний, трудный, сундук за 500: ванильные Drizzle, Rainstorm,
-- Monsoon и Eclipse — их игрок узнаёт по меню выбора сложности.
local DIFF_ICON = { gm.constants.sDifficultyDrizzle, gm.constants.sDifficultyRainstorm, gm.constants.sDifficultyMonsoon, gm.constants.sDifficultyEclipse1 }
for name, v in pairs(SPR) do
    if v == nil then log.warning("LocksUnlocked: vanilla sprite missing for panel."..name) end
end
for i = 1, 4 do
    if DIFF_ICON[i] == nil then log.warning("LocksUnlocked: vanilla difficulty icon "..i.." missing") end
end
local ICON_FRAME = 2   -- кадр с белой обводкой, как у выбранной сложности
-- sLockedInSmall: 0 тёмный крест, 1 зелёная галочка, 2 красный крест. Им же
-- помечен итог: у sUICharacterSelectLock открытого кадра нет, оба закрыты.
local MARK_OFF, MARK_OK, MARK_ON = 0, 1, 2
local RESULT_MARK = { clean = MARK_OK, ok = MARK_OK, fail = MARK_ON, cancel = MARK_OFF }

local function hud_size()
    local scale = U.num(Global.current_hud_scale, 1)
    if scale <= 0 then scale = 1 end
    return U.num(gm.display_get_gui_width(), 1920) / scale,
           U.num(gm.display_get_gui_height(), 1080) / scale
end

-- ===== Текст =====

-- Через Scribble, как у самой игры: у fntNormal есть запасной шрифт с
-- кириллицей, а значки клавиш из control_string — его же разметка.
-- halign: 0 — от x вправо, 1 — по центру на x, 2 — влево от x
-- (scribble_cache.gml:1597-1603).

local size_cache, size_count = {}, 0

-- Ширина и высота строки; wrap — ширина переноса или nil.
local function measure(str, wrap)
    local key = str.."\n"..tostring(wrap)
    local m = size_cache[key]
    if m then return m[1], m[2] end
    gm.scribble_set_starting_format("fntNormal", WHITE, 0)
    if wrap then gm.scribble_set_wrap(wrap, -1) end
    local w = U.num(gm.scribble_get_width(str), #str * 7)
    local h = U.num(gm.scribble_get_height(str), LINE)
    gm.scribble_reset()
    if size_count > 200 then size_cache, size_count = {}, 0 end
    size_cache[key], size_count = { w, h }, size_count + 1
    return w, h
end

local function text(x, y, str, col, halign, wrap)
    gm.scribble_set_starting_format("fntNormal", col or WHITE, halign or 0)
    if wrap then gm.scribble_set_wrap(wrap, -1) end
    gm.scribble_draw(math.floor(x), math.floor(y), str)
    gm.scribble_reset()
end

-- Тень на пиксель вниз-вправо, как у текста поверх сцены в игре. Только для
-- строк без значков: значок клавиши в тени нарисовался бы дважды.
local function text_shadow(x, y, str, col, halign)
    text(x + 1, y + 1, str, C.ink, halign)
    text(x, y, str, col, halign)
end

-- Малые значки, как подписи клавиш у навыков на HUD: строка управления
-- держится в одну-две строки и на узком экране.
local function glyph(idx, verb)
    local ok, s = pcall(gm.control_string, idx, verb, 0)
    if ok and type(s) == "string" then return s end
    return "["..verb.."]"
end

-- ===== Рисование =====

-- Нулевая ширина — пусто: GameMaker рисует перевёрнутый прямоугольник
-- полоской в пару пикселей, и пустая полоса времени не была бы пустой.
local function rect(x, y, w, h, col, a)
    if w <= 0 or h <= 0 then return end
    if a and a < 1 then gm.draw_set_alpha(a) end
    gm.draw_rectangle_color(x, y, x + w - 1, y + h - 1, col, col, col, col, false)
    if a and a < 1 then gm.draw_set_alpha(1) end
end

local function sprite(spr, frame, x, y)
    if spr ~= nil then gm.draw_sprite(spr, frame, math.floor(x), math.floor(y)) end
end

-- Спрайт по центру точки, как бы ни стоял его origin.
local function sprite_centered(spr, frame, cx, cy)
    if spr == nil then return end
    local w, h = U.num(gm.sprite_get_width(spr), 0), U.num(gm.sprite_get_height(spr), 0)
    local ox, oy = U.num(gm.sprite_get_xoffset(spr), 0), U.num(gm.sprite_get_yoffset(spr), 0)
    sprite(spr, frame, cx - w / 2 + ox, cy - h / 2 + oy)
end

local function stretched(spr, x, y, w, h)
    if spr ~= nil then gm.draw_sprite_stretched(spr, 0, math.floor(x), math.floor(y), math.floor(w), math.floor(h)) end
end

local MSG_COL = { good = C.green, info = C.light, bad = C.red }
local RESULT_COL = { clean = C.gold, ok = C.green, fail = C.red, cancel = C.steel }

local draw_failed = {}   -- id мини-игры -> ошибка отрисовки уже в логе

Callback.add(Callback.ON_HUD_DRAW, function()
    local v = LU.Session.view()
    if not v or not v.game then return end
    local player = U.by_id(v.player_id)
    local idx = player and math.max(0, math.floor(U.num(player.input_player_index, 0))) or 0

    local hw, hh = hud_size()
    local k = math.max(1, math.floor(math.min(hw * 0.5 / px.W, hh * 0.30 / px.H)))
    local cw, ch = px.W * k, px.H * k

    -- Строки до раскладки: от них зависит ширина панели.
    local title = gm.translate("locksunlocked.game."..v.game_id..".name")
    local diff_label = gm.translate("locksunlocked.panel.diff")
    local streak = (v.streak or 0) > 0 and gm.translate("locksunlocked.panel.streak", tostring(v.streak)) or nil
    local args = {}
    for i, verb in ipairs(LU.Games.verbs(v.game_id)) do args[i] = glyph(idx, verb) end
    local controls = gm.translate("locksunlocked.game."..v.game_id..".controls", table.unpack(args))
    controls = controls.."    "..gm.translate("locksunlocked.panel.cancel", glyph(idx, LU.Options.verb))

    -- Ширина: экран мини-игры с полями, и шапка, где плашка стоит ровно по
    -- центру — значит, обе стороны берут место по большей. Не лезет в экран —
    -- подпись «Сложность» уходит, иконка остаётся.
    local max_inner = math.floor(hw) - EDGE * 2 - PAD * 2
    local title_w = measure(title)
    local plate_w = math.max(60, title_w + 28)
    local streak_w = streak and measure(streak) or 0
    local label_w = measure(diff_label) + GAP
    local function head_need(with_label)
        local side = math.max(streak_w, ICON_W + (with_label and label_w or 0))
        return plate_w + (side + GAP * 2) * 2
    end
    local show_label = head_need(true) <= math.max(max_inner, cw + 12)
    local inner = math.min(math.max(cw + 12, head_need(show_label)), math.max(max_inner, cw))

    local _, ctl_h = measure(controls, inner)
    local pw = inner + PAD * 2
    local x0 = math.floor(hw / 2 - pw / 2)
    local y0 = math.max(4, math.floor(hh * 0.03))
    local cx = math.floor(hw / 2)
    local left, right = x0 + PAD, x0 + pw - PAD

    local hy = y0 + PAD - 2                        -- шапка
    local sx = math.floor(cx - cw / 2)             -- экран
    local sy = hy + HEAD_H + GAP + 2
    local ty = sy + ch + 2 + GAP                   -- метки и время
    local my = ty + MARK_H + GAP                   -- сообщение
    local ly = my + LINE + GAP                     -- управление
    local ph = (ly + ctl_h + PAD) - y0

    stretched(SPR.panel, x0, y0, pw, ph)

    -- Шапка.
    local mid = hy + HEAD_H / 2
    stretched(SPR.plate, cx - plate_w / 2, mid - PLATE_H / 2, plate_w, PLATE_H)
    text_shadow(cx, mid - 7, title, C.gold, 1)
    if streak then text_shadow(left, mid - 7, streak, C.gold, 0) end
    sprite_centered(DIFF_ICON[v.diff], ICON_FRAME, right - ICON_W / 2, mid)
    if show_label then text_shadow(right - ICON_W - GAP, mid - 7, diff_label, C.steel, 2) end

    -- Экран мини-игры, утопленный в панель её же тонами.
    rect(sx - 2, sy - 2, cw + 4, ch + 4, C.rim)
    rect(sx - 1, sy - 1, cw + 2, ch + 2, C.ink)
    -- Ошибка в отрисовке мини-игры не должна оставить холст целью рисования:
    -- весь HUD игры лёг бы в него. finish — всегда, ошибка — в лог один раз.
    px.begin()
    local ok, err = pcall(v.game.draw)
    px.finish(sx, sy, k)
    if not ok and not draw_failed[v.game_id] then
        draw_failed[v.game_id] = true
        log.warning("LocksUnlocked: "..v.game_id.." draw failed: "..tostring(err))
    end

    -- Метки ошибок и полоса времени.
    for i = 1, cfg.MAX_MISTAKES do
        sprite(SPR.mark, i <= v.mistakes and MARK_ON or MARK_OFF, left + (i - 1) * MARK_W + 2, ty - 1)
    end
    local bx = left + cfg.MAX_MISTAKES * MARK_W + GAP
    local bw = right - bx
    local frac = math.max(0, math.min(1, v.timer / v.limit))
    local tcol = frac > 0.5 and C.gold or (frac > 0.25 and C.orange or C.red)
    rect(bx, ty + 3, bw, 5, C.ink)
    rect(bx + 1, ty + 4, bw - 2, 3, C.dim)
    rect(bx + 1, ty + 4, math.floor((bw - 2) * frac), 3, tcol)

    -- Сообщение и управление по центру.
    if v.msg then
        local key = "locksunlocked."..v.msg
        local s = v.msg_arg ~= nil and gm.translate(key, tostring(v.msg_arg)) or gm.translate(key)
        text(cx, my, s, MSG_COL[v.msg_kind] or C.light, 1)
    end
    text(cx, ly, controls, C.light, 1, inner)

    -- Рамка вспыхивает красным на ошибке — поверх канта экрана.
    if v.flash > 0 then
        gm.draw_set_alpha(math.min(1, v.flash / 0.3))
        gm.draw_rectangle_color(sx - 2, sy - 2, sx + cw + 1, sy + ch + 1, C.red, C.red, C.red, C.red, true)
        gm.draw_set_alpha(1)
    end

    -- Итог поверх экрана: галочка или крест, как у меток ошибок.
    if v.result then
        local s = gm.translate("locksunlocked.result."..v.result)
        local band_h = 30
        local band_y = sy + math.floor(ch / 2 - band_h / 2)
        rect(sx, band_y, cw, band_h, C.ink, 0.85)
        rect(sx, band_y, cw, 1, C.rim); rect(sx, band_y + band_h - 1, cw, 1, C.rim)
        local sw = measure(s)
        sprite_centered(SPR.mark, RESULT_MARK[v.result] or MARK_OFF, cx - sw / 2 - 6, band_y + band_h / 2)
        text_shadow(cx + 8, band_y + band_h / 2 - 7, s, RESULT_COL[v.result] or WHITE, 1)
    end
end)

LU.Panel = Panel
