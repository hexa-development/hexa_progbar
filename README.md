# hexa_progbar

ระบบ progress ของสแตก `hexa_*` — เหลือ **รูปแบบเดียว: แถบตรึงกลางจอด้านล่าง**
แสดง **icon + title + progress** เป็น HUD ตายตัว ไม่เกาะอะไรในโลก

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
| `icon` | string | Material Symbols ligature หรือชื่อ Font Awesome เดิม (แปลงให้อัตโนมัติ) |
| `showRemaining` | boolean | โชว์วินาทีที่เหลือบนแถบ (default `Config.ShowRemaining` = `false`) |
| `canCancel` | boolean | ให้กด `Config.CancelControl` (Esc/B) ยกเลิกได้ |
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
  ตัวนี้ผูก `Config.CancelControl` ให้ `canCancel` ใช้งานได้จริง

---

## call site ที่มีอยู่แล้วในสแตก

`hexa_inventory` เรียกตัวนี้อยู่สองที่ (หลัง guard `GetResourceState('hexa_progbar') == 'started'`)
— ตอนหยิบถุงของขึ้น และตอนวางลง: `client/drops/prompts.lua`, `client/drops/loops.lua`
