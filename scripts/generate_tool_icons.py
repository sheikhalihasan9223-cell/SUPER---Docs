"""Render the complete tool icon set as high-resolution transparent PNG assets."""
from pathlib import Path
import math
from PIL import Image, ImageDraw, ImageFont
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets/tool_icons'
OUT.mkdir(parents=True, exist_ok=True)
SCALE = 3
W, H = 320, 180
COLORS = {'PDF': '#DD4545', 'WORD': '#4168E8', 'PPT': '#FF9838', 'EXCEL': '#35B96A', 'IMAGE': '#883AF4', 'JPG': '#883AF4', 'TXT': '#5D76E8', 'PNG': '#883AF4'}
FONT = Path('C:/Windows/Fonts/arialbd.ttf')

def font(size):
    return ImageFont.truetype(str(FONT), size * SCALE)

def rect(draw, box, fill, radius=0, outline=None, width=1):
    box = tuple(round(v*SCALE) for v in box)
    if radius:
        draw.rounded_rectangle(box, radius=radius*SCALE, fill=fill, outline=outline, width=width*SCALE)
    else:
        draw.rectangle(box, fill=fill, outline=outline, width=width*SCALE)

def line(draw, points, fill, width=3):
    draw.line([(round(x*SCALE), round(y*SCALE)) for x,y in points], fill=fill, width=width*SCALE, joint='curve')

def poly(draw, points, fill):
    draw.polygon([(round(x*SCALE),round(y*SCALE)) for x,y in points], fill=fill)

def label(draw, xy, text, size, fill='white'):
    draw.text((xy[0]*SCALE,xy[1]*SCALE), text, font=font(size), fill=fill, anchor='mm')

def document(draw, x, y, kind, size=1):
    # Format-specific paper and folded corner match the supplied flat reference.
    color = COLORS[kind]
    w,h = 76*size,100*size
    fold = 20*size
    poly(draw, [(x,y),(x+w-fold,y),(x+w,y+fold),(x+w,y+h),(x,y+h)], '#E5E4DB' if kind=='PDF' else color)
    poly(draw, [(x+w-fold,y),(x+w-fold,y+fold),(x+w,y+fold)], '#CFCEC4' if kind=='PDF' else '#FFFFFF80')
    if kind=='PDF':
        # A red continuous ribbon suggests a PDF document without a UI label.
        line(draw, [(x+19*size,y+60*size),(x+24*size,y+50*size),(x+38*size,y+25*size),(x+41*size,y+17*size),(x+38*size,y+13*size),(x+35*size,y+17*size),(x+37*size,y+30*size),(x+46*size,y+47*size),(x+58*size,y+52*size),(x+65*size,y+49*size),(x+63*size,y+45*size),(x+55*size,y+44*size),(x+40*size,y+47*size),(x+25*size,y+54*size),(x+18*size,y+61*size),(x+19*size,y+60*size)], color, max(1,round(2*size)))
        rect(draw,(x,y+73*size,x+w,y+h),color)
        label(draw,(x+w/2,y+87*size),'PDF',18*size)
    elif kind=='EXCEL':
        # Spreadsheet panel behind the green X cover.
        rect(draw,(x+47*size,y+17*size,x+90*size,y+87*size),color)
        for row in range(5):
            for col in range(2):
                rect(draw,(x+(54+col*16)*size,y+(24+row*11)*size,x+(65+col*16)*size,y+(30+row*11)*size),'white')
        poly(draw,[(x-5*size,y+10*size),(x+49*size,y),(x+49*size,y+h),(x-5*size,y+89*size)],color)
        label(draw,(x+24*size,y+51*size),'X',44*size)
    elif kind in ('IMAGE','JPG','PNG'):
        rect(draw,(x+15*size,y+29*size,x+61*size,y+64*size),None,3, 'white',2)
        draw.ellipse(tuple(round(v*SCALE) for v in (x+23*size,y+35*size,x+30*size,y+42*size)),fill='white')
        poly(draw,[(x+19*size,y+59*size),(x+31*size,y+47*size),(x+39*size,y+54*size),(x+48*size,y+43*size),(x+58*size,y+59*size)],'white')
        if kind!='IMAGE': label(draw,(x+38*size,y+83*size),kind,13*size)
    elif kind=='TXT':
        label(draw,(x+38*size,y+43*size),'T',32*size)
        for i in range(3): line(draw,[(x+19*size,y+(68+i*7)*size),(x+57*size,y+(68+i*7)*size)],'white',2)
    else:
        label(draw,(x+38*size,y+55*size),'W' if kind=='WORD' else 'P',40*size)

def arrow(draw,x=148,y=90):
    line(draw,[(x-11,y),(x+11,y)],'#393044',3)
    poly(draw,[(x+11,y),(x+3,y-6),(x+3,y+6)],'#393044')

