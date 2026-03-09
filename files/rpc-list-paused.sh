#!/bin/sh
# /usr/share/parental-privacy/rpc-list-paused.sh
#
# RPC handler for the list_paused method.
# Returns the current contents of the kids_paused_macs nftables set as JSON.
#
# Returns: { "paused_macs": ["aa:bb:cc:dd:ee:ff", ...] }

SCRIPTS="/usr/share/parental-privacy"

MACS=$("$SCRIPTS/pause-device.sh" list 2>/dev/null)

# Build JSON array
JSON_ARRAY=""
for mac in $MACS; do
    if [ -z "$JSON_ARRAY" ]; then
        JSON_ARRAY="\"$mac\""
    else
        JSON_ARRAY="$JSON_ARRAY,\"$mac\""
    fi
done

echo "{\"paused_macs\":[$JSON_ARRAY]}"
