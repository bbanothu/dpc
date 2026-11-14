#!/usr/bin/env bash
# Builds and signs User DPC without Gradle. Output: build/user-dpc.apk
set -euo pipefail
cd "$(dirname "$0")"
T=~/dpc/tools; export JAVA_HOME=$T/jdk PATH=$T/jdk/bin:$PATH
BT=$T/sdk/build-tools/35.0.0; JAR=$T/sdk/platforms/android-35/android.jar
KS=~/dpc/keys/user-dpc.jks; PASS=$(cat ~/dpc/keys/password.txt)
rm -rf build && mkdir -p build/res build/classes build/dex
$BT/aapt2 compile --dir res -o build/res.zip
$BT/aapt2 link -o build/unsigned.apk -I $JAR --manifest AndroidManifest.xml build/res.zip --java build/gen
javac -source 11 -target 11 -nowarn -classpath $JAR -d build/classes $(find src build/gen -name '*.java') 2>&1 | grep -v 'bootstrap\|^1 warning' || true
$BT/d8 --release --min-api 26 --lib $JAR --output build/dex $(find build/classes -name '*.class')
(cd build/dex && zip -qj ../unsigned.apk classes.dex)
$BT/zipalign -f -p 4 build/unsigned.apk build/aligned.apk
$BT/apksigner sign --ks $KS --ks-pass pass:$PASS --out build/user-dpc.apk build/aligned.apk
$BT/apksigner verify build/user-dpc.apk && echo "Built $(pwd)/build/user-dpc.apk"
