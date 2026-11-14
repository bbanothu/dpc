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
#   -w  Wi-Fi SSID to join during setup (for phones with no other internet, e.g. inactive eSIM)
#   -t  Wi-Fi security: WPA (default), WEP, EAP or NONE
#   -p  Wi-Fi password
#   -H  Wi-Fi network is hidden
set -euo pipefail
OUT=dpc-qr.png; EXTRAS=""; APK=""; SUM=""; SSID=""; SEC=WPA; WPASS=""; HIDDEN=0
while getopts "c:u:a:s:e:o:w:t:p:H" o; do case $o in
  c) COMP=$OPTARG;; u) URL=$OPTARG;; a) APK=$OPTARG;; s) SUM=$OPTARG;; e) EXTRAS=$OPTARG;; o) OUT=$OPTARG;; w) SSID=$OPTARG;; t) SEC=$OPTARG;; p) WPASS=$OPTARG;; H) HIDDEN=1;;
  *) sed -n '2,15p' "$0"; exit 1;; esac; done
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
  SUM=$(python3 -c 'import sys,base64;print(base64.urlsafe_b64encode(bytes.fromhex(sys.argv[1])).decode())' "$hex")
fi

json=$(python3 - "$COMP" "$URL" "$SUM" "$EXTRAS" "$SSID" "$SEC" "$WPASS" "$HIDDEN" <<'PY'
import json, sys
comp, url, csum, extras, ssid, sec, wpass, hidden = sys.argv[1:]
p = "android.app.extra.PROVISIONING_"
d = {p+"DEVICE_ADMIN_COMPONENT_NAME": comp,
     p+"DEVICE_ADMIN_PACKAGE_DOWNLOAD_LOCATION": url,
     p+"DEVICE_ADMIN_SIGNATURE_CHECKSUM": csum + "=" * (-len(csum) % 4)}
if "/." in comp: comp = comp.replace("/.", "/" + comp.split("/")[0] + ".", 1)
d[p+"DEVICE_ADMIN_COMPONENT_NAME"] = comp
if extras: d[p+"ADMIN_EXTRAS_BUNDLE"] = json.loads(extras)
if ssid:
    d[p+"WIFI_SSID"] = ssid
    d[p+"WIFI_SECURITY_TYPE"] = sec.upper()
    if wpass: d[p+"WIFI_PASSWORD"] = wpass
    if hidden == "1": d[p+"WIFI_HIDDEN"] = True
print(json.dumps(d, separators=(",", ":")))
PY
)
echo "$json" > "${OUT%.png}.json"
qrencode -o "$OUT" -s 10 -m 4 -l L "$json"
qrencode -t ANSIUTF8 -l L "$json"
echo "Wrote $OUT and ${OUT%.png}.json"
