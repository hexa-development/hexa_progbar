--[[
    hexa_progbar - client
    -------------------------------------------------------------------
    Progress UI ของสแตก hexa_* — มีรูปแบบเดียว: แถบตรึงอยู่ "กลางจอ
    ด้านล่าง" เหมือน HUD ไม่เกาะอะไรในโลกทั้งสิ้น

    เดิมเป็นแถบลอยเหนือหัว/เหนือ entity/เหนือพิกัดในโลก (พอร์ตจาก
    rb_progbar) ตอนนี้ถูกเปลี่ยนเป็นแถบบนจอทั้งหมดแล้ว ผลตามมาที่
    ตั้งใจ: ไม่มีการฉายพิกัดโลก->จอ และไม่มีข้อความ NUI รายเฟรมอีก
    ต่อไป ตำแหน่งเป็นเรื่องของ CSS ล้วน (ดู Config.BottomOffset)

    API ยังเป็น drop-in ของ lib.progressBar (ox_lib): ชื่อออปชันเดียวกัน
    เรียกแล้วบล็อกเหมือนกัน คืน true/false เหมือนกัน ส่วน `icon` คือของ
    ที่เพิ่มเข้ามา

    Public exports (client):

      exports['hexa_progbar']:Progress(data)   -- บล็อกจนจบ/ถูกยกเลิก
        data = {
          duration  = ms                     (ค่าเริ่มต้น Config.DefaultDuration)
          label     = string,                -- บรรทัดหัวเรื่อง
          icon      = ชื่อไอคอน Material/FA   (ค่าเริ่มต้น Config.DefaultIcon)
          canCancel = true|false             -- ให้ Config.CancelControl ยกเลิกได้
          showRemaining = true|false         -- พิมพ์วินาทีที่เหลือ

          -- ไม่ต้องขึ้นแถบกลางจอ เอาแค่ท่าทาง/prop/ล็อกปุ่ม/ปุ่มยกเลิก
          -- สำหรับผู้เรียกที่มีที่แสดงความคืบหน้าของตัวเองอยู่แล้ว (เช่น
          -- hexa_plants ที่ให้แถบวิ่งอยู่บน "ปุ่มในการ์ดสถานะพืช" — ถ้าไม่ปิด
          -- ตัวนี้ผู้เล่นจะเห็นแถบสองใบพร้อมกัน) นอกนั้นทำงานเหมือนเดิมทุกอย่าง
          -- รวมถึงค่าที่คืน
          silent = true|false

          -- เงื่อนไขที่ทำให้ล้ม (ชื่อ + ความหมายตาม ox_lib)
          useWhileDead, allowRagdoll, allowCuffed, allowFalling, allowSwimming

          anim   = { dict, clip, flag, blendIn, blendOut, ... } | { scenario }
          prop   = { model, bone, pos, rot } | { ...หลายชิ้น }
          disable = { move, sprint, car, combat, mouse }

          -- ยังรับ `style` / `position` / `entity` / `coords` / `offsetZ`
          -- ได้แต่ไม่มีผลแล้ว (call site เก่าอย่าง hexa_horses ส่งมาอยู่ —
          -- ปล่อยให้ผ่านเงียบ ๆ ดีกว่าให้พัง)
        } -> true เมื่อวิ่งจนจบ, false เมื่อถูกยกเลิก/ถูกขัด

      exports['hexa_progbar']:Cancel()         -- ล้มรอบที่กำลังทำงาน
      exports['hexa_progbar']:IsActive()       -- มีรอบทำงานอยู่ไหม

    Aliases สำหรับย้ายมาจาก ox_lib แบบไม่ต้องแก้ call site:
      progressBar / progressCircle / cancelProgress / progressActive

    Net events:
      TriggerEvent('hexa_progbar:cancel')
]]

local DisableControlAction = DisableControlAction
local DisablePlayerFiring = DisablePlayerFiring
local GetGameTimer = GetGameTimer
local playerState = LocalPlayer.state

