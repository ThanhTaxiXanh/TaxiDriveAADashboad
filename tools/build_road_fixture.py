from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent/'road_data'))
from build_pack import build
build(Path('test/fixtures/roads.osm'), Path('build/road-contract.sqlite'))
