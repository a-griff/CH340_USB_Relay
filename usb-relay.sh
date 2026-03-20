#!/bin/bash

# ==========================================
# USB Relay Control Script (CH340 based)
# Version: 1.0
# ==========================================
# DESCRIPTION:
#   Controls a 2-channel USB relay module that
#   uses a CH340 USB-to-Serial microcontroller.
#
#   The CH340 presents the relay board as a
#   serial device (/dev/ttyUSB*) and accepts
#   raw hexadecimal command frames at 9600 baud.
#
#   This script sends the required command bytes
#   to control relay state and query status.
#
#   Supported operations:
#     - Individual relay control (1 or 2)
#     - Control all relays
#     - Query relay status (ASCII response)
#
# HARDWARE:
#   - USB relay module with CH340 interface
#
# REQUIREMENTS:
#   - stty (coreutils)
#   - hexdump (util-linux)
#
# SLACKWARE INSTALL:
#   installpkg aaa_base
#   installpkg coreutils
#   installpkg util-linux
#
# PERMISSIONS:
#   User must have access to /dev/ttyUSB*
#
#   Add user to required groups:
#     usermod -aG dialout <username>
#
#   Then log out and back in for group changes to apply.
#
#   Temporary workaround (not recommended):
#     chmod 666 /dev/ttyUSB0
#
# NOTES:
#   - Device appears as /dev/ttyUSB*
#   - Default baud rate: 9600
#   - Status responses are ASCII (e.g. "CH1: ON")
#
# ==========================================

BAUD=9600
DEVICE=""
DEBUG=0

# ------------------------------------------
# Usage
# ------------------------------------------
usage() {
    echo "USB Relay Control Script"
    echo ""
    echo "Usage:"
    echo "  $0 1 on|off        - Control relay 1"
    echo "  $0 2 on|off        - Control relay 2"
    echo "  $0 all on|off      - Control both relays"
    echo "  $0 status          - Query relay status"
    echo "  $0 -debug <cmd>    - Enable debug output"
    echo ""
    exit 1
}

# ------------------------------------------
# Auto-detect USB serial device
# ------------------------------------------
detect_device() {
    for dev in /dev/ttyUSB*; do
        [ -e "$dev" ] && DEVICE="$dev" && return
    done

    echo "ERROR: No /dev/ttyUSB device found"
    exit 1
}

# ------------------------------------------
# Setup serial port
# ------------------------------------------
setup_serial() {
    stty -F "$DEVICE" $BAUD cs8 -cstopb -parenb -echo raw
}

# ------------------------------------------
# Send raw hex bytes
# ------------------------------------------
send_hex() {
    local hex="$1"

    if [ "$DEBUG" -eq 1 ]; then
        echo "DEBUG: Sending -> $hex"
    fi

    echo -ne "$hex" > "$DEVICE"
}

# ------------------------------------------
# Read response (status)
# ------------------------------------------
read_response() {
    timeout 1 cat "$DEVICE"
}

# ------------------------------------------
# Relay commands
# ------------------------------------------
relay_on() {
    case "$1" in
        1) send_hex '\xA0\x01\x01\xA2' ;;
        2) send_hex '\xA0\x02\x01\xA3' ;;
        *) usage ;;
    esac
}

relay_off() {
    case "$1" in
        1) send_hex '\xA0\x01\x00\xA1' ;;
        2) send_hex '\xA0\x02\x00\xA2' ;;
        *) usage ;;
    esac
}

all_on() {
    relay_on 1
    relay_on 2
}

all_off() {
    relay_off 1
    relay_off 2
}

status() {
    send_hex '\xFF'
    sleep 0.2

    RESPONSE=$(read_response)

    if [ "$DEBUG" -eq 1 ]; then
        echo "DEBUG RAW:"
        echo "$RESPONSE" | hexdump -C
    fi

    echo "Relay Status:"
    echo "$RESPONSE" | sed '/^$/d'
}

# ------------------------------------------
# Argument parsing
# ------------------------------------------
if [ "$1" == "-debug" ]; then
    DEBUG=1
    shift
fi

[ -z "$1" ] && usage

TARGET="$1"
ACTION="$2"

detect_device
setup_serial

if [ "$DEBUG" -eq 1 ]; then
    echo "DEBUG: Using device $DEVICE"
fi

case "$TARGET" in
    1|2)
        [ -z "$ACTION" ] && usage
        case "$ACTION" in
            on)
                relay_on "$TARGET"
                ;;
            off)
                relay_off "$TARGET"
                ;;
            *)
                usage
                ;;
        esac
        ;;
    all)
        [ -z "$ACTION" ] && usage
        case "$ACTION" in
            on)
                all_on
                ;;
            off)
                all_off
                ;;
            *)
                usage
                ;;
        esac
        ;;
    status)
        status
        ;;
    *)
        usage
        ;;
esac
