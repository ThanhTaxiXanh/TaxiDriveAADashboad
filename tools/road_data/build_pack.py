"""Build an ODbL derived road database. Public OSM only; no device data.

Two passes: collect signed nodes/relations, then stream located road ways.
Road geometries are split without simplification so offsets remain exact.
"""
import argparse
import collections
import datetime
import gzip
import hashlib
import json
import math
import re
import sqlite3
from pathlib import Path

DRIVABLE = set('motorway trunk primary secondary tertiary unclassified residential living_street service road track motorway_link trunk_link primary_link secondary_link tertiary_link'.split())
KINDS = {'102': 'noEntry', '103a': 'noCar', '103b': 'noRight', '103c': 'noLeft', '123a': 'noLeft', '123b': 'noRight', '124a': 'noUturn', '124b': 'noUturn', '127': 'speed', '130': 'noStop', '131a': 'noPark', '122': 'stop'}
RESTRICTIONS = {'no_left_turn': 'noLeft', 'no_right_turn': 'noRight', 'no_u_turn': 'noUturn', 'no_straight_on': 'noStraight'}

def distance(a, b):
    lat = math.radians((a[0] + b[0]) / 2)
    return math.hypot((b[0]-a[0])*111195, (b[1]-a[1])*111195*math.cos(lat))

def bearing(a, b):
    lat = math.radians((a[0]+b[0])/2)
    return math.degrees(math.atan2((b[1]-a[1])*math.cos(lat), b[0]-a[0])) % 360

def speed(value):
    m = re.fullmatch(r'\s*(\d+(?:\.\d+)?)\s*(km/h|kph|mph)?\s*', value or '', re.I)
    if not m:
        return None
    number = float(m[1]) * (1.609344 if (m[2] or '').lower() == 'mph' else 1)
    return round(number) if 1 <= number <= 150 else None

def sign_types(raw, tags):
    # Observed VN taginfo includes VN:102, VN:401,127[60], P.123a:
    # text, maxspeed, and predominantly 'yes'. Unknowns stay unknown.
    result = []
    if raw == 'maxspeed' and speed(tags.get('maxspeed')):
        result.append(('speed', speed(tags['maxspeed'])))
    if raw == 'stop': result.append(('stop', None))
    if raw == 'give_way': result.append(('giveWay', None))
    for token in re.split(r'[;,]', raw or ''):
        m = re.match(r'^\s*(?:VN:)?(?:P\.)?(102|103[abc]|123[ab]|124[ab]|127|130|131a?|122)(?:\[(\d+)\])?(?=\s*:|\s*$)', token, re.I)
        if not m: continue
        code = m[1].lower()
        if code == '131': code = '131a'
        kind = KINDS.get(code)
        value = speed(m[2] or tags.get('maxspeed')) if kind == 'speed' else None
        if kind and (kind != 'speed' or value is not None): result.append((kind, value))
    return list(dict.fromkeys(result))

def compact(value): return json.dumps(value, ensure_ascii=False, separators=(',', ':'))

def kept_tags(tags):
    exact = {'highway','name','oneway','junction','lanes','lanes:forward','lanes:backward','lanes:motor_vehicle','dual_carriageway','divider','urban','maxspeed:type','source:maxspeed','access','motor_vehicle','motorcar','hgv','bus','layer','bridge','tunnel'}
    return {k:v for k,v in tags.items() if k in exact or k.startswith(('maxspeed', 'traffic_sign', 'access:', 'motor_vehicle:', 'motorcar:', 'hgv:', 'bus:'))}

