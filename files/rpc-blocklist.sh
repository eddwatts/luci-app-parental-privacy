#!/bin/sh
# /usr/share/parental-privacy/rpc-blocklist.sh
#
# Handles two methods dispatched by parental-privacy-rpcd:
#
#   blocklist_apply  — saves blocklist selections to UCI
#   blocklist_update — triggers an immediate update in the background
#
# Called with METHOD as first argument (set by the rpcd dispatcher).

. /lib/functions.sh

METHOD="$1"
UCI_CONF="parental_privacy"
UPDATE_SCRIPT="/usr/share/parental-privacy/update-blocklists.sh"

read -r INPUT

# Unwrap 'data' envelope added by rpc.declare params:['data']
_unwrapped=$(echo "$INPUT" | jsonfilter -e '@.data' 2>/dev/null)
[ -n "$_unwrapped" ] && INPUT="$_unwrapped"

ok()   { echo '{"success":true}'; }
fail() { printf '{"success":false,"error":"%s"}\n' "$1"; exit 1; }

# ─────────────────────────────────────────────────────────────────────────────
# METHOD: blocklist_apply
# Saves enabled/disabled state for each list ID to UCI.
# Custom lists are also stored with their URL and name.
#
# Input JSON:
#   {
#     "enabled": { "hagezi_multi_light": true, "oisd_nsfw": false, ... },
#     "custom":  [ { "id": "custom_123", "name": "My List", "url": "https://..." }, ... ]
#   }
# ─────────────────────────────────────────────────────────────────────────────
if [ "$METHOD" = "blocklist_apply" ]; then

    # Remove all existing blocklist sections so we start clean
    # (config_foreach + uci delete would leave orphaned sections on rename)
    config_load "$UCI_CONF"
    config_foreach _del_bl_section "blocklist"

    _del_bl_section() { uci -q delete "${UCI_CONF}.$1" 2>/dev/null; }
    config_foreach _del_bl_section "blocklist"

    # Re-create sections from the enabled map (standard catalog entries)
    ENABLED_KEYS=$(echo "$INPUT" | jsonfilter -e '@.enabled' 2>/dev/null)
    if [ -n "$ENABLED_KEYS" ]; then
        for id in $(echo "$ENABLED_KEYS" | jsonfilter -e '@.*' 2>/dev/null | sort); do
            val=$(echo "$INPUT" | jsonfilter -e "@.enabled.${id}" 2>/dev/null)
            [ -z "$val" ] && val="false"
            enabled=0
            [ "$val" = "true" ] && enabled=1

            # Create a UCI section named after the list ID
            uci -q set "${UCI_CONF}.${id}=blocklist"
            uci -q set "${UCI_CONF}.${id}.id=${id}"
            uci -q set "${UCI_CONF}.${id}.enabled=${enabled}"
        done
    fi

    # Custom list entries
    IDX=0
    while true; do
        cid=$(echo "$INPUT" | jsonfilter -e "@.custom[${IDX}].id" 2>/dev/null)
        [ -z "$cid" ] && break
        curl=$(echo "$INPUT" | jsonfilter -e "@.custom[${IDX}].url" 2>/dev/null)
        cname=$(echo "$INPUT" | jsonfilter -e "@.custom[${IDX}].name" 2>/dev/null)

        # Validate URL
        echo "$curl" | grep -qE '^https?://' || { IDX=$((IDX+1)); continue; }

        uci -q set "${UCI_CONF}.${cid}=blocklist"
        uci -q set "${UCI_CONF}.${cid}.id=${cid}"
        uci -q set "${UCI_CONF}.${cid}.url=${curl}"
        uci -q set "${UCI_CONF}.${cid}.name=${cname:-$curl}"
        uci -q set "${UCI_CONF}.${cid}.enabled=1"
        uci -q set "${UCI_CONF}.${cid}.custom=1"
        IDX=$((IDX+1))
    done

    uci commit "$UCI_CONF"

    # Ensure 3 AM cron entry exists for nightly updates
    if ! grep -q '#kids-blocklist-update' /etc/crontabs/root 2>/dev/null; then
        echo "0 3 * * * $UPDATE_SCRIPT #kids-blocklist-update" >> /etc/crontabs/root
        /etc/init.d/cron restart 2>/dev/null
    fi

    # Also ensure the kids dnsmasq confdir is set in /etc/config/dhcp
    # The kids dnsmasq instance is section 'kids_dns' with tag kids_dns
    # We need: list confdir '/etc/dnsmasq.kids.d'
    KIDS_DNS_SEC=$(uci show dhcp 2>/dev/null | grep "=dnsmasq" | grep -v "@dnsmasq\[0\]" | head -1 | sed 's/=dnsmasq//' | sed 's/dhcp\.//')
    if [ -n "$KIDS_DNS_SEC" ]; then
        EXISTING_CONFDIR=$(uci -q get "dhcp.${KIDS_DNS_SEC}.confdir" 2>/dev/null)
        if [ "$EXISTING_CONFDIR" != "/etc/dnsmasq.kids.d" ]; then
            uci -q set "dhcp.${KIDS_DNS_SEC}.confdir=/etc/dnsmasq.kids.d"
            uci commit dhcp
            /etc/init.d/dnsmasq reload
        fi
    fi

    ok
    exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# METHOD: blocklist_update
# Runs update-blocklists.sh in the background and returns immediately.
# ─────────────────────────────────────────────────────────────────────────────
if [ "$METHOD" = "blocklist_update" ]; then
    if [ ! -x "$UPDATE_SCRIPT" ]; then
        fail "update script not found or not executable"
    fi
    # Background execution — HTTP response returns immediately
    "$UPDATE_SCRIPT" >/dev/null 2>&1 &
    ok
    exit 0
fi

fail "unknown method: $METHOD"
