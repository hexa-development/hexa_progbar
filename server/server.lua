-- 🖥️ hexa_progbar server - replicates progress props and exposes server-side starters

------------------------------------------------------------------
-- 🎒 Progress props
------------------------------------------------------------------

-- 🔒 Trimmed here, not on the client - the client can always lie about the count
local maxProps = GetConvarInt('hexa:progressPropLimit', Config.MaxProps or 2)

RegisterNetEvent('hexa_progbar:progressProps', function(props)
    local src = source

    if type(props) == 'table' then
        if #props > maxProps then
            props = { table.unpack(props, 1, maxProps) }
        end
    else
        props = nil
    end

    Player(src).state:set('hexa_progbar:props', props, true)
end)

------------------------------------------------------------------
-- 📤 Server-side helpers (fire-and-forget, the result lives on the client)
------------------------------------------------------------------
local function Progress(src, data)
    if not src or not data then return end
    TriggerClientEvent('hexa_progbar:start', src, data)
end

local function Cancel(src)
    if not src then return end
    TriggerClientEvent('hexa_progbar:cancel', src)
end

local function ProgressAll(data)
    if not data then return end
    TriggerClientEvent('hexa_progbar:start', -1, data)
end

exports('Progress', Progress)
exports('Cancel', Cancel)
exports('ProgressAll', ProgressAll)
