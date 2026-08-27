-- 🎬 hexa_progbar client - screen-fixed progress bar, drop-in for ox_lib's lib.progressBar

local DisableControlAction = DisableControlAction
local DisablePlayerFiring = DisablePlayerFiring
local IsControlPressed = IsControlPressed
local IsDisabledControlPressed = IsDisabledControlPressed
local IsControlJustPressed = IsControlJustPressed
local IsDisabledControlJustPressed = IsDisabledControlJustPressed
local GetGameTimer = GetGameTimer
local playerState = LocalPlayer.state

-- 🚦 nil = idle, table = running, false = told to stop (ox_lib queues on anything but nil)
local progress = nil
local seq = 0

------------------------------------------------------------------
-- 🎮 RedM control hashes
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
-- 🧰 Helpers
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

-- 🛑 Same conditions as ox_lib's interruptProgress, also used as a gate before starting
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
-- ✋ Cancel key
------------------------------------------------------------------

-- 🔇 Warn once per bad key name, not once per progress run
local warnedKeys = {}

-- 🔑 Resolve a key name / { hash, label } / raw hash into one hash + label pair
local function resolveKey(spec)
    local keys = type(Config.CancelKeys) == 'table' and Config.CancelKeys or {}

    if type(spec) == 'table' and tonumber(spec.hash) then
        return tonumber(spec.hash), tostring(spec.label or '?')
    end

    -- 🔢 Raw hash (legacy Config.CancelControl) - look up a label before falling back to '?'
    if type(spec) == 'number' then
        for name, key in pairs(keys) do
            if key.hash == spec then return spec, tostring(key.label or name) end
        end
        return spec, '?'
    end

    if type(spec) == 'string' then
        local key = keys[spec] or keys[spec:upper()]
        if key then return tonumber(key.hash), tostring(key.label or spec:upper()) end

        if not warnedKeys[spec] then
            warnedKeys[spec] = true
            print(('[hexa_progbar][WARN] unknown cancel key "%s" - see Config.CancelKeys, falling back to Config.CancelControl')
                :format(spec))
        end
    end

    return nil
end

-- 🎯 Cancel key for this run (nil = this run cannot be cancelled)
local function cancelKeyFor(data)
    if not data.canCancel then return nil end

    local hash, label = resolveKey(data.cancelKey or Config.CancelKey)
    if not hash then hash, label = resolveKey(Config.CancelControl) end
    if not hash then return nil end

    return hash, label
end

------------------------------------------------------------------
-- ▶️ The run
------------------------------------------------------------------
local function startProgress(data, id, cancelHash)
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

    -- 🔓 Cancel key only arms after it has been released once
    local cancelArmed = false

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
                -- 👤 Takes a PLAYER index, not a ped handle
                DisablePlayerFiring(PlayerId(), true)
            end
        end

        -- ⛔ Take the key back from the game every frame, then read the Disabled branch too
        if cancelHash then
            DisableControlAction(0, cancelHash, true)

            if not cancelArmed then
                if not (IsControlPressed(0, cancelHash)
                    or IsDisabledControlPressed(0, cancelHash)) then
                    cancelArmed = true
                end
            elseif IsControlJustPressed(0, cancelHash)
                or IsDisabledControlJustPressed(0, cancelHash) then
                progress = false
                break
            end
        end

        if interruptProgress(progress) then
            progress = false
            break
        end

        -- ⏱ Lua owns the truth, the NUI only owns the clock the player sees
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
            Wait(0)   -- ⏳ Without this frame the stop task cancels itself
        else
            ClearPedTasks(PlayerPedId())
            -- ⏳ Same reason - let the clear land before the caller queues a new task
            Wait(0)
        end
    end

    playerState.invBusy = false
    progress = nil

    -- 🤫 Never sent a start, so there is no run to close
    if not data.silent then
        SendNUIMessage({ action = 'finish', id = id, ok = completed })
    end
    return completed
end

