#!/system/bin/sh
# SysTune Diagnostic v3.5 - Full Stack Auditor

MODDIR="/data/adb/modules/SysTune"
LOG_DIR="$MODDIR/logs"
STATE_DIR="$MODDIR/state"

# 1. Header & Daemon Logic
echo "------------------------------------------"
echo "SysTune Polymath Diagnostic | $(date '+%H:%M:%S')"
echo "------------------------------------------"

PID=$(pgrep -f "service.sh --daemon" | head -n1)
if [ -n "$PID" ]; then
    OOM=$(cat /proc/$PID/oom_score_adj 2>/dev/null)
    [ "$OOM" -eq -500 ] && OOM_TYPE="GLOBAL" || OOM_TYPE="SANDBOXED"
    echo "[ DAEMON ] Status: RUNNING | PID: $PID | OOM: $OOM ($OOM_TYPE)"
else
    echo "[ DAEMON ] Status: NOT RUNNING"
fi

# 2. Performance State (Fixed "No State" by Sourcing)
if [ -f "$STATE_DIR/auto_profile.status" ]; then
    # Parse "Profile: name" into variable
    PERF_PROFILE=$(grep "Profile:" "$STATE_DIR/auto_profile.status" | cut -d' ' -f2)
    PERF_BAT=$(grep "Battery:" "$STATE_DIR/auto_profile.status" | cut -d' ' -f2)
    echo "[ PERF   ] Profile: $PERF_PROFILE | Context: $PERF_BAT"
else
    echo "[ PERF   ] Status: No active profile state."
fi

# 3. Battery Policy State
if [ -f "$STATE_DIR/battery_safe.state" ]; then
    . "$STATE_DIR/battery_safe.state"
    echo "[ BATT   ] $STATUS | Step: $STEP | Rem: ${TIME_LEFT:-0}s"
else
    echo "[ BATT   ] Status: Offline"
fi

# 4. Hardware Real-time Peek
CHG_LIMIT="/sys/class/power_supply/mtk-master-charger/input_current_limit"
CUR_LIM=$(cat "$CHG_LIMIT" 2>/dev/null || echo "0")
echo "[ CHARGE ] Hardware Limit: $((CUR_LIM/1000))mA"

# 5. Log Audit (Service, Battery, and Profile)
print_log() {
    local title=$1
    local file=$2
    echo "\n--- $title (Last 3) ---"
    if [ -f "$LOG_DIR/$file" ]; then
        tail -n 3 "$LOG_DIR/$file"
    else
        echo "  [!] $file missing"
    fi
}

print_log "ORCHESTRATOR LOG" "service.log"
print_log "AUTO PROFILE LOG" "auto_profile.log"
print_log "BATTERY SAFE LOG" "battery_safe.log"

echo "------------------------------------------"
