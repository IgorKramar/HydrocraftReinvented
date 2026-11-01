require "Entity/TimedActions/ISHandcraftAction"
require "HCR_Sandbox"
local S=HCRSandbox
local originalValid=ISHandcraftAction.isValid
local originalPerform=ISHandcraftAction.performRecipe
local originalDuration=ISHandcraftAction.getDuration

function ISHandcraftAction:isValid(...)
    local recipe=self.logic and self.logic:getRecipeData():getRecipe() or self.craftRecipe
    return S.recipeEnabled(recipe) and originalValid(self,...)
end

function ISHandcraftAction:performRecipe(...)
    local recipe=self.logic and self.logic:getRecipeData():getRecipe() or self.craftRecipe
    if not S.recipeEnabled(recipe) then
        if self.character then
            if isServer() then
                sendServerCommand(self.character,"HCRSandbox","RecipeDisabled",{})
            elseif HaloTextHelper then
                HaloTextHelper.addBadText(self.character,getText("IGUI_HCR_ProductionDisabled"))
            end
        end
        return false -- Проверка до расхода ингредиентов, в том числе на сервере.
    end
    return originalPerform(self,...)
end

function ISHandcraftAction:getDuration(...)
    local duration=originalDuration(self,...)
    local recipe=self.craftRecipe
    if duration<=1 or not recipe or not HCRSandboxCatalog.mining[recipe:getName()] then return duration end
    return math.max(1,duration/S.multiplier("MiningSpeedMultiplier",.1,10))
end

if Events.OnServerCommand then
    Events.OnServerCommand.Add(function(module,command)
        if module=="HCRSandbox" and command=="RecipeDisabled" and HaloTextHelper then
            local player=getSpecificPlayer(0)
            if player then HaloTextHelper.addBadText(player,getText("IGUI_HCR_ProductionDisabled")) end
        end
    end)
end
