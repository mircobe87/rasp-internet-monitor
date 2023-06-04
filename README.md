# Rasp Internet Monitor
*how to monitor your internet connection using a raspberrypi + promethus + grafana*

## Abstract
The idea is to put in crontab some bash script to execute some network speedtest and ping and then expose to Prometheus the metrics collected.

To permoform speedtests via bash script we are goning to use **SPEEDTEST® CLI** by *Ookla*.
To check Internet access we are going to use the standard `ping` command line tool.
All the metrics will be exposed to Prometheus by the Pushgateway gateway.

In this project, Prometheus will be installed on the same machine which will performe the tests but is also possible to install it on a defferent devices.

To grafically show the collected metrics we will use Grafana that will installed on the same machine as well.

## Data collecting
This section describes how to install all the software to perform tests and collect the results.

### Pushgateway
The Pushgateway is a part of the Prometheus service suite developed to expose metrics to Prometheus of jobs that are not durable. Following how to download and install it on Raspbian as **systemd** service:

1. Download the Pushgateway package for the proper system architecture from official web [page](https://prometheus.io/download/).

```
wget https://github.com/prometheus/pushgateway/releases/download/v1.4.1/pushgateway-1.4.1.linux-armv6.tar.gz
```
2. Extract the downloaded package:
```
tar -xf pushgateway-1.4.1.linux-armv6.tar.gz
```
3. Create a system user that will be who run the service.
```
sudo useradd --no-create-home --shell /bin/false pushgateway
```
4. Install `pushgateway` and give it the right owner.
```
sudo cp pushgateway-1.4.1.linux-armv6/pushgateway /usr/local/bin
sudo chown pushgateway:pushgateway /usr/local/bin/pushgateway
```
5. Create a systemd service for Pushgateway. Here we configured the service to run on `9099` tcp port.
```
sudo cat << EOF > /etc/systemd/system/pushgateway.service
[Unit]
Description=Pushgateway
Wants=network-online.target
After=network-online.target

[Service]
User=pushgateway
Group=pushgateway
Type=simple
ExecStart=/usr/local/bin/pushgateway --web.listen-address ":9099"

[Install]
WantedBy=multi-user.target
EOF
```
6. Reload systemd configuration, start the service and set it up to start automatically at system startup.
```
sudo systemctl daemon-reload
sudo systemctl start pushgateway
sudo systemctl enable pushgateway
```
7. You can check the exposed metrics by the pushgateway visiting http://localhost:9099

### Speedtest scripts
We will write two bash script to put in crontab: `speedtest/ping-monitoring.sh` to check internet connectivity and collect some ping statistics; `speedtest/speedtest-monitoring.sh` to collect metrics about internet bandwidth.

**ping-monitoring.sh**
```
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
```

**speedtest-monitoring.sh**

In order to make the following script working, you need to install `speedtest` cli before. You can download it for the official web [page](https://www.speedtest.net/it/apps/cli).

Please, change the `SERVER_ID` variable as your need. To obtain the list of the closest servers, run the command `speedtest -L`.

```
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
```

Now you can configure your crontab to execute these scripts. This is my scheduling:
```
#  m     h dom mon dow command
*/10   0-8   *   *   * /home/mircobe87/speedtest/speedtest-monitoring.sh
0,30  9-18   *   * 1-5 /home/mircobe87/speedtest/speedtest-monitoring.sh
*/10  9-18   *   * 6,7 /home/mircobe87/speedtest/speedtest-monitoring.sh
*/10 19-23   *   *   * /home/mircobe87/speedtest/speedtest-monitoring.sh
   *     *   *   *   * /home/mircobe87/speedtest/ping-monitoring.sh
```

### Prometheus
Following how to download and install Promethus on Raspbian as **systemd** service:

1. Download the Pushgateway package for the proper system architecture from official web [page](https://prometheus.io/download/).
```
wget https://github.com/prometheus/prometheus/releases/download/v2.28.0/prometheus-2.28.0.linux-armv6.tar.gz
```

2. Extract the downloaded package:
```
tar -xf prometheus-2.28.0.linux-armv6.tar.gz
```

3. Create a system user that will be who run the service.
```
sudo useradd --no-create-home --shell /bin/false prometheus
```

4. Create the necessary directories for storing Prometheus' files and data. Following standard Linux conventions, we'll create a directory in `/etc` for Prometheus' configuration files and a directory in `/var/lib` for its data.
```
sudo mkdir /etc/prometheus
sudo mkdir /var/lib/prometheus
```

5. Now, set the user and group ownership on the new directories to the prometheus user.
```
sudo chown prometheus:prometheus /etc/prometheus
sudo chown prometheus:prometheus /var/lib/prometheus
```

6. Copy the two binaries to the `/usr/local/bin` directory.
```
sudo cp prometheus-2.28.0.linux-armv6/prometheus /usr/local/bin/
sudo cp prometheus-2.28.0.linux-armv6/promtool /usr/local/bin/
 ```

7. Set the user and group ownership on the binaries to the prometheus user created in step 3.
```
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool
 ```

8. Copy the consoles and console_libraries directories to `/etc/prometheus` and also the configuration file prometheus.yml
```
sudo cp -r prometheus-2.28.0.linux-armv6/consoles /etc/prometheus
sudo cp -r prometheus-2.28.0.linux-armv6/console_libraries /etc/prometheus
sudo cp prometheus-2.28.0.linux-armv6/prometheus.yml /etc/prometheus
 ```

9. Set the user and group ownership on the directories to the prometheus user. Using the `-R` flag will ensure that ownership is set on the files inside the directory as well.
```
sudo chown -R prometheus:prometheus /etc/prometheus/consoles
sudo chown -R prometheus:prometheus /etc/prometheus/console_libraries
```

10. Edit the prometheus.yml configuration file to tell prometheus to scrape metrics from the pushgateway.
Put the following section inside the `scrape_configs` list. You are editing a yml file, pay attention to the indentation.
```
  - job_name: 'speedtest'
    static_configs:
    - targets: ['localhost:9099']
      labels:
        type: 'raspberry_pi_1'
```

11. Create a systemd service for Prometheus.
```
sudo cat << EOF > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries \
    --storage.tsdb.retention.time=7d \
    --storage.tsdb.wal-compression

[Install]
WantedBy=multi-user.target
EOF
```

6. Reload systemd configuration, start the service and set it up to start automatically at system startup.
```
sudo systemctl daemon-reload
sudo start prometheus
sudo enable prometheus
```
7. You can check if prometheus is running visiting http://localhost:9090

## Showing data
