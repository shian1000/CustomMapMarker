# Custom Map Marker — notes for agents

Flutter app (Android first, iOS maybe later) that turns any image (PNG/JPG/WebP…) into a
Google-Maps-like map: pan/zoom it, put markers on it, draw routes and areas, measure distances,
and export/share maps. The user (Polish speaker) drives development stage by stage.

## Working with this user

- **Answer in Polish.** Code, comments, commit-free docs and identifiers are in English; all UI
  strings are Polish (with correct grammar/plurals — see `lib/core/plural.dart`).
- **Never `git commit` / `git push`.** Finish a change, then give the user copyable commands
  (one command per ```bash block): `git add .`, `git commit -m "…"`, `git push`.
- **Stage-by-stage:** do one sub-stage, test it, install it on the phone, report, then **stop and
  wait**. When asked for a plan, only write the plan (no code).
- **Options are global**, not per map (user: "nie widzę sensu się rozdrabniać") — they live in
  `lib/data/settings.dart` / the Settings screen. Things that are inherently per map (legend
  filter, scale) stay per map.
- Verify on the real device whenever possible; say plainly what was and wasn't checked.

## Commands & skills

- Tests: `flutter test` (173 tests at the end of stage 7d, all green). Analyze: `flutter analyze`.
- Drift codegen after changing `lib/data/database.dart`: `dart run build_runner build`
  (`database.g.dart` is committed).
- Project skills in `.claude/skills/`:
  - `run-on-physical-phone` — build release APK (skipped if current), install on the USB phone
    (Huawei SNE-LX1, serial `HYFDU19412006823`, Android 10), launch, open scrcpy.
  - `share-build-tailscale` — serve the current APK for 15 min at the fixed link
    `http://100.116.249.111:8000/custom_map_marker.apk` (user tests on a Pixel 7a with it).
- **Machine has only 7.6 GB RAM**: a build once got OOM-killed. Gradle is capped in
  `android/gradle.properties` (`-Xmx2G`, Kotlin daemon 1G); check `free -m` before building and
  stop the daemon afterwards with `(cd android && JAVA_HOME=/snap/android-studio/current/jbr
  ./gradlew --stop)` (system Java won't stop it). Details in the skill.
- Never use `pkill -f`/`pgrep -f` with a pattern from a Bash tool call — it matches the tool's own
  shell and kills it (exit 144). Use `pgrep -x scrcpy`. Start scrcpy with
  `SNAP_LAUNCHER_NOTICE_ENABLED=false` (see skill). A white `screencap` = phone locked/asleep.
- Driving the phone for verification: `adb -s HYFDU19412006823 shell input tap|swipe …` +
  `exec-out screencap -p`. Screenshots are 1080×2340. Don't change the user's data while
  checking (cancel edits, don't set scales on their maps).

## Architecture

State: Riverpod 3 (`lib/data/providers.dart`). Persistence: Drift/SQLite
(`lib/data/database.dart`, **schema v6**, every migration tested in
`test/database_migration_test.dart` with hand-written old schemas). Global settings:
`shared_preferences` loaded once in `main.dart` (`PrefsSettingsStore`), in-memory default for tests.

```
lib/
  core/        pure logic: coordinate_mapper (image ↔ CrsSimple LatLng), tile_pyramid,
               tile_generator (Dart fallback tiler), native_tile_renderer (Android channel),
               image_utils, map_archive (.cmm ZIP), measure (lengths/areas/formatting),
               clustering, text_search (diacritic-insensitive), plural, map_naming
  data/        models (map_project, map_marker, map_shape, legend), repositories (map, marker,
               shape, legend), map_transfer (.cmm export/import), settings, providers, database
  features/    maps_list (grid, import, menu), map_view (main screen + layers, tiles, snapshot,
               clustering layer, point handles), marker_editor, marker_list (tabs: markers/
               routes/areas), legend, shape_editor, scale (dialog, scale bar), settings
  shared/      marker_colors (palette), marker_icons (key → IconData), widgets (pin, palette)
android/.../TileRenderer.kt   native tile rendering (BitmapRegionDecoder / whole-pyramid)
```

### Key design decisions (don't undo without reason)

- **Coordinates**: everything user-placed (markers, route/area points) is stored **normalized to
  the image (0..1)**. `MapCoordinateMapper` maps to `CrsSimple`; the image's longer side spans
  ≤1 map unit and full resolution lands exactly on an integer zoom (= tile pyramid top level).
  `CrsSimple` scale is `256 * 2^zoom` (an earlier bug forgot the 256).
- **Large maps (> 4096 px)** are shown as a tile pyramid (`tiles/{z}/{x}/{y}`, no extension;
  JPEG interior, PNG padded edges) next to the image in `maps/<id>/`:
  - JPEG on Android: tiles rendered **on demand** natively (`renderTile`), cached on disk.
  - PNG/WebP on Android: **all tiles generated at import** natively (`generateAllTiles`) because
    region-decoding PNG re-reads from the top per tile (was tens of seconds → blank map).
    Falls back to on-demand if the image doesn't fit in memory.
  - Elsewhere / GIF/BMP: Dart generator in an isolate (slow).
  - Tiles are requested `levelsUp` levels higher on dense screens (DPR ≈ 2.6) so they're sharp.
  - `_TileCompleter` tolerates tiles dropped mid-render (was "Stream has been disposed").
- Old single-image large maps can be converted via the map menu "Popraw jakość (kafelki)".
- **Icons** are stored by string key (`marker_icons.dart`), never by code point (release builds
  tree-shake the icon font).
- **Legend (variant A)**: per-map names for palette colors + hidden flag (= color filter). The
  filter applies to markers, routes and areas. Adding/editing something in a hidden color un-hides
  that color with a message.
- **Routes/areas** ("shapes", table `shapes`): three separate entities from markers; their points
  are their own (independent of markers; snapping to markers only while drawing/dragging, global
  option). Straight segments only.
- **Point handles** (`shape_point_handles.dart`) claim touches with an `EagerGestureRecognizer`
  + raw pointer events — a normal drag recognizer lost to the map's pan on real phones.
- Don't toggle `InteractiveFlag.doubleTapZoom` at runtime: flutter_map 8.3 then stops reporting
  taps entirely. Map taps arrive ~250 ms late because of double-tap detection; tests wait 400 ms.
- **.cmm export** = ZIP with `manifest.json` (+ uncompressed image). `formatVersion` 2 (shapes).
  Optional fields (e.g. `metersPerPixel`) don't bump the version. Import always creates a new map
  with new ids; v1 files still import; newer versions are rejected with a clear message.
- **Scale**: `maps.metersPerPixel` (per map). Lengths/areas in `core/measure.dart`, Polish
  formatting (decimal comma, NBSP thousands, m²/ha/km²).
- Clustering is our own (`flutter_map_marker_cluster` is incompatible with latlong2 0.10).

### Testing notes

- `test/fakes.dart` has fake repositories/pickers and builders (`testMap`, `testMarker`,
  `testShape`). Widget tests of the map screen override providers in `pumpMap`
  (`test/map_view_screen_test.dart`) and use a 1080×2340 @2.75 view like the phone.
- Prefer realistic gestures (`timedDragFrom`, waiting out the double-tap window) — synthetic ones
  hid a real-device bug once. When a test passes suspiciously, check it fails against the old code.
- Python-based edits to Dart files often miss after `dart format` reflows code; match on
  structure or edit with exact current text.

## Status

Done: stages 0–6 (import, markers, persistence, maps list, tiles, 6a–6g: naming/rename/tiling of
old maps, marker list+search+fly-to, legend & color filter, icons, .cmm export/import, clustering,
PNG snapshot) and 7a–7d (routes & areas: draw, select/edit/delete, drag/insert/delete points;
lists/legend/export/PNG integration; global settings; map scale, ruler, lengths/areas, scale bar).

### Remaining (agreed order)

1. **7e** — open `.cmm` files tapped in other apps (Files, Gmail, Drive): Android intent filters
   ("Open with…"; custom extensions are poorly recognized, so also register generic types) and
   route the incoming file to `MapTransfer.import`. Test on both phones (behaviour varies by
   vendor).
2. **7f** — global setting "Grupuj pobliskie znaczniki" (clustering on/off) in Settings.
3. **7g** — faster import of big PNGs (45 s on the Huawei, 21 s on the Pixel for 5456×7567):
   measure first (decode vs. scaling vs. writing ~900 tiles), then e.g. generate lower levels first
   and the full-resolution level in the background.

Ideas mentioned but not planned: scale bar in PNG exports, linking route points to markers,
curved segments (user explicitly wants straight ones).
