import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;
void registerNativeMapLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(
      'assets/licenses/MAPLIBRE_NATIVE_NOTICES.md',
    );
    yield LicenseEntryWithLineBreaks([
      'MapLibre Native and linked components',
    ], text);
    final sqlite = await rootBundle.loadString(
      'assets/licenses/ANDROIDX_SQLITE_LICENSE.txt',
    );
    yield LicenseEntryWithLineBreaks(['AndroidX SQLite (bundled)'], sqlite);
  });
}
