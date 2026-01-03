# ScanSnap Raspberry Pi Configs

Headless, model-specific Raspberry Pi configurations for running Fujitsu ScanSnap scanners **without a PC**.

This repository provides known-good, reproducible setups using:

- **SANE + scanbd** for hardware scan button handling
- **Custom scan pipelines** (TIFF → PDF → OCR)
- **Automatic upload to Nextcloud** via WebDAV
- **No secrets committed** (all credentials injected via `.env`)

**The goal is simple:**

> Insert paper → press Scan → PDF appears in Nextcloud

This repo acts as a **known-good reference** for rebuilding any ScanSnap Pi in minutes.

---

## Supported Scanners

| Model | Folder | Status |
|------|--------|--------|
| ScanSnap S1500 | `raspiscan-s1500/` | ✅ Working |
| ScanSnap iX500 | `raspiscan-ix500/` | ✅ Working |

Each scanner folder is **self-contained** and may differ slightly due to hardware, firmware, or driver behavior.

---

## Architecture (High-Level)

```text
[ScanSnap Button]
        ↓
     scanbd
        ↓
 wrapper script (root)
        ↓
 scansnap_to_nextcloud.sh (runs as pi)
        ↓
 scanimage → TIFFs
        ↓
 rotate / reorder
        ↓
 img2pdf
        ↓
 ocrmypdf (optional)
        ↓
 Nextcloud (WebDAV)
```

---

## Key Design Points

- `scanbd` runs as **root** to listen for hardware button events
- The actual scan workflow runs as user **pi**
- Privilege separation is enforced via **sudoers**, not scripts
- Secrets live in `/usr/local/etc/scansnap.env`
- No credentials are ever committed to Git
- Systems are designed to be **headless and unattended**

---

## Repository Layout

```text
scansnap-rpi-config/
├── raspiscan-s1500/
│   ├── etc-scanbd/
│   ├── usr-local-bin/
│   └── README.md
│
├── raspiscan-ix500/
│   ├── etc-scanbd/
│   ├── usr-local-bin/
│   ├── usr-local-etc/
│   └── README.md
│
└── .gitignore
```

Each scanner folder contains:

- `scanbd.conf`
- scanbd trigger scripts
- the full scan → PDF → upload workflow
- example `.env` files (never real credentials)
- exact deployment steps in its own `README.md`

---

## Secrets & Credentials

Nothing sensitive is committed.

Each Pi expects:

```text
/usr/local/etc/scansnap.env
```

Example (copy from `.env.example`):

```env
NC_BASE_URL=https://nextcloud.example.com/remote.php/dav/files/USERNAME
NC_TARGET_DIR=Scans
NC_USER=USERNAME
NC_PASS=APP_PASSWORD
```

Permissions are intentionally strict:

```bash
sudo chown root:root /usr/local/etc/scansnap.env
sudo chmod 600 /usr/local/etc/scansnap.env
```

---

## Deployment Philosophy

These systems are:

- Headless
- No GUI
- No keyboard or mouse

Designed for:

- Desks
- Shared spaces
- Family use
- Offices

**Just press the button.**

Each scanner folder documents exact rebuild steps so a Pi can be reimaged and restored in minutes.

---

## Why This Exists

ScanSnap hardware is excellent.  
ScanSnap software is… not.

This repository exists to:

- Remove Windows/macOS dependency
- Preserve button-based workflows
- Enable reliable, long-term scanning
- Make rebuilds painless
- Keep documentation alongside configuration

---

## Status

- Actively used
- Proven on multiple Raspberry Pis
- Designed to be boring, stable, and reliable

---

## License

Provided as-is for personal and educational use.  
No affiliation with Fujitsu.