class Builder:
    def __init__(self, output):
        self.path = Path(output)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        if self.path.exists(): self.path.unlink()
        self.db = sqlite3.connect(self.path)
        self.db.executescript('''PRAGMA journal_mode=OFF; PRAGMA synchronous=OFF; PRAGMA user_version=1;
        CREATE TABLE metadata (key TEXT PRIMARY KEY,value TEXT NOT NULL);
        CREATE TABLE roads (id INTEGER PRIMARY KEY,way INTEGER NOT NULL,payload TEXT NOT NULL);
        CREATE INDEX roads_way ON roads(way);
        CREATE VIRTUAL TABLE roads_rtree USING rtree(id,minLon,maxLon,minLat,maxLat);
        CREATE TABLE signs (id INTEGER PRIMARY KEY,key TEXT UNIQUE NOT NULL,payload TEXT NOT NULL);
        CREATE VIRTUAL TABLE signs_rtree USING rtree(id,minLon,maxLon,minLat,maxLat);
        CREATE TABLE places (id INTEGER PRIMARY KEY,lat REAL,lon REAL,radius REAL);
        CREATE VIRTUAL TABLE places_rtree USING rtree(id,minLon,maxLon,minLat,maxLat);''')
        self.nodes = {}
        self.relations = []
        self.coordinates = {}
        self.endpoints = {}
        self.attached = set()
        self.counts = collections.Counter()
        self.raw_signs = collections.Counter()
    def node(self, ident, point, tags):
        if tags.get('place') in {'city','town','village','hamlet','suburb','quarter'}:
            radius = {'city':6000,'town':3000,'village':1000,'hamlet':500,'suburb':1800,'quarter':800}[tags['place']]
            row = self.db.execute('INSERT INTO places VALUES(NULL,?,?,?)', (*point,radius)).lastrowid
            self.db.execute('INSERT INTO places_rtree VALUES(?,?,?,?,?)', (row,point[1],point[1],point[0],point[0]))
        if any(k.startswith('traffic_sign') for k in tags) or tags.get('highway') in {'speed_camera','stop','give_way'} or 'traffic_calming' in tags:
            self.nodes[ident] = (point, tags)
            self.raw_signs[tags.get('traffic_sign','')] += 1
    def relation(self, ident, tags, members):
        if tags.get('type') == 'restriction' or tags.get('enforcement') == 'maxspeed':
            self.relations.append((ident,tags,members))
    def add_sign(self, key, point, kind, value=None, heading=None, way=None, along=None, note='OSM', raw=None):
        payload = {'id':key,'lat':point[0],'lon':point[1],'kind':kind,'value':value,'bearing':heading,'way':way,'along':along,'source':'osm','note':note}
        if raw: payload['raw'] = raw[:240]
        cursor = self.db.execute('INSERT OR IGNORE INTO signs VALUES(NULL,?,?)', (key,compact(payload)))
        if cursor.rowcount:
            row = cursor.lastrowid
            self.db.execute('INSERT INTO signs_rtree VALUES(?,?,?,?,?)', (row,point[1],point[1],point[0],point[0]))
            self.counts['sign_'+kind] += 1
    def node_signs(self, ident, point, tags, way=None, along=None, course=None):
        values = []
        for suffix in ('',':forward',':backward'):
            raw = tags.get('traffic_sign'+suffix,'')
            relative = suffix[1:] or tags.get('traffic_sign:direction', tags.get('direction',''))
            heading = None
            if course is not None and relative in {'forward','backward'}:
                heading = (course + (180 if relative == 'backward' else 0)) % 360
            elif relative not in {'forward','backward','both',''}:
                cardinal = {'N':0,'NE':45,'E':90,'SE':135,'S':180,'SW':225,'W':270,'NW':315}
                try: facing = float(relative) if relative not in cardinal else cardinal[relative]
                except ValueError: facing = None
                if facing is not None and math.isfinite(facing): heading = (facing + 180) % 360
            for kind,value in sign_types(raw,tags): values.append((kind,value,heading,raw))
        generic = {'speed_camera':'camera','stop':'stop','give_way':'giveWay'}.get(tags.get('highway'))
        if 'traffic_calming' in tags: generic = 'calming'
        if generic:
            relative = tags.get('direction','')
            heading = (course + (180 if relative == 'backward' else 0)) % 360 if course is not None and relative in {'forward','backward'} else None
            # Cardinal camera faces are ambiguous for front/rear capture. Do not
            # silently pick a traffic direction without an enforcement relation.
            values.append((generic,None,heading,''))
        for kind,value,heading,raw in values:
            self.add_sign(f'n{ident}:{kind}:{way}:{heading}', point,kind,value,heading,way,along,'OSM' if heading is not None else 'OSM · hướng chưa rõ',raw)
    def way(self, ident, refs, points, tags):
        if tags.get('highway') not in DRIVABLE or len(points) < 2: return
        if tags.get('junction') == 'roundabout' and 'oneway' not in tags: tags = {**tags,'oneway':'yes'}
        if not all(-90 <= p[0] <= 90 and -180 <= p[1] <= 180 for p in points): return
        self.endpoints[ident] = ((refs[0],points[0],bearing(points[0],points[1])),(refs[-1],points[-1],bearing(points[-2],points[-1])))
        cumulative = [0.0]
        for a,b in zip(points,points[1:]): cumulative.append(cumulative[-1]+distance(a,b))
        clean = kept_tags(tags)
        start = 0
        for end in range(1,len(points)):
            if end == len(points)-1 or end-start >= 127 or cumulative[end]-cumulative[start] >= 2500:
                chunk = points[start:end+1]
                payload = {'id':ident,'offset':round(cumulative[start],2),'points':chunk,'tags':clean}
                row = self.db.execute('INSERT INTO roads VALUES(NULL,?,?)',(ident,compact(payload))).lastrowid
                self.db.execute('INSERT INTO roads_rtree VALUES(?,?,?,?,?)',(row,min(p[1] for p in chunk),max(p[1] for p in chunk),min(p[0] for p in chunk),max(p[0] for p in chunk)))
                self.counts['road_parts'] += 1
                start = end
        self.counts['roads'] += 1
        if 'maxspeed' in tags: self.counts['roads_maxspeed'] += 1
        for index,ref in enumerate(refs):
            if ref in self.nodes:
                point,node_tags = self.nodes[ref]
                course = bearing(points[max(0,index-1)],points[min(len(points)-1,index+1)])
                self.node_signs(ref,point,node_tags,ident,cumulative[index],course)
                self.attached.add(ref)
        for suffix,point,index,course in [('forward',points[0],0,bearing(points[0],points[1])),('backward',points[-1],-1,(bearing(points[-2],points[-1])+180)%360)]:
            if tags.get('oneway') in {'yes','1','true'} and suffix == 'backward' or tags.get('oneway') == '-1' and suffix == 'forward': continue
            raw = tags.get('traffic_sign:'+suffix, tags.get('traffic_sign',''))
            for kind,value in sign_types(raw,tags):
                self.add_sign(f'w{ident}:{kind}:{suffix}',point,kind,value,course,ident,cumulative[index],raw=raw)
            # Way maxspeed is segment data, not evidence of a physical sign.
            if not any('conditional' in k or 'lanes' in k for k in tags if k.startswith('maxspeed')):
                value = speed(tags.get('maxspeed:'+suffix,tags.get('maxspeed')))
                if value: self.add_sign(f'w{ident}:limit:{suffix}',point,'speed',value,course,ident,cumulative[index],'Đầu đoạn OSM · không xác nhận vị trí biển')
            if tags.get('motorcar',tags.get('motor_vehicle',tags.get('access'))) == 'no':
                self.add_sign(f'w{ident}:access:{suffix}',point,'noCar',heading=course,way=ident,along=cumulative[index],note='Hạn chế OSM · đầu đoạn')
    def finish(self, source):
        for ident,(point,tags) in self.nodes.items():
            if ident not in self.attached: self.node_signs(ident,point,tags)
        for ident,tags,members in self.relations:
            if any('conditional' in k for k in tags) or tags.get('except'):
                self.counts['conditional_relations_skipped'] += 1; continue
            via = [ref for role,typ,ref in members if role == 'via' and typ == 'n']
            if tags.get('type') == 'restriction':
                kind = RESTRICTIONS.get(tags.get('restriction:motorcar',tags.get('restriction')))
                incoming = [ref for role,typ,ref in members if role == 'from' and typ == 'w']
                if kind and len(via) == 1 and len(incoming) == 1:
                    ends = self.endpoints.get(incoming[0],())
                    match = next((e for e in ends if e[0] == via[0]),None)
                    if match:
                        course = match[2] if match is ends[-1] else (match[2]+180)%360
                        self.add_sign(f'r{ident}',match[1],kind,heading=course,way=incoming[0],note='Quan hệ hạn chế OSM')
                    else: self.counts['unresolved_relations'] += 1
                else: self.counts['unresolved_relations'] += 1
            elif tags.get('enforcement') == 'maxspeed':
                origin = [self.coordinates[ref] for role,typ,ref in members if role=='from' and typ=='n' and ref in self.coordinates]
                devices = [self.coordinates[ref] for role,typ,ref in members if role in {'device','via'} and typ=='n' and ref in self.coordinates]
                if len(origin)==1 and devices:
                    self.add_sign(f'r{ident}:camera',devices[0],'camera',heading=bearing(origin[0],devices[0]),note='Quan hệ enforcement OSM')
                else: self.counts['unresolved_relations'] += 1
        meta = {'schema':1,'country':'VN','built':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source':source,'license':'ODbL-1.0','attribution':'© OpenStreetMap contributors · Geofabrik','counts':dict(self.counts),'raw_sign_values':dict(self.raw_signs.most_common(50))}
        self.db.execute('INSERT INTO metadata VALUES(?,?)',('info',compact(meta)))
        self.db.commit()
        assert self.db.execute('PRAGMA quick_check').fetchone()[0] == 'ok'
        self.db.execute('ANALYZE'); self.db.commit(); self.db.close()
        return meta

def build(source, output):
    builder = Builder(output)
    if str(source).endswith('.osm'):
        import xml.etree.ElementTree as ET
        tree = ET.parse(source).getroot()
        nodes = {}
        for item in tree:
            tags = {t.attrib['k']:t.attrib['v'] for t in item.findall('tag')}
            ident = int(item.attrib['id'])
            if item.tag == 'node':
                point = [float(item.attrib['lat']),float(item.attrib['lon'])]
                nodes[ident]=point; builder.coordinates[ident]=point; builder.node(ident,point,tags)
            elif item.tag == 'relation': builder.relation(ident,tags,[(m.attrib['role'],m.attrib['type'][0],int(m.attrib['ref'])) for m in item.findall('member')])
        for item in tree.findall('way'):
            refs=[int(n.attrib['ref']) for n in item.findall('nd')]
            if all(n in nodes for n in refs): builder.way(int(item.attrib['id']),refs,[nodes[n] for n in refs],{t.attrib['k']:t.attrib['v'] for t in item.findall('tag')})
    else:
        import osmium
        class First(osmium.SimpleHandler):
            def node(self,n):
                if n.location.valid(): builder.node(n.id,[round(n.location.lat,7),round(n.location.lon,7)],dict(n.tags))
            def relation(self,r): builder.relation(r.id,dict(r.tags),[(m.role,m.type,m.ref) for m in r.members])
        First().apply_file(str(source))
        wanted={ref for _,_,members in builder.relations for _,typ,ref in members if typ=='n'}
        class Roads(osmium.SimpleHandler):
            def node(self,n):
                if n.id in wanted and n.location.valid(): builder.coordinates[n.id]=[n.location.lat,n.location.lon]
            def way(self,w):
                if w.tags.get('highway') not in DRIVABLE: return
                if all(n.location.valid() for n in w.nodes): builder.way(w.id,[n.ref for n in w.nodes],[[round(n.lat,7),round(n.lon,7)] for n in w.nodes],dict(w.tags))
        Roads().apply_file(str(source),locations=True,idx='sparse_file_array,/tmp/taxi-osm-node-index')
    return builder.finish('https://download.geofabrik.de/asia/vietnam-latest.osm.pbf' if not str(source).endswith('.osm') else 'Synthetic OSM fixture · not road truth')

if __name__ == '__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('input'); parser.add_argument('output'); args=parser.parse_args()
    meta=build(args.input,args.output)
    path=Path(args.output); compressed=path.with_suffix(path.suffix+'.gz')
    with path.open('rb') as inp,gzip.open(compressed,'wb',compresslevel=6) as out:
        import shutil
        shutil.copyfileobj(inp,out)
    assert compressed.stat().st_size < 200*1024*1024, 'Pack too large for mobile download'
    assert path.stat().st_size < 1536*1024*1024, 'Database too large for mobile storage'
    sha=hashlib.file_digest(compressed.open('rb'),'sha256').hexdigest()
    meta['builder_sha']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    source_meta=Path(args.input).with_name('source.json')
    if source_meta.exists(): meta['snapshot']=json.loads(source_meta.read_text())
    meta.update(file=compressed.name,sha256=sha,bytes=compressed.stat().st_size,db_bytes=path.stat().st_size)
    path.with_name('manifest.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2))
    path.with_name('LICENSE.txt').write_text('© OpenStreetMap contributors. Source: https://download.geofabrik.de/asia/vietnam.html\nDerived database: Open Database License 1.0 https://opendatacommons.org/licenses/odbl/1-0/\nBuild source: https://github.com/ThanhTaxiXanh/TaxiDriveAADashboad/tree/main/tools/road_data\nNo user data is included.\n')
    print(json.dumps(meta,ensure_ascii=False))
