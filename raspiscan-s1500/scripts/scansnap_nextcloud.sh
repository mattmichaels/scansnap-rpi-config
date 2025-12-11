#!/bin/bash
logger -t scanbd-scansnap "Scan button pressed - starting scansnap_to_nextcloud.sh"

sudo -n -u pi /usr/local/bin/scansnap_to_nextcloud.sh
RC=$?

logger -t scanbd-scansnap "scansnap_to_nextcloud.sh finished with exit code $RC"
exit "$RC"
