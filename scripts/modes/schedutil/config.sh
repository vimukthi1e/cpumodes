#!/system/bin/sh
# Schedutil mode targets - verified values for SM-G981N (kHz)
# All 8 cores online, governors=schedutil, min=cluster lowest, max=cluster max.
# No watchdog.

GOV_SILVER=schedutil
MIN_SILVER=614400
MAX_SILVER=1804800

GOV_GOLD=schedutil
MIN_GOLD=710400
MAX_GOLD=2419200

GOV_PRIME=schedutil
MIN_PRIME=844800
MAX_PRIME=3091200

GPU_GOV=msm-adreno-tz

ONLINE_ALL=1
KEEP_CORES=""

WATCHDOG=0
