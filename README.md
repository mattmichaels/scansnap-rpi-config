ScanSnap Raspberry Pi Configs

This repository contains model-specific, headless Raspberry Pi configurations for running Fujitsu ScanSnap scanners without a PC, using:

SANE + scanbd for hardware button handling

Custom scan pipelines (TIFF → PDF → OCR)

Automatic upload to Nextcloud via WebDAV

No secrets committed (everything injected via .env)

The goal is simple:

Insert paper → press Scan → PDF appears in Nextcloud

This repo acts as a known-good reference for rebuilding any ScanSnap Pi in minutes.

Supported Scanners
Model	Folder	Status
ScanSnap S1500	raspiscan-s1500/	✅ Working
ScanSnap iX500	raspiscan-ix500/	✅ Working

Each folder is self-contained and may differ slightly due to hardware and driver behavior.

Architecture (High-Level)
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


Key design points:

scanbd runs as root

The actual scan workflow runs as user pi

Secrets live in /usr/local/etc/scansnap.env

All configs are reproducible from this repo

Repository Layout
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


Each scanner folder contains:

scanbd.conf

scanbd trigger scripts

the scan → PDF → upload workflow

example .env (never real credentials)

Secrets & Credentials

Nothing sensitive is committed.

Each Pi expects:

/usr/local/etc/scansnap.env


Example (copy from .env.example):

NC_BASE_URL=https://nextcloud.example.com/remote.php/dav/files/USERNAME
NC_TARGET_DIR=Scans
NC_USER=USERNAME
NC_PASS=APP_PASSWORD


Permissions are intentionally strict:

sudo chown root:root /usr/local/etc/scansnap.env
sudo chmod 600 /usr/local/etc/scansnap.env

Deployment Philosophy

These systems are headless

No GUI

No keyboard/mouse

Designed for:

desks

shared spaces

family use

“just press the button”

Each scanner folder contains exact deployment steps in its own README.

Why This Exists

ScanSnap hardware is excellent.
ScanSnap software is… not.

This repo exists to:

Remove Windows/macOS dependency

Preserve button-based workflows

Enable reliable, long-term scanning

Make rebuilds painless

Keep documentation with configuration

Status

Actively used

Proven on multiple Raspberry Pis

Designed to be boring and reliable
