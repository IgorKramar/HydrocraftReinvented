"""Correct verified spelling/namespace migrations; never guess replacement items."""
from audit_lua_item_ids import declared
from hcr_paths import LUA, SCRIPTS, find_game, read_text

REPLACEMENTS = {
    'Hydrocraft.AlcoholWipes': 'Base.AlcoholWipes',
    'Hydrocraft.Screws': 'Base.Screws',
    'Hydrocraft.ElectronicsScrap': 'Base.ElectronicsScrap',
    'Hydrocraft.SheetMetal': 'Base.SheetMetal',
    'Hydrocraft.TreeBranch': 'Base.TreeBranch2',
    'Hydrocraft.RubberBand': 'Base.RubberBand',
    'Hydrocraft.Cornflour': 'Base.Cornflour2',
    'Hydrocraft.HCDMallarddead': 'Hydrocraft.HCMallarddead',
    'Hydrocraft.HCPlastcfork': 'Hydrocraft.HCPlasticfork',
    'Hydrocraft.HCMeatcleaver': 'Base.MeatCleaver',
    'Base.WildGarlic': 'Base.WildGarlic2',
    'Base.Erase': 'Base.Eraser',
    'Base.Disc': 'Base.Disc_Retail',
    'Base.WoodenStick': 'Base.WoodenStick2',
    'Base.Hairspray': 'Base.Hairspray2',
    'Hydrocraft.HCAluminumscrap': 'Base.AluminumScrap',
    'Hydrocraft.HCBrassscrap': 'Base.BrassScrap',
    'Hydrocraft.HCRake': 'Base.Rake',
    'Hydrocraft.HCLeafrake': 'Base.LeafRake',
    'Base.Radio': 'Base.RadioRed',
    'Base.DigitalWatch': 'Base.WristWatch_Left_DigitalBlack',
    'Base.223Bullets': 'Base.556Bullets',
    'Hydrocraft.HCBatteryempty': 'Hydrocraft.HCBatterydead',
    'Base.Bass': 'Base.LargemouthBass',
    'Base.Catfish': 'Base.ChannelCatfish',
    'Base.Crappie': 'Base.BlackCrappie',
    'Base.Panfish': 'Base.Bluegill',
    'Base.Perch': 'Base.YellowPerch',
    # The old species are absent in B42's Kentucky catalog; keep the pond's
    # large/small predator tiers using existing native species.
    'Base.Pike': 'Base.Muskellunge',
    'Base.Trout': 'Base.SpottedBass',
}
for index in range(1, 4):
    REPLACEMENTS[f'Base.MagazineCrossword{index}'] = 'Base.MagazineCrossword'
    REPLACEMENTS[f'Base.MagazineWordsearch{index}'] = 'Base.MagazineWordsearch'
    REPLACEMENTS[f'Base.SportCarSeat{index}'] = f'Base.NormalCarSeat{index}'
    REPLACEMENTS[f'Base.BigCarSeat{index}'] = f'Base.NormalCarSeat{index}'
for plant in ['Broccoli', 'Cabbage', 'Carrot', 'Potato', 'RedRadish', 'Strewberrie', 'Tomato']:
    REPLACEMENTS[f'farming.{plant}BagSeed'] = f'Base.{plant}BagSeed2'


if __name__ == '__main__':
    names = declared(SCRIPTS) | declared(find_game() / 'media/scripts')
    for old, new in REPLACEMENTS.items():
        if new not in names:
            raise ValueError(f'Unverified migration: {old} -> {new}')
    changed = 0
    for path in LUA.rglob('*.lua'):
        original = read_text(path)
        text = original
        for old, new in REPLACEMENTS.items():
            for quote in ['"', "'"]:
                text = text.replace(quote + old + quote, quote + new + quote)
        if text != original:
            path.write_text(text, encoding='utf-8')
            changed += 1
    print(f'Corrected verified item references in {changed} Lua files')