-- รอบที่กำลังทำงาน nil = ว่าง, table = กำลังวิ่ง, false = สั่งให้หยุดแล้ว
-- สามสถานะนี้คือสิ่งที่ทำให้ผู้เรียกรายถัดไปต่อคิวหลังรอบที่วิ่งอยู่ได้
-- เหมือน ox_lib เป๊ะ ๆ: nil = "ว่าง", อย่างอื่น = "รอคิว"
local progress = nil
local seq = 0

------------------------------------------------------------------
-- RedM control hashes
------------------------------------------------------------------
local controls = {
    INPUT_LOOK_LR = 0xA987235F,
    INPUT_LOOK_UD = 0xD2047988,
    INPUT_SPRINT = 0x8FFC75D6,
    INPUT_AIM = 0xF84FA74F,
    INPUT_MOVE_LR = 0x4D8FB4C1,
    INPUT_MOVE_UD = 0xFDA83190,
    INPUT_DUCK = 0xDB096B85,
    INPUT_VEH_MOVE_LEFT_ONLY = 0x9DF54706,
    INPUT_VEH_MOVE_RIGHT_ONLY = 0x97A8FD98,
    INPUT_VEH_ACCELERATE = 0x5B9FD4E2,
    INPUT_VEH_BRAKE = 0x6E1F639B,
    INPUT_VEH_EXIT = 0xFEFAB9B4,
    INPUT_VEH_MOUSE_CONTROL_OVERRIDE = 0x39CCABD5,
}

------------------------------------------------------------------
-- helpers
------------------------------------------------------------------
local function nextId()
    seq = seq + 1
    return ('hxp%d_%d'):format(GetGameTimer(), seq)
end

local function requestAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then return false end
        Wait(0)
    end
    return true
end

-- ตรงกับ interruptProgress ของ ox_lib: เงื่อนไขที่ทำให้รอบล้ม และผู้เรียก
-- ปิดได้ทีละข้อ ใช้เป็นด่านตรวจก่อนเริ่มด้วย — ox_lib ไม่ยอมเริ่มเลยถ้ามี
-- ข้อไหนเป็นจริงอยู่ก่อนแล้ว
local function interruptProgress(data)
    local ped = PlayerPedId()
    if not data.useWhileDead and IsEntityDead(ped) then return true end
    if not data.allowRagdoll and IsPedRagdoll(ped) then return true end
    if not data.allowCuffed and IsPedCuffed(ped) then return true end
    if not data.allowFalling and IsPedFalling(ped) then return true end
    if not data.allowSwimming and IsPedSwimming(ped) then return true end
    return false
end

