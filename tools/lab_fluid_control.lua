-- Командный файл доступен только частному HCRLab, не включать в дистрибутив.
local tick, last = 0, nil
Events.OnTick.Add(function()
    if isClient() or isServer() then return end
    tick=tick+1
    if tick%60~=0 then return end
    local reader=getFileReader("HCRLabFluidCommand.txt",false)
    if not reader then return end
    local line=reader:readLine();reader:close()
    if not line or line==last then return end
    last=line
    local sequence,command=line:match("^(%d+):([%w]+)$")
    if not command then return end
    local ok,reason=pcall(function()
        if command=="quality" then
            reloadLuaFile("media/lua/shared/HCRLabQuality.lua")
            HCRLabQuality.run(getSpecificPlayer(0),"HCRLab")
        elseif command=="water" then
            reloadLuaFile("media/lua/shared/HCRLabWaterFamilies.lua")
            HCRLabWaterFamilies.run(getSpecificPlayer(0),"HCRLab")
        elseif command=="boundaries" then
            reloadLuaFile("media/lua/shared/HCRLabFluidBoundaries.lua")
            HCRLabFluidBoundaries.run(getSpecificPlayer(0),"HCRLab")
        elseif command=="juices" then
            reloadLuaFile("media/lua/shared/HCRLabJuices.lua")
            HCRLabJuices.run(getSpecificPlayer(0),"HCRLab")
        elseif command=="juiceui" then
            reloadLuaFile("media/lua/shared/HCRLabJuices.lua")
            HCRLabJuices.show(getSpecificPlayer(0),"HCRLab")
        elseif command=="sandbox" then
            reloadLuaFile("media/lua/shared/HCRLabSandbox.lua")
            HCRLabSandbox.run(getSpecificPlayer(0),"HCRLab")
        elseif command=="sandboxui" then
            reloadLuaFile("media/lua/shared/HCRLabSandbox.lua")
            HCRLabSandbox.show(getSpecificPlayer(0),"HCRLab")
        elseif command=="sandboxlive" then
            reloadLuaFile("media/lua/shared/HCRLabSandbox.lua")
            HCRLabSandbox.live(getSpecificPlayer(0),"HCRLab")
        elseif command=="foodquality" then
            reloadLuaFile("media/lua/shared/HCRLabFoodQuality.lua")
            HCRLabFoodQuality.run(getSpecificPlayer(0),"HCRLab")
        elseif command=="fluidrecipe" then
            reloadLuaFile("media/lua/shared/HCRLabFluidRecipeQuality.lua")
            HCRLabFluidRecipeQuality.run(getSpecificPlayer(0),"HCRLab")
        elseif command=="freshseed" then
            reloadLuaFile("media/lua/shared/HCRLabFluidRecipeQuality.lua")
            HCRLabFluidRecipeQuality.seed(getSpecificPlayer(0),"HCRLab")
        elseif command=="freshverify" then
            reloadLuaFile("media/lua/shared/HCRLabFluidRecipeQuality.lua")
            HCRLabFluidRecipeQuality.verify(getSpecificPlayer(0),"HCRLab")
        elseif command=="retail" then
            reloadLuaFile("media/lua/shared/HCRLabRetailDrinks.lua")
            HCRLabRetailDrinks.run(getSpecificPlayer(0),"HCRLab")
        elseif command=="products" then
            reloadLuaFile("media/lua/shared/HCRLabDrinkProducts.lua")
            HCRLabDrinkProducts.run(getSpecificPlayer(0),"HCRLab")
        elseif command=="coffee" then
            reloadLuaFile("media/lua/shared/HCRLabCoffee.lua")
            HCRLabCoffee.run(getSpecificPlayer(0))
        elseif command=="alcohol" then
            reloadLuaFile("media/lua/shared/HCRLabAlcohol.lua")
            HCRLabAlcohol.run(getSpecificPlayer(0))
        elseif command=="beer" or command=="beerverify" then
            reloadLuaFile("media/lua/shared/HCRLabBeer.lua")
            if command=="beer" then HCRLabBeer.run(getSpecificPlayer(0))
            else HCRLabBeer.verify(getSpecificPlayer(0)) end
        elseif command=="whiskey" or command=="whiskeyverify" then
            reloadLuaFile("media/lua/shared/HCRLabNativeWhiskey.lua")
            if command=="whiskey" then HCRLabNativeWhiskey.run(getSpecificPlayer(0))
            else HCRLabNativeWhiskey.verify(getSpecificPlayer(0)) end
        elseif command=="bar" or command=="barverify" or command=="barshow" or command=="barchain" then
            reloadLuaFile("media/lua/shared/HCRLabSpirits.lua")
            reloadLuaFile("media/lua/shared/HCRLabBar.lua")
            if command=="bar" then HCRLabBar.run(getSpecificPlayer(0))
            elseif command=="barverify" then HCRLabBar.verify(getSpecificPlayer(0))
            elseif command=="barchain" then HCRLabBar.chain(getSpecificPlayer(0))
            else HCRLabBar.show(getSpecificPlayer(0)) end
        elseif command=="soft" or command=="softverify" or command=="softshow" or command=="softgym" then
            reloadLuaFile("media/lua/shared/HCRLabSpirits.lua")
            reloadLuaFile("media/lua/shared/HCRLabSoft.lua")
            if command=="soft" then HCRLabSoft.run(getSpecificPlayer(0))
            elseif command=="softverify" then HCRLabSoft.verify(getSpecificPlayer(0))
            elseif command=="softgym" then HCRLabSoft.gym(getSpecificPlayer(0))
            else HCRLabSoft.show(getSpecificPlayer(0)) end
        elseif command=="cocktails" or command=="cocktailsverify" or command=="cocktailsshow" then
            reloadLuaFile("media/lua/shared/HCRLabSpirits.lua")
            reloadLuaFile("media/lua/shared/HCRLabCocktails.lua")
            if command=="cocktails" then HCRLabCocktails.run(getSpecificPlayer(0))
            elseif command=="cocktailsverify" then HCRLabCocktails.verify(getSpecificPlayer(0))
            else HCRLabCocktails.show(getSpecificPlayer(0)) end
        elseif command=="milkbar" or command=="milkbarverify" then
            reloadLuaFile("media/lua/shared/HCRLabSpirits.lua")
            reloadLuaFile("media/lua/shared/HCRLabMilkCocktails.lua")
            if command=="milkbar" then HCRLabMilkCocktails.run(getSpecificPlayer(0))
            else HCRLabMilkCocktails.verify(getSpecificPlayer(0)) end
        elseif command=="medicine" or command=="medicineverify" then
            reloadLuaFile("media/lua/shared/HCRLabSpirits.lua")
            reloadLuaFile("media/lua/shared/HCRLabMedicine.lua")
            if command=="medicine" then HCRLabMedicine.run(getSpecificPlayer(0))
            else HCRLabMedicine.verify(getSpecificPlayer(0)) end
        elseif command=="aguaguard" then
            reloadLuaFile("media/lua/shared/HCRLabSpirits.lua")
            HCRLabSpirits.guard(getSpecificPlayer(0))
        elseif command=="spirits" or command=="spiritsverify" then
            reloadLuaFile("media/lua/shared/HCRLabSpirits.lua")
            if command=="spirits" then HCRLabSpirits.run(getSpecificPlayer(0))
            else HCRLabSpirits.verify(getSpecificPlayer(0)) end
        elseif command=="exit" then
            MainScreen.instance:quitToDesktop()
        elseif command=="alcoholseed" then
            reloadLuaFile("media/lua/shared/HCRLabAlcohol.lua")
            HCRLabAlcohol.seed(getSpecificPlayer(0))
        elseif command=="alcoholverify" then
            reloadLuaFile("media/lua/shared/HCRLabAlcohol.lua")
            HCRLabAlcohol.verify(getSpecificPlayer(0))
        elseif command=="wine" then
            reloadLuaFile("media/lua/shared/HCRLabWine.lua")
            HCRLabWine.run(getSpecificPlayer(0),"HCRLab")
        elseif command=="wineseed" then
            reloadLuaFile("media/lua/shared/HCRLabWine.lua")
            HCRLabWine.seed(getSpecificPlayer(0))
        elseif command=="wineverify" then
            reloadLuaFile("media/lua/shared/HCRLabWine.lua")
            HCRLabWine.verify(getSpecificPlayer(0))
        elseif command=="milk" then
            reloadLuaFile("media/lua/shared/HCRLabMilkChains.lua")
            HCRLabMilkChains.run(getSpecificPlayer(0),"HCRLab")
        elseif command=="storageprobe" then
            reloadLuaFile("media/lua/shared/HCRLabStorage.lua")
            HCRLabStorage.probe(getSpecificPlayer(0),"HCRLab")
        elseif command=="day" then
            getGameTime():setTimeOfDay(12) -- Только одноразовый мир HCRLab.
        else error("Unknown private fluid test command") end
    end)
    print("[HCRFluidControl] "..sequence..":"..command.." "..(ok and "PASS" or "FAIL "..tostring(reason)))
end)
