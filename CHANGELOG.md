# Changelog

Under-the-hood work only. No UI, layout, wording or feature changes — the app should look and behave exactly the same, just faster, lighter and harder to break.

## 2026-11-01 — day 1 (10 improvements)

- **Revoked the object URL** used when `createImageBitmap` is unavailable. The fallback path leaked a blob per photo, which slowly grew memory on long sessions.
- **Built the detector options once** instead of allocating a new `TinyFaceDetectorOptions` on every scan.
- **Guarded against zero-sized bitmaps** before decoding, so a corrupt or empty image now reports a clear message instead of failing deeper in the pipeline.
- **Dropped results from superseded scans.** Pressing "New" while a scan was still running could paint stale results onto a cleared stage; a generation counter now discards them.
- **Cleared stale chips, views and warnings** at the start of each scan, so nothing from the previous photo lingers on screen.
- **Chunked age inference into batches of five**, bounding peak memory on group photos where many crops would otherwise be stacked into one call.
- **Sampled brightness at 16×16** instead of 32×32 — the same signal, a quarter of the pixels to copy and read.
- **Skipped thumbnail encoding in fast mode**, where the views strip is never rendered but the JPEGs were still being produced.
- **Stopped drawing the overlay** when the photo has no layout size yet, avoiding a canvas resize to zero and wasted work on early renders.
- **Released the camera stream when the page is hidden**, instead of leaving the sensor running in a background tab.

Verified after the batch: the app boots in 2.4 s, detects two faces in a test photo, returns an estimate with a range and five aligned views, and throws no page errors.
