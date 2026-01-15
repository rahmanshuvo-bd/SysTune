#!/system/bin/sh
# SysTune - WiFi Worker v3.3 (FBT/FPSGO_V3 Final)

# 1. Logic Guard
if [ "$CUR_STAT" = "ScreenOff" ]; then
    MASK="1"
    WIFI_PRIO=0
    UCLAMP=0
else
    case "$NEW_PROFILE" in
        "performance")     MASK="ff"; WIFI_PRIO=1; UCLAMP=1 ;;
        "battery_saver")   MASK="0f"; WIFI_PRIO=0; UCLAMP=0 ;;
        *)                 MASK="0f"; WIFI_PRIO=1; UCLAMP=1 ;;
    esac
fi

# 2. Kernel RPS/XPS
if [ -d "/sys/class/net/wlan0/queues" ]; then
    for q in /sys/class/net/wlan0/queues/rx-*; do echo "$MASK" > "$q/rps_cpus" 2>/dev/null; done
fi

# 3. FBT/uclamp Orchestration
FBT_UC="/sys/kernel/fpsgo/fbt_cam/fbt_cam_uclamp_boost_enable"
[ -e "$FBT_UC" ] && echo "$UCLAMP" > "$FBT_UC"

# 4. MediaTek Node Injection
[ -e "/sys/kernel/debug/fpsgo/common/force_wifi_priority" ] && echo "$WIFI_PRIO" > /sys/kernel/debug/fpsgo/common/force_wifi_priority

# 5. Smart PID Injection (The Fix for 'last_fpid 0')
if [ "$CUR_STAT" = "ScreenOn" ]; then
    FPID=$(cat /dev/cpuset/foreground/tasks 2>/dev/null | awk '$1 > 2000 {print $1}' | tail -n 1)
    
    if [ ! -z "$FPID" ] && [ "$FPID" != "$LAST_PID" ]; then
        # FPSGO_V3 Logic
        [ -e "/sys/kernel/fpsgo/composer/fpsgo_control_pid" ] && echo "$FPID" > /sys/kernel/fpsgo/composer/fpsgo_control_pid
        
        # FBT Task Targeting
        [ -e "/sys/kernel/fpsgo/fbt/fbt_attr_by_pid" ] && echo "$FPID 16" > /sys/kernel/fpsgo/fbt/fbt_attr_by_pid 2>/dev/null
        
        echo "$FPID" > "$STATE/last_fpid"
#        echo "[$(date '+%H:%M:%S')] FBT_INJECT: $FPID" >> "$SYS/logs/wifi_worker.log"
    fi
fi
