#!/system/bin/sh
# ==========================================================
# SysTune Service Scheduler v2.0 (Reactive Polling)
# ==========================================================

MODDIR=${0%/*}
LOG="$MODDIR/logs/service.log"
STATE="$MODDIR/state"

mkdir -p "$MODDIR/logs" "$STATE"
chmod 755 "$MODDIR/"*.sh

log() { echo "[service] $(date '+%F %T') | $1" >> "$LOG"; }

LAST_STATUS=""
LAST_PROFILE=""
POLL_INTERVAL=30 # Dynamic interval

log "Service started (Reactive Mode)"

while true; do
    LEVEL=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null)
    STATUS=$(cat /sys/class/power_supply/battery/status 2>/dev/null)

    # 1. Profile Management (Logic inside auto_profile.sh)
    sh "$MODDIR/auto_profile.sh"

    # Detect profile changes for logging
    PROFILE_FILE="$STATE/auto_profile.status"
    if [ -f "$PROFILE_FILE" ]; then
        CUR_PROFILE=$(awk -F': ' '/^Profile:/ {print $2}' "$PROFILE_FILE")
        if [ "$CUR_PROFILE" != "$LAST_PROFILE" ]; then
            log "Profile: $CUR_PROFILE (Bat: ${LEVEL}%)"
            LAST_PROFILE="$CUR_PROFILE"
        fi
    fi

    # 2. Charging Logic: battery_safe.sh
    if [ "$STATUS" = "Charging" ]; then
        POLL_INTERVAL=60 # Check every minute while charging
        if [ ! -f "$STATE/battery_safe.pid" ] || ! kill -0 "$(cat "$STATE/battery_safe.pid")" 2>/dev/null; then
            sh "$MODDIR/battery_safe.sh" &
            echo $! > "$STATE/battery_safe.pid"
            log "battery_safe started"
        fi
    else
        POLL_INTERVAL=1800 # Deep sleep (30 min) when discharging
        # Clean up if charger was just pulled
        if [ -f "$STATE/battery_safe.pid" ]; then
            kill "$(cat "$STATE/battery_safe.pid")" 2>/dev/null
            rm -f "$STATE/battery_safe.pid"
            log "battery_safe stopped (unplugged)"
        fi
    fi

    LAST_STATUS="$STATUS"
    sleep "$POLL_INTERVAL"
done
