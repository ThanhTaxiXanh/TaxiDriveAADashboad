"""Once-per-month cache fill; follows dated Geofabrik HEAD redirect."""
import hashlib
import json
import urllib.request
from pathlib import Path

folder=Path('data-cache'); folder.mkdir(exist_ok=True)
target=folder/'vietnam.osm.pbf'
if not target.exists():
    request=urllib.request.Request('https://download.geofabrik.de/asia/vietnam-latest.osm.pbf',method='HEAD')
    with urllib.request.urlopen(request,timeout=45) as response:
        url=response.url; length=int(response.headers.get('Content-Length',0)); modified=response.headers.get('Last-Modified','')
    assert 0<length<1024*1024*1024, 'Unexpected Vietnam PBF size'
    partial=target.with_suffix('.part'); digest=hashlib.sha256(); count=0
    with urllib.request.urlopen(url,timeout=60) as response,partial.open('wb') as output:
        while chunk:=response.read(1024*1024):
            count+=len(chunk); assert count<=length
            output.write(chunk); digest.update(chunk)
    assert count==length
    partial.rename(target)
    (folder/'source.json').write_text(json.dumps({'url':url,'bytes':count,'sha256':digest.hexdigest(),'modified':modified}))
print((folder/'source.json').read_text())
