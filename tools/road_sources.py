"""Public sources only; never accepts device positions or user input."""
import json
import urllib.request
from pathlib import Path

report = {}
urls = {
    'geofabrik_head': 'https://download.geofabrik.de/asia/vietnam-latest.osm.pbf',
    'maxspeed_keys': 'https://taginfo.geofabrik.de/asia:vietnam/api/4/keys/all?query=maxspeed&rp=30&page=1&sortname=count_all&sortorder=desc',
    'sign_values': 'https://taginfo.geofabrik.de/asia:vietnam/api/4/key/values?key=traffic_sign&rp=30&page=1&sortname=count&sortorder=desc',
    'direction_values': 'https://taginfo.geofabrik.de/asia:vietnam/api/4/key/values?key=traffic_sign:direction&rp=20&page=1&sortname=count&sortorder=desc',
}
for name, url in urls.items():
    try:
        request = urllib.request.Request(url, method='HEAD' if name.endswith('head') else 'GET', headers={'User-Agent': 'TaxiDriverAADashboard/0.5 public-data-build (github.com/ThanhTaxiXanh/TaxiDriveAADashboad)'})
        with urllib.request.urlopen(request, timeout=45) as response:
            if name.endswith('head'):
                report[name] = {'status': response.status, 'length': response.headers.get('Content-Length'), 'modified': response.headers.get('Last-Modified'), 'url': response.url}
            else:
                report[name] = json.load(response)
    except Exception as error:
        report[name] = {'error': type(error).__name__}
Path('road-source-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
print(json.dumps(report, ensure_ascii=False))
