-- Explicit private HCRLab only. Never copy this file into the distributable mod.
HCRLabFluids160 = HCRLabFluids160 or {}
local mark = "HCRLabFluids160Legacy"
local function guard(player, profile)
    assert(profile == "HCRLab" and player and not isClient() and not isServer())
end

function HCRLabFluids160.show(player, profile)
    guard(player, profile)
    local items=player:getInventory():getItems()
    for i=0,items:size()-1 do
        local item=items:get(i)
        if item:getModData()[mark] then
            ISFluidContainerMenu.showInfo(player,item:getFluidContainer())
            return
        end
    end
    error("saved flask fixture missing")
end

function HCRLabFluids160.prepareOldSave(player, profile)
    guard(player, profile)
    local inv = player:getInventory()
    local old = inv:AddItem("Hydrocraft.HCWaterflaskfull")
    assert(old and instanceof(old, "DrainableComboItem"))
    old:setCurrentUsesFloat(0.49)
    assert(old:getCurrentUses() == 7)
    old:setFavorite(true)
    old:setName("HCR16 inherited flask")
    old:setCustomName(true)
    old:getModData()[mark] = true
    old:getModData().keptNote = "native 1.5.12 saved stock"
    player:setPrimaryHandItem(old)
    print("[HCRFluids160] PREPARED native legacy save: 7 charges; save and cold-reload with 1.6 development files")
end

function HCRLabFluids160.verify(player, profile)
    guard(player, profile)
    local inv = player:getInventory()
    -- Earlier lab scenarios deliberately create heavy machinery. Native transfer
    -- rejects an overfull player inventory, so clear disposable unequipped stock.
    for i=inv:getItems():size()-1,0,-1 do
        local item=inv:getItems():get(i)
        if not item:getModData()[mark] and not item:isEquipped() then inv:Remove(item) end
    end
    assert(not player:hasFullInventory(),"private fixture inventory is overfull")
    HCRTimed.updateContainer(inv, getGameTime():getWorldAgeHours(), 0)
    HCRTimed.updateContainer(inv, getGameTime():getWorldAgeHours(), 0)
    local found = 0
    for i=0,inv:getItems():size()-1 do
        local item=inv:getItems():get(i)
        if item:getModData()[mark] then
            found=found+1
            assert(item:getFullType() == "Hydrocraft.HCWaterflaskFluid")
            assert(item:isFavorite() and item:isCustomName())
            assert(item:getModData().keptNote == "native 1.5.12 saved stock")
            local f=item:getFluidContainer()
            assert(f and math.abs(f:getAmount()-.7)<.00001)
            assert(math.abs(f:getSpecificFluidAmount(Fluid.TaintedWater)-.7)<.00001)
        end
    end
    assert(found==1,"saved stock missing/duplicated: "..found)
    local primary=player:getPrimaryHandItem()
    local held=inv:AddItem("Hydrocraft.HCWaterflaskfull")
    held:getModData().HCRLabHeld160=true
    held:setName("Native custom flask")
    held:setCustomName(true)
    player:setPrimaryHandItem(held)
    HCRTimed.updateContainer(inv,getGameTime():getWorldAgeHours(),0)
    local heldNew=player:getPrimaryHandItem()
    assert(heldNew and heldNew:getFullType()=="Hydrocraft.HCWaterflaskFluid")
    assert(heldNew:getModData().HCRLabHeld160)
    assert(heldNew:getModData().HCRLegacyCustomName=="Native custom flask")
    player:setPrimaryHandItem(primary)
    local empty=inv:AddItem("Hydrocraft.HCWaterflaskFluid")
    local f=empty:getFluidContainer()
    assert(f and f:isEmpty() and math.abs(f:getCapacity()-1.4)<.00001)
    assert(not f:canAddFluid(Fluid.Petrol),"waterflask accepted petrol")
    local bottle=inv:AddItem("Base.WaterBottle")
    local b=bottle:getFluidContainer()
    b:Empty();b:addFluid(Fluid.Water,1)
    assert(FluidContainer.CanTransfer(b,f))
    FluidContainer.Transfer(b,f,.45)
    assert(math.abs(b:getAmount()-.55)<.00001 and math.abs(f:getAmount()-.45)<.00001)
    FluidContainer.Transfer(f,b,.45)
    assert(f:isEmpty() and math.abs(b:getAmount()-1)<.00001)
    assert(inv:contains(empty),"empty native flask was destroyed")
    assert(HCRLabCraft and HCRLabCraft.nativeCraft and HCRLabCraft.findRecipe)
    local known=player:getKnownRecipes():contains("Make Waterflask")
    if not known then player:getKnownRecipes():add("Make Waterflask") end
    local leather={inv:AddItem("Hydrocraft.HCLeather"),inv:AddItem("Hydrocraft.HCLeather")}
    local bench={inv:AddItem("Hydrocraft.HCTailoringbench2")}
    local thread={inv:AddItem("Base.Thread")}
    local outputs=HCRLabCraft.nativeCraft(player,HCRLabCraft.findRecipe("Make Waterflask"),{leather,bench,thread})
    local made=0
    for i=0,outputs:size()-1 do
        local item=outputs:get(i)
        if item:getFullType()=="Hydrocraft.HCWaterflaskFluid" then
            made=made+1;assert(item:getFluidContainer():isEmpty(),"craft created free water")
        end
    end
    assert(made==1 and bench[1]:getContainer()==inv)
    if not known then player:getKnownRecipes():remove("Make Waterflask") end
    f:addFluid(Fluid.Water,.5)
    local brush={inv:AddItem("Base.Toothbrush")}
    local paste={inv:AddItem("Hydrocraft.HCToothpasteopen")}
    HCRLabCraft.nativeCraft(player,HCRLabCraft.findRecipe("Brush Teeth"),{brush,{empty},paste})
    assert(math.abs(f:getAmount()-.4)<.00001 and empty:getContainer()==inv,
        "native craft did not retain flask and consume exactly .1L")
    print("[HCRFluids160] PASS native Make Waterflask creates one empty flask; Brush Teeth consumes .1L and retains it")
    print("[HCRFluids160] PASS native 1.5.12 save migration, 7 charges=.7L tainted; state/held identity and exactly-once stock; native empty 1.4L flask, water transfer conservation and petrol rejection")
end

function HCRLabFluids160.verifyReload(player, profile)
    guard(player, profile)
    local items=player:getInventory():getItems()
    local found=0
    for i=0,items:size()-1 do
        local item=items:get(i)
        if item:getModData()[mark] then
            found=found+1
            assert(item:getFullType()=="Hydrocraft.HCWaterflaskFluid")
            assert(item:isFavorite() and item:isCustomName())
            assert(item:getModData().keptNote=="native 1.5.12 saved stock")
            assert(math.abs(item:getFluidContainer():getAmount()-.7)<.00001)
            assert(math.abs(item:getFluidContainer():getSpecificFluidAmount(Fluid.TaintedWater)-.7)<.00001)
        end
    end
    assert(found==1,"native reload lost/duplicated saved flask")
    print("[HCRFluids160] PASS second cold load preserves one native flask, .7L tainted, favourite/custom flag and modData")
end