------------------------------------------------------------------
-- the run
------------------------------------------------------------------
local function startProgress(data, id)
    playerState.invBusy = true
    progress = data

    local anim = data.anim
    if anim then
        if anim.dict then
            if requestAnimDict(anim.dict) then
                TaskPlayAnim(PlayerPedId(), anim.dict, anim.clip,
                    anim.blendIn or 3.0, anim.blendOut or 1.0,
                    anim.duration or -1, anim.flag or 49,
                    anim.playbackRate or 0, anim.lockX, anim.lockY, anim.lockZ)
                RemoveAnimDict(anim.dict)
            end
        elseif anim.scenario then
            TaskStartScenarioInPlace(PlayerPedId(), anim.scenario, 0,
                anim.playEnter == nil or anim.playEnter)
        end
    end

    if data.prop then
        TriggerServerEvent('hexa_progbar:progressProps', data.prop)
    end

    local disable = data.disable
    local startTime = GetGameTimer()
    local endTime = startTime + data.duration

    while progress do
        if disable then
            if disable.mouse then
                DisableControlAction(0, controls.INPUT_LOOK_LR, true)
                DisableControlAction(0, controls.INPUT_LOOK_UD, true)
                DisableControlAction(0, controls.INPUT_VEH_MOUSE_CONTROL_OVERRIDE, true)
            end
            if disable.move then
                DisableControlAction(0, controls.INPUT_SPRINT, true)
                DisableControlAction(0, controls.INPUT_MOVE_LR, true)
                DisableControlAction(0, controls.INPUT_MOVE_UD, true)
                DisableControlAction(0, controls.INPUT_DUCK, true)
            end
            if disable.sprint and not disable.move then
                DisableControlAction(0, controls.INPUT_SPRINT, true)
            end
            if disable.car then
                DisableControlAction(0, controls.INPUT_VEH_MOVE_LEFT_ONLY, true)
                DisableControlAction(0, controls.INPUT_VEH_MOVE_RIGHT_ONLY, true)
                DisableControlAction(0, controls.INPUT_VEH_ACCELERATE, true)
                DisableControlAction(0, controls.INPUT_VEH_BRAKE, true)
                DisableControlAction(0, controls.INPUT_VEH_EXIT, true)
            end
            if disable.combat then
                DisableControlAction(0, controls.INPUT_AIM, true)
                -- รับ PLAYER index ไม่ใช่ ped handle
                DisablePlayerFiring(PlayerId(), true)
            end
        end

        -- ปุ่มยกเลิก ox_lib ไม่มีปุ่มยกเลิกให้ฝั่ง RedM เลย (RegisterKeyMapping
        -- ของมันใช้ได้เฉพาะ FiveM) ตรงนี้คือจุดที่ canCancel กลายเป็นของจริง
        -- สำหรับผู้เล่น
        if data.canCancel and IsControlJustReleased(0, Config.CancelControl) then
            progress = false
            break
        end

        if interruptProgress(progress) then
            progress = false
            break
        end

        -- NUI เป็นเจ้าของนาฬิกาที่ตาเห็น ส่วนฝั่ง Lua เป็นเจ้าของความจริง
        -- จบรอบตรงนี้ (ไม่ใช่รอ callback จาก NUI) ค่าที่คืนจึงยังตรงแม้ NUI
        -- จะช้า ถูกซ่อน หรือไม่วาดเลย
        if GetGameTimer() >= endTime then break end

        Wait(0)
    end

    local completed = progress ~= false

    if data.prop then
        TriggerServerEvent('hexa_progbar:progressProps', nil)
    end

    if anim then
        if anim.dict then
            StopAnimTask(PlayerPedId(), anim.dict, anim.clip, 1.0)
            Wait(0)   -- ถ้าไม่มีบรรทัดนี้ StopAnimTask จะโดนยกเลิกเสียเอง
        else
            ClearPedTasks(PlayerPedId())
            -- ด้วยเหตุผลเดียวกับข้างบน: ClearPedTasks ไม่ได้มีผลในเฟรมที่สั่ง
            -- ถ้าคืนค่ากลับไปเลย ผู้เรียกที่สั่งท่าใหม่ต่อทันที (เช่น hexa_plants
            -- เอาท่าเดินถือถังกลับมาหลังรดน้ำ) จะโดนคำสั่งล้างนี้กินท่าใหม่ไปด้วย
            -- เหลือตัวละครค้างอยู่ในท่าของ scenario ที่เพิ่งเล่นจบ
            Wait(0)
        end
    end

    playerState.invBusy = false
    progress = nil

    -- ไม่ได้ส่ง start ไปตั้งแต่แรก ก็ไม่มีรอบให้ปิด (NUI เมิน id ที่ไม่รู้จักอยู่แล้ว
    -- แต่ไม่ส่งเลยชัดกว่า — อ่านโค้ดแล้วเห็นว่า silent ตัดทั้งเส้นทาง NUI จริง ๆ)
    if not data.silent then
        SendNUIMessage({ action = 'finish', id = id, ok = completed })
    end
    return completed
end

