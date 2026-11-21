-- Защита от вылета в клавишах модов ReturnsAPI 0.1.61: «index out of bounds
-- request 29 maximum size is 29» в __input_player_tick_sources у игрока на
-- геймпаде в начале забега. Та же защита стоит в GreenAlen22-DeerQOL.
--
-- ReturnsAPI подменяет __profile_choice_updated библиотеки ввода и, когда
-- опрашиваемых глаголов ровно 29 (список меню), дописывает к ним клавиши
-- модов. В забеге это 22 глагола игры плюс клавиши модов: при ровно семи
-- клавишах их тоже 29, и клавиши дописываются второй раз. Состояния глаголов
-- у игроков сделаны на 29, список стал длиннее, и опрос геймпада читает за
-- край. Семь — это шесть клавиш DeerQOL и одна наша; любой другой набор на
-- семь клавиш делает то же, поэтому защищается каждый мод с клавишей. Две
-- одинаковые защиты не мешают: вторая просто не находит повторов.
--
-- После каждого __profile_choice_updated повторы глаголов вынимаются из
-- списка и из массива привязок каждого игрока на тех же местах, а состояния
-- глаголов собираются заново по списку, как их делает библиотека ввода.

LU = LU or {}

-- .auto() подменяет type на Util.type, исходный — lua_type
-- (ReturnsAPI 1_Util/Util.lua:116-119).
local type = lua_type or type

local VerbFix = { repaired = 0 }

-- Под каким именем метод виден движку, заранее неизвестно: DeerQOL хукает
-- длинное имя метода конструктора, а в списке имён игры есть только короткое.
-- Хук ставится на каждое найденное: починка повторяема, двойной вызов ей не вредит.
local NAMES = {
    "__profile_choice_updated@anon@3823@__input_class_player@__input_class_player",
    "__profile_choice_updated",
}
local PLAYERS = 4   -- __input_initialize.gml:69

local function players()
    local out = {}
    local list = gm.variable_global_get("__input_players")
    for p = 0, PLAYERS - 1 do
        local pl = gm.array_get(list, p)
        if pl ~= nil then out[#out + 1] = pl end
    end
    local dp = gm.variable_global_get("__input_default_player")
    if dp ~= nil then out[#out + 1] = dp end
    return out
end

local function repair()
    local arr = gm.variable_global_get("__input_ticking_verbs_array")
    if arr == nil or type(arr) == "boolean" then return end
    local n = tonumber(gm.array_length(arr)) or 0
    local seen, dup = {}, {}
    for i = 0, n - 1 do
        local v = gm.array_get(arr, i)
        if seen[v] then dup[#dup + 1] = i else seen[v] = true end
    end
    if #dup == 0 then return end

    local pls = players()
    for k = #dup, 1, -1 do
        local i = dup[k]
        gm.array_delete(arr, i, 1)
        for _, pl in ipairs(pls) do
            local b = gm.variable_struct_get(pl, "__binding_current_array")
            if b ~= nil and (tonumber(gm.array_length(b)) or 0) > i then gm.array_delete(b, i, 1) end
        end
    end

    local m = tonumber(gm.array_length(arr)) or 0
    for _, pl in ipairs(pls) do
        local dict = gm.variable_struct_get(pl, "__verb_state_dict")
        local states = gm.array_create(m, 0)
        if dict ~= nil then
            for j = 0, m - 1 do
                local st = gm.variable_struct_get(dict, gm.array_get(arr, j))
                -- nil сдвинул бы аргументы вызова: такое место остаётся как создано.
                if st ~= nil then gm.array_set(states, j, st) end
            end
        end
        gm.variable_struct_set(pl, "__verb_state_array", states)
    end

    VerbFix.repaired = VerbFix.repaired + 1
    if VerbFix.repaired == 1 then
        log.info("LocksUnlocked: verb_fix -> took "..#dup.." repeated mod keys out of the input list ("..n.." -> "..m..")")
    end
end

local function guarded()
    local ok, err = pcall(repair)
    if not ok and not VerbFix.warned then
        VerbFix.warned = true
        log.warning("LocksUnlocked: verb_fix repair failed -> "..tostring(err))
    end
end

local hooked = {}
for _, name in ipairs(NAMES) do
    local id = gm.constants[name]
    if id then
        local ok, err = pcall(Hook.add_post, id, guarded)
        if ok then hooked[#hooked + 1] = name
        else log.warning("LocksUnlocked: verb_fix hook on "..name.." not set -> "..tostring(err)) end
    end
end
if #hooked == 0 then
    log.warning("LocksUnlocked: verb_fix -> no __profile_choice_updated found; the 7-mod-keys crash is not guarded")
else
    log.info("LocksUnlocked: verb_fix -> guarding "..table.concat(hooked, ", "))
end

LU.VerbFix = VerbFix
