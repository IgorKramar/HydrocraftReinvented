require "HCR_FluidLedger"
HCRFluidCooling = {}
local C, L = HCRFluidCooling, HCRFluidLedger

local function segment(lot, hours, env, fridge, rot, agePowered, operationalPowered)
    if hours <= 0 then return end
    local food = lot.food
    local freezing = food.freezingTime or (food.frozen and 100 or 0)
    local ageing = hours
    if food.canBeFrozen ~= false and env.freezer and operationalPowered then
        local untilFrozen = (100 - freezing) / 25 -- native four hours
        ageing = food.frozen and 0 or math.min(hours, untilFrozen)
        freezing = math.min(100, freezing + hours * 25)
        if freezing >= 100 then food.frozen = true end
    elseif food.canBeFrozen ~= false and freezing > 0 then
        local thawHours = env.cold and not env.freezer and operationalPowered and 3 or 1.5
        if env.temperature > 1 then thawHours = thawHours / 6 end
        local untilThawed = freezing / 100 * thawHours
        if food.frozen then ageing = math.max(0, hours - untilThawed) end
        freezing = math.max(0, freezing - hours / thawHours * 100)
        if freezing <= 0 then food.frozen = false end
    end
    food.freezingTime = freezing
    food.heat = (food.heat or 1) + (env.temperature - (food.heat or 1)) * math.min(1, hours * 3)
    lot.age = lot.age + ageing * (env.cold and agePowered and fridge or 1) * rot / 24
end

-- Native Food по-разному определяет охлаждение возраста и заморозку:
-- первое учитывает общий срок отключения, второе требует работающего прибора.
local function interval(lot, start, finish, previous, fridge, rot, shutdown, gridShutdown)
    if finish <= start then return end
    local env=L.copy(previous)
    local agePowered=previous.powered or (shutdown>=0 and start<shutdown)
    local operational=previous.operationalPowered
    if operational==nil then operational=previous.powered end -- старый private ledger
    if previous.gridPowered and not previous.powered and (gridShutdown<0 or start>=gridShutdown) then
        operational=false
        env.temperature=math.max(1,env.temperature)
    end
    segment(lot,finish-start,env,fridge,rot,agePowered,operational)
end

-- Храним состояние в начале следующего интервала: перемещение или новый
-- генератор не должны менять уже прошедшие тёплые/холодные дни.
function C.advance(ledger, now, current, fridge, rot, shutdown, unobserved, gridShutdown)
    L.validate(ledger)
    local result = L.copy(ledger)
    local previous = result.storage or L.copy(current)
    gridShutdown = gridShutdown or shutdown
    if unobserved then
        -- В выгруженном chunk время остановки генератора неизвестно. Не
        -- считаем весь пропуск холодным, если питание есть только на одном
        -- конце интервала. Известный срок отключения сети учитывается ниже.
        previous.powered=previous.powered and current.powered
        if not previous.powered and not previous.gridPowered then
            previous.operationalPowered=false
            previous.temperature=math.max(1,previous.temperature)
        end
    end
    for _, lot in ipairs(result.lots) do
        local start = lot.lastHour
        if now > start then
            local boundaries={start,now}
            if previous.cold and not previous.powered then
                if shutdown>start and shutdown<now then boundaries[#boundaries+1]=shutdown end
                if gridShutdown~=shutdown and gridShutdown>start and gridShutdown<now then
                    boundaries[#boundaries+1]=gridShutdown
                end
                table.sort(boundaries)
            end
            for i=1,#boundaries-1 do
                interval(lot,boundaries[i],boundaries[i+1],previous,fridge,rot,shutdown,gridShutdown)
            end
            lot.lastHour = now
        end
    end
    result.storage = L.copy(current)
    return result
end
