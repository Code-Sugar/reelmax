"""Download the public assets referenced by the supplied Reel Max prototype."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASE = 'https://reel-max-mobile-prototype.ryan91james9008.chatgpt.site'
source = '\n'.join((ROOT / 'reference' / name).read_text(encoding='utf-8')
                   for name in ('prototype.js', 'prototype.css'))
paths = sorted(set(re.findall(r'/[\w/-]+\.(?:png|jpg|svg|mp4|ttf)', source)))

def download(path):
    target = ROOT / 'assets' / path.lstrip('/')
    target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(['curl.exe', '-fsSL', '--retry', '2', '--max-time', '180',
                    BASE + path, '-o', str(target)], check=True)
    return {'path': path, 'bytes': target.stat().st_size}

with ThreadPoolExecutor(max_workers=6) as pool:
    manifest = list(pool.map(download, paths))
(ROOT / 'reference' / 'assets.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print(f'Downloaded {len(manifest)} assets, {sum(a["bytes"] for a in manifest):,} bytes')
