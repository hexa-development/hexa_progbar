# hexa_progbar

ระบบ progress ของสแตก `hexa_*` — เหลือ **รูปแบบเดียว: แถบตรึงกลางจอด้านล่าง**
แสดง **icon + title + description + progress** เป็น HUD ตายตัว ไม่เกาะอะไรในโลก

> **แถบลอยเหนือหัว (world-anchored) ถูกตัดออกทั้งหมดแล้ว** เช่นเดียวกับแผงกลางจอของ `rb_progbar` ต้นทาง
> ค่า `style` / `position` / `entity` / `coords` / `offsetZ` ที่ยังส่งมาจาก call site เก่า
> (`hexa_horses` ส่งครบทั้งสามตัวหลัง) จะถูก**ละเว้นเงียบ ๆ** ไม่ error

API เป็น **drop-in ของ `lib.progressBar` (ox_lib)** — ชื่อ option เหมือนกัน, บล็อกเหมือนกัน, คืน `true`/`false` เหมือนกัน

```lua
-- เดิม
local ok = lib.progressBar({ duration = 5000, label = '...' })
-- ใหม่
local ok = exports['hexa_progbar']:Progress({ duration = 5000, label = '...' })
```

---

## ติดตั้ง

1. วางโฟลเดอร์ที่ `resources/hexa_progbar`
2. `ensure hexa_progbar` ใน `modifiers/resources.cfg` — วางไว้**ก่อน** resource ที่เรียกใช้ (เช่น `hexa_inventory`)
3. เพิ่ม `'hexa_progbar'` ใน `dependencies` ของ resource ที่เรียก (ถ้าต้องการบังคับ)

standalone — ไม่พึ่ง ox_lib และไม่พึ่ง `hexa_core`

---

## Client exports

### `Progress(data)` → `boolean`

**บล็อกจนกว่าจะจบ** คืน `true` เมื่อทำครบเวลา, `false` เมื่อถูกยกเลิก/ถูกขัดจังหวะ,
`nil` เมื่อเริ่มไม่ได้เลย (เช่นตายอยู่) — ตรงกับ ox_lib ทุกกรณี

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
| `canCancel` | boolean | ขึ้น**ป้ายปุ่มยกเลิก**ท้ายแถบ และกดปุ่มนั้นยกเลิกได้จริง (ดู [ปุ่มยกเลิก](#ปุ่มยกเลิก)) |
| `cancelKey` | string / table | เปลี่ยนปุ่มยกเลิกเฉพาะรอบนี้ — ชื่อใน `Config.CancelKeys` หรือ `{ hash = 0x..., label = 'K' }` (default `Config.CancelKey` = `X`) |
| `cancelLabel` | string | ข้อความข้างป้ายปุ่ม (default `Config.CancelLabel` = `ยกเลิก`) |
| `silent` | boolean | ไม่ขึ้นแถบกลางจอ เอาแค่ท่าทาง/prop/ล็อกปุ่ม/ปุ่มยกเลิก — สำหรับผู้เรียกที่มีที่แสดงความคืบหน้าของตัวเองอยู่แล้ว (`hexa_plants` ให้แถบวิ่งบนปุ่มในการ์ดสถานะพืช) ค่าที่คืนเหมือนเดิมทุกกรณี |
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

ใช้ **ธีมเดียวกับ `hexa_inventory`** — โทเคนใน `web/style.css` ลอกชื่อและค่ามาจาก
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
  ดู [ปุ่มยกเลิก](#ปุ่มยกเลิก)

---

## call site ที่มีอยู่แล้วในสแตก

`hexa_inventory` เรียกตัวนี้อยู่สองที่ (หลัง guard `GetResourceState('hexa_progbar') == 'started'`)
— ตอนหยิบถุงของขึ้น และตอนวางลง: `client/drops/prompts.lua`, `client/drops/loops.lua`
