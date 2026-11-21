-- Консольные команды для проверки в игре.

LU = LU or {}

local U = LU.Util

local Debug = { forced_game = nil, forced_diff = nil }

Console.new{
    "lu_chest",
    { "LocksUnlocked: state of the chest nearest to the player." },
    function(args)
        local p = U.local_players()[1]
        if not p then Console.print("no local player") return end

        local inst = Instance.nearest(p.x, p.y, gm.constants.pInteractable)
        if not U.alive(inst) then Console.print("no interactable nearby") return end

        local entry = LU.Chests.entry(inst)
        if not entry then
            Console.print("not a pickable target: "..tostring(gm.object_get_name(inst.object_index)))
            return
        end

        local d = LU.Chests.data(inst)
        local picker = U.by_id(d.picker_id)
        Console.print(string.format(
            "%s diff=%d game=%s mistakes=%d broken=%s cost=%d active=%s picker=%s rewire=%d can_pick=%s rewire_only=%s",
            entry.obj, entry.diff, LU.Games.IDS[LU.Chests.game_index(inst)],
            d.mistakes or 0, tostring(d.broken or false), U.num(inst.cost, 0),
            tostring(inst.active), picker and tostring(picker.user_name or picker.id) or "-",
            d.rewire or 0, tostring(LU.Chests.can_pick(inst, true)), tostring(entry.extra == true)))
    end
}

Console.new{
    "lu_game [id]",
    {
        "LocksUnlocked: force a minigame for picks on this machine.",
        { "[id]", "string", "a minigame id, list, or off" },
    },
    function(args)
        local id = args[1]
        if id == nil or id == "off" then
            Debug.forced_game = nil
            Console.print("minigame: by chest")
            return
        end
        if id == "list" then
            for _, known in ipairs(LU.Games.IDS) do
                local name = gm.translate("locksunlocked.game."..known..".name")
                Console.print(known.." - "..tostring(name)..(LU.Games.has(known) and "" or " (not loaded)"))
            end
            return
        end
        for _, known in ipairs(LU.Games.IDS) do
            if known == id then
                Debug.forced_game = id
                Console.print("minigame: "..id)
                return
            end
        end
        Console.print("unknown minigame: "..tostring(id))
    end
}

-- Легендарный сундук попадается редко, а проверить мини-игры нужно на всех
-- четырёх уровнях. Меняет только мини-игру и лимит времени у взломщика;
-- награду, цену и шум хост по-прежнему считает по сундуку.
Console.new{
    "lu_diff [level]",
    {
        "LocksUnlocked: force the lock level (1-4) of minigames on this machine.",
        { "[level]", "string", "1, 2, 3, 4, or off" },
    },
    function(args)
        local n = tonumber(args[1])
        if n and n >= 1 and n <= 4 and n == math.floor(n) then
            Debug.forced_diff = n
            Console.print("lock level: "..n)
        else
            Debug.forced_diff = nil
            Console.print("lock level: by chest")
        end
    end
}

LU.Debug = Debug
