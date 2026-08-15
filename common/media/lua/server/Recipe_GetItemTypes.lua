
--These will exist, but just in case
HCRecipe = HCRecipe or {}
HCRecipe.GetItemTypes = HCRecipe.GetItemTypes or {}
--TODO: rename to Hydrocraft.GetItemTypes, to make it clearer which are vanilla and which are HC?

function HCRecipe.GetItemTypes.LeatherGloves(scriptItems)
	local all = getScriptManager():getAllItems()
	for i=0, all:size()-1 do
		local item = all:get(i)
		if item:getTypeString() == "Clothing" and item:getBodyLocation() == "Hands" and item:getFabricType() == "Leather" then
			scriptItems:add(item)
		end
	end
end

function HCRecipe.GetItemTypes.BlacksmithTongs(scriptItems)
	scriptItems:addAll(getScriptManager():getItemsTag("BlacksmithTongs"))
end

function HCRecipe.GetItemTypes.Potato(scriptItems)
	scriptItems:addAll(getScriptManager():getItemsTag("Potato"))
end

function HCRecipe.GetItemTypes.RoastingPanFull(scriptItems)
	scriptItems:addAll(getScriptManager():getItemsTag("RoastingPanFull"))
end

function HCRecipe.GetItemTypes.PaperBagFull(scriptItems)
	scriptItems:addAll(getScriptManager():getItemsTag("PaperBagFull"))
end

function HCRecipe.GetItemTypes.ServeInPaperBag(scriptItems)
	scriptItems:addAll(getScriptManager():getItemsTag("ServeInPaperBag"))
end

function HCRecipe.GetItemTypes.Box12(scriptItems)
	scriptItems:addAll(getScriptManager():getItemsTag("Box12"))
end

function HCRecipe.GetItemTypes.Box25(scriptItems)
	scriptItems:addAll(getScriptManager():getItemsTag("Box25"))
end

function HCRecipe.GetItemTypes.Box50(scriptItems)
	scriptItems:addAll(getScriptManager():getItemsTag("Box50"))
end

function HCRecipe.GetItemTypes.Box100(scriptItems)
	scriptItems:addAll(getScriptManager():getItemsTag("Box100"))
end

--Note: Recipe.GetItemTypes.Milk exists in Vanilla PZ
function HCRecipe.GetItemTypes.Cereal(scriptItems)
	scriptItems:addAll(getScriptManager():getItemsTag("Cereal"))
end

function HCRecipe.GetItemTypes.NylonBag(scriptItems)
	scriptItems:addAll(getScriptManager():getItemsTag("NylonBag"))
end

function HCRecipe.GetItemTypes.HuntingShotgun(scriptItems)
	scriptItems:addAll(getScriptManager():getItemsTag("HuntingShotgun"))
end

function HCRecipe.GetItemTypes.BooksWithNumberOfPages(scriptItems)
	local all = getScriptManager():getAllItems()
	for i=0, all:size()-1 do
		local item = all:get(i)
		local pageCount = item:getNumberOfPages() --returns -1 for NA, or 220, 260, etc.

		if pageCount > 0 then
			scriptItems:add( item )
		end
	end
end

function HCRecipe.GetItemTypes.FoodThatCanRot(scriptItems)
	local all = getScriptManager():getAllItems()
	for i=0, all:size()-1 do
		local item = all:get(i)
		if item:getTypeString() == "Food" and item:getDaysTotallyRotten() > 0 then
			scriptItems:add( item )
		end
	end
end

function HCRecipe.GetItemTypes.Shit(scriptItems)
	scriptItems:addAll(getScriptManager():getItemsTag("Shit"))
end

function HCRecipe.GetItemTypes.BucketConcrete(scriptItems)
	scriptItems:addAll(getScriptManager():getItemsTag("BucketConcrete"))
end