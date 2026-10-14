"""Fit existing foliage to the exact original hcBuilding2x planter pixels.

Only the original mod atlas and existing generated icons are read. No generation
or network request. Original foliage RGB pixels are retained at 1:1 scale.
Use --out for a review folder; --apply explicitly updates the eight mod icons.
"""
import argparse, hashlib, io, json, struct
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
PACK=ROOT/'common/media/texturepacks/hcBuilding2x.pack'
TEXTURES=ROOT/'common/media/textures'
# Explicit, reviewed soil/plant interfaces. A global warm-colour bounding box
# confuses wood with ripe fruit, stems, and purple leaves and squashes the box.
# root = the foliage's soil insertion point, not its overall image centre.
STATES={
 'HCPottedpotatoready': {'rear':249,'root':[100,265],'end':265,'stems':[[89,106]]},
 'HCPottedCabbageredready': {'rear':243,'root':[103,254],'end':258,'stems':[]},
 'HCPottedtomatoready': {'rear':212,'root':[101,248],'end':250,'stems':[[65,69],[99,105],[119,123]]},
 'HCPottedradishready': {'rear':226,'root':[100,255],'end':260,'stems':[]},
 'HCPottedCabbagewhiteready': {'rear':240,'root':[103,260],'end':264,'stems':[]},
 'HCPottedorangetreeready': {'rear':204,'root':[68,234],'end':235,'stems':[[61,74]]},
 'HCPottedorangetreedead': {'rear':208,'root':[68,234],'end':235,'stems':[[61,74]]},
 'HCPottedpeaplantsmalldry': {'rear':198,'root':[103,243],'end':245,'stems':[[81,82],[100,102],[126,128]]},
}

def atlas_sprite(name='hcFarmingLemontree00_0'):
    data=PACK.read_bytes();at=0
    def integer():
        nonlocal at
        n=struct.unpack_from('<I',data,at)[0];at+=4;return n
    def string():
        nonlocal at
        n=integer();s=data[at:at+n].decode();at+=n;return s
    pages=integer()
    for _ in range(pages):
        page=string();count=integer();flag=integer();entries=[]
        for _ in range(count):entries.append((string(),[integer() for _ in range(8)]))
        start=at;assert data[at:at+8]==b'\x89PNG\r\n\x1a\n';at+=8
        while True:
            size=struct.unpack_from('>I',data,at)[0];tag=data[at+4:at+8];at+=size+12
            if tag==b'IEND':break
        image=Image.open(io.BytesIO(data[start:at])).convert('RGBA')
        assert integer()==0xdeadbeef
        for entry,nums in entries:
            if entry==name:
                x,y,w,h,ox,oy,fw,fh=nums
                return image.crop((x,y,x+w,y+h)), {'sprite':name,'page':page,'atlasRect':[x,y,w,h],
                    'offset':[ox,oy],'frame':[fw,fh],'pack_sha256':hashlib.sha256(data).hexdigest()}
    raise ValueError('Original planter sprite absent from mod pack')

def foliage(image,spec):
    data=np.array(image.convert('RGBA'));h,w=data.shape[:2];yy,xx=np.indices((h,w))
    r,g,b=[data[:,:,i].astype(float) for i in range(3)]
    green=(g>r*1.025)&(g>b*1.04)
    purple=(b>r*.65)&(b>g*.97)&(r>g*1.06)
    red=(r>g*1.8)&(b>g*.9)
    lower=(yy<spec['end'])&(green|purple|red)
    keep=(yy<spec['rear'])|lower
    for left,right in spec['stems']:
        keep|=(xx>=left)&(xx<=right)&(yy<spec['end'])
    data[~keep,3]=0
    if spec is STATES['HCPottedtomatoready']:
        # Tomato source has a white matte baked into otherwise opaque edges.
        # Restrict cleanup to the isolated plant, before adding the atlas box.
        rgb=data[:,:,:3].astype(int)
        neutral=(rgb.max(axis=2)-rgb.min(axis=2)<=35)&(rgb.min(axis=2)>=155)
        alpha=data[:,:,3]>0
        empty=np.pad(~alpha,2,constant_values=True)
        edge=np.zeros(alpha.shape,dtype=bool)
        for dy in range(5):
            for dx in range(5):edge|=empty[dy:dy+image.height,dx:dx+image.width]
        matte=neutral&alpha&(edge|(rgb.min(axis=2)>=210))
        data[matte,3]=0
    return Image.fromarray(data)