------------------------------------------------------------------
-- 📤 Public API
------------------------------------------------------------------
local function Progress(data)
    if type(data) == 'string' then data = { label = data } end
    data = data or {}

    -- 🚶 Queue behind the run in flight (ox_lib behaviour)
    while progress ~= nil do Wait(0) end

    -- 🚫 Refuse to start when an interrupt already holds - ox_lib returns nil here, not false
    if interruptProgress(data) then return nil end

    data.duration = tonumber(data.duration) or Config.DefaultDuration

    -- ✅ Explicit nil check, so a caller's deliberate `false` is not swallowed
    local showRemaining = Config.ShowRemaining
    if data.showRemaining ~= nil then showRemaining = data.showRemaining end

    local id = nextId()

    -- 🔑 Resolved once: the hash drives the loop, the label goes on the bar
    local cancelHash, cancelKeyLabel = cancelKeyFor(data)

    -- 🤫 silent = the caller draws progress elsewhere, everything but the NUI path still runs
    if not data.silent then
        SendNUIMessage({
            action = 'start',
            payload = {
                id            = id,
                label         = data.label or '',
                -- 📄 Second line is its own row on the bar, not text glued onto the title
                description   = data.description or nil,
                icon          = data.icon or Config.DefaultIcon,
                duration      = data.duration,
                showRemaining = showRemaining and true or false,
                -- 🎨 Ignored by the NUI, kept so old call sites keep working
                accent        = data.accent or Config.Accent,
                -- 📐 Geometry rides along every run, so a client restart shows config edits
                bottom        = tonumber(Config.BottomOffset) or 12.0,
                minWidth      = tonumber(Config.MinWidth) or 34.0,
                maxWidth      = tonumber(Config.MaxWidth) or 60.0,
                -- 🏷️ No key means no key cap, so the player never sees a dead button
                cancel        = cancelHash and {
                    key   = cancelKeyLabel,
                    label = data.cancelLabel or Config.CancelLabel or 'ยกเลิก',
                } or nil,
            }
        })
    end

    return startProgress(data, id, cancelHash)
end

local function Cancel()
    if progress then progress = false end
end

local function IsActive()
    return progress ~= nil
end

exports('Progress', Progress)
exports('progressBar', Progress)      -- 🔁 ox_lib aliases, move over without touching call sites
exports('progressCircle', Progress)
exports('Cancel', Cancel)
exports('cancelProgress', Cancel)
exports('IsActive', IsActive)
exports('progressActive', IsActive)

-- 🧵 Progress() blocks, so run it off the event thread or every other event queues behind it
RegisterNetEvent('hexa_progbar:start', function(data)
    CreateThread(function() Progress(data) end)
end)

RegisterNetEvent('hexa_progbar:cancel', function() Cancel() end)

RegisterCommand('cancelprogress', function()
    if progress and progress.canCancel then progress = false end
end, false)

------------------------------------------------------------------
-- 🎒 Replicated props (parity with ox_lib progress props)
------------------------------------------------------------------

-- 👀 Built from the state bag, so everyone nearby sees the tool, not just its owner
local createdProps = {}

-- 🦴 Bone index from a name or a number - GetPedBoneIndex only takes numeric bone ids
local function resolveBone(ped, bone)
    if type(bone) == 'number' then
        return GetPedBoneIndex(ped, bone)
    end

    if type(bone) == 'string' then
        local index = GetEntityBoneIndexByName(ped, bone)
        if index and index ~= -1 then return index end
        -- 🔠 Some builds are case sensitive, retry the standard spellings
        for _, alt in ipairs({ bone:upper(), bone:lower() }) do
            index = GetEntityBoneIndexByName(ped, alt)
            if index and index ~= -1 then return index end
        end
    end

    -- 🤚 Not found: the right hand beats a pile of props at the ped's feet
    local fallback = GetEntityBoneIndexByName(ped, 'PH_R_Hand')
    return (fallback and fallback ~= -1) and fallback or 0
end

-- 📍 Plain numbers out of a vector3 / {x,y,z} / array - state bags serialize both ways
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
    -- 🛟 Native missing on this build: assume attached rather than delete every prop
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

    -- 🚧 A held prop must not collide or fall while it waits to be attached
    SetEntityCollision(object, false, false)

    local px, py, pz = xyz(prop.pos)
    local rx, ry, rz = xyz(prop.rot)
    local bone = resolveBone(ped, prop.bone or 'PH_R_Hand')

    local ok, err = pcall(AttachEntityToEntity, object, ped, bone,
        px, py, pz, rx, ry, rz,
        true, true, false, true, prop.rotOrder or 0, true)

    -- 🔁 Requested bone did not take, retry on bone 0 before giving up
    if not ok or not attached(object, ped) then
        ok, err = pcall(AttachEntityToEntity, object, ped, 0,
            px, py, pz, rx, ry, rz,
            true, true, false, true, 0, true)
    end

    if not ok or not attached(object, ped) then
        -- 🗑️ Leaving it behind means a prop floating in mid air for everyone
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
-- 🧪 /hexaprog test command
------------------------------------------------------------------
if Config.TestCommand then
    RegisterCommand('hexaprog', function(_, args)
        local mode = args[1]

        if mode == 'cancel' then Cancel() return end

        if mode == 'long' then
            -- 📏 Over-long label, to check the bar stops at MaxWidth and clips with …
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
