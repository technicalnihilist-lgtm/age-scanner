#!/bin/bash
set -e
export JAVA_HOME=/scratch/work/toolchain/jdk-17.0.11+9
export PATH="$JAVA_HOME/bin:$PATH"
unset JAVA_TOOL_OPTIONS

JVM="-Xmx192m -Xms64m -Xss256k -XX:+UseSerialGC -XX:MaxMetaspaceSize=96m -XX:CompressedClassSpaceSize=32m -XX:ReservedCodeCacheSize=24m"
JVMJ="-J-Xmx320m -J-Xss512k -J-XX:+UseSerialGC -J-XX:MaxMetaspaceSize=96m -J-XX:CompressedClassSpaceSize=32m -J-XX:ReservedCodeCacheSize=24m"
BT=/scratch/work/toolchain/bt/android-14
AJAR=/scratch/work/toolchain/pt/android-34/android.jar
APP=/scratch/work/apk/app
OUT=/scratch/work/apk/build
rm -rf "$OUT"; mkdir -p "$OUT/classes" "$OUT/dex" "$OUT/compiled"

echo "== 1/7 javac =="
javac $JVMJ -source 8 -target 8 -nowarn -bootclasspath "$AJAR" \
      -d "$OUT/classes" "$APP"/java/com/technicalnihilist/agescanner/MainActivity.java 2>&1 | grep -vi "note:" || true
find "$OUT/classes" -name '*.class' | wc -l

echo "== 2/7 d8 =="
java $JVM -cp "$BT/lib/d8.jar" com.android.tools.r8.D8 \
     --lib "$AJAR" --min-api 24 --output "$OUT/dex" \
     $(find "$OUT/classes" -name '*.class') 2>&1 | tail -8
ls -la "$OUT/dex"

echo "== 3/7 aapt2 compile =="
"$BT/aapt2" compile --dir "$APP/res" -o "$OUT/compiled/res.zip"

echo "== 4/7 aapt2 link =="
"$BT/aapt2" link -o "$OUT/base.apk" -I "$AJAR" \
    --manifest "$APP/AndroidManifest.xml" -A "$APP/assets" \
    --min-sdk-version 24 --target-sdk-version 34 \
    --version-code 1 --version-name 1.0 "$OUT/compiled/res.zip"

echo "== 5/7 add dex =="
(cd "$OUT/dex" && zip -q -X "$OUT/base.apk" classes.dex)
unzip -l "$OUT/base.apk" | tail -6

echo "== 6/7 zipalign =="
"$BT/zipalign" -f -p 4 "$OUT/base.apk" "$OUT/aligned.apk"

echo "== 7/7 sign =="
if [ ! -f /scratch/work/apk/keystore.jks ]; then
  keytool $JVMJ -genkeypair -keystore /scratch/work/apk/keystore.jks \
    -storepass agescanner -keypass agescanner -alias agescanner \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=Age Scanner, OU=Apps, O=technicalnihilist, L=Internet, C=IN" 2>&1 | tail -1
fi
java $JVM -cp "$BT/lib/apksigner.jar" com.android.apksigner.ApkSignerTool sign \
    --ks /scratch/work/apk/keystore.jks --ks-pass pass:agescanner --key-pass pass:agescanner \
    --out /scratch/work/apk/AgeScanner.apk "$OUT/aligned.apk"

echo "== verify =="
java $JVM -cp "$BT/lib/apksigner.jar" com.android.apksigner.ApkSignerTool verify \
    --print-certs /scratch/work/apk/AgeScanner.apk | head -5
ls -la /scratch/work/apk/AgeScanner.apk