------------------------------------------------------------------
-- public API
------------------------------------------------------------------
local function Progress(data)
    if type(data) == 'string' then data = { label = data } end
    data = data or {}

    -- ต่อคิวหลังรอบที่วิ่งอยู่ (ตาม ox_lib)
    while progress ~= nil do Wait(0) end

    -- ไม่ยอมเริ่มถ้ามีเงื่อนไขล้มอยู่ก่อนแล้ว ox_lib คืน nil ตรงนี้ ไม่ใช่
    -- false และ call site ที่เขียนกับมันอ่านค่านี้ว่า "ไม่ได้ทำงาน"
    if interruptProgress(data) then return nil end

    data.duration = tonumber(data.duration) or Config.DefaultDuration

    -- ห้ามเขียนเป็น `(x ~= nil) and x or default`: สำนวนนั้นกลืน `false`
    -- ที่ผู้เรียกตั้งใจส่งมาทิ้งไปเงียบ ๆ ทั้งที่มันคือค่าที่ตั้งใจส่ง
    local showRemaining = Config.ShowRemaining
    if data.showRemaining ~= nil then showRemaining = data.showRemaining end

    local id = nextId()

    -- silent = ผู้เรียกวาดความคืบหน้าเองที่อื่น (ดูหัวไฟล์) ตัดเฉพาะเส้นทาง NUI
    -- ที่เหลือ — ท่าทาง prop ล็อกปุ่ม ปุ่มยกเลิก เงื่อนไขล้ม — เหมือนเดิมทุกข้อ
    if not data.silent then
        SendNUIMessage({
            action = 'start',
            payload = {
                id            = id,
                label         = data.label or '',
                icon          = data.icon or Config.DefaultIcon,
                duration      = data.duration,
                showRemaining = showRemaining and true or false,
                -- ส่งค่าตำแหน่ง/ขนาดไปกับทุกรอบ ไม่ใช่ตอน resource สตาร์ท:
                -- NUI อาจยังไม่พร้อมรับข้อความตอนนั้น แถมวิธีนี้ทำให้แก้ config
                -- แล้ว restart เฉพาะฝั่ง client ก็เห็นผลทันที
                bottom        = tonumber(Config.BottomOffset) or 12.0,
                minWidth      = tonumber(Config.MinWidth) or 34.0,
                maxWidth      = tonumber(Config.MaxWidth) or 60.0,
            }
        })
    end

    return startProgress(data, id)
end

local function Cancel()
    if progress then progress = false end
end

local function IsActive()
    return progress ~= nil
end

exports('Progress', Progress)
exports('progressBar', Progress)      -- alias สไตล์ ox_lib ไว้ย้ายมาแบบไม่ต้องแก้
exports('progressCircle', Progress)
exports('Cancel', Cancel)
exports('cancelProgress', Cancel)
exports('IsActive', IsActive)
exports('progressActive', IsActive)

-- Progress() บล็อก แต่ handler ของ net event ห้ามบล็อก: ถ้าถือ thread ของ
-- event ไว้ event อื่น ๆ ที่เข้ามาหา client นี้จะต่อคิวหลังรอบ progress ทั้งหมด
RegisterNetEvent('hexa_progbar:start', function(data)
    CreateThread(function() Progress(data) end)
end)

RegisterNetEvent('hexa_progbar:cancel', function() Cancel() end)

RegisterCommand('cancelprogress', function()
    if progress and progress.canCancel then progress = false end
end, false)

------------------------------------------------------------------
-- replicated props (พาริตี้กับ progress props ของ ox_lib)
------------------------------------------------------------------
-- prop ถูกสร้างจาก state bag ไม่ใช่สร้างในเครื่องตัวเอง ผู้เล่นทุกคนที่อยู่
-- ในระยะจึงเห็นเครื่องมือในมือคนที่ทำงาน ไม่ใช่เห็นแค่เจ้าตัว
local createdProps = {}

