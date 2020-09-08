#!/bin/bash

MODEM_ID=""

get_modem_id()
{
    MODEM_LIST="`mmcli -L | grep QUECTEL`"
    if [ "$MODEM_LIST" ]; then
        # mmcli output is "   /org/freedesktop/ModemManager1/Modem/MODEM_ID ..."
        # MODEM_PATH will store the D-Bus object path, from which we'll extract
        # MODEM_ID
        MODEM_PATH="`echo "$MODEM_LIST" | sed 's%[^/]*\(/[^ ]*\).*%\1%'`"
        MODEM_ID=`basename "$MODEM_PATH"`
    fi
}

configure_modem()
{
    COMMAND=$1
    VALUE=$2
    STATE=""

    if [ "$COMMAND" = "QCFG" -o "$COMMAND" = "QURCCFG" ]; then
        SUBCMD=`echo $VALUE | cut -d ',' -f 1`
        STATE=`mmcli -m $MODEM_ID --command="AT+$COMMAND=$SUBCMD" | sed "s%response: '+$COMMAND: \(.*\)'%\1%"`
    else
        STATE=`mmcli -m $MODEM_ID --command="AT+$COMMAND?" | sed "s%response: '+$COMMAND: \(.*\)'%\1%"`
    fi

    if [[ $STATE != $VALUE* ]]; then
        mmcli -m $MODEM_ID --command="AT+$COMMAND=$VALUE" > /dev/null 2>&1
    fi
}

# Wait for the modem to be available
while [ ! "$MODEM_ID" ]; do
    sleep 1
    get_modem_id
done

# Enable VoLTE
configure_modem "QCFG" '"ims",1'

# Enable GPS
# TODO: move all of this to a dedicated user service/daemon and switch GPS
# according to user preferences (org.gnome.system.location enabled)
configure_modem "QGPS" "1"

# Location can't be setup while the SIM is locked, loop until we get there
# (yes, that's nasty)
while ! mmcli -m $MODEM_ID --location-enable-gps-raw --location-enable-gps-nmea; do
    sleep 1
done
