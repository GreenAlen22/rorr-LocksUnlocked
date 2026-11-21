-- Подсказка «[клавиша] Взломать» под ванильной «Открыть сундук».
--
-- Тем же путём, что ваниль: interactable_draw_prompt кладёт строку в очередь
-- oHUD на этот кадр, а oHUD рисует её в Draw End со значком клавиши из
-- control_string (interactable_draw_prompt.gml:1-15, :136). Значок берётся по
-- глаголу, а наш глагол API заводит в профиле ввода, так что игрок видит
-- свою привязку. Пока сундук взламывают, interactable_check_cost отвечает
-- «нет» (core/host.lua), и ваниль сама прячет обе подсказки.

LU = LU or {}

local U = LU.Util

local Prompt = {}

-- Ниже ванильной подсказки: та стоит на bbox_bottom - 32 - 24 и высотой ~16.
local OFF_Y = 20

-- Ваниль прячет «Открыть сундук», пока золота не хватает
-- (interactable_draw_prompt.gml:3), и «Взломать» оставалась одна на его
-- месте: выглядело так, будто взлом заменил покупку. Без денег строку
-- покупки рисуем сами, цена красным — видно оба пути. Нажатие на неё
-- обрабатывает ваниль, как обычно: звук ошибки.
local function draw_buy_short(chest, p)
    local cost = math.floor(U.num(chest.cost, 0))
    -- Сырой gm.* обёртку не разворачивает: без .value игра получает
    -- undefined и падает каждый кадр.
    if U.num(gm.player_get_gold(p.value), 0) >= cost then return end
    local label = tostring(chest.text).." <r>("..gm.translate("cost.gold", tostring(cost))..")"
    chest:interactable_draw_prompt(0, 0, "interact", label, 0, 0, p)
end

Callback.add(Callback.ON_STEP, function()
    if not LU.Options or LU.Session.active() then return end
    for _, p in ipairs(U.local_players()) do
        if not U.bool(p.dead) then
            local chest = LU.Chests.near(p)
            if chest and LU.Chests.can_pick(chest) then
                draw_buy_short(chest, p)
                chest:interactable_draw_prompt(0, OFF_Y, LU.Options.verb,
                    gm.translate("locksunlocked.prompt.pick"), 0, 0, p)
            end
        end
    end
end)

LU.Prompt = Prompt
