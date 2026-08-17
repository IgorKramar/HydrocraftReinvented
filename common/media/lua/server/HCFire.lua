--Fire Risks

-- Мощность ожога по источнику тепла и порядок проверки — как в B41: срабатывает
-- первое совпадение, поэтому слабый источник перебивает сильный, если игрок
-- несёт оба. Ветка гончарной печи снята вместе с гончарством: в B42 оно ванильное,
-- предметов HCKiln в моде нет.
local HEAT_SOURCES = {
	{ power = 40,  types = { "HCSmelter", "HCSmelter2" } },
	{ power = 70,  types = { "HCBlastfurnace", "HCBlastfurnace2" } },
	{ power = 100, types = { "HCFurnace", "HCFurnace2" } },
}

-- Источник тепла ищется в инвентаре, а не в items. В B42 он входит в рецепт
-- с mode:keep, то есть не расходуется, а мост отдаёт в items только
-- getAllConsumedItems — печи там не будет никогда.
local function heatBurnPower(player)
	local inv = player:getInventory()
	for _, source in ipairs(HEAT_SOURCES) do
		for _, itemType in ipairs(source.types) do
			if inv:containsTypeRecurse(itemType) then
				return source.power
			end
		end
	end
	return 0
end


local function GenericBurn(items, result, player, burnPower)

	--print (player:getDescriptor():getProfession())

	local bgt=player:getBodyDamage();
	local bodyParts = {bgt:getBodyPart(BodyPartType.Hand_R),bgt:getBodyPart(BodyPartType.Hand_L),bgt:getBodyPart(BodyPartType.ForeArm_L),bgt:getBodyPart(BodyPartType.ForeArm_R),bgt:getBodyPart(BodyPartType.Torso_Upper),bgt:getBodyPart(BodyPartType.Head)}
	local bodyProtection = {0,0,0,0,0,0}

	local bodyPart=''
	local inv = player:getInventory():getItems()
	local count=0;


	--set protection
	for i = 0, inv:size() -1 do
		local item=inv:get(i)
		if item:isEquipped() then
			local itemType = item:getType()
			if itemType == "HCFiresuit" then bodyProtection[1]=200;
				break
			end

			if itemType == "HCWorkgloves"				then bodyProtection[1]=15;bodyProtection[2]=15;
			elseif itemType == "HCGlovesHardLeather"	then bodyProtection[1]=20;bodyProtection[2]=20;
			elseif itemType == "Jacket_Fireman"			then bodyProtection[3]=10;bodyProtection[4]=10;bodyProtection[5]=bodyProtection[5]+10;
			elseif itemType == "HCBlacksmithapron"		then bodyProtection[5]=bodyProtection[5]+15;
			elseif itemType == "Hat_Fireman" 			then bodyProtection[6]=bodyProtection[6]+10;
			elseif itemType == "WeldingMask" 			then bodyProtection[6]=bodyProtection[6]+10;
			elseif itemType == "Glasses_SafetyGoggles" 	then bodyProtection[6]=bodyProtection[6]+5;
			end --chk clothing item

		end -- is equiped?
	end -- loop

	--print ("Burnpower before proffesion/trait/random: " .. burnPower);

	if player:getTraits():contains('Lucky') then
		burnPower = burnPower - ZombRand(10);
	else
		burnPower = burnPower + ZombRand(15); 
	end

	local profession = player:getDescriptor():getProfession()
	if profession == "fireofficer" or profession == "metalworker" then
		burnPower = burnPower - 30
	end

	--print ("Burnpower after proffesion/trait/random: " .. burnPower);
	if burnPower > 100 then
		burnPower = 100
	end
	--print ("Burnpower - start" .. burnPower);

	if burnPower <= 0 then
		return
	end

	--Sandbox values: 1 = full, 2 = 50%, 3 = None
	-- Опции песочницы Hydrocraft в B42 не объявлены (файл потерян при порте,
	-- в Sandbox.json остались только переводы), поэтому SandboxVars.Hydrocraft
	-- равен nil и обращение к полю напрямую роняет обработчик. Защита — как
	-- в ProceduralDistributions_HC.lua. Без опции действует значение
	-- по умолчанию: урон полный.
	local hcSandbox = SandboxVars and SandboxVars.Hydrocraft
	local burnDamage = hcSandbox and hcSandbox.BurnDamage
	if(burnDamage ~= nil) then
		if(burnDamage == 2) then --50%
			burnPower = burnPower / 2
		elseif(burnDamage == 3) then --None
			burnPower = -100
		end
	end

	for count, bodyPart in ipairs(bodyParts) do

		burnPower=burnPower-bodyProtection[count] - ZombRand(10);
		--print("Protection:" .. bodyProtection[count]," Burnpower:  " .. burnPower)


		if (burnPower > 0) then
		bodyPart:AddDamage(burnPower);
		bodyPart:setBurned();
		player:getBodyDamage():SetBandaged(bodyPart:getIndex(), false, 0, false, nil);

		player:Say("Ouch, that burns!");
		player:getCurrentSquare():playSound("PZ_Fire", false);

		end

	end

end

-- Точка входа для 30 рецептов плавки: источник тепла у них задан списком
-- альтернатив, поэтому мощность определяется на месте, а не константой.
function getBurned(items, result, player)
	GenericBurn(items, result, player, heatBurnPower(player))
end

function KilnUse(items, result, player)
	GenericBurn(items, result, player, 10)
end

function SmelterUse(items, result, player)
	GenericBurn(items, result, player, 40)
end

function BlastFurnaceUse(items, result, player)
	GenericBurn(items, result, player, 70)
end

function IndustrialFurnaceUse(items, result, player)
	GenericBurn(items, result, player, 100)
end
