-- LocksUnlocked, English.
--
-- Three roots:
--   control.locksunlocked.*     the rebind button reads this one;
--   ui.options.locksunlocked.*  the settings page (the `ui.options.` prefix is the game's);
--   locksunlocked.*             everything the player reads in a run.
-- %s in a string is filled in order by the code: a key icon or a number.

return {
    control = {
        locksunlocked = {
            pick = "Pick lock",
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
            pick   = "Pick lock",
            broken = "(lock broken)",
        },

        panel = {
            diff   = "Difficulty",
            streak = "Streak x%s",
            cancel = "%s cancel",
        },

        result = {
            clean  = "Clean pick!",
            ok     = "Unlocked",
            fail   = "Lock broken",
            cancel = "Cancelled",
        },

        game = {
            pins = {
                name     = "Pins",
                controls = "%s %s pick a pin, %s set it on the line",
            },
            ring = {
                name     = "Ring",
                controls = "%s when the marker is inside a sector",
            },
            lockpick = {
                name     = "Lockpick",
                controls = "%s %s move the pick, hold %s to turn the lock",
            },
            pressure = {
                name     = "Pressure",
                controls = "Hold %s, let go in the green zone",
            },
            cipher = {
                name     = "Cipher",
                controls = "Watch the flashes, then repeat them: %s %s %s %s",
            },
            circuit = {
                name     = "Circuit",
                controls = "%s %s %s %s pick a tile, %s rotate it. Lead the current to the gold exit",
            },
            probe = {
                name     = "Probe",
                controls = "%s %s %s %s steer the probe to the gold core",
            },
            frequency = {
                name     = "Frequency",
                controls = "%s %s frequency, %s %s height, %s when the waves match",
            },
            code = {
                name     = "Code",
                controls = "%s %s cell, %s %s symbol, %s check the code",
            },
        },

        why = {
            time       = "Out of time",
            pin        = "The pin was off the line",
            ring       = "Missed the sector",
            overheat   = "Overheated",
            zone       = "Missed the zone",
            pick_broke = "The pick snapped",
            arrow      = "Wrong arrow",
            spark      = "The fuse burned out",
            beam       = "The probe touched a beam",
            wave       = "The waves don't match",
            code       = "Wrong code",
        },

        say = {
            pin_set     = "Pin set",
            ring_hit    = "Got it",
            pressure_ok = "Pressure released",
            layer       = "Layer turned",
            watch       = "Watch",
            your_turn   = "Your turn",
            round       = "Round cleared",
            freq_ok     = "Frequency locked",
            code_free   = "Wrong code. Free tries left: %s",
            code_last   = "Wrong code. No free tries left",
        },
    },
}
