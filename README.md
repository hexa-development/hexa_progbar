<div align="center">

<a href="https://github.com/hexa-development">
  <img src="https://raw.githubusercontent.com/hexa-development/.github/main/assets/banner.png" alt="Hexa Development" width="880">
</a>

# HEXA PROGBAR

### Screen-fixed progress bar for RedM

A standalone progress bar for the Hexa Framework stack — a drop-in replacement for `ox_lib`'s `progressBar`, themed to match [`hexa_inventory`](https://github.com/hexa-development/hexa_inventory).

<br>

[![Documentation](https://img.shields.io/badge/Documentation-Hexa_Docs-B45309?style=for-the-badge)](https://hexa-development.github.io/hexa-docs/)
[![ภาษาไทย](https://img.shields.io/badge/Docs-ภาษาไทย-D97706?style=for-the-badge)](https://hexa-development.github.io/hexa-docs/th/)
[![RedM](https://img.shields.io/badge/Platform-RedM-8B0000?style=for-the-badge)](https://redm.net/)
[![Lua](https://img.shields.io/badge/Lua-5.4-2C2D72?style=for-the-badge&logo=lua&logoColor=white)](https://www.lua.org/)
[![Standalone](https://img.shields.io/badge/Dependencies-None-181717?style=for-the-badge)](#requirements)

<br>

**Screen-Fixed Bar · Cancel Key · Animations · Props · ox_lib Drop-in**

<br>

**[English](#english) · [ภาษาไทย](#thai)**

</div>

---

<a id="english"></a>

# English

## About

**hexa_progbar** is the progress system for the `hexa_*` stack.

It ships **one presentation only: a bar fixed to the bottom-centre of the screen**, showing **icon + title + description + progress** as a static HUD element. Nothing is anchored to the world.

> **World-anchored bars above the player's head have been removed entirely**, as has the centre-screen panel from the original `rb_progbar`.
> `style` / `position` / `entity` / `coords` / `offsetZ` are still accepted from older call sites and are **silently ignored** — they do not error.

The API is a **drop-in for `lib.progressBar` (ox_lib)** — same option names, same blocking behaviour, same `true` / `false` return.

```lua
-- before
local ok = lib.progressBar({ duration = 5000, label = '...' })
-- after
local ok = exports['hexa_progbar']:Progress({ duration = 5000, label = '...' })
```

---

## Requirements

| Requirement | Description |
| :--- | :--- |
| **FXServer / RedM** | Server runtime |
| **Lua 5.4** | Enabled in `fxmanifest.lua` |

`hexa_progbar` is **standalone** — it does not depend on `ox_lib` and it does not depend on [`hexa_core`](https://github.com/hexa-development/hexa_core). It runs on any RedM server, inside a Hexa stack or outside one.

---

## Installation

1. Place the folder at `resources/hexa_progbar`
2. Add `ensure hexa_progbar` to `modifiers/resources.cfg` — **before** any resource that calls it (e.g. [`hexa_inventory`](https://github.com/hexa-development/hexa_inventory))
3. Add `'hexa_progbar'` to the `dependencies` of the calling resource, if you want the order enforced

---

## Client exports

### `Progress(data)` → `boolean`

**Blocks until finished.** Returns `true` on completion, `false` when cancelled or interrupted, and `nil` when it could not start at all (e.g. the ped is dead) — matching ox_lib in every case.

```lua
local ok = exports['hexa_progbar']:Progress({
    duration  = 5000,
    label     = 'Filling canteen...',
    icon      = 'water_drop',
    canCancel = true,
    disable   = { move = true, combat = true },
})
if ok then
    -- succeeded
end
```

| Key | Value | Meaning |
|---|---|---|
| `duration` | ms | Run length (default `Config.DefaultDuration`) |
| `label` | string | Title line |
| `description` | string | Secondary line under the title — one step smaller and dimmer (omit it and the line is not drawn) |
| `icon` | string | Material Symbols ligature, or a legacy Font Awesome name (converted automatically) |
| `showRemaining` | boolean | Print the remaining seconds on the bar (default `Config.ShowRemaining` = `false`) |
| `accent` | string | Colour family: `cyan` `gold` `crimson` `mint` `violet` `silver` (default `Config.Accent` = `cyan`) |
| `canCancel` | boolean | Draw a **key cap** at the end of the bar and make that key actually cancel the run (see [Cancel key](#cancel-key)) |
| `cancelKey` | string / table | Override the cancel key for this run — a name from `Config.CancelKeys` or `{ hash = 0x..., label = 'K' }` (default `Config.CancelKey` = `X`) |
| `cancelLabel` | string | Text printed next to the key cap (default `Config.CancelLabel`) |
| `silent` | boolean | Skip the on-screen bar and keep only the animation / prop / control lock / cancel key — for callers that already draw their own progress. The return value is unchanged in every case. |
| `disable` | table | `{ move, sprint, car, combat, mouse }` |
| `anim` | table | `{ dict, clip, flag, blendIn, blendOut, ... }` or `{ scenario = '...' }` |
| `prop` | table | `{ model, bone, pos, rot }`, or an array for several props |
| guards | boolean | `useWhileDead`, `allowRagdoll`, `allowCuffed`, `allowFalling`, `allowSwimming` |
| ~~`style`~~ / ~~`position`~~ | — | Accepted but inert (compatibility with old call sites) |
| ~~`entity`~~ / ~~`coords`~~ / ~~`offsetZ`~~ | — | Accepted but inert — the bar is no longer world-anchored |

### `Cancel()` / `IsActive()`

```lua
exports['hexa_progbar']:Cancel()      -- safe even when nothing is running (ox_lib errors here)
if exports['hexa_progbar']:IsActive() then ... end
```

**Aliases for migrating off ox_lib:** `progressBar` · `progressCircle` · `cancelProgress` · `progressActive`

---

<a id="cancel-key"></a>

## Cancel key

**The cancel key belongs to `hexa_progbar` itself.** It is not the game's cancel prompt and it does not route through another resource's prompt system. On a run started with `canCancel = true`, the bar does all three of these in one place:

1. **Draws the key cap at the end of the bar** — `[X] ยกเลิก` — so the player can see what to press without being told beforehand
2. **Holds that key away from the game for the whole run** (`DisableControlAction` every frame)
3. **Reads the key itself**, on both the normal and the `Disabled` branch — once a control is disabled you must also read the disabled branch, or the key goes completely silent

Step 2 is the important one: the original cancel control (`INPUT_FRONTEND_CANCEL`) is **the same key the game uses for itself**, so every cancel press also made the character or a menu react. Holding it means the key belongs to the bar alone while the bar is running.

| Key | Default | Meaning |
|---|---|---|
| `Config.CancelKey` | `'X'` | Cancel key — a name from `Config.CancelKeys` or `{ hash = 0x..., label = 'K' }` |
| `Config.CancelLabel` | `'ยกเลิก'` | Text next to the key cap |
| `Config.CancelKeys` | table | Keys that may be used to cancel (`X` `BACKSPACE` `SPACEBAR` `TAB` `G` `F`) — `label` is what the player sees |
| `Config.CancelControl` | `0xD9D0E1C0` | Fallback when `Config.CancelKey` names a key that is not in the table |

The hashes in that table match `hexa_core/shared/keybinds.lua`, but are **deliberately copied rather than shared** — this resource is standalone and does not include `hexa_core` files, so it cannot borrow the central table at runtime. Whenever you add a key, copy the hash from that file.

> ⚠ **Never set `ESC`** as the cancel key — the game opens the pause menu on that key first, and `DisableControlAction` cannot take it back. The player gets the menu instead of a cancel.

The key cap travels with the NUI `start` message as `cancel = { key, label }` — **the NUI side has no key-name table of its own**, so the cap on screen and the key Lua actually reads are always the same key.

A run with `silent = true` can still be cancelled by that key (there is just no bar to see; the caller draws its own) — `silent` only removes the NUI path.

---

## Appearance

The bar uses the **same theme as [`hexa_inventory`](https://github.com/hexa-development/hexa_inventory)** — the tokens in `web/style.css` copy their names and values straight from `hexa_inventory/html/main.css` (`--ink-*` / `--line-*` / `--text*` / `--accent*` / `--radius`). Read the two files side by side and they are visibly one system; if inventory ever shifts its colours, the block can be copied across wholesale.

```
┌────────────────────────────────────────────────┐  ← hairline + four corner brackets
│ ┌────┐  IN PROGRESS               [BKSP] Cancel│
│ │ ⛏  │  ──────────────────────────────────────  │
│ └────┘  ▎Digging                        12.4s  │
│          3 / 10 units                           │
├════════════════════════════════════════════════┤  ← track, flush with the panel's bottom edge
```

- **Gradient ink panel** with a thin hairline border, a second inner frame, and **corner brackets** on all four corners (inventory's main motif); corners are near-square at `0.3vh`
- **Icon box** — a square black field, following the `.item-box-icon` idiom
- **Status pill** — small, bold, wide letter-spacing, following the `.item-box-type` idiom: in progress / done / cancelled
- **Gradient vertical tick** before the title, following the `.inventory-label p::before` idiom, tinted with the status colour
- **The track is a thin full-width rule flush with the bottom edge of the panel**, following the `.item-slot-durability` idiom — not a capsule floating inside it
- **State changes a single `--c` variable.** The icon, the tick, the timer, the status pill and the track all change together; no colour is written directly anywhere
- **State is not signalled by colour alone** — there is text and an icon that swaps to a check / cross (a green bar and a red bar are the same dark grey to a red-green colourblind player)

Fonts ship inside the resource (RedM's CEF cannot load Google Fonts):

| File | Used for |
|---|---|
| `web/assets/RDRLino-Regular.ttf` | Titles + the timer (the same file as `hexa_inventory`) |
| `web/fonts/kanit-*.woff2` | Body text, and **the fallback for RDR Lino** |

> RDR Lino has no Thai glyphs, so Thai titles fall through to Kanit per character (inventory accepts the same trade-off for non-Latin locales). If you dislike the mixed look on bilingual titles, set `--font-display` in `web/style.css` to the same value as `--font-ui` — one line, and the whole page becomes Kanit.

`web/style.css` **stands on its own** and no longer depends on `hexa-kit.css` — the kit is a different design dialect (no borders, rounder corners, capsule tracks). Layering them meant overriding nearly every line while still shipping 96 KB of unused CSS. The full reasoning is at the top of `web/style.css`.

---

## Placement

The bar is **always horizontally centred** — there is no setting for that. Only the vertical position and the width are configurable, all in `vh`.

| Key | Default | Meaning |
|---|---|---|
| `Config.BottomOffset` | `12.0` | Gap between the bottom of the screen and the bottom of the bar |
| `Config.MinWidth` | `34.0` | Minimum width |
| `Config.MaxWidth` | `60.0` | Maximum width — labels longer than this are clipped with `…` |

These are sent to the NUI with every run's `start` message, not at resource start — so there is no worry about the NUI not being ready at boot, and editing the config plus `restart hexa_progbar` takes effect immediately.

---

## Server exports

Tell a client to start a progress run (fire-and-forget — the `true` / `false` result exists only on the client).

```lua
exports['hexa_progbar']:Progress(source, data)
exports['hexa_progbar']:Cancel(source)
exports['hexa_progbar']:ProgressAll(data)
```

If a server-side flow needs the result, have the client call the export itself and fire an event back.

---

## Events

```lua
TriggerEvent('hexa_progbar:cancel')            -- client
TriggerClientEvent('hexa_progbar:start', src, data)
```

---

## Testing in game

```
/hexaprog           -- a normal 6 second bar (remaining time shown + movement locked)
/hexaprog long      -- a label longer than the max width, to check the … clipping
/hexaprog cancel    -- cancel the running bar
```

Turn it off on a live server with `Config.TestCommand = false`.

---

## Technical notes

- **One at a time** — nested calls **queue** behind the running one (same semantics as ox_lib)
- **Lua owns the real clock**, not the NUI — the return value is trustworthy even if the NUI is slow or fails to repaint
- **The bar animates with CSS** (`transform: scaleX`, composited) and since the move to a screen-fixed bar there are **no per-frame NUI messages left at all** — a whole run is one `start` and one `finish` message (the old version projected world coordinates to screen space and sent x/y every frame)
- Sets `LocalPlayer.state.invBusy` while running (same as ox_lib)
- `prop` is created through a state bag → **other players see it too**, not just the player performing the action
- ox_lib on RedM never binds a cancel key at all (its `RegisterKeyMapping` is FiveM-only) — this resource owns its cancel key end to end (cap on the bar + control held from the game + read directly), so `canCancel` actually works. See [Cancel key](#cancel-key)

---

## Calling it from another resource

`hexa_progbar` is standalone, so callers should treat it as optional and guard the call:

```lua
local function progress(data)
    if GetResourceState('hexa_progbar') ~= 'started' then
        return true -- or your own fallback
    end
    return exports['hexa_progbar']:Progress(data)
end
```

That keeps a resource runnable on a server that has not installed the bar, while giving the full presentation on one that has.

---

<a id="thai"></a>

# ภาษาไทย

## เกี่ยวกับ

**hexa_progbar** คือระบบ progress ของสแตก `hexa_*`

เหลือ **รูปแบบเดียว: แถบตรึงกลางจอด้านล่าง** แสดง **icon + title + description + progress** เป็น HUD ตายตัว ไม่เกาะอะไรในโลก

> **แถบลอยเหนือหัว (world-anchored) ถูกตัดออกทั้งหมดแล้ว** เช่นเดียวกับแผงกลางจอของ `rb_progbar` ต้นทาง
> ค่า `style` / `position` / `entity` / `coords` / `offsetZ` ที่ยังส่งมาจาก call site เก่าจะถูก**ละเว้นเงียบ ๆ** ไม่ error

API เป็น **drop-in ของ `lib.progressBar` (ox_lib)** — ชื่อ option เหมือนกัน, บล็อกเหมือนกัน, คืน `true`/`false` เหมือนกัน

```lua
-- เดิม
local ok = lib.progressBar({ duration = 5000, label = '...' })
-- ใหม่
local ok = exports['hexa_progbar']:Progress({ duration = 5000, label = '...' })
```

---

## สิ่งที่ต้องมี

| สิ่งที่ต้องมี | คำอธิบาย |
| :--- | :--- |
| **FXServer / RedM** | ตัวรันเซิร์ฟเวอร์ |
| **Lua 5.4** | เปิดใช้ใน `fxmanifest.lua` |

`hexa_progbar` เป็น **standalone** — ไม่พึ่ง `ox_lib` และไม่พึ่ง [`hexa_core`](https://github.com/hexa-development/hexa_core) ใช้กับเซิร์ฟ RedM ตัวไหนก็ได้ จะอยู่ในสแตก Hexa หรือไม่ก็ตาม

---

## ติดตั้ง

1. วางโฟลเดอร์ที่ `resources/hexa_progbar`
2. `ensure hexa_progbar` ใน `modifiers/resources.cfg` — วางไว้**ก่อน** resource ที่เรียกใช้ (เช่น [`hexa_inventory`](https://github.com/hexa-development/hexa_inventory))
3. เพิ่ม `'hexa_progbar'` ใน `dependencies` ของ resource ที่เรียก (ถ้าต้องการบังคับลำดับ)

---

## Client exports

### `Progress(data)` → `boolean`

**บล็อกจนกว่าจะจบ** คืน `true` เมื่อทำครบเวลา, `false` เมื่อถูกยกเลิก/ถูกขัดจังหวะ, `nil` เมื่อเริ่มไม่ได้เลย (เช่นตายอยู่) — ตรงกับ ox_lib ทุกกรณี

```lua
local ok = exports['hexa_progbar']:Progress({
    duration  = 5000,
    label     = 'กำลังเติมน้ำ...',
    icon      = 'water_drop',
    canCancel = true,
    disable   = { move = true, combat = true },
})
if ok then
    -- ทำสำเร็จ
end
```

| key | ค่า | ความหมาย |
|---|---|---|
| `duration` | ms | ความยาว (default `Config.DefaultDuration`) |
| `label` | string | บรรทัดหัวเรื่อง |
| `description` | string | บรรทัดรองใต้หัวเรื่อง — เล็กกว่าและจางกว่าหนึ่งขั้น (ไม่ส่ง = ไม่มีบรรทัดนี้) |
| `icon` | string | Material Symbols ligature หรือชื่อ Font Awesome เดิม (แปลงให้อัตโนมัติ) |
| `showRemaining` | boolean | โชว์วินาทีที่เหลือบนแถบ (default `Config.ShowRemaining` = `false`) |
| `accent` | string | ตระกูลสีของแถบ: `cyan` `gold` `crimson` `mint` `violet` `silver` (default `Config.Accent` = `cyan`) |
| `canCancel` | boolean | ขึ้น**ป้ายปุ่มยกเลิก**ท้ายแถบ และกดปุ่มนั้นยกเลิกได้จริง (ดู [ปุ่มยกเลิก](#cancel-key-th)) |
| `cancelKey` | string / table | เปลี่ยนปุ่มยกเลิกเฉพาะรอบนี้ — ชื่อใน `Config.CancelKeys` หรือ `{ hash = 0x..., label = 'K' }` (default `Config.CancelKey` = `X`) |
| `cancelLabel` | string | ข้อความข้างป้ายปุ่ม (default `Config.CancelLabel` = `ยกเลิก`) |
| `silent` | boolean | ไม่ขึ้นแถบกลางจอ เอาแค่ท่าทาง/prop/ล็อกปุ่ม/ปุ่มยกเลิก — สำหรับผู้เรียกที่มีที่แสดงความคืบหน้าของตัวเองอยู่แล้ว ค่าที่คืนเหมือนเดิมทุกกรณี |
| `disable` | table | `{ move, sprint, car, combat, mouse }` |
| `anim` | table | `{ dict, clip, flag, blendIn, blendOut, ... }` หรือ `{ scenario = '...' }` |
| `prop` | table | `{ model, bone, pos, rot }` หรือหลายชิ้นเป็น array |
| guards | boolean | `useWhileDead`, `allowRagdoll`, `allowCuffed`, `allowFalling`, `allowSwimming` |
| ~~`style`~~ / ~~`position`~~ | — | รับได้แต่ไม่มีผล (compat กับ call site เก่า) |
| ~~`entity`~~ / ~~`coords`~~ / ~~`offsetZ`~~ | — | รับได้แต่ไม่มีผล — แถบไม่เกาะโลกแล้ว |

### `Cancel()` / `IsActive()`

```lua
exports['hexa_progbar']:Cancel()      -- ปลอดภัยแม้ไม่มีอะไรทำงานอยู่ (ต่างจาก ox_lib ที่ error)
if exports['hexa_progbar']:IsActive() then ... end
```

**Alias สำหรับย้ายจาก ox_lib:** `progressBar` · `progressCircle` · `cancelProgress` · `progressActive`

---

<a id="cancel-key-th"></a>

## ปุ่มยกเลิก

**ปุ่มยกเลิกเป็นของ `hexa_progbar` เอง** ไม่ใช่ปุ่มยกเลิกของเกม และไม่ผ่าน prompt ของ resource อื่น
รอบที่ส่ง `canCancel = true` มา แถบทำครบสามอย่างเองในที่เดียว:

1. **พิมพ์ป้ายปุ่มไว้ท้ายแถบ** — `[X] ยกเลิก` ผู้เล่นจึงเห็นว่ากดอะไรได้ ไม่ต้องรู้มาก่อน
2. **ยึดปุ่มนั้นคืนจากเกมตลอดรอบ** (`DisableControlAction` ทุกเฟรม)
3. **อ่านปุ่มเอง** ทั้งสาขาปกติและสาขา `Disabled` — ยึดแล้วต้องอ่านสาขาล่างด้วย ไม่งั้นปุ่มเงียบสนิท

ข้อ 2 คือหัวใจ: ปุ่มยกเลิกตัวเดิม (`INPUT_FRONTEND_CANCEL`) เป็น**ปุ่มเดียวกับที่เกมใช้เอง**
กดยกเลิกทีหนึ่งตัวละคร/เมนูจะทำตามปุ่มนั้นไปด้วยทุกครั้ง พอยึดคืนมาแล้วปุ่มนั้นเป็นของแถบล้วน ๆ ระหว่างที่แถบวิ่ง

| key | default | ความหมาย |
|---|---|---|
| `Config.CancelKey` | `'X'` | ปุ่มยกเลิก — ชื่อใน `Config.CancelKeys` หรือ `{ hash = 0x..., label = 'K' }` |
| `Config.CancelLabel` | `'ยกเลิก'` | ข้อความข้างป้ายปุ่ม |
| `Config.CancelKeys` | ตาราง | ปุ่มที่ตั้งเป็นปุ่มยกเลิกได้ (`X` `BACKSPACE` `SPACEBAR` `TAB` `G` `F`) — `label` คือสิ่งที่ผู้เล่นเห็น |
| `Config.CancelControl` | `0xD9D0E1C0` | ทางถอยเมื่อ `Config.CancelKey` ชี้ไปที่ชื่อที่ไม่มีในตาราง |

ฮาชในตารางนั้นตรงกับ `hexa_core/shared/keybinds.lua` แต่ **คัดมาเฉพาะเท่าที่ต้องใช้โดยตั้งใจ** —
resource นี้เป็น standalone ไม่ include ไฟล์ของ `hexa_core` จึงยืมตารางกลางตอนรันไม่ได้
เพิ่มปุ่มในตารางเมื่อไหร่ ให้ลอกฮาชมาจากไฟล์นั้นเสมอ

> ⚠ **อย่าตั้ง `ESC`** เป็นปุ่มยกเลิก — เกมเปิดเมนูหยุดชั่วคราวด้วยปุ่มนั้นก่อนเสมอ และ `DisableControlAction`
> ยึดคืนมาไม่ได้ ผู้เล่นจะได้เมนูแทนการยกเลิก

ป้ายปุ่มมากับข้อความ `start` ของ NUI ในรูป `cancel = { key, label }` — **ฝั่ง NUI ไม่มีตารางแปลงชื่อคีย์ของตัวเอง**
ป้ายที่เห็นบนจอกับปุ่มที่ Lua อ่านจริงจึงเป็นตัวเดียวกันเสมอ

รอบที่ `silent = true` ยังกดยกเลิกได้เหมือนเดิม (แค่ไม่มีแถบให้เห็น ผู้เรียกวาดเอง) — `silent` ตัดเฉพาะเส้นทาง NUI

---

## หน้าตาของแถบ

ใช้ **ธีมเดียวกับ [`hexa_inventory`](https://github.com/hexa-development/hexa_inventory)** — โทเคนใน `web/style.css` ลอกชื่อและค่ามาจาก
`hexa_inventory/html/main.css` ตรง ๆ (`--ink-*` / `--line-*` / `--text*` / `--accent*` / `--radius`)
อ่านสองไฟล์คู่กันแล้วเห็นว่าเป็นระบบเดียวกัน และลอกทับได้ทั้งบล็อกถ้าวันหนึ่ง inventory ขยับสี

```
┌────────────────────────────────────────────────┐  ← เส้นผมขาว + ฉากมุมสี่มุม
│ ┌────┐  กำลังดำเนินการ           [BKSP] ยกเลิก │
│ │ ⛏  │  ──────────────────────────────────────  │
│ └────┘  ▎กำลังขุด                       12.4s  │
│          3 / 10 หน่วย                           │
├════════════════════════════════════════════════┤  ← ราง ติดขอบล่างของแผง
```

- **แผงหมึกดำไล่เฉด** ตีเส้นผมขาวบางรอบชิ้น + กรอบในอีกชั้น + **ฉากมุม** สี่มุม (โมทีฟหลักของ inventory) มุมเกือบฉาก `0.3vh`
- **ช่องไอคอน** สี่เหลี่ยมพื้นดำตามสำนวน `.item-box-icon`
- **ป้ายสถานะ** ตัวเล็กหนาระยะห่างอักษรกว้าง ตามสำนวน `.item-box-type` — กำลังดำเนินการ / สำเร็จ / ยกเลิกแล้ว
- **ขีดตั้งไล่เฉด** หน้าหัวเรื่อง ตามสำนวน `.inventory-label p::before` ย้อมด้วยสีสถานะ
- **รางเป็นขีดบางเต็มความกว้าง ติดขอบล่างของแผง** ตามสำนวน `.item-slot-durability` ไม่ใช่หลอดแคปซูลลอยอยู่ข้างใน
- **สถานะเปลี่ยนตัวแปร `--c` ตัวเดียว** ไอคอน ขีดหน้าหัวเรื่อง ตัวเลขเวลา ป้ายสถานะ และราง เปลี่ยนพร้อมกัน ไม่มีที่ไหนเขียนสีตรง ๆ
- **สถานะไม่ได้บอกด้วยสีอย่างเดียว** — มีทั้งตัวหนังสือและไอคอนที่สลับเป็นเครื่องหมายถูก/กากบาท (แถบเขียวกับแถบแดงเป็นเทาเข้มเหมือนกันหมดสำหรับคนตาบอดสีแดง-เขียว)

ฟอนต์อยู่ใน resource ทั้งหมด (CEF ของ RedM โหลด Google Fonts ไม่ได้):

| ไฟล์ | ใช้ที่ไหน |
|---|---|
| `web/assets/RDRLino-Regular.ttf` | หัวเรื่อง + ตัวเลขเวลา (ไฟล์เดียวกับ `hexa_inventory`) |
| `web/fonts/kanit-*.woff2` | เนื้อความ และเป็น**ตัวสำรองของ RDR Lino** |

> RDR Lino ไม่มีอักขระไทย หัวเรื่องภาษาไทยจึงตกไป Kanit เองทีละอักขระ (inventory ยอมรับข้อแลกเปลี่ยนเดียวกัน
> กับ locale ที่ไม่ใช่ละติน) ถ้าไม่ชอบตอนหัวเรื่องมีสองภาษาปนกัน ให้แก้ `--font-display` ใน `web/style.css`
> ให้มีค่าเดียวกับ `--font-ui` บรรทัดเดียว ทั้งหน้ากลับเป็น Kanit ล้วนทันที

`web/style.css` **ยืนได้ด้วยตัวเอง** ไม่พึ่ง `hexa-kit.css` แล้ว — kit เป็นภาษาออกแบบคนละสำนวน
(ไม่ใช้เส้นขอบ มุมมนกว่า รางเป็นแคปซูล) เอามาซ้อนกันคือเขียนทับแทบทุกบรรทัดแล้วยังต้องแบก CSS 96KB ที่ไม่ได้ใช้
ดูเหตุผลเต็มที่หัวไฟล์ `web/style.css`

---

## ตำแหน่งของแถบ

แถบอยู่**กึ่งกลางแนวนอนเสมอ** ไม่มีค่าให้ตั้ง — ปรับได้แค่แนวตั้งกับความกว้าง ทุกค่าเป็น `vh`

| key | default | ความหมาย |
|---|---|---|
| `Config.BottomOffset` | `12.0` | ระยะจากขอบล่างของจอถึงขอบล่างของแถบ |
| `Config.MinWidth` | `34.0` | ความกว้างขั้นต่ำ |
| `Config.MaxWidth` | `60.0` | ความกว้างสูงสุด — label ยาวเกินนี้ถูกตัดท้ายด้วย `…` |

ค่าเหล่านี้ถูกส่งไป NUI พร้อมข้อความ `start` ของทุกรอบ (ไม่ใช่ตอน resource สตาร์ท) จึงไม่ต้องกังวลว่า
NUI จะยังไม่พร้อมตอนบูต และแก้ config แล้ว `restart hexa_progbar` เห็นผลทันที

---

## Server exports

ยิงให้ client เริ่ม progress (fire-and-forget — ผลลัพธ์ `true`/`false` อยู่ที่ client เท่านั้น)

```lua
exports['hexa_progbar']:Progress(source, data)
exports['hexa_progbar']:Cancel(source)
exports['hexa_progbar']:ProgressAll(data)
```

ถ้า flow ฝั่ง server ต้องรู้ผล ให้ client เรียก export เองแล้วยิง event กลับมา

---

## Events

```lua
TriggerEvent('hexa_progbar:cancel')            -- client
TriggerClientEvent('hexa_progbar:start', src, data)
```

---

## ทดสอบในเกม

```
/hexaprog           -- แถบปกติ 6 วินาที (โชว์เวลาที่เหลือ + ล็อกการเคลื่อนไหว)
/hexaprog long      -- label ยาวเกินความกว้าง เพื่อดูว่าตัดด้วย … ถูกไหม
/hexaprog cancel    -- ยกเลิกอันที่ทำงานอยู่
```

ปิดด้วย `Config.TestCommand = false` บนเซิร์ฟจริง

---

## หมายเหตุทางเทคนิค

- **ทำได้ทีละอัน** — เรียกซ้อนจะ**ต่อคิว**รอตัวเดิมจบ (semantics เดียวกับ ox_lib)
- **Lua เป็นเจ้าของเวลาจริง** ไม่ใช่ NUI — ค่าที่คืนจึงเชื่อถือได้แม้ NUI ช้า/ไม่ repaint
- **แถบวิ่งด้วย CSS animation** (`transform: scaleX`, composite) และตั้งแต่ย้ายมาเป็นแถบบนจอก็
  **ไม่มีข้อความ NUI รายเฟรมเหลืออยู่เลย** — ทั้งรอบมีแค่ `start` กับ `finish` อย่างละหนึ่งข้อความ
  (ของเดิมต้องฉายพิกัดโลก→จอ แล้วส่ง x/y ไปทุกเฟรม)
- ตั้ง `LocalPlayer.state.invBusy` ระหว่างทำงาน (เหมือน ox_lib)
- `prop` สร้างผ่าน state bag → **ผู้เล่นคนอื่นเห็นด้วย** ไม่ใช่แค่คนทำ
- ox_lib บน RedM ไม่ได้ผูกปุ่มยกเลิกไว้เลย (`RegisterKeyMapping` ของมันเป็น FiveM-only) —
  ตัวนี้เป็นเจ้าของปุ่มยกเลิกเอง (ป้ายบนแถบ + ยึดปุ่มคืนจากเกม + อ่านเอง) `canCancel` จึงใช้งานได้จริง
  ดู [ปุ่มยกเลิก](#cancel-key-th)

---

## เรียกจาก resource อื่น

`hexa_progbar` เป็น standalone ผู้เรียกจึงควรถือว่าเป็นของ optional และใส่ guard ไว้:

```lua
local function progress(data)
    if GetResourceState('hexa_progbar') ~= 'started' then
        return true -- หรือทางถอยของคุณเอง
    end
    return exports['hexa_progbar']:Progress(data)
end
```

แบบนี้ resource ยังรันได้บนเซิร์ฟที่ไม่ได้ลงแถบนี้ และได้หน้าตาเต็ม ๆ บนเซิร์ฟที่ลงไว้

---

## Hexa Ecosystem

`hexa_progbar` is a standalone resource in the Hexa Framework stack. Each part is its own repository.

| Project | Description |
| :--- | :--- |
| [`hexa_core`](https://github.com/hexa-development/hexa_core) | Core framework — players, jobs, items, economy, status, callbacks, permissions |
| [`hexa_inventory`](https://github.com/hexa-development/hexa_inventory) | Persistent grid inventory — stashes, shops, ground drops, secure trading |
| **`hexa_progbar`** | Screen-fixed progress bar — drop-in for `ox_lib` `progressBar` <br> *(this repository)* |
| [`hexa-bridge`](https://github.com/hexa-development/hexa-bridge) | Compatibility layer for supported RSG and VORP resources |
| [`hexa-docs`](https://github.com/hexa-development/hexa-docs) | Official documentation and API reference (VitePress) |
| [`rdr2-unpack`](https://github.com/hexa-development/rdr2-unpack) | Read a local RDR2 install into open formats — GLB, PNG, `.ymap` JSON |
| [`txAdmin`](https://github.com/hexa-development/txAdmin) | One-click txAdmin recipe that deploys the whole Hexa stack |

Full API reference and installation guides live in [`hexa-docs`](https://github.com/hexa-development/hexa-docs) → [hexa-development.github.io/hexa-docs](https://hexa-development.github.io/hexa-docs/)

---

<div align="center">

### One bar. Same theme as the inventory.

**Built for Hexa Framework**

<br>

[Documentation](https://hexa-development.github.io/hexa-docs/) ·
[เอกสารภาษาไทย](https://hexa-development.github.io/hexa-docs/th/) ·
[hexa_core](https://github.com/hexa-development/hexa_core) ·
[hexa_inventory](https://github.com/hexa-development/hexa_inventory) ·
[hexa_progbar](https://github.com/hexa-development/hexa_progbar) ·
[hexa-bridge](https://github.com/hexa-development/hexa-bridge) ·
[Organization](https://github.com/hexa-development)

<br>

*Lua owns the clock. The bar just shows it.*

</div>
