-- Private 1.5.12 -> 1.6.0 saved-world fixture. Specs exported from release catalogue.
HCRLabReleaseMigration={}
local M=HCRLabReleaseMigration
local function log(s) print('[HCRReleaseMigration] '..s) end
local function near(a,b,label) assert(a and math.abs(a-b)<.002,label..' '..tostring(a)..' / '..tostring(b)) end
function M.seed()
 assert(not HCRFluidQuality,'Seed must run with actual pre-fluids release')
 local r=assert(getFileReader('HCRLegacySpecs.txt',false));local lines={};local line=r:readLine()
 while line do lines[#lines+1]=line;line=r:readLine() end;r:close()
 local specs=assert(loadstring(table.concat(lines,'\n')))();local p=getPlayer();p:setUnlimitedCarry(true)
 local held=p:getInventory():AddItem('Base.Bag_Schoolbag');local ground=instanceItem('Base.Bag_Schoolbag')
 local holders={held,ground};local containers={}
 for i,bag in ipairs(holders) do
  bag:getModData().HCRReleaseMigration={rows={},version='1.5.12',boot=tostring(getTimestampMs())}
  containers[i]=bag:getItemContainer():AddItem('Base.Bag_Schoolbag'):getItemContainer()
 end
 local count,skipped=0,0
 for _,spec in ipairs(specs) do
  local script=getScriptManager():FindItem(spec.kind)
  if script then
   local item=assert(instanceItem(spec.kind));local slot=count%2+1;containers[slot]:AddItem(item)
   item:getModData().HCRReleaseFixture=spec.kind;item:setFavorite(true);item:setName('saved stock '..spec.kind);item:setCustomName(true)
   if item:IsDrainable() then item:setCurrentUsesFloat(.49) end
   if item:IsFood() then
    if item:getBaseHunger()<0 then item:setHungChange(item:getBaseHunger()*.5)
    elseif spec.remaining=='native-zero-hunger-thirst' then item:setThirstChange(item:getScriptItem():getThirstChange()/200) end
    item:setCalories(137);item:setCarbohydrates(23);item:setProteins(7);item:setLipids(3)
    item:setOffAge(1);item:setOffAgeMax(2);item:setAge(2.5);item:setPoisonPower(3);item:setPoisonDetectionLevel(4)
    if spec.cooked then item:setCooked(true) end
    spec.food=true;spec.fraction=item:getBaseHunger()<0 and item:getHungChange()/item:getBaseHunger() or .5
   end
   spec.oldId=item:getID();spec.uses=item:IsDrainable() and item:getCurrentUses() or 0
   spec.nativeAmount=item:getFluidContainer() and item:getFluidContainer():getAmount() or nil
   local rows=holders[slot]:getModData().HCRReleaseMigration.rows;rows[#rows+1]=spec;count=count+1
  else skipped=skipped+1 end
 end
 p:getSquare():AddWorldInventoryItem(ground,.4,.4,0,true)
 assert(count>150,'Incomplete legacy catalogue');log('SEED PASS actual 1.5.12 '..count..' stocks, '..skipped..' post-release IDs skipped')
end
local function bags(p)
 local result={};local function visit(inv)
  for i=0,inv:getItems():size()-1 do local item=inv:getItems():get(i)
   if item:getModData().HCRReleaseMigration then result[#result+1]=item end
  end
 end
 visit(p:getInventory());local sq=p:getSquare()
 for x=sq:getX()-2,sq:getX()+2 do for y=sq:getY()-2,sq:getY()+2 do local s=getCell():getGridSquare(x,y,sq:getZ())
  if s then for i=0,s:getWorldObjects():size()-1 do local item=s:getWorldObjects():get(i):getItem()
   if item and item:getModData().HCRReleaseMigration then result[#result+1]=item end
  end end
 end end
 return result
end
function M.verify(cold)
 local Q,L=HCRFluidQuality,HCRFluidLedger;assert(Q,'Load with release candidate')
 local count=0;local foundBags=bags(getPlayer());assert(#foundBags==2,'Held and ground nested stock bags')
 for _,bag in ipairs(foundBags) do
  local saved=bag:getModData().HCRReleaseMigration;local found={}
  local function visit(inv)
   for i=0,inv:getItems():size()-1 do local item=inv:getItems():get(i);local key=item:getModData().HCRReleaseFixture
    if key then assert(not found[key],'Duplicate migrated stock');found[key]=item end
    if instanceof(item,'InventoryContainer') then visit(item:getItemContainer()) end
   end
  end
  visit(bag:getItemContainer())
  for _,spec in ipairs(saved.rows) do
   local item=assert(found[spec.kind],'Lost '..spec.kind);local fluid=assert(Q.fluid(item),'Not migrated '..spec.kind)
   assert(item:getFullType()==spec.target,'Target '..spec.kind..' '..item:getFullType())
   assert(item:isFavorite() and item:isCustomName(),'Lost item preferences')
   assert(item:getModData().HCRMigrationFrom==spec.kind,'Missing migration provenance')
   local amount
   if spec.mode=='water' then amount=spec.nativeAmount or spec.uses*spec.unit
   elseif spec.empty then amount=0
   elseif spec.unit>0 then amount=spec.uses*spec.unit
   elseif spec.food then amount=spec.litres*spec.fraction
   else amount=spec.litres end
   near(Q.rawAmount(fluid),amount,'Migrated volume '..spec.kind)
   if spec.mode=='water' and not spec.nativeAmount then near(fluid:getSpecificFluidAmount(Fluid.TaintedWater),amount,'Unknown water taint') end
   if spec.food and amount>0 then
    local ledger=assert(item:getModData()[Q.key]);assert(L.matches(ledger,Q.amounts(fluid)))
    near(L.budget(ledger,'calories'),137,'Saved Food nutrition '..spec.kind)
    near(L.budget(ledger,'poisonPower'),3,'Saved poison '..spec.kind)
    assert(L.quality(ledger)=='rotten','Saved worst freshness')
   end
   if cold then assert(spec.newId==item:getID(),'Migration repeated after cold save') else spec.newId=item:getID() end
   count=count+1
  end
 end
 log((cold and 'COLD' or 'UPGRADE')..' PASS '..count..' actual old stocks; nested inventory/ground, volumes, nutrition, poison and identity')
end
