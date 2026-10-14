require "HCR_TimedDefinitions"
HCRTimed = HCRTimed or {}

-- Чистый расчёт: остаток времени переносится на следующие стадии,
-- поэтому выгрузка чанка не останавливает рост и не обнуляет возраст.
function HCRTimed.resolve(fullType, startedAt, now)
    if now < startedAt then startedAt = now end
    local seen = {}
    while true do
        local transition = HCRTimedDefinitions[fullType]
        if not transition or transition.hours <= 0 then break end
        if seen[fullType] then
            local period = startedAt - seen[fullType]
            if period > 0 then
                local cycles = math.floor((now - startedAt) / period)
                startedAt = startedAt + cycles * period
            end
            seen = {}
        end
        seen[fullType] = startedAt
        if now - startedAt < transition.hours then break end
        startedAt = startedAt + transition.hours
        fullType = transition.target
    end
    return fullType, startedAt
end

function HCRTimed.initialize(item, now)
    if not item or not HCRTimedDefinitions[item:getFullType()] then return false end
    local data = item:getModData()
    if type(data.HCRTimedStart) ~= "number" then
        -- Сохраняем возраст предметов, уже помеченных старым Hydrocraft.
        data.HCRTimedStart = type(data.StartTime) == "number" and data.StartTime or now
    end
    return true
end
