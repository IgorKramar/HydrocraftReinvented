require "HCR_DrinkFamilies"
-- Четыре исходных HC бокала на литр. Старые Food ID нужны для чтения сейва.
HCRWineFamilies={
    ["Hydrocraft.HCMead"]={target="Base.Whiskey",litres=1,fluid="HCRMead",enabled=true},
    ["Hydrocraft.HCSake"]={target="Base.Whiskey",litres=1,fluid="HCRSake",enabled=true},
    ["Hydrocraft.HCWineglass"]={target="Hydrocraft.HCWineglassFluid",litres=0,empty=true,enabled=true},
    ["Hydrocraft.HCWineglassfull"]={target="Hydrocraft.HCWineglassFluid",litres=.25,fluid="HCRWineWhite",enabled=true},
    ["Hydrocraft.HCWineglassfull2"]={target="Hydrocraft.HCWineglassFluid",litres=.25,fluid="HCRWineRed",enabled=true},
}
for kind,spec in pairs(HCRWineFamilies) do HCRDrinkFamilies[kind]=spec end
