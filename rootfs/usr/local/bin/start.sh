#!/bin/bash
# Run the ipp-usb supervisor in the background, then hand PID 1 to the base
# image's entrypoint (which execs cupsd -f).
set -e

if [ "${IPP_USB_ENABLE:-1}" = "1" ]; then
    /usr/local/bin/ipp-usb-supervisor &
fi

exec /entrypoint.sh
