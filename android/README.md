# Android build

The APK in the [v1.0 release](https://github.com/technicalnihilist-lgtm/age-scanner/releases/tag/v1.0) is built from this folder: a single `Activity` hosting a `WebView` that loads `assets/AgeScanner.html` — the exact same app as the web version, models included.

There is no Gradle project here on purpose. The whole thing is three files and a shell script, built straight against the SDK:

| File | Role |
| --- | --- |
| `AndroidManifest.xml` | package `com.technicalnihilist.agescanner`, minSdk 24, targetSdk 34, `CAMERA` permission only — **no `INTERNET` permission** |
| `java/.../MainActivity.java` | WebView setup, `<input type="file">` → system document picker, `getUserMedia()` → runtime camera permission, back-button handling |
| `build.sh` | javac → d8 → aapt2 → zipalign → apksigner |

## Rebuilding

You need a JDK 17, `android.jar` (platform 34) and Android build-tools 34.0.0. Then:

```bash
# point these at your SDK
BT=$ANDROID_HOME/build-tools/34.0.0
AJAR=$ANDROID_HOME/platforms/android-34/android.jar
```

Copy `AgeScanner.html` into `app/assets/`, generate launcher icons into `app/res/mipmap-*`, and run `build.sh`. It produces a signed `AgeScanner.apk`.

The signing key used for the published APK is a throwaway key created by the script itself — it is not in this repo, so a rebuild produces an APK that cannot update over the released one. Uninstall first if you swap between them.
