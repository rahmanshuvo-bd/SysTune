#!/system/bin/sh
# SysTune v3.0 - Event-Driven Orchestrator (Stable Production)

MODDIR="/data/adb/modules/SysTune"
STATE="$MODDIR/state"
LOGS="$MODDIR/logs"
PIDFILE="$STATE/service.pid"

export SYS="$MODDIR"
export STATE="$STATE"

# --- 1. Singleton Guard ---
if [ -f "$PIDFILE" ]; then
    OLD_PID=$(cat "$PIDFILE")
    if [ -d "/proc/$OLD_PID" ] && grep -q "service.sh" "/proc/$OLD_PID/cmdline" 2>/dev/null; then
        [ "$1" = "--daemon" ] && exit 0
        exit 0
    fi
    rm -f "$PIDFILE"
fi

# --- 2. Daemonization ---
if [ "$1" != "--daemon" ]; then
    setsid nohup sh "$0" --daemon >/dev/null 2>&1 &
    exit 0
fi
echo $$ > "$PIDFILE"

# --- 3. Environment & Permission Guard ---
mkdir -p "$STATE" "$LOGS"
for log_file in "service.log" "battery_safe.log" "wifi_worker.log"; do
    [ ! -f "$LOGS/$log_file" ] && touch "$LOGS/$log_file"
done
chmod 755 "$MODDIR"/*.sh
chown -R root:root "$MODDIR"

echo "[$(date '+%H:%M:%S')] Daemon started. PID: $$" >> "$LOGS/service.log"

# --- 4. Execution Wrapper ---
# Logic: Runs workers in subshells to isolate variables and prevent environment pollution.
run_worker() {
    (
      export NEW_PROFILE="$1"
      export CUR_BAT="$2"
      export CUR_STAT="$3"
      [ -f "$SYS/$4" ] && . "$SYS/$4"
    )
}

# --- 5. The Orchestration Loop ---
while true; do
    # Protect from OOM Killer
    echo "-500" > /proc/$$/oom_score_adj 2>/dev/null

    # Hardware Polling
    LEVEL=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null)
    STATUS=$(cat /sys/class/power_supply/battery/status 2>/dev/null)

    # Validity Check: Ensure hardware nodes are ready (Prevents bootloop desync)
    if [ -z "$LEVEL" ] || [ "$LEVEL" -lt 0 ]; then
        sleep 5
        continue
    fi

    # Screen Detection (Hardware Priority)
    if [ -e "/sys/class/backlight/panel0-backlight/brightness" ]; then
        [ "$(cat /sys/class/backlight/panel0-backlight/brightness)" -eq 0 ] && SCR="ScreenOff" || SCR="ScreenOn"
    else
        # Fallback to dumpsys only if boot is fully completed
        SCR="ScreenOn"
        if [ "$(getprop sys.boot_completed)" = "1" ]; then
            dumpsys display | grep -q "mScreenState=OFF" && SCR="ScreenOff"
        fi
    fi

    # Zone Determination Logic
    if [ "$LEVEL" -le 30 ]; then 
        ZONE="battery_saver"
    elif [ "$LEVEL" -le 80 ]; then 
        ZONE="balanced_smooth"
    else 
        ZONE="performance"
    fi

    # --- ACTION 1: Zone/Screen Event Trigger ---
    if [ "$ZONE" != "$LAST_ZONE" ] || [ "$SCR" != "$LAST_SCR" ]; then
        run_worker "$ZONE" "$LEVEL" "$SCR" "auto_profile.sh"
        run_worker "$ZONE" "$LEVEL" "$SCR" "wifi_worker.sh" 2>>"$LOGS/wifi_worker.log"

        LAST_ZONE="$ZONE"
        LAST_SCR="$SCR"
    fi

    # --- ACTION 2: Charging/Safety Logic ---
    if [ "$STATUS" = "Charging" ] || [ "$LAST_CHG" = "Charging" ]; then
        run_worker "$ZONE" "$LEVEL" "$STATUS" "battery_safe.sh"
        LAST_CHG="$STATUS"
    fi

    # --- ACTION 3: Active PID Sync ---
    # Logic: Keep the kernel updated with the foreground PID while screen is on.
    if [ "$SCR" = "ScreenOn" ]; then
        run_worker "$ZONE" "$LEVEL" "$SCR" "wifi_worker.sh"
        SLEEP_TIME=10
    else
        SLEEP_TIME=60
    fi

    sleep $SLEEP_TIME
done
