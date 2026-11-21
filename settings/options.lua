-- Клавиша взлома в настройках мода. Подписи: ui.options.locksunlocked.* и
-- control.locksunlocked.pick (кнопка переназначения читает второй корень).

LU = LU or {}

-- F на клавиатуре и крестовина вверх на геймпаде: у ванили обе свободны
-- (__input_config_profiles_and_default_bindings.gml:8-68). default обязателен
-- числом (ModOptions.lua:353), иначе API падает при загрузке.
local KEY_F    = 70
local GP_PAD_U = 32781

local opts = ModOptions.new()
local kb = opts:add_keybind("pick", KEY_F, GP_PAD_U)

LU.Options = {
    verb = kb.verb,   -- глагол ввода вида <namespace>.<id>
}
