#!/bin/sh

# Copyright (C) 2020 - Dreemurrs Embedded Labs / DanctNIX Community
# Copyright (C) 2020 - postmarketOS Contributors
# SPDX-License-Identifier: GPL-2.0-only

while [ ! -e /dev/EG25.AT ]; do sleep 1 ; done

# When running this script from udev the modem might not be fully initialized
# yet, so give it some time to initialize
#
# We'll try to query for the firmware version for 15 seconds after which we'll
# consider the initialization failed

echo "Waiting for the modem to initialize"
INITIALIZED=false
for second in $(seq 1 15)
do
        if echo "AT+QDAI?" | atinout - /dev/EG25.AT - | grep -q OK
        then
                INITIALIZED=true
                break
        fi

        echo "Waited for $second seconds..."

        sleep 1
done

if $INITIALIZED
then
        echo "Modem initialized"
else
        echo "Modem failed to initialize"
        exit 1
fi

# Setup VoLTE
if echo "AT+QMBNCFG=\"AutoSel\",1" | atinout - /dev/EG25.AT - | grep -q OK; then
        echo "Successfully configured VoLTE to AutoSel"
else
        echo "Failed to configure VoLTE Profile: $?"
fi

# Enable VoLTE
if echo "AT+QCFG=\"ims\",1" | atinout - /dev/EG25.AT - | grep -q OK; then
        echo "Successfully enabled VoLTE"
else
        echo "Failed to enable VoLTE: $?"
fi
