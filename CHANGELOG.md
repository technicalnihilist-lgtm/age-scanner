# Changelog

Under-the-hood work only. No UI, layout, wording or feature changes — the app should look and behave exactly the same, just faster, lighter and harder to break.

## 2026-11-04 — day 2 (10 improvements)

- **Made the camera start single-flight.** Two quick taps on Camera — or a reset while the permission prompt was still up — could fire two `getUserMedia` requests; the second overwrote `stream` and the first camera was never stopped, leaving the sensor on. Requests now carry a token, and one that is cancelled while it waits hands its tracks straight back.
- **Cleared the scan timeout.** `withTimeout` raced detection against a 60 s `setTimeout` that was never cleared, so every scan left a live timer holding its closures for a full minute. It is cleared on both the settled and the failed path.
- **Actually discarded superseded scans.** `scan()` took a generation number at the top but never checked it, so pressing New mid-scan still let the old detection paint boxes and an estimate onto the cleared stage. The generation is compared after detection and after age inference, and reset now stops the scanline itself, since a discarded scan no longer does.
- **Closed the decoded `ImageBitmap`.** `createImageBitmap` returns a full-resolution bitmap that was never closed — around 48 MB held for a 12-megapixel photo for the whole scan, next to the downscaled canvas. It is closed immediately after the single `drawImage` that needs it.
- **Reused one brightness canvas.** `luminance()` allocated a 16×16 canvas and a fresh context per face and then read it back with `getImageData`, which forces a GPU sync each time. A single scratch canvas, created once with `willReadFrequently`, replaces it; the sampled values are identical.
- **Loaded the three models in parallel.** Detector, landmarks and age net were awaited one after another even though they are independent and read from the embedded store. `Promise.all` overlaps them and trims startup; the error path is unchanged.
- **Stopped reallocating the overlay canvas.** `drawOverlay` assigned `overlay.width`/`height` on every draw, and any assignment throws the backing store away and reallocates it even when the number is the same. It now resizes only on a real change and still clears and re-applies the dpr transform every time.
- **Showed the photo through a blob URL.** Every photo was base64-encoded into a data URL on the main thread and then decoded again by the `<img>`, which janks the page on a large image and keeps a string 1.3× the JPEG size in memory. `toBlob` plus an object URL skips both, with the data URL kept as the fallback; the previous photo's URL is revoked once the new one paints, and reset revokes it too.
- **Guarded degenerate face geometry.** A zero-sized or NaN detection box reached `drawImage` as a zero-width source rectangle, which throws `IndexSizeError` (zero) or silently draws nothing (NaN), aborting the whole scan. Side and centre now fall back to the full frame, and `scan()` returns quietly when there is no source canvas.
- **Queued a scan for a photo that arrives mid-scan, and made the newest photo win.** A second photo picked during a running scan hit the `busy` guard and was silently dropped — shown with no result, under the previous photo's boxes. It is now queued and runs when the current scan finishes, and the generation is also checked around the photo encode, which is asynchronous, so an older photo finishing late can no longer take over the `<img>`.

Verified in headless Chromium: the app boots to "Ready" on both the WebGL and CPU backends (parallel model load included), takes a photo through the file input, runs detection including the padded retry, reports "No face found" cleanly, survives a reset mid-scan and two overlapping uploads, and logs no page errors. A full face read could not be exercised here — the repository has no face photo and software GL cannot finish the age net inside the 60 s scan budget.

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
