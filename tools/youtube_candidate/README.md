# NewPipe fallback candidate (inactive)

This directory is an isolated scratch project. It is not referenced by the dashboard, its Gradle files, its CI, or its APK. Use it only if the smaller Dart/VisionOS/muxed fix does not pass actual playback. No dashboard files were edited to create this candidate.

Pinned dependency: `com.github.teamnewpipe:NewPipeExtractor:v0.26.5` from JitPack. Official v0.26.5 was released on 2026-08-15. Its release notes fix media.ccc.de; the release itself does not establish YouTube playback success for this app, phone, or network.

## Contents

- `BoundedDownloader.kt`: own `HttpURLConnection` implementation of NewPipe `Downloader.execute(Request)`, allowing HTTPS and known Google service host families, bounded responses, request timeouts, bounded redirects, disconnect cancellation, and no logging/persistent cookies/account import.
- `NewPipeCandidate.kt`: serialized NewPipe initialization and extraction using `StreamInfo.getInfo`. Picks one progressive MP4 muxed source up to 360p first; audio-only alternatives follow. It does not pre-consume the selected URL. Signed URLs are transient and absent from `toString`.
- `NewPipeSpike.kt`: extracts public Blender fixture `aqz-KE-bpKQ`, range-reads at most 2048 bytes from at most two returned candidates, checks MP4 `ftyp`/WebM EBML bytes, prints only scalar status/count/type data, exits 2 on failure. It does not print URLs, response bodies, headers, or exception messages.

The spike is a network/format probe, not a successful decoder session or long playback test. It does not prove in-car audio, steering controls, seek, expiry recovery, or video policy enforcement.

## Build and probe

Java 17 and Gradle 8.9+ are required by this isolated sample. The standalone Kotlin JVM plugin is 2.2.20; it does not change the dashboard's Kotlin plugin. A wrapper is intentionally not copied from another project. On a runner with Gradle installed:

```sh
gradle -p /workspace/scratch/newpipe_candidate classes --no-daemon --console=plain
gradle -p /workspace/scratch/newpipe_candidate run --no-daemon --console=plain
```

Alternatively use a trusted existing wrapper, giving this directory with `-p`. Keep `GRADLE_USER_HOME` writable. The `run` task has a 100-second execution timeout; allow dependency installation separate time. Do not run Gradle or the spike with verbose HTTP/debug logging.

Local validation status: source/API review completed against the pinned upstream tag. Compilation and live range reads have **not** run: no installed Gradle/cache is present, and the attempt to bootstrap Gradle 8.9 was rejected by the environment with `java.net.SocketException: Operation not permitted`. No playback success is claimed.

## Exact upstream references

- Release: https://github.com/TeamNewPipe/NewPipeExtractor/releases/tag/v0.26.5
- Dependency, Android desugaring, R8, license: https://github.com/TeamNewPipe/NewPipeExtractor/blob/v0.26.5/README.md
- License text: https://github.com/TeamNewPipe/NewPipeExtractor/blob/v0.26.5/LICENSE
- Downloader abstract API: https://github.com/TeamNewPipe/NewPipeExtractor/blob/v0.26.5/extractor/src/main/java/org/schabi/newpipe/extractor/downloader/Downloader.java
- Request functions and automatic language headers: https://github.com/TeamNewPipe/NewPipeExtractor/blob/v0.26.5/extractor/src/main/java/org/schabi/newpipe/extractor/downloader/Request.java
- Response constructor: https://github.com/TeamNewPipe/NewPipeExtractor/blob/v0.26.5/extractor/src/main/java/org/schabi/newpipe/extractor/downloader/Response.java
- Global initialization: https://github.com/TeamNewPipe/NewPipeExtractor/blob/v0.26.5/extractor/src/main/java/org/schabi/newpipe/extractor/NewPipe.java
- StreamInfo entry point: https://github.com/TeamNewPipe/NewPipeExtractor/blob/v0.26.5/extractor/src/main/java/org/schabi/newpipe/extractor/stream/StreamInfo.java
- Progressive stream APIs: https://github.com/TeamNewPipe/NewPipeExtractor/blob/v0.26.5/extractor/src/main/java/org/schabi/newpipe/extractor/stream/Stream.java
- Logger null means empty logger: https://github.com/TeamNewPipe/NewPipeExtractor/blob/v0.26.5/extractor/src/main/java/org/schabi/newpipe/extractor/utils/ExtractorLogger.java
- Upstream app currently pins `com.android.tools:desugar_jdk_libs_nio:2.1.5`: https://github.com/TeamNewPipe/NewPipe/blob/dev/gradle/libs.versions.toml (moving branch; confirm resolved dependency with this project's AGP before shipping).

See `ACTIVATION.md` for the Android integration and release gates. This candidate does not alter the existing parked/GPS video restriction.
