import json
import sqlite3
import tempfile
import unittest
from pathlib import Path
from build_pack import build, sign_types, speed, encode_polyline6

ROOT=Path(__file__).resolve().parents[2]
class PackTest(unittest.TestCase):
    def test_polyline6_cross_language_vector(self):
        self.assertEqual(encode_polyline6([[21.281,106.194],[21.282,106.194],[21.282,106.196]]), r'om{qg@_dqpiEo}@??_|B')
    def test_observed_vietnam_tags_and_unknowns(self):
        self.assertEqual(sign_types('VN:401,127[60]',{}),[('speed',60)])
        self.assertEqual(sign_types('VN:P.103c',{}),[('noLeft',None)])
        self.assertEqual(sign_types('P.123a: No left turn',{}),[('noLeft',None)])
        self.assertEqual(sign_types('yes',{}),[])
        self.assertEqual(sign_types('Cấm ô tô rẽ trái từ 6:00AM đến 22:00PM',{}),[])
        self.assertEqual(sign_types('VN:127[60] (wet)',{}),[])
        self.assertEqual(sign_types('P.123a: No left turn 06:00-22:00',{}),[])
        self.assertEqual(sign_types('VN:127[60]',{'maxspeed:conditional':'40 @ (wet)'}),[])
        self.assertIsNone(speed('60|80'))
        self.assertIsNone(speed('signals'))
        self.assertEqual(speed('30 mph'),48)
    def test_real_sqlite_rtree_direction_and_restriction_geometry(self):
        with tempfile.TemporaryDirectory() as folder:
            target=Path(folder)/'fixture.sqlite'
            meta=build(ROOT/'test/fixtures/roads.osm',target)
            self.assertEqual(meta['counts']['roads'],2)
            with sqlite3.connect(target) as db:
                self.assertEqual(db.execute('PRAGMA quick_check').fetchone()[0],'ok')
                signs=[json.loads(v[0]) for v in db.execute('SELECT payload FROM signs')]
                limit=next(v for v in signs if v['id']=='w100:limit:forward')
                self.assertAlmostEqual(limit['bearing'],0,places=3)
                backwards=next(v for v in signs if v['id']=='w100:limit:backward')
                self.assertEqual(backwards['value'],40)
                self.assertAlmostEqual(backwards['bearing'],180,places=3)
                restriction=next(v for v in signs if v['id']=='r900')
                self.assertEqual(restriction['kind'],'noRight')
                self.assertAlmostEqual(restriction['bearing'],0,places=3)
                self.assertEqual(restriction['lat'],21.291)
                self.assertFalse(any(v['id'].startswith('w101:limit') for v in signs))
                self.assertFalse(any(v['id'].startswith('n7:') for v in signs))
                self.assertEqual(next(v for v in signs if v['kind']=='noEntry')['bearing'],0)
                rows=db.execute('SELECT s.payload FROM signs s JOIN signs_rtree r ON r.id=s.id WHERE r.minLat<=? AND r.maxLat>=? AND r.minLon<=? AND r.maxLon>=?',(21.287,21.285,106.195,106.193)).fetchall()
                self.assertTrue(any(json.loads(r[0])['id'].startswith('n2:') for r in rows))
                self.assertEqual(db.execute('SELECT count(*) FROM places').fetchone()[0],1)
                # Shared contract consumed by Dart replay tests (public fixture).
                exported={'roads':[json.loads(v[0]) for v in db.execute('SELECT payload FROM roads')],'signs':signs,'urbanHint':True}
                generated=ROOT/'test/fixtures/roads.generated.json'
                if __import__('os').environ.get('WRITE_ROAD_FIXTURE')=='1': generated.write_text(json.dumps(exported,ensure_ascii=False,indent=2))
                elif generated.exists(): self.assertEqual(json.loads(generated.read_text()),exported)

if __name__=='__main__': unittest.main()
