-- Перепрошивка Робомандо (R) запускает мини-игру взлома вместо мгновенного
-- открытия. Льготы — только у неё: ошибки не
-- шумят и не поднимают цену, провал не забирает золото, замок на уровень
-- проще (core/host.lua, core/session.lua). Ею же, и только ею, взламываются
-- дроны и прочее платное, кроме святилищ (core/chests.lua, Chests.entry).

LU = LU or {}

local U = LU.Util

local Rewire = {}

-- Навык вызывает _survivor_robomando_hack_skill_impl(актор, навык, со
-- Скипетром) на машине игрока (scr_ror_init_survivor_robomando.gml:203-222).
-- Есть цель — уходит наша просьба, ванильное состояние взлома не
-- запускается, перезарядка уже потрачена. Цели нет — ванильный путь: звук
-- ошибки и короткий откат.
Hook.add_pre(gm.constants._survivor_robomando_hack_skill_impl, function(self, other, result, args)
    local actor = args[1] and args[1].value
    if not U.alive(actor) or not U.bool(actor.is_local) then return end
    local boosted = args[3] and U.bool(args[3].value)
    if LU.Session.rewire(actor, boosted) then return false end
end)

-- Ванильная Перепрошивка больше ничего не открывает сама: всё, что она умела
-- открывать, теперь идёт через мини-игру. Без этого она мгновенно вскрыла
-- бы сломанный замок или сундук, который взламывает другой игрок.
Hook.add_post(gm.constants._survivor_robomando_interactable_is_hackable, function(self, other, result, args)
    result.value = false
end)

LU.Rewire = Rewire
