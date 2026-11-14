#!/usr/bin/env bash
# Generate an Android Enterprise (fully managed / device owner) provisioning QR code for a custom DPC.
# Usage:
#   make-dpc-qr.sh -c com.example.dpc/.AdminReceiver -u https://host/dpc.apk [-a local.apk | -s CHECKSUM] [-e '{"key":"val"}'] [-o out.png]
#   -c  admin component name (package/receiver class)
#   -u  HTTPS URL the device downloads the APK from
#   -a  local copy of that APK (signature checksum is computed from it)
#   -s  signature checksum (SHA-256 of signing cert, base64url, no padding) if you already have it
#   -e  optional JSON object passed to the DPC as admin extras bundle
#   -o  output PNG (default dpc-qr.png)
set -euo pipefail
OUT=dpc-qr.png; EXTRAS=""; APK=""; SUM=""
while getopts "c:u:a:s:e:o:" o; do case $o in
  c) COMP=$OPTARG;; u) URL=$OPTARG;; a) APK=$OPTARG;; s) SUM=$OPTARG;; e) EXTRAS=$OPTARG;; o) OUT=$OPTARG;;
  *) sed -n '2,11p' "$0"; exit 1;; esac; done
: "${COMP:?-c component required}" "${URL:?-u download URL required}"

if [[ -z $SUM ]]; then
  [[ -n $APK ]] || { echo "Give -a APK or -s checksum" >&2; exit 1; }
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  if command -v apksigner >/dev/null; then
    hex=$(apksigner verify --print-certs "$APK" | awk '/Signer #1 certificate SHA-256 digest/{print $NF; exit}')
  else  # v1 (JAR) signature block fallback
    blk=$(unzip -Z1 "$APK" | grep -E '^META-INF/.*\.(RSA|DSA|EC)$' | head -1) \
      || { echo "No v1 signature block; install apksigner (android-sdk-build-tools) or pass -s" >&2; exit 1; }
    unzip -p "$APK" "$blk" > "$tmp/sig"
    openssl pkcs7 -inform DER -in "$tmp/sig" -print_certs | openssl x509 -outform DER > "$tmp/cert.der"
    hex=$(sha256sum "$tmp/cert.der" | cut -d' ' -f1)
  fi
  SUM=$(echo -n "$hex" | xxd -r -p | base64 | tr '+/' '-_' | tr -d '=\n')
fi

json=$(python3 - "$COMP" "$URL" "$SUM" "$EXTRAS" <<'PY'
import json, sys
comp, url, csum, extras = sys.argv[1:]
p = "android.app.extra.PROVISIONING_"
d = {p+"DEVICE_ADMIN_COMPONENT_NAME": comp,
     p+"DEVICE_ADMIN_PACKAGE_DOWNLOAD_LOCATION": url,
     p+"DEVICE_ADMIN_SIGNATURE_CHECKSUM": csum,
     p+"LEAVE_ALL_SYSTEM_APPS_ENABLED": True,
     p+"SKIP_ENCRYPTION": False}
if extras: d[p+"ADMIN_EXTRAS_BUNDLE"] = json.loads(extras)
print(json.dumps(d, separators=(",", ":")))
PY
)
echo "$json" > "${OUT%.png}.json"
qrencode -o "$OUT" -s 8 -m 4 -l M "$json"
qrencode -t ANSIUTF8 -l M "$json"
echo "Wrote $OUT and ${OUT%.png}.json"
