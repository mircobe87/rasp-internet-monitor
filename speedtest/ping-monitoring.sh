#!/bin/bash

TARGET=8.8.8.8
PACKETS=10

ONLINE=0
MIN=-1
AVG=-1
MAX=-1
MDEV=-1

PING_OUTPUT="$(ping $TARGET -c $PACKETS -q)"
if [ "$?" = "0" ]; then
    # we are online
    ONLINE=1
    PING_STATS=$(echo $PING_OUTPUT | tail -n 1 | sed -r 's/^[^=]+= ([^ ]+) ms$/\1/i')
    MIN=$(echo $PING_STATS | sed -r 's,^([^/]+)/([^/]+)/([^/]+)/([^/]+)$,\1,i')
    AVG=$(echo $PING_STATS | sed -r 's,^([^/]+)/([^/]+)/([^/]+)/([^/]+)$,\2,i')
    MAX=$(echo $PING_STATS | sed -r 's,^([^/]+)/([^/]+)/([^/]+)/([^/]+)$,\3,i')
   MDEV=$(echo $PING_STATS | sed -r 's,^([^/]+)/([^/]+)/([^/]+)/([^/]+)$,\4,i')
fi

cat << EOF | curl --data-binary @- http://localhost:9099/metrics/job/speedtest
# TYPE ping_stats_online gauge
ping_stats_online{target="$TARGET",packets="$PACKETS"} $ONLINE
# TYPE ping_stats_rtt_max gauge
ping_stats_rtt_max{target="$TARGET",packets="$PACKETS"} $MAX
# TYPE ping_stats_rtt_min gauge
ping_stats_rtt_min{target="$TARGET",packets="$PACKETS"} $MIN
# TYPE ping_stats_rtt_avg gauge
ping_stats_rtt_avg{target="$TARGET",packets="$PACKETS"} $AVG
# TYPE ping_stats_rtt_mdev gauge
ping_stats_rtt_mdev{target="$TARGET",packets="$PACKETS"} $MDEV
EOF

exit 0
