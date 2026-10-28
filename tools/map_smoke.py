"""One-shot integration probes using public city-centre fixtures, never user GPS."""
import json
import pathlib
import urllib.parse
import urllib.request

UA = 'TaxiXanhAADashboard-CI/0.4 (https://github.com/ThanhTaxiXanh/TaxiDriveAADashboad)'
report = {}
def get(url):
    req = urllib.request.Request(url, headers={'User-Agent': UA})
    with urllib.request.urlopen(req, timeout=25) as response:
        raw = response.read(4 * 1024 * 1024 + 1)
    if len(raw) > 4 * 1024 * 1024:
        raise ValueError('Too large')
    return json.loads(raw)

def probe(name, callback):
    try:
        report[name] = {'ok': True, **callback()}
    except Exception as exc:
        report[name] = {'ok': False, 'errorClass': type(exc).__name__}
        if isinstance(exc, urllib.error.HTTPError):
            report[name]['status'] = exc.code
            report[name]['detail'] = exc.read(1000).decode('utf-8', errors='replace')

probe('style', lambda: {'layers': len(get('https://tiles.openfreemap.org/styles/liberty')['layers'])})
probe('dark', lambda: {'layers': len(get('https://tiles.openfreemap.org/styles/dark')['layers'])})
# Public Bac Giang city-centre coordinates; these are not a trip or user data.
a, b = (21.281, 106.194), (21.284, 106.200)
params = {'locations': [{'lat': a[0], 'lon': a[1]}, {'lat': b[0], 'lon': b[1]}], 'costing': 'auto', 'language': 'vi-VN', 'units': 'kilometers'}
def valhalla():
    trip = get('https://valhalla1.openstreetmap.de/route?' + urllib.parse.urlencode({'json': json.dumps(params)}))['trip']
    assert trip['status'] == 0 and trip['legs'][0]['shape']
    return {'language': trip.get('language'), 'maneuvers': len(trip['legs'][0]['maneuvers'])}
probe('valhalla', valhalla)
def osrm():
    data = get(f'https://routing.openstreetmap.de/routed-car/route/v1/driving/{a[1]},{a[0]};{b[1]},{b[0]}?overview=full&geometries=geojson&steps=true')
    assert data['code'] == 'Ok' and data['routes'][0]['geometry']['coordinates']
    return {'steps': len(data['routes'][0]['legs'][0]['steps'])}
probe('osrm', osrm)
probe('photon', lambda: {'results': len(get('https://photon.komoot.io/api/?' + urllib.parse.urlencode({'q': 'Bac Giang', 'limit': 3}))['features'])})
pathlib.Path('map-services-report.json').write_text(json.dumps(report, indent=2))
print('MAP_SMOKE ' + json.dumps(report))
# Public services are not deterministic CI dependencies; report availability
# separately from the hermetic application tests and builds.
