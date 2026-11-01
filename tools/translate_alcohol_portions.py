"""Имена и подсказки порций спиртного для native evolved recipes."""
import json
from hcr_paths import LUA

translations={
 'RU':{
  'ItemName':{'Hydrocraft.HCRCookingSpirit':'Порция спиртного для готовки','Hydrocraft.HCRCookingMead':'Порция медовухи для готовки'},
  'Recipes':{'Prepare Spirit for Cooking':'Отмерить спиртное для готовки','Prepare Mead for Cooking':'Отмерить медовуху для готовки'},
  'Tooltip':{'Tooltip_HCR_CookingSpirit':'Отмерить 0,2 л в пустой стакан для добавления в блюда и горячие напитки. Состав, свежесть и примеси сохраняются. Стакан возвращается после расхода порции.',
             'Tooltip_HCR_CookingMead':'Отмерить 0,4 л в пустую пивную кружку для супа или рагу. Состав, свежесть и примеси сохраняются. Кружка возвращается после расхода порции.'}},
 'EN':{
  'ItemName':{'Hydrocraft.HCRCookingSpirit':'Spirit for Cooking','Hydrocraft.HCRCookingMead':'Mead for Cooking'},
  'Recipes':{'Prepare Spirit for Cooking':'Measure Spirit for Cooking','Prepare Mead for Cooking':'Measure Mead for Cooking'},
  'Tooltip':{'Tooltip_HCR_CookingSpirit':'Measure 0.2 L into an empty tumbler for dishes and hot drinks. Contents, freshness and contaminants are retained. Using the portion returns the tumbler.',
             'Tooltip_HCR_CookingMead':'Measure 0.4 L into an empty ale stein for soup or stew. Contents, freshness and contaminants are retained. Using the portion returns the stein.'}},
}
for lang,files in translations.items():
    for filename,values in files.items():
        path=LUA/f'shared/Translate/{lang}/{filename}.json'
        data=json.loads(path.read_text(encoding='utf-8'));data.update(values)
        path.write_text(json.dumps(data,ensure_ascii=False,indent=4)+'\n',encoding='utf-8')
