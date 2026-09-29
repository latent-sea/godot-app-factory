#!/usr/bin/env bash
# Rebuild the GoogleSignIn AAR (if its sources changed), make sure the Android
# build template is installed, then export a signed APK and verify it. A release
# export: the debug one is too big to send to a phone (77 MB). Both are signed
# with the factory debug key, whose SHA-1 is the one registered with Google.
# Needs ../supa.gd copied here, and plugin_src/local.properties with sdk.dir.
#   ./build.sh            -> googletest.apk
set -euo pipefail
cd "$(dirname "$0")"
HERE=$PWD
GODOT=${GODOT:-/home/user/tools/Godot_v4.6.2-stable_linux.x86_64}
GRADLE=${GRADLE:-/opt/gradle/bin/gradle}
TEMPLATES=$HOME/.local/share/godot/export_templates/4.6.2.stable
SDK=/home/user/tools/android-sdk
BT=$SDK/build-tools/35.0.0
MIRROR='https://maven-central.storage-download.googleapis.com/maven2/'
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 ANDROID_HOME=$SDK ANDROID_SDK_ROOT=$SDK

retry() { # Maven Central sometimes answers 429; just try again.
  local n; for n in 1 2 3 4; do "$@" && return 0; echo "retry $n: $*" >&2; sleep 5; done; return 1
}

# 1. Plugin AARs
BIN=addons/google_sign_in/bin
if [[ ! -f $BIN/GoogleSignIn-release.aar || -n "$(find plugin_src -newer $BIN/GoogleSignIn-release.aar -type f \( -name '*.kt' -o -name '*.gradle' -o -name '*.xml' \) -not -path '*/build/*')" ]]; then
  echo "== building GoogleSignIn AAR"
  (cd plugin_src && retry "$GRADLE" --no-daemon -q :googlesignin:assembleDebug :googlesignin:assembleRelease)
  mkdir -p $BIN
  cp plugin_src/googlesignin/build/outputs/aar/googlesignin-debug.aar $BIN/GoogleSignIn-debug.aar
  cp plugin_src/googlesignin/build/outputs/aar/googlesignin-release.aar $BIN/GoogleSignIn-release.aar
fi

# 2. Android build template (headless "Install Android Build Template")
if [[ "$(cat android/.build_version 2>/dev/null)" != "4.6.2.stable" || ! -f android/build/build.gradle ]]; then
  echo "== installing Android build template"
  rm -rf android && mkdir -p android/build
  printf '4.6.2.stable\n' > android/.build_version
  : > android/build/.gdignore
  unzip -q "$TEMPLATES/android_source.zip" -d android/build
  chmod +x android/build/gradlew
  # Only build-tools 35.0.0 is installed (template wants 35.0.1).
  sed -i "s/buildTools *: '35.0.1'/buildTools         : '35.0.0'/" android/build/config.gradle
  # Google's Maven Central mirror first, to dodge 429s from repo.maven.apache.org.
  sed -i "0,/google()/s##google()\n        maven { url \"$MIRROR\" }#" android/build/build.gradle android/build/settings.gradle
fi

# 3. Import + export
echo "== importing"
"$GODOT" --headless --path "$HERE" --import >/dev/null 2>&1 || true
echo "== exporting"
rm -f googletest.apk
retry "$GODOT" --headless --path "$HERE" --export-release Android "$HERE/googletest.apk"
[[ -f googletest.apk ]] || { echo "export failed"; exit 1; }

# 4. Verify
echo "== verify"
"$BT/apksigner" verify --print-certs googletest.apk | grep -E "SHA-1|DN"
"$BT/aapt2" dump badging googletest.apk | grep -iE "^package|uses-permission|sdkVersion"
"$BT/aapt2" dump xmltree --file AndroidManifest.xml googletest.apk | grep -A1 "org.godotengine.plugin.v2.GoogleSignIn" | tr -s ' '
TMP=$(mktemp -d); unzip -q -o googletest.apk 'classes*.dex' -d "$TMP"
for dex in "$TMP"/classes*.dex; do
  "$BT/dexdump" "$dex" 2>/dev/null | grep -E "Class descriptor.*'L(com/latentsea/googlesignin/GoogleSignInPlugin|androidx/credentials/CredentialManager|androidx/credentials/playservices/CredentialProviderPlayServicesImpl|com/google/android/libraries/identity/googleid/GoogleIdTokenCredential);'" | sed "s#^ *#$(basename "$dex"): #" || true
done
rm -rf "$TMP"
grep -q '"PASTE_WEB_CLIENT_ID"$' main.gd && grep -q '^const GOOGLE_WEB_CLIENT_ID := "PASTE_WEB_CLIENT_ID"' main.gd && echo "NOTE: GOOGLE_WEB_CLIENT_ID is still the placeholder" || true
echo "== done: $HERE/googletest.apk"