def badge(draw,action):
    x,y=206,112
    draw.ellipse((x*SCALE,y*SCALE,(x+49)*SCALE,(y+49)*SCALE),fill='#7428F5',outline='white',width=3*SCALE)
    cx,cy=x+25,y+25
    if action in ('protect','unlock'):
        rect(draw,(cx-11,cy-2,cx+11,cy+13),'white',3)
        draw.arc(tuple(round(v*SCALE) for v in (cx-8,cy-16,cx+8,cy+6)),180,360,fill='white',width=3*SCALE)
        if action=='unlock': rect(draw,(cx+4,cy-15,cx+12,cy-4),'#7428F5')
        line(draw,[(cx,cy+3),(cx,cy+8)],'#7428F5',2)
    elif action in ('compress','image_compress'):
        for sign in [-1,1]:
            line(draw,[(cx+sign*15,cy),(cx+sign*4,cy)],'white',3)
            line(draw,[(cx+sign*8,cy-5),(cx+sign*3,cy),(cx+sign*8,cy+5)],'white',3)
    elif action=='rotate':
        draw.arc(tuple(round(v*SCALE) for v in (cx-12,cy-12,cx+12,cy+12)),40,320,fill='white',width=3*SCALE)
        poly(draw,[(cx+12,cy-10),(cx+4,cy-11),(cx+11,cy-3)],'white')
    elif action=='image_resize':
        rect(draw,(cx-11,cy-11,cx+11,cy+11),None,0,'white',2)
        line(draw,[(cx-6,cy+6),(cx+6,cy-6)],'white',2)
        line(draw,[(cx+1,cy-6),(cx+6,cy-6),(cx+6,cy-1)],'white',2)
    elif action=='organize':
        for a,b in [(-10,-10),(3,-10),(-10,3),(3,3)]: rect(draw,(cx+a,cy+b,cx+a+8,cy+b+8),'white',1)
    elif action=='split':
        line(draw,[(cx-10,cy-11),(cx+10,cy+11)],'white',3)
        line(draw,[(cx+10,cy-11),(cx-10,cy+11)],'white',3)
    elif action=='merge':
        line(draw,[(cx-12,cy-10),(cx,cy),(cx,cy+12)],'white',3)
        line(draw,[(cx+12,cy-10),(cx,cy)],'white',3)
    elif action in ('edit','sign'):
        line(draw,[(cx-10,cy+10),(cx+9,cy-9)],'white',5)
        poly(draw,[(cx-11,cy+7),(cx-13,cy+13),(cx-7,cy+11)],'white')
    elif action=='scanner':
        for sx,sy in [(-1,-1),(1,-1),(-1,1),(1,1)]:
            line(draw,[(cx+sx*6,cy+sy*12),(cx+sx*12,cy+sy*12),(cx+sx*12,cy+sy*6)],'white',2)
        line(draw,[(cx-8,cy),(cx+8,cy)],'white',2)
    else:
        label(draw,(cx,cy),{'create':'+','extract':'−','repair':'+','ocr':'Aa','numbers':'1','watermark':'W'}.get(action,'+'),22 if action!='ocr' else 16)

CONVERSIONS={'word_pdf':('WORD','PDF'),'ppt_pdf':('PPT','PDF'),'excel_pdf':('EXCEL','PDF'),'image_pdf':('IMAGE','PDF'), 'pdf_word':('PDF','WORD'),'pdf_ppt':('PDF','PPT'),'pdf_excel':('PDF','EXCEL'),'pdf_jpg':('PDF','JPG'),'text':('PDF','TXT'),'image_jpg':('IMAGE','JPG'),'image_convert':('JPG','PNG')}
ACTIONS=['merge','split','organize','rotate','extract','compress','repair','ocr','create','edit','numbers','watermark','sign','protect','unlock','image_compress','image_resize','scanner']
for tool in list(CONVERSIONS)+ACTIONS:
    image=Image.new('RGBA',(W*SCALE,H*SCALE),(0,0,0,0))
    draw=ImageDraw.Draw(image)
    if tool in CONVERSIONS:
        source,target=CONVERSIONS[tool]
        document(draw,38,40,source)
        arrow(draw)
        document(draw,192,40,target)
    else:
        document(draw,116,32,'IMAGE' if tool.startswith('image_') else 'PDF',1.1)
        badge(draw,tool)
    image.resize((W,H),Image.Resampling.LANCZOS).save(OUT / f'{tool}.png')
# Keep a contact sheet for reviewing the complete set without opening 29 files.
ids=list(CONVERSIONS)+ACTIONS
sheet=Image.new('RGB',(4*W,math.ceil(len(ids)/4)*220),'#F8F6FF')
draw=ImageDraw.Draw(sheet)
small=ImageFont.truetype(str(FONT),14)
for i,tool in enumerate(ids):
    x,y=(i%4)*W,(i//4)*220
    image=Image.open(OUT/f'{tool}.png')
    sheet.paste(image,(x,y),image)
    draw.text((x+W/2,y+190),tool,font=small,fill='#393044',anchor='mm')
sheet.save(ROOT/'assets/tool_icons/catalog-preview.png')
print(f'Generated {len(ids)} transparent icons and a review sheet in {OUT}')
