import datetime
import hashlib
import json
import os
from pathlib import Path

folder=Path('build/road-data'); valid=False
try:
    meta=json.loads((folder/'manifest.json').read_text())
    valid=(meta['schema']==1 and meta['country']=='VN' and meta['built'][:7]==datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m') and meta['builder_sha']==hashlib.sha256(Path('tools/road_data/build_pack.py').read_bytes()).hexdigest())
except (OSError,ValueError,KeyError): pass
if not valid:
    for path in folder.glob('*'):
        if path.is_file(): path.unlink()
with open(os.environ['GITHUB_OUTPUT'],'a') as out: out.write(f'reuse={str(valid).lower()}\n')
print('Reuse current validated builder output' if valid else 'Build from monthly PBF cache')
