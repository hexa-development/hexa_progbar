-- ⚙️ hexa_progbar configuration - see README.md for the full API

Config = {}

-- ⏱ Default run length when the caller omits `duration`
Config.DefaultDuration = 5000

-- ⌛ Default icon, resolved by web/hexa-icons.js (central / Font Awesome / Material names)
Config.DefaultIcon = 'hourglass_top'

-- 🎨 Kept for old call sites only - the bar is monochrome and picks its own state colors
Config.Accent = 'cyan'

------------------------------------------------------------------
-- 📐 Placement and size (all values in vh)
------------------------------------------------------------------

-- ⬇️ Gap between the bottom of the screen and the bottom of the bar
Config.BottomOffset = 12.0

-- ↔️ Bar grows with the label between these two widths, then clips with …
Config.MinWidth = 34.0
Config.MaxWidth = 60.0

-- 🔢 Print the remaining seconds on the bar (per call: `showRemaining = true|false`)
Config.ShowRemaining = false

------------------------------------------------------------------
-- ✋ Cancelling
------------------------------------------------------------------

-- 🎯 Key that cancels a run started with `canCancel = true`
Config.CancelKey = 'X'

-- 🏷️ Text printed next to the key cap on the bar
Config.CancelLabel = 'ยกเลิก'

-- 🔑 Selectable cancel keys - hashes mirror hexa_core/shared/keybinds.lua, never use ESC
Config.CancelKeys = {
    BACKSPACE = { hash = 0x156F7119, label = 'BKSP'  },
    SPACEBAR  = { hash = 0xD9D0E1C0, label = 'SPACE' },
    TAB       = { hash = 0xB238FE0B, label = 'TAB'   },
    X         = { hash = 0x8CC9CD42, label = 'X'     },
    G         = { hash = 0x760A9C6F, label = 'G'     },
    F         = { hash = 0xB2F377E8, label = 'F'     },
}

-- 🛟 Fallback when Config.CancelKey names a key that is not in the table above
Config.CancelControl = 0xD9D0E1C0

-- 💀 Drop the run when the ped dies (per call: `useWhileDead = true`)
Config.CancelOnDeath = true

------------------------------------------------------------------
-- 🎒 Props
------------------------------------------------------------------

-- 🔒 Max props one `prop = { ... }` set may spawn, extras are trimmed
Config.MaxProps = 2

------------------------------------------------------------------
-- 🧪 Misc
------------------------------------------------------------------

-- 🧰 Register the /hexaprog test command, turn off on live servers
Config.TestCommand = true
