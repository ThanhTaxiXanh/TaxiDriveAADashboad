"""Fail CI if the 64-bit personal APK lacks native 3D code or GPU shaders."""
from pathlib import Path
from zipfile import ZipFile

folder = Path("build/app/outputs/flutter-apk")
release = folder / "app-arm64-v8a-release.apk"
apk = release if release.exists() else folder / "app-debug.apk"
with ZipFile(apk) as archive:
    names = archive.namelist()
    native = [n for n in names if n.startswith("lib/arm64-v8a/") and "maplibre" in n and n.endswith(".so")]
    shaders = [n for n in names if n.endswith("MapShaders.shaderbundle")]
    assert native, "ARM64 MapLibre native library missing"
    assert shaders, "Flutter GPU MapShaders.shaderbundle missing"
    for name in native + shaders:
        assert archive.getinfo(name).file_size > 0, name
        print(f"Verified {name}: {archive.getinfo(name).file_size} bytes")
print(f"Verified native 3D payload in {apk.name}")
