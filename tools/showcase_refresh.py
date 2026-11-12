#!/usr/bin/env python3
"""Rebuild local GG artwork from original vectors and the actual range module.

No game, save, network, publishing or package operations. Requires the already
installed Python/Pillow, Lua, Fira Sans and rsvg-convert. Native menu imagery
is opt-in through a reviewed, repository-relative manifest; never synthesized.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import html
import json
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/showcase/refresh"
W, H = 1280, 720
WHITE, TURQ, MINT = "#ffffff", "#1ee8c2", "#9af5de"
MUTED, NAVY = "#a6c4d3", "#12263a"
ET.register_namespace("", "http://www.w3.org/2000/svg")
ET.register_namespace("xlink", "http://www.w3.org/1999/xlink")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def values():
    # Uses the mod's pure calculation module, without UE4SS or any save access.
    lua = '''local R=dofile('src/range.lua');local c=dofile('config.lua')
local p=R.settings(c)
for _,k in ipairs({'growthPercentPerLevel','maxRangeBonusPercent','maxChestBonusSlots','startingPalboxBoxes','maxPalboxBoxes'}) do
 print(k..'='..p[k]) end
for k,v in pairs(R.limits) do print('limit_'..k..'='..v) end
print('chestSlotStep='..R.chestSlotStep)
for l=1,35 do print(string.format('level=%d,%g,%d,%d',l,R.radius(35,l,c,35),R.storageBonus(l,c,35),R.palboxTotal(l,c,35))) end
for l=1,35 do print(string.format('small=%d,%d',l,R.palboxTotal(l,{startingPalboxBoxes=1,maxPalboxBoxes=16},35))) end
'''
    output = subprocess.check_output(["lua", "-"], input=lua, text=True, cwd=ROOT)
    result = {"levels": [], "small": []}
    for line in output.splitlines():
        key, value = line.split("=", 1)
        if key == "level":
            l, radius, chest, palbox = map(float, value.split(","))
            result["levels"].append({"level": int(l), "radius": radius,
                                     "chest": int(chest), "palbox": int(palbox)})
        elif key == "small":
            result["small"].append(list(map(int, value.split(","))))
        else:
            result[key] = float(value)
    expected = {"growthPercentPerLevel": 4, "maxRangeBonusPercent": 100,
                "maxChestBonusSlots": 18, "startingPalboxBoxes": 32, "maxPalboxBoxes": 64,
                "limit_growthPercentPerLevel":20,"limit_maxRangeBonusPercent":300,
                "limit_maxChestBonusSlots":42,"limit_maxPalboxBoxes":96,"chestSlotStep":6}
    for key, number in expected.items():
        if result[key] != number:
            raise SystemExit(f"Artwork must be reconciled: {key} changed from {number} to {result[key]}")
    return result


def text(x, y, content, size=28, color=WHITE, weight=500, italic=False, anchor="start"):
    return (f'<text x="{x}" y="{y}" font-family="Fira Sans" font-size="{size}" '
            f'font-weight="{weight}" font-style="{"italic" if italic else "normal"}" '
            f'fill="{color}" text-anchor="{anchor}">{html.escape(str(content))}</text>')


def background(w=W, h=H):
    return (f'<defs><radialGradient id="slate" cx="38%" cy="25%" r="94%">'
            '<stop offset="0" stop-color="#49627c"/><stop offset="0.52" stop-color="#293e54"/>'
            '<stop offset="1" stop-color="#0c1c2b"/></radialGradient></defs>'
            f'<rect width="{w}" height="{h}" fill="url(#slate)"/>')


def rect(x, y, w, h, fill="none", stroke="none", sw=1, opacity=1):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" '
            f'stroke="{stroke}" stroke-width="{sw}" opacity="{opacity}"/>')


def line(x1, y1, x2, y2, color=MINT, sw=2, opacity=1):
    return f'<path d="M{x1} {y1}L{x2} {y2}" fill="none" stroke="{color}" stroke-width="{sw}" opacity="{opacity}"/>'


def vector(relative, x, y, w, h, strip_tile=False):
    tree = ET.fromstring((ROOT / relative).read_text())
    if strip_tile:
        for child in list(tree):
            if child.tag.rsplit("}", 1)[-1] in ("rect", "defs"):
                tree.remove(child)
    tree.attrib.update(x=str(x), y=str(y), width=str(w), height=str(h))
    return ET.tostring(tree, encoding="unicode")


def gem(cx, cy, r=14):
    colors = ["#35dabd", "#74f2d8", "#06957c", "#14b89b"]
    points = [(cx,cy-r,cx-r,cy),(cx,cy-r,cx+r,cy),
              (cx-r,cy,cx,cy+r),(cx+r,cy,cx,cy+r)]
    return "".join(f'<path d="M{cx} {cy}L{a} {b}L{c} {d}Z" fill="{fill}"/>'
                   for (a,b,c,d),fill in zip(points,colors))


def top(title, subtitle, icon):
    return [background(), vector(icon, 66, 60, 44, 44),
            text(132, 101, title, 48, weight=600, italic=True),
            text(68, 150, subtitle, 26, MINT)]


def footer(content):
    return line(68, 645, 1212, 645, MUTED, 1, .3) + text(68, 685, content, 23, MUTED, italic=True)


def svg(name, body, description, w=W, h=H):
    result = (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
              f'width="{w}" height="{h}" viewBox="0 0 {w} {h}">\n'
              f'<title>Growing Grounds — {html.escape(name)}</title>\n'
              f'<desc>{html.escape(description)}</desc>\n' + "\n".join(body) + '\n</svg>\n')
    path = OUT / f"growing-grounds-{name}.svg"
    path.write_text(result)
    subprocess.run(["rsvg-convert", "-o", str(path.with_suffix(".png")), str(path)], check=True)
    return path


def range_card(data):
    body = top("A base that grows with you", "More room with every upgrade. A cap you choose.", "assets/base-range.svg")
    body += [text(66, 305, "+4%", 132, weight=700, italic=True),
             text(70, 354, "radius per upgrade", 34, TURQ, italic=True),
             text(70, 475, "+100%", 79, weight=700, italic=True),
             text(70, 520, "default maximum bonus", 30, TURQ, italic=True)]
    cx, cy, scale = 745, 542, 6.0
    arc = lambda r: f'M{cx} {cy-r}A{r} {r} 0 0 1 {cx+r} {cy}'
    body.append(f'<path d="{arc(70*scale)}L{cx} {cy}Z" fill="{TURQ}" fill-opacity=".08"/>')
    body.append(f'<path d="{arc(35*scale)}L{cx} {cy}Z" fill="{TURQ}" fill-opacity=".19"/>')
    for row in data["levels"][:26]:
        selected = row["level"] in (1, 11, 26)
        body.append(f'<path d="{arc(row["radius"]*scale)}" fill="none" stroke="{MINT if selected else TURQ}" '
                    f'stroke-width="{3 if selected else 1.4}" opacity="{1 if selected else .38}"/>')
    body += [line(cx, 106, cx, cy, MUTED, 1, .5), line(cx, cy, 1195, cy, MUTED, 1, .5), gem(cx, cy, 18)]
    for level in (1,11,26):
        radius = data["levels"][level-1]["radius"]
        x = cx+radius*scale
        body += [line(x,cy,x,cy+10), text(x,584,f"{radius:g} m",28,weight=600,italic=True,anchor="middle"),
                 text(x,617,f"Lv. {level}",23,MINT,italic=True,anchor="middle")]
    body.append(footer("Default 35 m base • Nearby bases may limit growth"))
    return svg("range",body,"Illustrated default radius: 35 m at level 1, 49 m at level 11, 70 m at level 26. No in-game boundary preview is depicted.")


def palbox_card(data):
    body = top("Let your Pal collection grow", "Choose your starting boxes and your total capacity.", "assets/palbox-bonus.svg")
    # Endpoints are regular Palbox boxes, one small cell per whole box.
    for total,x,y in [(32,84,310),(64,732,310)]:
        for i in range(total):
            row,col=divmod(i,8)
            body.append(rect(x+col*47,y+row*31,36,22,TURQ if i>=32 else "#42677b",MINT if i<32 else TURQ,1.2))
    body += [text(82,260,"32",100,weight=700,italic=True),text(222,256,"starting boxes",31,MINT,italic=True),
             text(730,260,"64",100,weight=700,italic=True),text(875,256,"total boxes",31,TURQ,italic=True),
             text(84,591,"Level 1",26,MINT,italic=True),text(732,591,"Level 35",26,MINT,italic=True),
             line(522,408,655,408,TURQ,4), '<path d="M636 394L655 408L636 422" fill="none" stroke="#1ee8c2" stroke-width="4"/>',
             text(587,467,"Whole boxes",24,MINT,anchor="middle"),text(587,499,"unlock gradually",24,MINT,anchor="middle")]
    body.append(footer("Default settings • A smaller start is possible: 1 → 16 • Global Palbox unchanged"))
    return svg("palbox",body,"Illustrated default regular Palbox capacity: 32 starting boxes and 64 total at level 35. The cap includes the start; it is not 64 extra boxes. Not a game screenshot.")


def compose_banner(panel, path, historical=False):
    # Preserve the original lettering and mark. PK requested a larger menu,
    # no surrounding frame, and no visible capture/provenance slogan.
    tree=ET.fromstring((ROOT/"assets/showcase/source/legacy-20261110/banner-1920.svg").read_text())
    original=list(tree)
    if len(original)!=21 or not original[17].tag.endswith("image"):
        raise SystemExit("Review the changed original banner template before composing.")
    for child in original[4:]:
        tree.remove(child)
    brand=ET.SubElement(tree,"{http://www.w3.org/2000/svg}g",{"transform":"translate(10 54) scale(.9)"})
    brand.extend(original[4:16])
    ET.SubElement(tree,"{http://www.w3.org/2000/svg}image",{
        "x":"935","y":"12","width":"965","height":"1056",
        "preserveAspectRatio":"xMidYMid meet",
        "{http://www.w3.org/1999/xlink}href":"data:image/png;base64,"+base64.b64encode(panel.read_bytes()).decode()})
    tree.find("{http://www.w3.org/2000/svg}title").text="Growing Grounds — banner"+(" historical layout reference" if historical else "")
    tree.find("{http://www.w3.org/2000/svg}desc").text=("Original GG lettering and mark, scaled to 90%, beside an enlarged native UMG render. "
        "No surrounding frame or visible capture caption. Menu contents are unedited. "+
        ("Historical menu used only to review the layout; not the current candidate." if historical else "Current candidate menu."))
    path.write_text(ET.tostring(tree,encoding="unicode")+"\n")
    subprocess.run(["rsvg-convert","-o",str(path.with_suffix(".png")),str(path)],check=True)
    return path


def hero(manifest_path, data):
    manifest=json.loads(manifest_path.read_text())
    if manifest.get("kind") != "native-umg-render" or not manifest.get("visually_reviewed"):
        raise SystemExit("Hero requires a visually inspected native UMG render.")
    native=(ROOT/manifest["file"]).resolve()
    if not native.is_relative_to(ROOT) or sha(native)!=manifest["sha256"]:
        raise SystemExit("Native image must be within this checkout and match its reviewed hash.")
    im=Image.open(native)
    if im.format!="PNG": raise SystemExit("Convert and review the native export before composition.")
    values_path=(ROOT/manifest["values_file"]).resolve()
    if not values_path.is_relative_to(ROOT) or sha(values_path)!=manifest["values_sha256"]:
        raise SystemExit("Native value evidence must match the reviewed hash.")
    observed={parts[0]:parts[1:] for row in values_path.read_text().splitlines() if (parts:=row.split('\t'))}
    level=int(observed["base_level"][0])
    if not 1<=level<35:
        raise SystemExit("Review the native upgrade level before composition.")
    current, following=data["levels"][level-1:level+1]
    expected={"Base Range Bonus":[round((v["radius"]/35-1)*100) for v in (current,following)],
              "Bonus Chest Slots":[v["chest"] for v in (current,following)],
              "Palbox Boxes":[v["palbox"] for v in (current,following)]}
    for label,numbers in expected.items():
        if list(map(int,observed[label]))!=numbers:
            raise SystemExit(f"Native {label} differs from the illustrated defaults: {observed[label]} vs {numbers}")
    crop=tuple(manifest["crop_xyxy"])
    if not (0<=crop[0]<crop[2]<=im.width and 0<=crop[1]<crop[3]<=im.height):
        raise SystemExit("Invalid native crop bounds")
    panel=OUT/"growing-grounds-rewards.png"
    im.crop(crop).save(panel)
    return compose_banner(panel,OUT/"growing-grounds-banner.svg")


def build(manifest=None):
    OUT.mkdir(parents=True,exist_ok=True)
    if manifest is None and (OUT/"native.json").is_file():
        manifest=(OUT/"native.json").resolve()
    data=values()
    paths=[fn(data) for fn in (range_card,palbox_card)]
    if manifest: paths.insert(0,hero(manifest,data))
    approval_path=OUT/"approvals.json"
    approvals=json.loads(approval_path.read_text())["assets"] if approval_path.exists() else {}
    approval_status={}
    for name,item in approvals.items():
        approval_status[name]="approved locally; not published" if all(sha(ROOT/p)==digest for p,digest in item["files"].items()) else "changed since approval; review required"
    receipt={"state":"Release 0.2.1-beta artwork; publication requested by PK", "approval_status":approval_status,
             "policy_commit":subprocess.check_output(["git","log","-1","--format=%H","--","src/range.lua","config.lua"],cwd=ROOT,text=True).strip(),
             "source_hashes":{p:sha(ROOT/p) for p in ["src/range.lua","config.lua","assets/identity/wordmark.svg","assets/identity/icon.svg","assets/showcase/source/legacy-20261110/banner-1920.svg"]},
             "values":data,"native_manifest":str(manifest.relative_to(ROOT)) if manifest else None,
             "outputs":{str(p.relative_to(ROOT)):sha(p) for svgpath in paths for p in [svgpath,svgpath.with_suffix('.png')]}}
    if manifest:
        receipt["native_manifest_sha256"]=sha(manifest)
        receipt["outputs"]["assets/showcase/refresh/growing-grounds-rewards.png"]=sha(OUT/"growing-grounds-rewards.png")
    (OUT/"build-receipt.json").write_text(json.dumps(receipt,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"cards":len(paths),"native_hero":bool(manifest),"output":"assets/showcase/refresh"}))


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native-manifest",type=Path)
    args=parser.parse_args()
    build(args.native_manifest.resolve() if args.native_manifest else None)
