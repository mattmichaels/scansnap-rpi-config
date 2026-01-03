#!/bin/bash
set -euo pipefail

###############################################################################
# ScanSnap iX500 → Nextcloud
###############################################################################

# ---- HARD SETTINGS (safe defaults) ------------------------------------------
SCAN_MODE="Color"
SCAN_RESOLUTION="300"
SCAN_SOURCE="ADF Duplex"     # confirmed valid via scanimage -A

# Duplex behavior control:
# ScanSnap face-up duplex via SANE often returns pages as: BACK then FRONT for each sheet.
# Setting KEEP_FACE_UP=true will reorder each duplex pair to FRONT then BACK.
KEEP_FACE_UP=true

# If pages are coming out upside down, force rotate TIFFs 180 degrees.
FORCE_ROTATE_180=true

# Page size / cropping protection:
# Use Legal height to avoid clipping longer pages; Letter will just have extra whitespace.
PAGE_WIDTH_MM="215.9"    # 8.5"
PAGE_HEIGHT_MM="355.6"   # 14" (Legal)
OVERSCAN="On"

WORK_BASE="/home/pi/scansnap-work"

# ---- OPTIONAL: hard-code device (recommended once stable)
SCANNER_DEVICE_OVERRIDE="fujitsu:ScanSnap iX500:1251149"

# ---- Load Nextcloud secrets -------------------------------------------------
ENV_FILE="/usr/local/etc/scansnap.env"
if [[ ! -r "$ENV_FILE" ]]; then
  echo "[scansnap] ERROR: Cannot read $ENV_FILE"
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

: "${NC_BASE_URL:?NC_BASE_URL not set}"
: "${NC_TARGET_DIR:?NC_TARGET_DIR not set}"
: "${NC_USER:?NC_USER not set}"
: "${NC_PASS:?NC_PASS not set}"

###############################################################################
# Resolve scanner device
###############################################################################
resolve_scanner_device() {
  if [[ -n "${SCANNER_DEVICE_OVERRIDE:-}" ]]; then
    echo "$SCANNER_DEVICE_OVERRIDE"
    return 0
  fi

  local dev
  dev="$(scanimage -L | awk -F"'" '/ScanSnap iX500/ {print $2; exit}')"

  if [[ -z "$dev" ]]; then
    echo "[scansnap] ERROR: Could not detect ScanSnap iX500"
    exit 1
  fi

  echo "$dev"
}

###############################################################################
# Job setup
###############################################################################
SCANNER_DEVICE="$(resolve_scanner_device)"

JOB_NAME="ScanSnap-$(date +%Y-%m-%d-%H-%M-%S)"
RANDOM_SUFFIX="$(head -c 64 /dev/urandom | tr -dc 'A-Za-z0-9' | head -c6)"
WORKDIR="${WORK_BASE}/job-${RANDOM_SUFFIX}"

mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "[scansnap] Starting job: $JOB_NAME"
echo "[scansnap] Workdir: $WORKDIR"
echo "[scansnap] Device: $SCANNER_DEVICE"
echo "[scansnap] Source: $SCAN_SOURCE | Mode: $SCAN_MODE | DPI: $SCAN_RESOLUTION"
echo "[scansnap] Keep face up: $KEEP_FACE_UP | Rotate 180: $FORCE_ROTATE_180"
echo "[scansnap] Page size (mm): ${PAGE_WIDTH_MM} x ${PAGE_HEIGHT_MM} | Overscan: $OVERSCAN"

###############################################################################
# Scan to TIFF(s)
###############################################################################
scanimage \
  -d "$SCANNER_DEVICE" \
  --source "$SCAN_SOURCE" \
  --mode "$SCAN_MODE" \
  --resolution "$SCAN_RESOLUTION" \
  --page-width "$PAGE_WIDTH_MM" \
  --page-height "$PAGE_HEIGHT_MM" \
  --overscan "$OVERSCAN" \
  --batch=page-%03d.tif \
  --format=tiff

shopt -s nullglob
pages=(page-*.tif)

if [[ ${#pages[@]} -eq 0 ]]; then
  echo "[scansnap] ERROR: No pages scanned"
  exit 1
fi

echo "[scansnap] Scanned ${#pages[@]} page(s)"
ls -1 page-*.tif >/dev/null

###############################################################################
# Optional: force rotate pages 180° (upside-down output workaround)
###############################################################################
if [[ "$FORCE_ROTATE_180" == "true" ]]; then
  if command -v mogrify >/dev/null 2>&1; then
    echo "[scansnap] Rotating TIFFs 180 degrees..."
    mogrify -rotate 180 page-*.tif
  else
    echo "[scansnap] WARNING: mogrify not found (imagemagick). Skipping rotate."
  fi
fi

###############################################################################
# Page ordering
###############################################################################
ordered=()

if [[ "$KEEP_FACE_UP" == "true" && "$SCAN_SOURCE" == "ADF Duplex" ]]; then
  # Expect pairs: back, front -> reorder to front, back
  count=${#pages[@]}
  if (( count % 2 != 0 )); then
    echo "[scansnap] WARNING: Odd number of pages ($count); leaving order unchanged."
    ordered=("${pages[@]}")
  else
    for ((i=0; i<count; i+=2)); do
      back="${pages[i]}"
      front="${pages[i+1]}"
      ordered+=("$front" "$back")
    done
  fi
else
  ordered=("${pages[@]}")
fi

echo "[scansnap] Final PDF page order:"
for p in "${ordered[@]}"; do
  echo "  $p"
done

###############################################################################
# Build PDF
###############################################################################
PDF_FILE="${WORKDIR}/${JOB_NAME}.pdf"
img2pdf "${ordered[@]}" -o "$PDF_FILE"

###############################################################################
# OCR (best-effort)
###############################################################################
if command -v ocrmypdf >/dev/null 2>&1; then
  OCR_PDF="${WORKDIR}/${JOB_NAME}-ocr.pdf"
  if TMPDIR="$WORKDIR" ocrmypdf \
        --skip-text \
        --optimize 1 \
        --fast-web-view 1 \
        --rotate-pages \
        --deskew \
        "$PDF_FILE" "$OCR_PDF"; then
    mv "$OCR_PDF" "$PDF_FILE"
  fi
fi

###############################################################################
# Upload to Nextcloud (WebDAV)
###############################################################################
NC_URL="${NC_BASE_URL}/${NC_TARGET_DIR}/${JOB_NAME}.pdf"

HTTP_CODE="$(curl -sS -k -u "${NC_USER}:${NC_PASS}" \
  -T "$PDF_FILE" \
  "$NC_URL" \
  -o /dev/null -w '%{http_code}')"

if [[ "$HTTP_CODE" != "201" && "$HTTP_CODE" != "204" ]]; then
  echo "[scansnap] ERROR: Upload failed (HTTP $HTTP_CODE)"
  exit 1
fi

echo "[scansnap] Upload complete"
