require "HCR_Sandbox"
HCRSandboxLoot=HCRSandboxLoot or {}
local M=HCRSandboxLoot
local pools={}
local active=false
local lastSettings
local function settings()
    local values={tostring(HCRSandbox.multiplier("LootMultiplier",0,10))}
    for _,name in ipairs({"EnableCannabis","EnableMeth","EnableOpium","EnableTobacco","SpawnHydrocraftGuns"}) do
        values[#values+1]=tostring(HCRSandbox.enabled(name))
    end
    return table.concat(values,":")
end

local function factor(kind,option)
    if not HCRSandbox.itemEnabled(kind) or (option and not HCRSandbox.enabled(option)) then return 0 end
    return HCRSandbox.multiplier("LootMultiplier",0,10)
end

function M.register(list,index,option)
    local entries=pools[list] or {}
    pools[list]=entries
    for _,entry in ipairs(entries) do
        if entry.present and entry.index==index then return end
    end
    local kind,weight=list[index],list[index+1]
    assert(type(kind)=="string" and type(weight)=="number","Invalid authored loot pair")
    local entry={index=index,kind=kind,baseline=weight,last=weight,option=option,present=true}
    entries[#entries+1]=entry
end

function M.contains(list,kind)
    for _,entry in ipairs(pools[list] or {}) do if entry.kind==kind then return true end end
    return false
end

function M.append(list,items,scale,option)
    if type(list)~="table" or type(items)~="table" then return end
    assert(#items%2==0,"Unpaired authored loot list")
    for index=1,#items,2 do
        local offset=#list+1
        list[offset],list[offset+1]=items[index],items[index+1]*(scale or 1)
        M.register(list,offset,option)
    end
    if active then M.apply() end
end

function M.registerTree(root,seen)
    if type(root)~="table" then return end
    seen=seen or {}
    if seen[root] then return end
    seen[root]=true
    for key,value in pairs(root) do
        if key=="items" and type(value)=="table" then
            for index=1,#value,2 do M.register(value,index) end
        elseif type(value)=="table" then M.registerTree(value,seen) end
    end
end

function M.apply()
    if isClient() then return end
    active=true
    local changed,conflicts=0,0
    for list,entries in pairs(pools) do
        local valid=true
        -- Другой мод мог переставить/перебалансировать список. Не ищем похожие
        -- записи по всему пулу и не переписываем чужие веса при конфликте.
        for _,entry in ipairs(entries) do
            if entry.present and (list[entry.index]~=entry.kind or list[entry.index+1]~=entry.last) then
                valid=false
            end
        end
        if not valid then
            conflicts=conflicts+1
        else
            local positions,output={},{}
            for _,entry in ipairs(entries) do
                local index=math.min(entry.index,#list+1)
                positions[index]=positions[index] or {}
                positions[index][#positions[index]+1]=entry
            end
            for index=1,#list+1,2 do
                local replace=false
                for _,entry in ipairs(positions[index] or {}) do
                    replace=replace or entry.present
                    entry.index=#output+1
                    entry.last=entry.baseline*factor(entry.kind,entry.option)
                    entry.present=entry.last>0
                    if entry.present then
                        output[#output+1]=entry.kind
                        output[#output+1]=entry.last
                    end
                    changed=changed+1
                end
                if index<=#list and not replace then
                    output[#output+1]=list[index]
                    output[#output+1]=list[index+1]
                end
            end
            -- Нулевой вес НЕ выключает native spawn: zombieDensity добавляет
            -- шанс даже при weight=0. Отключённые пары отсутствуют в списке;
            -- insertion index сохраняет их порядок при последующем включении.
            for index=#list,1,-1 do list[index]=nil end
            for index,value in ipairs(output) do list[index]=value end
        end
    end
    -- Сохранённые SandboxVars загружаются ПОСЛЕ первого ItemPicker.Parse.
    -- Этот публичный static API также обновляет SandboxLootSettings Java cache.
    IsoWorld.parseDistributions()
    lastSettings=settings()
    print("[HydrocraftReinvented] Sandbox loot entries="..changed..", conflicts="..conflicts)
    return changed,conflicts
end

Events.OnInitGlobalModData.Add(M.apply)

local ticks=0
function M.poll()
    if isClient() or not active then return end
    ticks=ticks+1
    if ticks%60==0 and settings()~=lastSettings then M.apply() end
end
Events.OnTickEvenPaused.Add(M.poll)
