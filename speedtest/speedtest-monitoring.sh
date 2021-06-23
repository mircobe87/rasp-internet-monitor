#!/bin/bash

# Vianova Spa (Massarosa)
SERVER_ID=5011
# TIM Spa (Firenze)
#SERVER_ID=9636

OUTPUT=$(speedtest -s $SERVER_ID -f csv -u B/s)
#echo $OUTPUT

SERVER=$(echo $OUTPUT | sed -r 's/^"([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)"$/\1/i')
LATENCY=$(echo $OUTPUT | sed -r 's/^"([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)"$/\3/i')
DOWNLOAD=$(echo $OUTPUT | sed -r 's/^"([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)"$/\6/i')
UPLOAD=$(echo $OUTPUT | sed -r 's/^"([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)","([^,"]+)"$/\7/i')


cat << EOF | curl --data-binary @- http://localhost:9099/metrics/job/speedtest
# TYPE latency gauge
# HELP Connection latency [ms]
latency{server_id="$SERVER_ID",server_name="$SERVER"} $LATENCY
# TYPE download gauge
# HELP Download bandwidth [B/s]
download{server_id="$SERVER_ID",server_name="$SERVER"} $DOWNLOAD
# TYPE upload gauge
# HELP Upload bandwidth [B/s]
upload{server_id="$SERVER_ID",server_name="$SERVER"} $UPLOAD
EOF

echo $SERVER $LATENCY $DOWNLOAD $UPLOAD

exit 0
