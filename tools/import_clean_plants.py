"""Compose independently generated RGBA foliage with the original HC planter.

Raw fal outputs remain outside the checkout. Review --out before --apply.
"""
import argparse,hashlib,json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from fit_planter_icons import ROOT,TEXTURES,atlas_sprite

PLANTS={'HCPottedtomatoready':(116,164),
        'HCPottedCabbageredready':(118,90),
        'HCPottedCabbagewhiteready':(118,90)}

def compose(raw,bounds,box):
    image=Image.open(raw).convert('RGBA')
    data=np.array(image)
    assert data[:,:,3].min()==0 and data[:,:,3].max()==255,'genuine RGBA transparency required'
    # Ignore nearly invisible pixels, then use one nearest-neighbour fit.
    data[data[:,:,3]<8]=0
    plant=Image.fromarray(data);plant=plant.crop(plant.getbbox())
    plant.thumbnail(bounds,Image.Resampling.NEAREST)
    layer=Image.new('RGBA',(200,424))
    pos=(100-plant.width//2,234-plant.height)
    layer.alpha_composite(plant,pos)
    walls=Image.new('1',box.size,0)
    ImageDraw.Draw(walls).polygon([(0,38),(55,71),(109,38),(109,99),(55,122),(0,99)],fill=1)
    wall_mask=np.array(walls,dtype=bool)&(np.array(box)[:,:,3]>0)
    foliage=np.array(layer)
    # Soil and plant are behind the solid original front walls.
    region=foliage[194:317,45:155]
    region[wall_mask]=0
    layer=Image.fromarray(foliage)
    result=Image.new('RGBA',(200,424));result.alpha_composite(box,(45,194));result.alpha_composite(layer)
    actual=np.array(result)[194:317,45:155]
    assert np.array_equal(actual[wall_mask],np.array(box)[wall_mask]),'planter walls changed'
    return result,{'foliage_size':list(plant.size),'foliage_position':list(pos)}

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--raw',type=Path,required=True)
    ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--apply',action='store_true')
    args=ap.parse_args();args.out.mkdir(parents=True,exist_ok=True)
    box,reference=atlas_sprite()
    old=json.loads((ROOT/'docs/PLANTER_SCALE.json').read_text(encoding='utf-8'))
    scale={r['asset']:r for r in old['assets']}
    provenance=[]
    for name,bounds in PLANTS.items():
        raw=args.raw/name/(name+'.png')
        result,info=compose(raw,bounds,box)
        dest=args.out/('Item_'+name+'.png');result.save(dest)
        asset='common/media/textures/'+dest.name
        source_sha=hashlib.sha256(raw.read_bytes()).hexdigest()
        output_sha=hashlib.sha256(dest.read_bytes()).hexdigest()
        scale[asset]={'asset':asset,'source_sha256':source_sha,'output_sha256':output_sha,
            'source_canvas':list(Image.open(raw).size),'canvas':[200,424],
            'planter_rect':[45,194,110,123],'front_walls_exact':True,
            'pipeline':'fal-native-alpha-v2',**info}
        record=json.loads((args.raw/name/'fal_manifest.jsonl').read_text(encoding='utf-8').splitlines()[-1])
        provenance.append({'asset':asset,'service':'fal.ai','endpoint':record['endpoint'],
            'request_id':record['request_id'],'prompt':record['input']['prompt'],
            'reference':asset,'background':record['input']['background'],
            'quality':record['input']['quality'],'source_sha256':source_sha,'output_sha256':output_sha,
            'processing_tool':'tools/import_clean_plants.py','planter_reference':'docs/PLANTER_SCALE.json',
            'processing':'Regenerated foliage with native transparent alpha; trim invisible pixels; one nearest-neighbour fit; compose behind exact original 110x123 atlas planter walls; native ground-anchor bottom padding.',**info})
        print(name,info,'original walls PASS',flush=True)
    old['assets']=list(scale.values())
    old['processing']='Original atlas planter pixels reused; older foliage retained at 1:1, tomato and both cabbage canopies regenerated with native alpha and fitted once; ground anchor 317 on canvas 200x424.'
    (args.out/'PLANTER_SCALE.json').write_text(json.dumps(old,indent=2)+'\n',encoding='utf-8')
    (args.out/'PLANT_REGENERATION.json').write_text(json.dumps(provenance,indent=2)+'\n',encoding='utf-8')
    if args.apply:
        for name in PLANTS:(TEXTURES/('Item_'+name+'.png')).write_bytes((args.out/('Item_'+name+'.png')).read_bytes())
        for name in ['PLANTER_SCALE.json','PLANT_REGENERATION.json']:
            (ROOT/'docs'/name).write_bytes((args.out/name).read_bytes())

if __name__=='__main__':main()
