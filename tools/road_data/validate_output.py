import gzip
import hashlib
import json
import sqlite3
import sys
from pathlib import Path

folder=Path(sys.argv[1]); meta=json.loads((folder/'manifest.json').read_text())
assert meta['schema']==1 and meta['country']=='VN'
assert meta['file']=='vietnam-roads.sqlite.gz'
archive=folder/meta['file']
assert archive.stat().st_size==meta['bytes']<384*1024*1024
with archive.open('rb') as inp: assert hashlib.file_digest(inp,'sha256').hexdigest()==meta['sha256']
db_path=folder/'vietnam-roads.sqlite'
if not db_path.exists():
    total=0
    with gzip.open(archive,'rb') as inp,db_path.open('wb') as out:
        while chunk:=inp.read(1024*1024):
            total+=len(chunk); assert total<=meta['db_bytes']<1536*1024*1024
            out.write(chunk)
assert db_path.stat().st_size==meta['db_bytes']
with sqlite3.connect(f'file:{db_path}?mode=ro',uri=True) as db:
    assert db.execute('PRAGMA user_version').fetchone()[0]==1
    assert db.execute('PRAGMA quick_check').fetchone()[0]=='ok'
    for table in ['roads','signs','places']:
        count=db.execute(f'SELECT count(*) FROM {table}').fetchone()[0]
        assert count==db.execute(f'SELECT count(*) FROM {table}_rtree').fetchone()[0]
    assert db.execute('SELECT count(*) FROM roads').fetchone()[0]>10000
print(json.dumps({k:meta[k] for k in ['built','counts','bytes','db_bytes','sha256']},ensure_ascii=False))