--- หา bone index จากสิ่งที่ call site ส่งมา — รับได้ทั้งชื่อและตัวเลข
---
--- GetPedBoneIndex รับ *bone id ที่เป็นตัวเลข* เท่านั้น แต่ config แทบทุกตัวเขียน
--- bone เป็นชื่อ ('PH_R_Hand') ตามที่สคริปต์ RedM ทั่วไปใช้กัน  ส่งสตริงเข้าไปตรง ๆ
--- จะได้ index มั่ว (0/-1) แล้ว prop ไปเกาะที่จุดกำเนิดของ ped แทนที่จะอยู่ในมือ —
--- อาการที่เห็นคือ "ของไม่ตรงกับท่า" ทั้งที่ animation ถูกต้องอยู่แล้ว
---
--- ชื่อของ RDR2 ที่ใช้บ่อย: PH_R_Hand / PH_L_Hand (จุดถือของ — ตั้งท่ามาให้แล้ว)
--- และ SKEL_R_Hand / SKEL_L_Hand (กระดูกมือจริง ต้องปรับ pos/rot เอง)
local function resolveBone(ped, bone)
    if type(bone) == 'number' then
        return GetPedBoneIndex(ped, bone)
    end

    if type(bone) == 'string' then
        local index = GetEntityBoneIndexByName(ped, bone)
        if index and index ~= -1 then return index end
        -- ผิดตัวพิมพ์เล็ก/ใหญ่ก็ยังหาไม่เจอในบางบิลด์ ลองรูปแบบมาตรฐานอีกที
        for _, alt in ipairs({ bone:upper(), bone:lower() }) do
            index = GetEntityBoneIndexByName(ped, alt)
            if index and index ~= -1 then return index end
        end
    end

    -- หาไม่เจอ = ให้ไปอยู่ในมือขวาไว้ก่อน ดีกว่าไปกองที่เท้า
    local fallback = GetEntityBoneIndexByName(ped, 'PH_R_Hand')
    return (fallback and fallback ~= -1) and fallback or 0
end

--- แกะ x/y/z ออกมาเป็นตัวเลขล้วน
---
--- prop เดินทางมาทาง state bag ซึ่ง serialize vector3 ไม่เหมือนกันทุกบิลด์ —
--- บางทีกลับมาเป็น {x=,y=,z=} บางทีเป็น array {1,2,3}  ถ้าอ่าน .x แล้วได้ nil
--- แล้วส่ง nil เข้า AttachEntityToEntity native จะ error ทั้งบรรทัด object ที่
--- สร้างไปแล้วเลยไม่ได้ถูกผูกกับใคร = ลอยค้างอยู่กลางอากาศตรงที่มันเกิด
local function xyz(v)
    if type(v) == 'vector3' then return v.x + 0.0, v.y + 0.0, v.z + 0.0 end
    if type(v) == 'table' then
        return tonumber(v.x or v[1]) or 0.0,
               tonumber(v.y or v[2]) or 0.0,
               tonumber(v.z or v[3]) or 0.0
    end
    return 0.0, 0.0, 0.0
end

local function attached(object, ped)
    local ok, res = pcall(IsEntityAttachedToEntity, object, ped)
    -- บิลด์ที่ไม่มี native ตัวนี้: เชื่อว่าติดแล้ว ดีกว่าลบ prop ทิ้งทุกครั้ง
    if not ok then return true end
    return res == true or res == 1
end

