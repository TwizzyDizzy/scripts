#!/bin/sh

IPERF=/usr/bin/iperf3
DATASIZE="20M"
IPERF_SERVER="iperf.example.com"
IPERF_SERVER_PORT="48000"
LOGFILE="/jffs/speedcheck/speedcheck.log"
BEGIN_DATE=$(date +'%Y-%m-%d %H:%M:%S')
echo "$BEGIN_DATE -- START RECEIVING DATA" >> $LOGFILE

/usr/bin/iperf3 --reverse -n $DATASIZE --client $IPERF_SERVER --port $IPERF_SERVER_PORT >> $LOGFILE

END_DATE=$(date +'%Y-%m-%d %H:%M:%S')
echo "$END_DATE -- RECEIVING DATA FINISHED" >> $LOGFILE

