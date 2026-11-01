-- Только частный HCRLab: настройки возвращаются после проверки даже при ошибке.
require "HCR_Sandbox"
require "HCR_SandboxLoot"
HCRLabSandbox={}
local function near(a,b,label)
    assert(math.abs(a-b)<.0001,label..": "..tostring(a).." != "..tostring(b))
end
local function weight(list,kind)
    local total,count=0,0
    for i=1,#list,2 do
        if list[i]==kind then total=total+list[i+1];count=count+1 end
    end
    return total,count
end

function HCRLabSandbox.show(player,profile)
    assert(profile=="HCRLab" and player and not isClient() and not isServer())
    if ISServerSandboxOptionsUI.instance then ISServerSandboxOptionsUI.instance:close() end
    local ui=ISServerSandboxOptionsUI:new(80,40,1100,620)
    ui:initialise();ui:addToUIManager()
    HCRLabSandboxUI=ui
end

function HCRLabSandbox.run(player,profile)
    assert(profile=="HCRLab" and player and not isClient() and not isServer())
    local options=getSandboxOptions()
    local saved={}
    local function set(name,value)
        local option=assert(options:getOptionByName("Hydrocraft."..name),"Missing sandbox option "..name)
        if saved[name]==nil then saved[name]={option:getValue()} end
        option:setValue(value);options:toLua()
        assert(SandboxVars.Hydrocraft[name]==value,"Native option did not reach Lua")
    end
    local ok,reason=pcall(function()
        for _,name in ipairs({"LootMultiplier","MiningSpeedMultiplier","EnableCannabis","EnableMeth",
            "EnableOpium","EnableTobacco","SpawnHydrocraftGuns","SpawnBookCovers","SpawnCigaretteButts","BurnDamage"}) do
            assert(options:getOptionByName("Hydrocraft."..name),name)
        end
        print("[HCRSandbox160] all 10 native sandbox definitions loaded PASS")
        local pool=ProceduralDistributions.list.KitchenDishes.items
        local base=weight(pool,"Hydrocraft.HCPlasticplate")
        assert(base>0,"Native seed not registered")
        local vanilla=weight(pool,"Base.Plate")
        set("LootMultiplier",2);local _,conflicts=HCRSandboxLoot.apply()
        assert(conflicts==0,"Authored pool conflict in vanilla lab")
        near(weight(pool,"Hydrocraft.HCPlasticplate"),base*2,"double authored weight")
        HCRSandboxLoot.apply()
        near(weight(pool,"Hydrocraft.HCPlasticplate"),base*2,"repeat not compounded")
        near(weight(pool,"Base.Plate"),vanilla,"vanilla weight unchanged")
        set("LootMultiplier",0);HCRSandboxLoot.apply()
        local _,count=weight(pool,"Hydrocraft.HCPlasticplate")
        assert(count==0,"Disabled pair still present")
        set("LootMultiplier",1);HCRSandboxLoot.apply()
        near(weight(pool,"Hydrocraft.HCPlasticplate"),base,"original weight restored")
        local _,restoredCount=weight(pool,"Hydrocraft.HCPlasticplate")
        assert(restoredCount==1,"Restored seed duplicate")
        print("[HCRSandbox160] live authored loot x2/repeat/zero/remove/restore + Java reparse PASS")
        for _,entry in ipairs({{"EnableCannabis","Cure Hemp Bud"},{"EnableMeth","Make Homemade Crystal Meth"},
            {"EnableOpium","Dry Poppy Flower"},{"EnableTobacco","Dry Leaves"}}) do
            local recipe=HCRLabCraft.findRecipe(entry[2])
            local logic=HandcraftLogic.new(player,nil,nil);logic:setRecipe(recipe)
            local action={character=player,craftRecipe=recipe,logic=logic}
            set(entry[1],false)
            assert(not HCRSandbox.recipeEnabled(recipe),"Recipe gate absent")
            assert(ISHandcraftAction.performRecipe(action)==false,"Disabled craft reached mutation")
            set(entry[1],true)
            assert(HCRSandbox.recipeEnabled(recipe),"Recipe not restored")
        end
        print("[HCRSandbox160] four native production gates before ingredient lookup PASS")
        local mine=HCRLabCraft.findRecipe("Mine Iron")
        local action={character=player,craftRecipe=mine}
        set("MiningSpeedMultiplier",1)
        local duration=ISHandcraftAction.getDuration(action)
        assert(duration>1,"Disable private instant action cheat for duration test")
        set("MiningSpeedMultiplier",2)
        near(ISHandcraftAction.getDuration(action),duration/2,"mining duration")
        local normal=HCRLabCraft.findRecipe("Cure Hemp Bud")
        action.craftRecipe=normal
        near(ISHandcraftAction.getDuration(action),normal:getTime(player)*5,"ordinary duration")
        print("[HCRSandbox160] native mining duration halved; ordinary recipe unchanged PASS")
    end)
    for name,entry in pairs(saved) do options:getOptionByName("Hydrocraft."..name):setValue(entry[1]) end
    options:toLua();HCRSandboxLoot.apply()
    assert(ok,reason)
end

function HCRLabSandbox.live(player,profile)
    assert(profile=="HCRLab" and player and not isClient() and not isServer())
    local options=getSandboxOptions()
    local option=options:getOptionByName("Hydrocraft.LootMultiplier")
    local previous=option:getValue()
    assert(previous==1,"Live fixture requires default multiplier")
    local pool=ProceduralDistributions.list.KitchenDishes.items
    local original=weight(pool,"Hydrocraft.HCPlasticplate")
    local luaValue=SandboxVars.Hydrocraft.LootMultiplier
    local ticks=0
    options:set("Hydrocraft.LootMultiplier",2) -- Тот же путь, что SP admin UI; без toLua/apply.
    local check
    check=function()
        ticks=ticks+1
        if ticks~=180 and ticks~=360 then return end
        local ok,reason=pcall(function()
            near(weight(pool,"Hydrocraft.HCPlasticplate"),original*(ticks==180 and 2 or 1),"live admin multiplier")
            assert(SandboxVars.Hydrocraft.LootMultiplier==luaValue,"Fixture unexpectedly refreshed SandboxVars")
        end)
        options:set("Hydrocraft.LootMultiplier",previous)
        if not ok or ticks==360 then
            Events.OnTickEvenPaused.Remove(check)
            print("[HCRSandbox160] live admin update without toLua "..(ok and "PASS" or "FAIL "..tostring(reason)))
        end
    end
    Events.OnTickEvenPaused.Add(check)
end
