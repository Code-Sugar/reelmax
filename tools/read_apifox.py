import concurrent.futures
import json
import re
import sys
import urllib.request
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')
base = 'https://s.apifox.cn/92890dbf-0d41-4872-b0ef-573d0218baa6/'
out = Path('build/verification/api-docs')
out.mkdir(parents=True, exist_ok=True)
tree = json.loads(Path('build/verification/skit-tree.json').read_text(encoding='utf-8'))

def flatten(node):
    if node.get('method'):
        yield node
    for child in node.get('children', []):
        yield from flatten(child)

def fetch(node):
    request = urllib.request.Request(base + str(node['id']) + 'e0', headers={'User-Agent': 'Mozilla/5.0'})
    html = urllib.request.urlopen(request, timeout=40).read().decode('utf-8')
    match = re.search(r'streamController.enqueue\(("(?:[^"\\]|\\.)*")\)', html)
    values = json.loads(json.loads(match[1]))
    def decode(i):
        if i < 0:
            return None
        value = values[i]
        if isinstance(value, dict):
            return {values[int(k[1:])]: decode(v) for k, v in value.items()}
        if isinstance(value, list):
            return [decode(x) if isinstance(x, int) else x for x in value]
        return value
    data = decode(0)['loaderData']['root']['docsDataState']['resourceData']
    (out / f"{node['id']}.json").write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
    return node['name']

with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
    for name in pool.map(fetch, list(flatten(tree))):
        print(name, flush=True)
