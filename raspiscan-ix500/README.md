# raspiscan-ix500

Files to deploy:

- `/usr/local/bin/scansnap_to_nextcloud.sh`
- `/etc/scanbd/scanbd.conf`
- `/etc/scanbd/scripts/scansnap_nextcloud.sh`
- Create `/usr/local/etc/scansnap.env` from `usr-local-etc/scansnap.env.example`

Notes:
- Script uses Legal height + overscan to avoid cropping.
- Duplex “keep face up” pair-reordering enabled.
- Forces 180° rotate (common for ScanSnap face-up feed).
