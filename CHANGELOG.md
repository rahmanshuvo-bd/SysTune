# SysTune Changelog

## v3.0 – Current
**Date:** 2025-12-31

### Battery Safe (`battery_safe.sh`)
- Revamped pause/resume logic for 80%, 90%, and 95% thresholds
- Charging pause duration fixed to 5 minutes, with 1-minute UI sync between
- Hard stop at 100% and automatic exit when charger unplugged
- Improved state tracking (`MODE`, `TIMER`, `PAUSE_x_DONE`) for stability
- Logs and status updated every 15 seconds without rapid on/off cycles

### Auto Profile (`auto_profile.sh`)
- Added robust automatic profile switching based on battery and system triggers
- Profiles can be defined and stored in `$MODDIR/config/profile.conf`
- Added status tracking in `$MODDIR/state/auto_profile.status`
- Improved log formatting and timestamped entries in `$MODDIR/logs/auto_profile.log`

### Terminal Monitor (`sys_monitor.sh`)
- Real-time monitoring of module activity and system resources
- Integrated with battery_safe and auto_profile for centralized logging
- Displays CPU, memory, battery, and module process info in terminal

---

## v2.0
**Date:** 2025-11-25

- Added pause logic at 90% in battery_safe
- Introduced basic auto_profile module for automatic profile changes
- Integrated simple logs and status files for module tracking

---

## v1.0
**Date:** 2025-10-20

- Initial release of battery_safe module
- Basic charging pause at 80% with simple logging
- Kernel-level charging control without framework abuse
