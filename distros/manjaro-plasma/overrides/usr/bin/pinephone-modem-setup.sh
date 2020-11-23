#!/bin/sh

log() {
	echo "$@" | logger -t "postmarketOS:modem-setup"
}

QMBNCFG_CONFIG="1"
QCFG_IMS_CONFIG="1"

if [ -z "$1" ]
then
	DEV="/dev/EG25.AT"
else
	DEV="$1"
fi

# When running this script from udev the modem might not be fully initialized
# yet, so give it some time to initialize
#
# We'll try to query for the firmware version for 15 seconds after which we'll
# consider the initialization failed

log "Waiting for the modem to initialize"
INITIALIZED=false
for second in $(seq 1 15)
do
        if echo "AT+QDAI?" | atinout - $DEV - | grep -q OK
        then
                INITIALIZED=true
                break
        fi

        log "Waited for $second seconds..."

        sleep 1
done

if $INITIALIZED
then
        log "Modem initialized"
else
        log "Modem failed to initialize"
        exit 1
fi

# Read current config
QMBNCFG_ACTUAL_CONFIG=$(echo 'AT+QMBNCFG="AutoSel"' | atinout - $DEV -)
QCFG_IMS_ACTUAL_CONFIG=$(echo 'AT+QCFG="ims"' | atinout - $DEV -)

# Configure VoLTE auto selecting profile
RET=$(echo "AT+QMBNCFG=\"AutoSel\",$QMBNCFG_CONFIG" | atinout - $DEV -)

if ! echo $RET | grep -q OK
then
	log "Failed to enable VoLTE profile auto selecting: $RET"
	exit 1
fi

# Enable VoLTE
RET=$(echo "AT+QCFG=\"ims\",$QCFG_IMS_CONFIG" | atinout - $DEV -)

if ! echo $RET | grep -q OK
then
	log "Failed to enable VoLTE: $RET"
	exit 1
fi
