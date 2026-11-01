require "ISUI/ISToolTipInv"
require "HCR_FluidQuality"
require "HCR_ItemNames"

local Q,L=HCRFluidQuality,HCRFluidLedger
local original=ISToolTipInv.render

-- Используем нативную раскладку tooltip: строка участвует и в измерении,
-- и в отрисовке, поэтому не выходит за экран при наведении в нижнем углу.
-- Временный tooltip восстанавливается в том же кадре; предмет не синхронизируется.
function ISToolTipInv:render()
    local item=self.item
    if not item then return original(self) end
    local P=HCRProcessQuality
    local process=P and P.carrier(item) and item:getModData()[P.key]
    local fluid=Q.fluid(item)
    local name=fluid and HCRItemNames.custom(item)
    local tracked=process or Q.active(item,fluid)
    if not tracked and not name then return original(self) end
    local labels={}
    -- Передаём пользовательскую надпись как исходную Unicode-строку.
    if name then labels[#labels+1]=getText("Tooltip_HCR_VesselName",name) end
    if tracked then
        local ok,state=pcall(function()
            return process and P.read(item).quality or L.quality(Q.capture(item,fluid).ledger)
        end)
        local key=ok and ("Tooltip_HCR_Liquid_"..state) or "Tooltip_HCR_Liquid_unknown"
        labels[#labels+1]=getText(key)
    end
    local previous=item:getTooltip()
    local label=table.concat(labels," | ")
    if previous then label=label.." | "..getText(previous) end
    item:setTooltip(label)
    local rendered,result=pcall(original,self)
    item:setTooltip(previous)
    if not rendered then error(result) end
    return result
end
