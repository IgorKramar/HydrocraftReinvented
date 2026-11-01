-- Фитнес-напиток сохраняет авторское питание рецепта и качество сырья.
require "HCR_SoftDrinkCatalog"
require "HCR_DrinkProducts"
HCRSoftDrinks={}
local fitness={sourceFood="Hydrocraft.HCFitnessdrink",target="Hydrocraft.HCCanteenFluid",
    fluid="HCRFitness",litres=1.4,vesselSlot=0}
function HCRSoftDrinks.createFitness(data,character)
    return HCRDrinkProducts.create(fitness,data,character)
end