def compose(image,spec,box,meta):
    assert image.width>=128 and image.height>=315
    result=Image.new('RGBA',(200,424),(0,0,0,0))
    # Native dropped-item rendering anchors at 3/4 of the canvas height.
    # Bottom padding puts the existing ground edge (317) at that anchor (318).
    origin=((200-meta['frame'][0])//2,320-meta['frame'][1])
    dest=(origin[0]+meta['offset'][0],origin[1]+meta['offset'][1])
    result.alpha_composite(box,dest)
    plant=foliage(image,spec)
    shift=(100-spec['root'][0],234-spec['root'][1])
    bbox=plant.getbbox();assert bbox
    assert bbox[0]+shift[0]>=0 and bbox[1]+shift[1]>=0, 'foliage would clip'
    assert bbox[2]+shift[0]<=200 and bbox[3]+shift[1]<=320, 'foliage would clip'
    result.alpha_composite(plant,shift)
    # The solid front walls must retain the original source pixels exactly.
    actual=np.array(result)[dest[1]:dest[1]+box.height,dest[0]:dest[0]+box.width]
    original=np.array(box)
    walls=Image.new('1',box.size,0)
    ImageDraw.Draw(walls).polygon([(0,38),(55,71),(109,38),(109,99),(55,122),(0,99)],fill=1)
    wall_mask=np.array(walls,dtype=bool)&(original[:,:,3]>0)
    assert np.array_equal(actual[wall_mask],original[wall_mask]),'foliage or an old planter overwrote original front walls'
    return result,{'planter_rect':[dest[0],dest[1],box.width,box.height],
        'foliage_translation':list(shift),'foliage_bbox':list(bbox),'front_walls_exact':True}

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out',type=Path)
    ap.add_argument('--input-dir',type=Path,default=TEXTURES)
    ap.add_argument('--limit',type=int,default=8)
    ap.add_argument('--names',nargs='+',help='Optional subset of reviewed plant IDs')
    ap.add_argument('--apply',action='store_true')
    ap.add_argument('--check',action='store_true',help='Verify delivered size, ground anchor and original wall pixels')
    args=ap.parse_args()
    box,meta=atlas_sprite();assert box.size==(110,123)
    published=ROOT/'docs/PLANTER_SCALE.json'
    reviewed={r['asset']:r for r in json.loads(published.read_text())['assets']} if published.exists() else {}
    if args.check:
        reference=Image.new('RGBA',(200,424));reference.alpha_composite(box,(45,194))
        for name in STATES:
            path=TEXTURES/('Item_'+name+'.png');image=Image.open(path).convert('RGBA')
            assert image.size==(200,424),f'{name}: unexpected canvas'
            assert image.getbbox()[3]==317,f'{name}: ground anchor changed'
            assert np.array_equal(np.array(image)[258:],np.array(reference)[258:]),f'{name}: original lower box pixels differ'
            rec=reviewed['common/media/textures/'+path.name]
            assert hashlib.sha256(path.read_bytes()).hexdigest()==rec['output_sha256'],f'{name}: reviewed asset hash changed'
            print(name,'original planter pixels/size/anchor PASS')
        return
    if args.out is None:ap.error('--out is required unless --check')
    args.out.mkdir(parents=True,exist_ok=True)
    records=[]
    selected=list(STATES.items())
    if args.names:
        if any(name not in STATES for name in args.names):ap.error('Unknown reviewed plant ID')
        selected=[(name,STATES[name]) for name in args.names]
    for name,spec in selected[:args.limit]:
        source=args.input_dir/('Item_'+name+'.png')
        raw=source.read_bytes();image=Image.open(io.BytesIO(raw)).convert('RGBA')
        asset='common/media/textures/'+source.name
        prior=reviewed.get(asset)
        digest=hashlib.sha256(raw).hexdigest()
        if prior and digest==prior['output_sha256'] and image.size==(200,424):
            (args.out/source.name).write_bytes(raw);records.append(prior)
            print(name,'already correct; unchanged',flush=True);continue
        if prior and digest!=prior['source_sha256']:
            raise ValueError(name+': input differs from reviewed foliage layout')
        result,info=compose(image,spec,box,meta)
        destination=args.out/source.name;result.save(destination)
        records.append({'asset':asset,'source_sha256':digest,
            'output_sha256':hashlib.sha256(destination.read_bytes()).hexdigest(),'source_canvas':list(image.size),'canvas':[200,424],**info})
        print(name,'planter=110x123','anchor=(45,194)','front walls exact',flush=True)
    report={'reference':meta,'processing':'Original atlas planter pixels reused byte-for-byte; reviewed foliage mask and translation only, no colour change or rescaling; ground anchor preserved.', 'assets':records}
    (args.out/'PLANTER_SCALE.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    if args.apply:
        for record in records:
            name=Path(record['asset']).name
            (TEXTURES/name).write_bytes((args.out/name).read_bytes())

if __name__=='__main__':main()
