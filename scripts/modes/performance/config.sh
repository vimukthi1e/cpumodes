#!/system/bin/sh
# Performance mode targets - verified values for SM-G981N (kHz)
# All 8 cores online, governors=performance, min=max locked to max.
# Watchdog ON (armed 20s after verified apply).

GOV_SILVER=performance
MIN_SILVER=1804800
MAX_SILVER=1804800

GOV_GOLD=performance
MIN_GOLD=2419200
MAX_GOLD=2419200

GOV_PRIME=performance
MIN_PRIME=3091200
MAX_PRIME=3091200

GPU_GOV=performance

ONLINE_ALL=1
KEEP_CORES=""

WATCHDOG=1
