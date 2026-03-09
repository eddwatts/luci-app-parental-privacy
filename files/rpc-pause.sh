#!/bin/sh
# /usr/share/parental-privacy/rpc-pause.sh
#
# RPC handler for the pause_device method.
# Called by parental-privacy-rpcd when the LuCI dashboard clicks Pause/Resume.
#
# Expects JSON on stdin:  { "action": "add|del|clear", "mac": "aa:bb:cc:dd:ee:ff" }
# Returns JSON:           { "result": "paused|resumed|cleared", "mac": "..." }
#
# Test from CLI:
#   echo '{"action":"add","mac":"aa:bb:cc:dd:ee:ff"}' | \
#       /usr/share/parental-privacy/rpc-pause.sh

SCRIPTS="/usr/share/parental-privacy"

# Read the JSON payload from stdin (rpcd pipes it in)
read -r INPUT

# Portable JSON field extraction (no jq dependency on OpenWrt)
json_get() {
    echo "$INPUT" | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
        | head -1 | sed 's/.*":\s*"\(.*\)"/\1/'
}

ACTION=$(json_get action)
MAC=$(json_get mac)

# Validate action
case "$ACTION" in
    add|del|clear) ;;
    *)
        echo '{"error":"invalid action — must be add, del, or clear"}'
        exit 1
        ;;
esac

# Validate MAC when required
if [ "$ACTION" != "clear" ]; then
    echo "$MAC" | grep -qiE '^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$' || {
        echo '{"error":"invalid or missing mac address"}'
        exit 1
    }
fi

# Delegate to pause-device.sh and return its JSON output
exec "$SCRIPTS/pause-device.sh" "$ACTION" "$MAC"
