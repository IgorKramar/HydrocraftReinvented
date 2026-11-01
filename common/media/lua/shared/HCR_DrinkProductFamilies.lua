-- Генерируется tools/build_drink_products.py.
require "HCR_DrinkFamilies"
HCRDrinkProductFamilies = {["Hydrocraft.HCLemonade1"]={["target"]="Base.PopBottle",["litres"]=2,["fluid"]="HCRLemonade",["enabled"]=true,["product"]=true,["policy"]="legacy-native-vessel-capacity; current Food snapshot"},["Hydrocraft.HCLemonade2"]={["target"]="Base.WaterBottle",["litres"]=1,["fluid"]="HCRLemonade",["enabled"]=true,["product"]=true,["policy"]="legacy-native-vessel-capacity; current Food snapshot"}}
for kind,spec in pairs(HCRDrinkProductFamilies) do HCRDrinkFamilies[kind]=spec end
