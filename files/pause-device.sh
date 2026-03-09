#!/bin/sh
# /usr/share/parental-privacy/pause-device.sh
#
# Instantly pause or resume a single device on the kids network using an
# nftables set.  Paused MACs have ALL forwarded traffic rejected at wire
# speed — no firewall reload required, sub-second effect.
#
# The set (kids_paused_macs) and its drop rule are created on first use and
# survive subsequent fw4 reloads because we re-check / re-insert on every call.
#
# Usage:
#   pause-device.sh add  <MAC>   — pause (block internet for this MAC)
#   pause-device.sh del  <MAC>   — resume (restore internet for this MAC)
#   pause-device.sh clear        — unpause ALL devices (called at session start)
#   pause-device.sh list         — print currently-paused MACs, one per line

SET_NAME="kids_paused_macs"
TABLE="inet fw4"
CHAIN="forward"
BRIDGE="br-kids"

# ── Ensure the nft set and drop rule exist ────────────────────────────────────
ensure_set() {
    nft list set $TABLE $SET_NAME >/dev/null 2>&1 || \
        nft add set $TABLE $SET_NAME \
            "{ type ether_addr; flags dynamic,timeout; comment \"Devices paused by Parental Privacy\"; }"
}

ensure_rule() {
    # Insert the reject rule at the head of the forward chain only if absent.
    # We match on the comment string we embed to make the grep reliable.
    nft list chain $TABLE $CHAIN 2>/dev/null | grep -q "kids-pause-reject" || \
        nft insert rule $TABLE $CHAIN \
            iifname "$BRIDGE" \
            ether saddr "@$SET_NAME" \
            counter comment "\"kids-pause-reject\"" \
            reject
}

ACTION="$1"
MAC="$2"

case "$ACTION" in
    add)
        [ -z "$MAC" ] && { echo "Usage: $0 add <MAC>"; exit 1; }
        ensure_set
        ensure_rule
        # nft is idempotent for set elements — adding an existing MAC is a no-op
        nft add element $TABLE $SET_NAME "{ $MAC }" 2>/dev/null
        logger -t parental-privacy "Device PAUSED: $MAC"
        echo '{"result":"paused","mac":"'"$MAC"'"}'
        ;;

    del)
        [ -z "$MAC" ] && { echo "Usage: $0 del <MAC>"; exit 1; }
        ensure_set
        nft delete element $TABLE $SET_NAME "{ $MAC }" 2>/dev/null || true
        logger -t parental-privacy "Device RESUMED: $MAC"
        echo '{"result":"resumed","mac":"'"$MAC"'"}'
        ;;

    clear)
        # Called automatically at the start of each allowed time window so
        # previously-paused devices regain access with the rest of the network.
        if nft list set $TABLE $SET_NAME >/dev/null 2>&1; then
            nft flush set $TABLE $SET_NAME
            logger -t parental-privacy "All paused devices cleared (new session started)"
        fi
        echo '{"result":"cleared"}'
        ;;

    list)
        ensure_set
        # Print one MAC per line (strip nft formatting noise)
        nft list set $TABLE $SET_NAME 2>/dev/null \
            | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}'
        ;;

    *)
        echo "Usage: $0 {add <MAC>|del <MAC>|clear|list}"
        exit 1
        ;;
esac