-- Хмель возобновляется через штатный поиск; старый loot сохранён.
require 'Foraging/forageDefinitions'
require 'Foraging/forageSystem'
local function addHops()
    forageSystem.addForageDef('HCRHops',{
        type='Hydrocraft.HCHops',skill=4,minCount=1,maxCount=2,xp=3,
        categories={'WildHerbs'},
        zones={Forest=1,DeepForest=1,BirchForest=1,OrganicForest=1,
            PHForest=1,PRForest=1,FarmLand=1,Vegitation=1},
        months={8,9,10},bonusMonths={9},spawnFuncs={},
        altWorldTexture=forageSystem.worldSprites.wildPlants,
    })
end
Events.preAddForageDefs.Add(addHops)