local function createProp(ped, prop)
    local model = type(prop.model) == 'string' and joaat(prop.model) or prop.model
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then return nil end
        Wait(0)
    end

    local coords = GetEntityCoords(ped)
    local object = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if not object or object == 0 then return nil end

    -- prop ในมือไม่ควรไปชนอะไร และไม่ควรร่วงตามแรงโน้มถ่วงระหว่างรอผูก
    SetEntityCollision(object, false, false)

    local px, py, pz = xyz(prop.pos)
    local rx, ry, rz = xyz(prop.rot)
    local bone = resolveBone(ped, prop.bone or 'PH_R_Hand')

    local ok, err = pcall(AttachEntityToEntity, object, ped, bone,
        px, py, pz, rx, ry, rz,
        true, true, false, true, prop.rotOrder or 0, true)

    -- ผูกไม่ติดด้วย bone ที่ขอมา ลองซ้ำที่ bone 0 (จุดกำเนิดของ ped) ก่อนยอมแพ้
    if not ok or not attached(object, ped) then
        ok, err = pcall(AttachEntityToEntity, object, ped, 0,
            px, py, pz, rx, ry, rz,
            true, true, false, true, 0, true)
    end

    if not ok or not attached(object, ped) then
        -- ปล่อยไว้จะกลายเป็นของลอยค้างกลางอากาศให้ทุกคนเห็น ลบทิ้งดีกว่า
        print(('[hexa_progbar][ERROR][PROP_ATTACH] Failed to attach the prop to the ped | Model: %s | Bone: %s | Error: %s')
            :format(tostring(prop.model), tostring(prop.bone), tostring(err)))
        if DoesEntityExist(object) then DeleteEntity(object) end
        return nil
    end

    return object
end

local function deleteProgressProps(serverId)
    local playerProps = createdProps[serverId]
    if not playerProps then return end
    createdProps[serverId] = nil

    for i = 1, #playerProps do
        if DoesEntityExist(playerProps[i]) then DeleteEntity(playerProps[i]) end
    end
end

RegisterNetEvent('onPlayerDropped', function(serverId)
    deleteProgressProps(serverId)
end)

AddStateBagChangeHandler('hexa_progbar:props', nil, function(bagName, _, value, _, replicated)
    if replicated then return end

    local ply = GetPlayerFromStateBagName(bagName)
    if ply == 0 then return end

    local ped = GetPlayerPed(ply)
    local serverId = GetPlayerServerId(ply)

    if not value or createdProps[serverId] then
        return deleteProgressProps(serverId)
    end

    local playerProps = {}
    if value.model then
        local prop = createProp(ped, value)
        if prop then playerProps[#playerProps + 1] = prop end
    else
        for i = 1, math.min(Config.MaxProps or 2, #value) do
            local prop = createProp(ped, value[i])
            if prop then playerProps[#playerProps + 1] = prop end
        end
    end
    createdProps[serverId] = playerProps
end)

------------------------------------------------------------------
-- คำสั่งทดสอบ /hexaprog
------------------------------------------------------------------
if Config.TestCommand then
    RegisterCommand('hexaprog', function(_, args)
        local mode = args[1]

        if mode == 'cancel' then Cancel() return end

        if mode == 'long' then
            -- label ยาวเกินความกว้าง เพื่อดูว่าแถบยืดถึง MaxWidth แล้วตัด
            -- ด้วย … จริงไหม และยังอยู่กึ่งกลางจอพอดี
            local ok = Progress({
                duration      = 12000,
                label         = 'กำลังต้มยาสมุนไพรสูตรพิเศษของคุณยายอยู่ รอสักครู่นะ',
                icon          = 'science',
                canCancel     = true,
                showRemaining = true,
            })
            print(('[hexa_progbar] long -> %s'):format(tostring(ok)))
            return
        end

        local ok = Progress({
            duration      = 6000,
            label         = 'กำลังเก็บเกี่ยว...',
            icon          = 'agriculture',
            canCancel     = true,
            showRemaining = true,
            disable       = { move = true, combat = true },
        })
        print(('[hexa_progbar] bottom -> %s'):format(tostring(ok)))
    end, false)

    TriggerEvent('chat:addSuggestion', '/hexaprog',
        'ทดสอบ hexa_progbar (ใส่ "long" หรือ "cancel" ต่อท้ายได้)')
end
