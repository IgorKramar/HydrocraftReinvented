-- Только отдельный профиль HCRLab; не входит в пакет мода.
require "HCR_WaterFamilies"
require "HCR_FluidRecipes"
HCRLabWaterFamilies = {}

local function near(a,b,label)
    assert(math.abs(a-b)<.00001, label..": "..tostring(a).." / "..tostring(b))
end

function HCRLabWaterFamilies.run(player, profile)
    assert(profile=="HCRLab" and player and not isClient() and not isServer())
    local count, cases = 0, 0
    for kind, definition in pairs(HCRWaterFamilies.migrations) do
        count=count+1
        for _, fraction in ipairs({0, .5, .999, 1}) do
            local old=instanceItem(kind)
            assert(old, "Missing old vessel "..kind)
            if instanceof(old,"DrainableComboItem") then old:setCurrentUsesFloat(fraction) end
            old:setFavorite(true);old:getModData().HCRWaterTest="keep"
            local amount=old:getCurrentUses()*definition.unitLitres
            local new=HCRItemMigrations.newReplacement(old)
            assert(new and new:getFullType()==definition.target, "Migration failed "..kind)
            local fluid=new:getFluidContainer()
            near(fluid:getAmount(),amount,kind)
            near(fluid:getSpecificFluidAmount(Fluid.TaintedWater),amount,kind.." purity")
            assert(new:isFavorite() and new:getModData().HCRWaterTest=="keep")
            assert(not HCRItemMigrations.newReplacement(new),"Migration repeated")
            cases=cases+1
        end
    end
    assert(count==122 and cases==488)
    print("[HCRWater160] 122 legacy IDs, 488 native stock/state migrations PASS")

    local inv=player:getInventory()
    local created={}
    local function add(kind)
        local item=inv:AddItem(kind);created[#created+1]=item;return item
    end
    local function craft(name,groups)
        local known=player:getKnownRecipes():contains(name)
        if not known then player:getKnownRecipes():add(name) end
        local result=HCRLabCraft.nativeCraft(player,HCRLabCraft.findRecipe(name),groups)
        if not known then player:getKnownRecipes():remove(name) end
        return result
    end
    local rule
    for _,r in pairs(HCRWaterRecipeRules) do if r.name=="Purify Water" then rule=r end end
    local kind
    for k in pairs(rule.water) do kind=k end
    local vessel=add(kind)
    local f=vessel:getFluidContainer();f:Empty();f:addFluid(Fluid.TaintedWater,.37)
    local tablets=add("Hydrocraft.HCPurifyingtablets")
    -- Подбираем порядок реальных входов из зарегистрированного рецепта.
    local recipe=HCRLabCraft.findRecipe("Purify Water")
    local groups={}
    for i=0,recipe:getInputs():size()-1 do
        local input=recipe:getInputs():get(i)
        print("[HCRWater160] input "..i.." "..input:getOriginalLine().." vessel="..tostring(input:containsItem(vessel:getScriptItem())))
        if input:containsItem(vessel:getScriptItem()) then groups[#groups+1]={vessel}
        else groups[#groups+1]={tablets} end
    end
    print("[HCRWater160] purify "..kind.." amount="..f:getAmount().." taint="..f:getSpecificFluidAmount(Fluid.TaintedWater).." ontest="..tostring(HCRFluidRecipes.test(rule,vessel,player)))
    craft("Purify Water",groups)
    assert(vessel:getContainer()==inv)
    near(f:getAmount(),.37,"purified volume");near(f:getSpecificFluidAmount(Fluid.Water),.37,"purified clean")
    print("[HCRWater160] native purification retains vessel and partial .37 L PASS")

    local beaker=add("Hydrocraft.HCGlassbeakerFluid")
    local dropper=add("Hydrocraft.HCEyedropperwater")
    local lab=add("Hydrocraft.HCLab2")
    local before=inv:getCountTypeRecurse("Hydrocraft.HCGlassbeakerFluid")
    craft("Put Water In Beaker",{{dropper},{beaker},{lab}})
    near(beaker:getFluidContainer():getAmount(),.1,"dropper fill")
    assert(beaker:getContainer()==inv and dropper:getContainer()==nil)
    local empty=inv:getFirstTypeRecurse("Hydrocraft.HCEyedropper")
    assert(empty,"Missing returned eyedropper")
    craft("Remove Water From Beaker",{{empty},{beaker},{lab}})
    near(beaker:getFluidContainer():getAmount(),0,"dropper withdrawal")
    assert(beaker:getContainer()==inv)
    assert(inv:getCountTypeRecurse("Hydrocraft.HCGlassbeakerFluid")==before,"Duplicated beaker")
    print("[HCRWater160] native dropper closed cycle .1 L, one beaker PASS")
    for _,item in ipairs(created) do if item:getContainer()==inv then inv:Remove(item) end end
    print("[HCRWater160] ALL PASS")
end

-- Запускается явно через HCRLabFluidControl после подготовки света и инвентаря.
