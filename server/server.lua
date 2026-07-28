--[[
    hexa_progbar - server
    -------------------------------------------------------------------
    ทำสองอย่าง:

      1. Progress props client ขอ prop มา server ประกาศลง state bag ของ
         ผู้เล่นคนนั้น ทุก client ที่อยู่ในระยะจึงสร้าง prop ตาม — นั่นคือ
         สิ่งที่ทำให้ "คนอื่น" เห็นเครื่องมือในมือ ไม่ใช่แค่เจ้าตัว

      2. ทริกเกอร์ฝั่งเซิร์ฟเวอร์ เพื่อให้สคริปต์ฝั่ง server เริ่ม progress
         ให้ผู้เล่นได้โดยไม่ต้องเขียน event เอง:

           exports['hexa_progbar']:Progress(source, data)
           exports['hexa_progbar']:Cancel(source)
           exports['hexa_progbar']:ProgressAll(data)

         ทั้งหมดเป็น fire-and-forget — ผลลัพธ์ true/false ของรอบนั้นอยู่ที่
         client ที่รันมัน flow ฝั่ง server ที่ต้องการผลลัพธ์ควรให้ client
         เรียก export เองแล้วรายงานกลับมา
]]

------------------------------------------------------------------
-- progress props
------------------------------------------------------------------
-- ตัดจำนวนที่ฝั่ง server ไม่ใช่ฝั่ง client: เพดานนี้คือเส้นแบ่งความเชื่อใจ
-- และ client โกหกจำนวน prop ที่ขอได้เสมอ convar ไว้ override ต่อเซิร์ฟ
-- ส่วน Config.MaxProps คือค่าเริ่มต้นที่บันทึกไว้ในคอนฟิก
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
-- server-side helpers
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
