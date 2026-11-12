#!/usr/bin/env python3
"""Generate local listing drafts in four formats; never uploads or publishes."""
import argparse
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "publishing/refresh"


def build(asset_base=None, sync_readme=False):
    if sync_readme and not (ROOT/"assets/showcase/refresh/growing-grounds-banner.png").is_file():
        raise SystemExit("Synchronize the README after the current native-menu banner is available.")
    data = json.loads((DEST / "content.json").read_text())
    base = (asset_base or "../../assets/showcase/refresh").rstrip("/")
    md, web, bb, plain = [], [], [], []

    def paragraph(value):
        md.append(value)
        web.append(f"<p>{html.escape(value)}</p>")
        bb.append(value)
        plain.append(value)

    def heading(value):
        md.append("## " + value)
        web.append(f"<h2>{html.escape(value)}</h2>")
        bb.append("[b]" + value + "[/b]")
        plain.append(value)

    def picture(filename, alt):
        url = base + "/" + filename
        md.append(f"![{alt}]({url})")
        web.append(f'<p><img src="{html.escape(url,quote=True)}" alt="{html.escape(alt,quote=True)}" /></p>')
        bb.append(f"[img]{url}[/img]")
        plain.append(f"[Image: {filename} — {alt}]")

    if data.get("state"):
        paragraph(data["state"])
    if (ROOT / "assets/showcase/refresh/growing-grounds-banner.png").is_file():
        picture("growing-grounds-banner.png", "Growing Grounds with the game's actual Base Upgrade rewards.")
    paragraph(data["intro"])
    for section in data["sections"]:
        # The image already contains its heading: avoid another wall of headings.
        if section.get("image"):
            picture(section["image"], section["alt"])
        else:
            heading(section["title"])
        paragraph(section["text"])
        if section.get("note"):
            paragraph(section["note"])
    readme_intro="# Growing Grounds\n\n"+"\n\n".join(md).replace("../../assets/","assets/")+"\n\n"
    (DEST/"readme-intro.md").write_text(readme_intro)
    if sync_readme:
        path=ROOT/"README.md"
        existing=path.read_text()
        marker="## Install or update\n"
        if existing.count(marker)!=1:
            raise SystemExit("README structure changed; review the introduction boundary first.")
        path.write_text(readme_intro+
                        marker+existing.split(marker,1)[1])
    heading("Getting started")
    paragraph(data["install"])
    links = data["links"]
    md.append(" · ".join(f'[{item["label"]}]({item["url"]})' for item in links))
    web.append("<p>" + " · ".join(f'<a href="{html.escape(item["url"],quote=True)}">{html.escape(item["label"])}</a>' for item in links) + "</p>")
    bb.append(" · ".join(f'[url={item["url"]}]{item["label"]}[/url]' for item in links))
    plain.append("\n".join(f'{item["label"]}: {item["url"]}' for item in links))
    heading("Share your experience")
    before, after = data["feedback"].split("report a bug", 1)
    url=data["issues"]
    md.append(before+f"[report a bug]({url})"+after)
    web.append("<p>"+html.escape(before)+f'<a href="{url}">report a bug</a>'+html.escape(after)+"</p>")
    bb.append(before+f"[url={url}]report a bug[/url]"+after)
    plain.append(data["feedback"]+"\n"+url)
    paragraph(data["credits"])
    for extension, blocks in [("md",md),("html",web),("bbcode",bb),("txt",plain)]:
        (DEST/f"description.{extension}").write_text("\n\n".join(blocks)+"\n")
    (DEST/"summary.txt").write_text(data["summary"]+"\n")
    # Readable local preview, no script, network assets or publication control.
    (DEST/"preview.html").write_text('''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>Growing Grounds — local draft</title>
<style>body{margin:0;background:#141d27;color:#e8eef2;font:18px/1.65 sans-serif}main{max-width:896px;margin:0 auto;padding:32px 20px 64px}img{display:block;width:100%;height:auto}p{margin:20px 0 36px}h2{font-size:26px;margin-top:44px}a{color:#9af5de}main>p:first-child{padding:14px 18px;border-left:3px solid #1ee8c2;font-size:14px;color:#bfd5df}</style>
<main>'''+"\n".join(web)+"</main></html>\n")
    gallery=[]
    if (ROOT / "assets/showcase/refresh/growing-grounds-banner.png").is_file():
        gallery.append({"file":"growing-grounds-banner.png","title":"Growing Grounds","caption":"Give your base room to grow. Base upgrades show your current and next rewards."})
    gallery += [{"file":s["image"],"title":s["title"],"caption":s["alt"]} for s in data["sections"] if s.get("image")]
    (DEST/"gallery.json").write_text(json.dumps({"state":data["state"],"images":gallery},indent=2)+"\n")
    word_count=sum(len(data.get(k,"").split()) for k in ["intro","install","feedback","credits"])
    word_count+=sum(len((s["text"]+" "+s.get("note","")).split()) for s in data["sections"])
    print(json.dumps({"copy_words":word_count,"images":len(gallery),"state":"local draft"}))


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--asset-base",help="Optional already-published image base URL; default uses local relative files.")
    parser.add_argument("--sync-readme",action="store_true",help="Update the README introduction, preserving install and technical sections.")
    args=parser.parse_args()
    build(args.asset_base,args.sync_readme)
