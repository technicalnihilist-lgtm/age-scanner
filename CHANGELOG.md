# Changelog

Under-the-hood work only. No UI, layout, wording or feature changes — the app should look and behave exactly the same, just faster, lighter and harder to break.

## 2026-11-11 — day 3 (10 improvements)

- **Fell back to a box crop when the eye landmarks are unusable.** An empty landmark set averaged to `NaN` and two coincident eyes gave an alignment scale of 70x, so the crop was blank or wildly zoomed — and the age net happily scored it. `centre()` now returns `null` for an empty or non-finite set, `eyesApart()` requires a real eye distance, and both cases drop to the existing `boxCrop` fallback.
- **Made the overlay survive an un-drawable box.** A zero or `NaN` width reached `arcTo` as a negative corner radius, which throws `IndexSizeError` and aborts the whole draw — every box on the photo vanished, not just the bad one. `roundRect` now opens a fresh path, clamps the radius to `0`, and returns early on a non-finite or non-positive rectangle; `drawOverlay` skips such a detection up front.
- **Kept the photo-to-screen scaling finite.** If the `<img>` had no layout size at the moment a scan finished, `dispW / natW` produced `Infinity` or `NaN`, and those box coordinates stuck until the next scan. Both factors now fall back to `1`.
- **Stopped a prediction without a face from killing the scan.** `preds.forEach` indexed `buckets[owners[i]]` blindly, so one extra prediction in a batch threw a `TypeError` and lost the whole result. The owner index is range-checked now.
- **Settled photo loads that get superseded.** Assigning a new `src` cancels the previous load, so its `onload` never fired and the promise waiting on it never settled — that async function and the canvas it held stayed alive for the rest of the session. A pending load is now resolved as "superseded" when a newer photo or New takes over.
- **Stopped blaming the wrong file for a late decode failure.** A photo replaced (or cleared) while it was decoding still surfaced "Could not read that image." for the file the user had since picked. A decode failure is now only reported when it belongs to the photo that is still current.
- **Drew a captured frame straight at the fitted size.** `capture()` built a full-resolution frame canvas and `useBitmap` then resampled it into a second canvas: two resamples and a 1280x720 (~3.7 MB) buffer alive next to the downscaled copy. The shared `fittedSize()` helper now lets the frame be drawn once, at the size the detector uses.
- **Released the camera on `pagehide`.** iOS Safari does not reliably fire `visibilitychange` when a tab is closed or the app is swiped away, so the sensor could stay on until the page was collected. `pagehide` now stops the stream (and cancels a `getUserMedia` still waiting on the prompt).
- **Released the aligned crop canvases after a scan.** Five 224x224 canvases per face were left to the garbage collector; on a group photo that is tens of MB held for no reason. They are resized to 0 as soon as their brightness and thumbnails have been read.
- **Cached the decoded model weights.** The embedded-store shim ran `atob` over hundreds of kB of base64 on every fetch of the same file. Decoded bytes are cached by name, and the base64 string — ~1.3x the size of the bytes — is dropped once it has been decoded.

Verified in headless Chromium against the same multi-face photo used for the screenshots: boot to "Ready" on the WebGL backend, two faces read with the identical estimate as before the batch (30 yrs top face, the same five aligned views and face chips) and no page errors; a fake camera device opens, captures (1280x720 frame fitted to 1100x619, exactly as before), releases the stream and reports "No face found" cleanly; fast mode, a no-face photo, reset mid-scan and two overlapping uploads all behave as before. `node --check` passes on all three inline scripts.

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
