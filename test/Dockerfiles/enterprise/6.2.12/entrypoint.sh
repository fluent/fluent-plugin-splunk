#!/bin/bash

set -e

echo OPTIMISTIC_ABOUT_FILE_LOCKING = 1 >> ${SPLUNK_HOME_TCP}/etc/splunk-launch.conf
echo OPTIMISTIC_ABOUT_FILE_LOCKING = 1 >> ${SPLUNK_HOME_SSL}/etc/splunk-launch.conf

SPLUNK_HOME=$SPLUNK_HOME_TCP sudo -HEu ${SPLUNK_USER} ${SPLUNK_HOME_TCP}/bin/splunk start --accept-license
SPLUNK_HOME=$SPLUNK_HOME_SSL sudo -HEu ${SPLUNK_USER} ${SPLUNK_HOME_SSL}/bin/splunk start --accept-license

# Trap exit signal and shutdown gracefully
trap "sudo -HEu ${SPLUNK_USER} ${SPLUNK_HOME_TCP}/bin/splunk stop; sudo -HEu ${SPLUNK_USER} ${SPLUNK_HOME_SSL}/bin/splunk stop" SIGINT SIGTERM EXIT

sudo -HEu ${SPLUNK_USER} tail -n 0 -f ${SPLUNK_HOME_TCP}/var/log/splunk/splunkd_stderr.log &
wait
