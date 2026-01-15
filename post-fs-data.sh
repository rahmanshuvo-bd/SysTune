#!/system/bin/sh
# SysTune Early Unlock (post-fs-data.sh)
FBT_UC="/sys/kernel/fpsgo/fbt_cam/fbt_cam_uclamp_boost_enable"
FBT_PID="/sys/kernel/fpsgo/fbt/fbt_attr_by_pid"
FPSGO_PID="/sys/kernel/fpsgo/composer/fpsgo_control_pid"

for node in "$FBT_UC" "$FBT_PID" "$FPSGO_PID"; do
    if [ -e "$node" ]; then
        chmod 666 "$node"
        chcon u:object_r:sysfs:s0 "$node" 2>/dev/null
    fi
done
