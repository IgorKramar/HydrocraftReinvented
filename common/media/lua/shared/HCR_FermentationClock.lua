-- Часы принадлежат партии жидкости, а не текущему предмету. Длительности
-- исходных восьми переходов берём из того же каталога, что legacy таймеры.
require 'HCR_TimedDefinitions'
require 'HCR_MashCatalog'
require 'HCR_BreweryCatalog'
HCRFermentationClock={VERSION=1}
local F=HCRFermentationClock
local musts={
    ['Hydrocraft.HCBarrelgrape']=true,['Hydrocraft.HCBarrelgrapegreen']=true,
    ['Hydrocraft.HCBarrelhoney']=true,['Hydrocraft.HCBarrelrice']=true,
}
local wines={
    ['Hydrocraft.HCBarrelwine']=true,['Hydrocraft.HCBarrelwinewhite']=true,
    ['Hydrocraft.HCBarrelmead']=true,['Hydrocraft.HCBarrelsake']=true,
}
local vinegar='Hydrocraft.HCBarrelvinegar'
local mashTransitions={}
for kind,rule in pairs(HCRMashCatalog.transitions) do mashTransitions[kind]=rule end
for kind,rule in pairs(HCRBreweryCatalog and HCRBreweryCatalog.transitions or {}) do mashTransitions[kind]=rule end
local terminals={}
for _,rule in pairs(mashTransitions) do terminals[rule.target]=true end
function F.transition(kind) return mashTransitions[kind] or HCRTimedDefinitions[kind] end
local function finite(n) return type(n)=='number' and n==n and n~=math.huge and n~=-math.huge end

function F.validate(clock)
    assert(type(clock)=='table' and clock.version==F.VERSION,'Unknown fermentation clock')
    assert(musts[clock.kind] or wines[clock.kind] or clock.kind==vinegar
        or mashTransitions[clock.kind] or terminals[clock.kind],'Unknown fermentation stage')
    assert(finite(clock.startedAt) and finite(clock.lastHour) and clock.startedAt<=clock.lastHour,
        'Invalid fermentation time')
    assert(type(clock.barrel)=='boolean','Missing fermentation storage')
    if clock.kind~=vinegar and not terminals[clock.kind] then
        local rule=F.transition(clock.kind)
        assert(rule and finite(rule.hours) and rule.hours>0,'Missing legacy fermentation transition')
    end
    return true
end

function F.advance(clock,now,inBarrel)
    F.validate(clock)
    assert(finite(now) and type(inBarrel)=='boolean','Invalid fermentation observation')
    local out={version=clock.version,kind=clock.kind,startedAt=clock.startedAt,
        lastHour=clock.lastHour,barrel=clock.barrel}
    if now<out.lastHour then
        -- При откате часов сохраняется накопленный интервал, а не добавляются
        -- повторные часы выдержки. Смена тары действует только после наблюдения.
        out.startedAt=out.startedAt+now-out.lastHour
    else
        local mash=mashTransitions[out.kind]
        if mash and now-out.startedAt>=mash.hours then
            out.kind=mash.target;out.startedAt=out.startedAt+mash.hours
        end
        if musts[out.kind] then
            local rule=HCRTimedDefinitions[out.kind]
            if now-out.startedAt>=rule.hours then
                out.kind=rule.target;out.startedAt=out.startedAt+rule.hours
            end
        end
        if wines[out.kind] then
            if out.barrel then
                local rule=HCRTimedDefinitions[out.kind]
                if now-out.startedAt>=rule.hours then
                    out.kind=rule.target;out.startedAt=out.startedAt+rule.hours
                end
            else
                -- В оригинале бутылочное вино стабильно; уксус получается
                -- при дальнейшей выдержке в бочке. Переливание приостанавливает
                -- эти часы, но не обнуляет уже накопленный срок.
                out.startedAt=out.startedAt+math.max(0,now-math.max(out.lastHour,out.startedAt))
            end
        end
    end
    out.lastHour=now;out.barrel=inBarrel
    F.validate(out)
    return out,out.kind~=clock.kind
end

function F.new(kind,startedAt,now,inBarrel)
    assert(finite(startedAt),'Missing saved fermentation start')
    return F.advance({version=F.VERSION,kind=kind,startedAt=startedAt,lastHour=startedAt,
        barrel=inBarrel},now,inBarrel)
end
