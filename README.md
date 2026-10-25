# CPU Mode Control (cpumodes)

Performance / Schedutil / Power Save switcher for SM-G981N (Snapdragon 865),
with a localhost WebUI opened from the KernelSU module action button.

## Install
1. KernelSU manager -> Modules -> Install from storage -> pick the module zip
2. Reboot.

## Use
- Tap the module's action button (>) in KernelSU manager.
- The control panel opens in your browser at `http://127.0.0.1:8899/?token=...`
- Tap a mode button: apply + verify runs (3-10s), then a success/fail popup.
- Closing the page stops the server. The performance-mode watchdog keeps
  running (it is the only background process this module ever has).

## Modes (verified values, kHz)

| Setting | Performance | Schedutil | Power Save |
|---|---|---|---|
| Cluster 1 Silver (CPU 0-3, policy0) | perf, 1804-1804 | schedutil, 614-1804 | powersave, 614-614 |
| Cluster 2 Gold (CPU 4-6, policy4) | perf, 2419-2419 | schedutil, 710-2419 | powersave, 710-710 |
| Cluster 3 Prime (CPU 7, policy7) | perf, 3091-3091 | schedutil, 844-3091 | powersave, 844-844 |
| Cores online | all 8 | all 8 | 0, 4, 7 only |
| GPU governor | performance | msm-adreno-tz | powersave |
| GPU frequencies | never touched | never touched | never touched |
| Watchdog | yes (20s after apply) | no | no |

## Watchdog (performance only)
- First check 20s after a verified apply; clean -> 60s cycle.
- Any deviation (core/governor/frequency/gpu governor) is fixed and the
  cycle drops to 10s. 100s clean -> back to 60s. Deviation in 60s -> 10s.
- Killed automatically when another mode is applied. Gone after reboot.

## Rules this module obeys
- Nothing is changed at boot, ever. Only button presses act.
- No extra downloads/components: uses KernelSU's busybox httpd only.
- Live WebUI values are read straight from sysfs on every poll.
- Log: `/data/adb/modules/cpumodes/module.log`
