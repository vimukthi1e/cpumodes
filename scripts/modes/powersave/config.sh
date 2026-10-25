#!/system/bin/sh
# Power Save mode targets - verified values for SM-G981N (kHz)
# Governors=powersave, min=max locked to cluster minimum.
# Only cores 0,4,7 online (one per cluster, so all 3 policies stay alive).
# No watchdog.

GOV_SILVER=powersave
MIN_SILVER=614400
MAX_SILVER=614400

GOV_GOLD=powersave
MIN_GOLD=710400
MAX_GOLD=710400

GOV_PRIME=powersave
MIN_PRIME=844800
MAX_PRIME=844800

GPU_GOV=powersave

ONLINE_ALL=0
KEEP_CORES="0 4 7"

WATCHDOG=0
