#!/bin/bash
set -euo pipefail

###############################################################################
# Config: S1500 → Nextcloud
###############################################################################

# If you ever want to hard-code the device, set this:
# SCANNER_DEVICE_OVERRIDE="fujitsu:ScanSnap S1500:15129"
#SCANNER_DEVICE_OVERRIDE="${SCANNER_DEVICE_OVERRIDE:-}"
# Hard-code S1500 device on this Pi
SCANNER_DEVICE_OVERRIDE="fujitsu:ScanSnap S1500:15129"


SCAN_MODE="Color"
SCAN_RESOLUTION="300"
SCAN_SOURCE="ADF Duplex"

WORK_BASE="/home/pi/scansnap-work"

NC_BASE_URL=""
NC_TARGET_DIR="Scan"
NC_USER="matt"
NC_PASS=""

###############################################################################
# Helper: resolve scanner device for S1500
###############################################################################
resolve_scanner_device() {
  if [ -n "$SCANNER_DEVICE_OVERRIDE" ]; then
    echo "$SCANNER_DEVICE_OVERRIDE"
    return 0
  fi

  # Try to auto-detect ScanSnap S1500 from scanimage -L
  local dev
  dev="$(scanimage -L 2>/dev/null | awk -F"'" '/ScanSnap S1500/ {print $2; exit}')"

  if [ -z "$dev" ]; then
    echo "[scansnap] ERROR: Could not auto-detect ScanSnap S1500 device from 'scanimage -L'." >&2
    echo "[scansnap] Please set SCANNER_DEVICE_OVERRIDE at the top of this script." >&2
    exit 1
  fi

  echo "$dev"
}

###############################################################################
# Job setup
###############################################################################
SCANNER_DEVICE="$(resolve_scanner_device)"

JOB_NAME="ScanSnap-$(date +%Y-%m-%d-%H-%M-%S)"
RANDOM_SUFFIX="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c6 || echo rand)"
WORKDIR="${WORK_BASE}/job-${RANDOM_SUFFIX}"

mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "[scansnap] Starting job: $JOB_NAME"
echo "[scansnap] Workdir: $WORKDIR"
echo "[scansnap] Scanning from device: $SCANNER_DEVICE"

###############################################################################
# Scan to TIFF(s)
###############################################################################
scanimage \
  --device "$SCANNER_DEVICE" \
  --source "$SCAN_SOURCE" \
  --mode "$SCAN_MODE" \
  --resolution "$SCAN_RESOLUTION" \
  --batch=page-%03d.tif \
  --format=tiff

shopt -s nullglob
pages=(page-*.tif)

if [ ${#pages[@]} -eq 0 ]; then
  echo "[scansnap] ERROR: No scanned pages (page-*.tif) found. Aborting."
  exit 1
fi

echo "[scansnap] Scanned ${#pages[@]} page(s):"
ls -lh page-*.tif

###############################################################################
# Duplex reordering (face-up stack: reverse order)
###############################################################################
ordered=()
for ((i=${#pages[@]}-1; i>=0; i--)); do
  ordered+=("${pages[i]}")
done

echo "[scansnap] Reordered page sequence:"
for p in "${ordered[@]}"; do
  echo "  $p"
done

###############################################################################
# Build PDF
###############################################################################
PDF_FILE="${WORKDIR}/${JOB_NAME}.pdf"
echo "[scansnap] Building PDF: $PDF_FILE"

img2pdf "${ordered[@]}" -o "$PDF_FILE"

ls -lh "$PDF_FILE"

###############################################################################
# OCR (light mode, best-effort, using WORKDIR for temp)
###############################################################################
if command -v ocrmypdf >/dev/null 2>&1; then
  OCR_PDF="${WORKDIR}/${JOB_NAME}-ocr.pdf"
  echo "[scansnap] Running OCR (light mode, temp in WORKDIR)…"

  if TMPDIR="$WORKDIR" ocrmypdf \
        --skip-text \
        --optimize 1 \
        --fast-web-view 1 \
        --rotate-pages \
        --deskew \
        "$PDF_FILE" "$OCR_PDF"; then

    mv "$OCR_PDF" "$PDF_FILE"
    echo "[scansnap] OCR complete (light mode)."
  else
    rc=$?
    echo "[scansnap] WARNING: ocrmypdf failed with exit code $rc. Continuing without OCR."
  fi
else
  echo "[scansnap] ocrmypdf not installed; skipping OCR."
fi

###############################################################################
# Upload to Nextcloud
###############################################################################
NC_URL="${NC_BASE_URL}/${NC_TARGET_DIR}/${JOB_NAME}.pdf"
echo "[scansnap] Uploading to Nextcloud: $NC_URL"

HTTP_CODE="$(curl -sS -k -u "${NC_USER}:${NC_PASS}" \
  -T "$PDF_FILE" \
  "$NC_URL" \
  -o /dev/null -w '%{http_code}')"

echo "[scansnap] curl HTTP code: $HTTP_CODE"

if [ "$HTTP_CODE" != "201" ]; then
  echo "[scansnap] ERROR: upload failed with HTTP code $HTTP_CODE."
  exit 1
fi

echo "[scansnap] Upload complete."
