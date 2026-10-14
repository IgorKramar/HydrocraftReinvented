-- Stage as HCRLabBoxing.lua in the private HCRLab profile.
require "HCRLabCraft"
require "HCR_Boxing"
HCRLabBoxing = HCRLabBoxing or {}
local function check(ok,msg) if not ok then error(msg) end end
local function spawn(inv,name,count)
    local items={}
    for i=1,count do items[#items+1]=inv:AddItem(name);check(items[#items]~=nil,"missing fixture ") end
    return items
end
local function canConsume(player,items)
    local recipe=HCRLabCraft.findRecipe("Store 50 in a Box")
    local logic=HandcraftLogic.new(player,nil,nil)
    local containers=ArrayList.new();containers:add(player:getInventory())
    logic:setContainers(containers);logic:setRecipe(recipe);logic:setManualSelectInputs(true);logic:clearManualInputs()
    local selected=ArrayList.new();for _,item in ipairs(items) do selected:add(item) end
    if not logic:setManualInputsFor(recipe:getInputs():get(0),selected) then return false end
    return logic:getRecipeData():canConsumeInputs(logic:getSourceResources())
end
local function positive(player,inv)
    local before=0
    for i=0,inv:getItems():size()-1 do if inv:getItems():get(i):getFullType()=="Hydrocraft.HCStaples" then before=before+1 end end
    local items=spawn(inv,"Hydrocraft.HCStaples",50)
    check(canConsume(player,items),"plain reviewed stock rejected")
    local outputs=HCRLabCraft.nativeCraft(player,HCRLabCraft.findRecipe("Store 50 in a Box"),{items})
    check(outputs:size()==1,"expected one generic box")
    local box=outputs:get(0)
    check(box:getModData().StoredFullType=="Hydrocraft.HCStaples" and box:getModData().StoredAmount==50,"wrong stored type/count")
    for _,item in ipairs(items) do check(item:getContainer()==nil,"packing retained stock") end
    HCRLabCraft.nativeCraft(player,HCRLabCraft.findRecipe("Open Box"),{{box}})
    local count=0
    for i=0,inv:getItems():size()-1 do if inv:getItems():get(i):getFullType()=="Hydrocraft.HCStaples" then count=count+1 end end
    check(count-before==50,"unpacking did not restore exactly fifty stateless materials")
end
function HCRLabBoxing.run(player,profile)
    check(profile=="HCRLab" and player and not isClient() and not isServer(),"explicit offline lab required")
    local inv=player:getInventory();local original={}
    for i=0,inv:getItems():size()-1 do original[inv:getItems():get(i):getID()]=true end
    local cases={{"normal roundtrip",positive}}
    for _,kind in ipairs({"Base.Potato","Base.Hammer","Hydrocraft.BoxOfThings","Hydrocraft.HCFries"}) do
        local captured=kind
        cases[#cases+1]={"reject "..kind,function(p,v) check(not canConsume(p,spawn(v,captured,50)),"foreign item accepted") end}
    end
    cases[#cases+1]={"reject mixed normal fullTypes",function(p,v)
        local mixed=spawn(v,"Hydrocraft.HCStaples",25)
        for _,item in ipairs(spawn(v,"Hydrocraft.HCCork",25)) do mixed[#mixed+1]=item end
        check(not canConsume(p,mixed),"mixed fullTypes accepted")
    end}
    for _,state in ipairs({"metadata","damaged","favorite","custom name","RGB colour","alpha colour"}) do
        local captured=state
        cases[#cases+1]={"reject "..state,function(p,v)
            local items=spawn(v,"Hydrocraft.HCStaples",50)
            if captured=="metadata" then items[1]:getModData().note="must survive"
            elseif captured=="damaged" then items[1]:setCondition(items[1]:getConditionMax()-1)
            elseif captured=="favorite" then items[1]:setFavorite(true)
            elseif captured=="RGB colour" then items[1]:setColor(Color.new(0.5,1.0,1.0,1.0))
            elseif captured=="alpha colour" then items[1]:setColor(Color.new(1.0,1.0,1.0,0.5))
            else items[1]:setName("Must survive");items[1]:setCustomName(true) end
            check(not canConsume(p,items),"stateful material accepted")
        end}
    end
    local failures=0
    for _,case in ipairs(cases) do
        local ok,err=pcall(case[2],player,inv)
        if not ok then failures=failures+1 end
        print("[HCRLabBoxing] "..case[1].." "..(ok and "PASS" or "FAIL: "..tostring(err)))
        for i=inv:getItems():size()-1,0,-1 do
            local item=inv:getItems():get(i);if not original[item:getID()] then inv:Remove(item) end
        end
    end
    print("[HCRLabBoxing] cases="..#cases.." failures="..failures)
    return failures
end
