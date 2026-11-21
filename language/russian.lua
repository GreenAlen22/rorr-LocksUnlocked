-- LocksUnlocked, русский. Ключи — как в english.lua, корни описаны там.

return {
    control = {
        locksunlocked = {
            pick = "Взломать замок",
        },
    },

    ui = {
        options = {
            locksunlocked = {
                header = "LOCKS UNLOCKED",
            },
        },
    },

    locksunlocked = {
        prompt = {
            pick   = "Взломать",
            broken = "(замок сломан)",
        },

        panel = {
            diff   = "Сложность",
            streak = "Серия x%s",
            cancel = "%s отмена",
        },

        result = {
            clean  = "Вскрыто чисто!",
            ok     = "Вскрыто",
            fail   = "Замок сломан",
            cancel = "Отменено",
        },

        game = {
            pins = {
                name     = "Штифты",
                controls = "%s %s выбрать штифт, %s поставить на линию",
            },
            ring = {
                name     = "Кольцо",
                controls = "%s, когда метка в секторе",
            },
            lockpick = {
                name     = "Отмычка",
                controls = "%s %s двигать отмычку, держи %s, чтобы провернуть замок",
            },
            pressure = {
                name     = "Давление",
                controls = "Держи %s, отпусти в зелёной зоне",
            },
            cipher = {
                name     = "Шифр",
                controls = "Запомни вспышки и повтори их: %s %s %s %s",
            },
            circuit = {
                name     = "Схема",
                controls = "%s %s %s %s выбрать плитку, %s повернуть. Проведи ток к золотому выходу",
            },
            probe = {
                name     = "Зонд",
                controls = "%s %s %s %s веди зонд к золотому ядру",
            },
            frequency = {
                name     = "Частота",
                controls = "%s %s частота, %s %s размах, %s когда волны совпали",
            },
            code = {
                name     = "Код",
                controls = "%s %s ячейка, %s %s символ, %s проверить код",
            },
        },

        why = {
            time       = "Время вышло",
            pin        = "Штифт не на линии",
            ring       = "Мимо сектора",
            overheat   = "Перегрев",
            zone       = "Мимо зоны",
            pick_broke = "Отмычка сломалась",
            arrow      = "Не та стрелка",
            spark      = "Фитиль догорел",
            beam       = "Зонд задел луч",
            wave       = "Волны не совпали",
            code       = "Код не подошёл",
        },

        say = {
            pin_set     = "Штифт встал",
            ring_hit    = "Есть",
            pressure_ok = "Давление сброшено",
            layer       = "Слой поддался",
            watch       = "Запоминай",
            your_turn   = "Повторяй",
            round       = "Раунд пройден",
            freq_ok     = "Частота поймана",
            code_free   = "Не тот код. Бесплатных попыток: %s",
            code_last   = "Не тот код. Бесплатных попыток нет",
        },
    },
}
