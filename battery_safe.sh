#!/system/bin/sh
# =================================================================
# MTK Battery Safe Charging Controller v3.7
# Fixed: Infinite relaunch loop & Log noise
# =================================================================

MODDIR="/data/adb/modules/SysTune"
PIDFILE="$MODDIR/battery_safe.pid"
LOG="$MODDIR/logs/battery_safe.log"
CHG_LIMIT="/sys/class/power_supply/mtk-master-charger/input_current_limit"
TEMP_NODE="/sys/class/power_supply/battery/temp"
CAP_NODE="/sys/class/power_supply/battery/capacity"

PAUSE_TIME=300
TEMP_LIMIT=430 
ORIG_LIMIT="$(cat "$CHG_LIMIT" 2>/dev/null || echo 3200000)"

# --- Improved Logging (Prevents duplicate spam) ---
last_log=""
log() { 
    if [ "$1" != "$last_log" ]; then
        echo "$(date '+%F %T') | $1" >> "$LOG"
        last_log="$1"
    fi
}

charger_connected() {
    # Specifically check USB/AC online status
    grep -q "1" /sys/class/power_supply/*/online 2>/dev/null
}

set_charging() {
    if [ "$1" = "off" ]; then
        echo 0 > "$CHG_LIMIT"
    else
        echo "$ORIG_LIMIT" > "$CHG_LIMIT"
    fi
}

# Cleanup only on actual system shutdown/manual stop
cleanup() {
    set_charging on
    rm -f "$PIDFILE"
    log "🛑 Service Stopped"
    exit 0
}
trap cleanup INT TERM

# --- Singleton ---
if [ -f "$PIDFILE" ]; then
    read -r OLD_PID < "$PIDFILE"
    if kill -0 "$OLD_PID" 2>/dev/null; then
        exit 0
    fi
fi
echo $$ > "$PIDFILE"

log "⚡ Battery Safe v3.7 started"

PAUSE_80=0; PAUSE_90=0; PAUSE_95=0

while true; do
    # --- Dormant Logic ---
    if ! charger_connected; then
        # Reset states for next plug-in
        if [ "$PAUSE_80" -ne 0 ] || [ "$PAUSE_90" -ne 0 ]; then
            log "🔌 Charger removed - Resetting triggers"
            PAUSE_80=0; PAUSE_90=0; PAUSE_95=0
            set_charging on
        fi
        # Long sleep to save CPU when not charging
        sleep 60
        continue
    fi

    BAT="$(cat "$CAP_NODE" 2>/dev/null || echo 0)"
    TEMP="$(cat "$TEMP_NODE" 2>/dev/null || echo 0)"

    # Thermal guard
    if [ "$TEMP" -gt "$TEMP_LIMIT" ]; then
        set_charging off
        log "🔥 Thermal guard active: $((TEMP/10))C"
        sleep 60
        continue
    fi

    # Logic Sequence
    if [ "$BAT" -ge 95 ] && [ "$PAUSE_95" -eq 0 ]; then
        set_charging off
        log "⏸ Pause @95% - Final"
        sleep "$PAUSE_TIME"
        set_charging on
        PAUSE_95=1
        # Instead of exit, we just wait for unplug
        log "✅ Cycle complete. Waiting for unplug."
        while charger_connected; do sleep 60; done
    
    elif [ "$BAT" -ge 90 ] && [ "$PAUSE_90" -eq 0 ]; then
        set_charging off
        log "⏸ Pause @90%"
        sleep "$PAUSE_TIME"
        set_charging on
        PAUSE_90=1
    
    elif [ "$BAT" -ge 80 ] && [ "$PAUSE_80" -eq 0 ]; then
        set_charging off
        log "⏸ Pause @80%"
        sleep "$PAUSE_TIME"
        set_charging on
        PAUSE_80=1
    fi

    sleep 30
done
