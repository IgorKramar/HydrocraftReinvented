-- Только частный HCRLab. Отказы проверяются перед обращением к объектам-целям.
require "HCR_FluidBoundaries"
require "HCR_DrinkFluids"
HCRLabFluidBoundaries = {}

function HCRLabFluidBoundaries.run(player, profile)
    assert(profile == "HCRLab" and player and not isClient() and not isServer())
    local Q, L, E = HCRFluidQuality, HCRFluidLedger, HCRFluidEffects
    local item = player:getInventory():AddItem("Base.WaterBottle")
    local fluid = Q.fluid(item)
    fluid:Empty(); fluid:addFluid("HCRJuiceApple", .2); fluid:addFluid(Fluid.Water, .2)
    local food = instanceItem("Hydrocraft.HCMilkjug")
    food:setPoisonPower(10)
    Q.store(item, fluid, L.batch("HCRJuiceApple", fluid:getSpecificFluidAmount(Fluid.Get("HCRJuiceApple")),
        E.snapshot(food), getGameTime():getWorldAgeHours()))
    local cases = {
        {ISWaterPlantAction,"complete","item"},
        {ISGiveWaterToAnimal,"update","item"},
        {ISAddWaterToTrough,"updateAddingWater","itemFrom"},
        {ISGatherBloodFromAnimal,"updateBucket","bucket"},
        {ISHutchCleanFloor,"clean","water"},
        {ISMilkAnimal,"milk","bucket"},
        {ISMilkAnimal,"stress","bucket"},
        {ISAddTakeDispenserBottle,"complete","bottle"},
        {ISOpenCloseLid,"complete","barrel"},
        {ISDrinkFromBottle,"drink","item"},
        {ISWashClothing,"complete","sink"},
        {ISWashYourself,"complete","sink"},
        {ISCleanBandage,"complete","waterObject"},
        {ISDisinfect,"complete","alcohol"},
        {ISCleanBlood,"complete","cleaner"},
        {ISCleanGraffiti,"complete","cleaner"},
        {ISWashVehicle,"removeBlood","unused"},
        {ISPutOutFire,"useItem","item"},
        {ISPutOutFire,"complete","item"},
    }
    for _, case in ipairs(cases) do
        local action = {character=player, [case[3]]=item}
        if case[1] == ISHutchCleanFloor then action.bleach=item end
        local before = Q.rawAmount(fluid)
        local ok, result = pcall(case[1][case[2]], action)
        assert(ok and result == false and action.hcrFluidRefused,
            "Boundary did not refuse: "..tostring(case[1].Type).."."..case[2])
        assert(Q.rawAmount(fluid) == before and L.budget(item:getModData()[Q.key],"poisonPower") == 10,
            "Boundary changed liquid before refusing")
    end
    local soaps=ArrayList.new(); soaps:add(item)
    local washing={character=player,soaps=soaps}
    assert(ISWashClothing.useSoap(washing)==false and washing.hcrFluidRefused,
        "Soap-only route changed tracked liquid")
    player:getInventory():Remove(item)
    print("[HCRBoundaries160] 20 native action entry points refuse tracked mixtures before effects PASS")
end
