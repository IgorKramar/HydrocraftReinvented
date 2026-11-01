"""Имена новой пищевой порции и рецепта для EN/RU."""
import json
from hcr_paths import LUA

for lang,item,recipe in (
    ('RU','Миска молока','Налить молоко в миску'),
    ('EN','Bowl of Milk','Pour Milk into Bowl'),
):
    for filename,key,value in (
        ('ItemName','Hydrocraft.HCRMilkBowl',item),
        ('Recipes','Pour Milk into Bowl',recipe),
    ):
        path=LUA/f'shared/Translate/{lang}/{filename}.json'
        data=json.loads(path.read_text(encoding='utf-8')) if path.exists() else {}
        data.pop('Recipe_Pour Milk into Bowl',None)
        data[key]=value
        path.write_text(json.dumps(data,ensure_ascii=False,indent=4)+'\n',encoding='utf-8')
