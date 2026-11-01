require "HCR_FoodQuality"
require "HCR_ProcessQuality"
require "ISUI/ISToolTipInv"
require "ISUI/ISInventoryPane"
local render=ISToolTipInv.render
function ISToolTipInv:render(...)
    local item=self.item
    HCRFoodQuality.reconcile(item)
    local process=item and HCRProcessQuality.carrier(item) and item:getModData()[HCRProcessQuality.key]
    if not process and (not item or not item:IsFood() or not item:getModData()[HCRFoodQuality.qualityKey]) then
        return render(self,...)
    end
    -- У непортящихся консервов native имя скрывает Stale. Явно показываем
    -- перенесённое состояние, не придумывая новый срок хранения продукта.
    local previous=item:getTooltip()
    local quality=process and HCRProcessQuality.read(item).quality or HCRFoodQuality.quality(item)
    local label=getText("Tooltip_HCR_Food_"..quality)
    if previous then label=label.." | "..getText(previous) end
    item:setTooltip(label)
    local ok,result=pcall(render,self,...)
    item:setTooltip(previous)
    if not ok then error(result) end
    return result
end

-- Native список тоже использует marker для цвета/имени и запрета быстрого
-- двойного клика. Обновить его до сортировки, даже без наведения tooltip.
local refresh=ISInventoryPane.refreshContainer
function ISInventoryPane:refreshContainer(...)
    if self.inventory then
        local items=self.inventory:getItems()
        for i=0,items:size()-1 do HCRFoodQuality.reconcile(items:get(i)) end
    end
    return refresh(self,...)
end
local doubleClick=ISInventoryPane.doContextualDblClick
function ISInventoryPane:doContextualDblClick(item,...)
    HCRFoodQuality.reconcile(item)
    return doubleClick(self,item,...)
end
