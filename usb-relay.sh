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
#   (SLACKWARE) Add user to required groups:
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
# DEVICE SELECTION:
#   - If ONE CH340 device is present → used automatically
#   - If MULTIPLE are present → you MUST specify:
#
#       usb-relay.sh ttyUSB1 1 on
#
# ==========================================

BAUD=9600
DEVICE=""
DEBUG=0
DEVICE_OVERRIDE=""

# ------------------------------------------
# Usage
# ------------------------------------------
usage() {
    echo "USB Relay Control Script"
    echo ""
    echo "Usage:"
    echo "  Single device:"
    echo "    $0 1 on|off"
    echo "    $0 2 on|off"
    echo "    $0 all on|off"
    echo "    $0 status"
    echo ""
    echo "  Multiple devices:"
    echo "    $0 ttyUSBx 1 on|off"
    echo "    $0 ttyUSBx 2 on|off"
    echo "    $0 ttyUSBx all on|off"
    echo "    $0 ttyUSBx status"
    echo ""
    echo "  Utility:"
    echo "    $0 list          - List CH340 devices only"
    echo ""
    echo "  Debug:"
    echo "    $0 -debug [ttyUSBx] <command>"
    echo ""
    exit 1
}

# ------------------------------------------
# Detect CH340 devices only
# ------------------------------------------
detect_devices() {
    DEV_LIST=()

    for tty in /sys/class/tty/ttyUSB*; do
        [ -e "$tty" ] || continue

        dev=$(basename "$tty")
        base="$tty/device"

        usb_path=$(readlink -f "$base/../..")

        if [ -f "$usb_path/idVendor" ] && [ -f "$usb_path/idProduct" ]; then
            vid=$(cat "$usb_path/idVendor")
            pid=$(cat "$usb_path/idProduct")

            if [ "$vid" == "1a86" ] && [ "$pid" == "7523" ]; then
                DEV_LIST+=("/dev/$dev")
            fi
        fi
    done

    if [ ${#DEV_LIST[@]} -eq 0 ]; then
        echo "ERROR: No CH340 relay devices found"
        exit 1
    fi
}

# ------------------------------------------
# List CH340 devices
# ------------------------------------------
list_devices() {
    detect_devices

    echo "Detected CH340 devices:"
    for d in "${DEV_LIST[@]}"; do
        echo "  $(basename "$d")"
    done
}

# ------------------------------------------
# Select device
# ------------------------------------------
select_device() {

    if [ -n "$DEVICE_OVERRIDE" ]; then
        DEVICE="/dev/$DEVICE_OVERRIDE"

        if [ ! -e "$DEVICE" ]; then
            echo "ERROR: Device $DEVICE not found"
            exit 1
        fi
        return
    fi

    if [ ${#DEV_LIST[@]} -eq 1 ]; then
        DEVICE="${DEV_LIST[0]}"
    else
        echo "ERROR: Multiple CH340 devices detected:"
        for d in "${DEV_LIST[@]}"; do
            echo "  $(basename "$d")"
        done
        echo ""
        echo "Use: $0 ttyUSBx ..."
        exit 1
    fi
}

# ------------------------------------------
# Setup serial
# ------------------------------------------
setup_serial() {
    stty -F "$DEVICE" $BAUD cs8 -cstopb -parenb -echo raw
}

# ------------------------------------------
# Send hex
# ------------------------------------------
send_hex() {
    local hex="$1"
    [ "$DEBUG" -eq 1 ] && echo "DEBUG: Sending $hex"
    echo -ne "$hex" > "$DEVICE"
}

# ------------------------------------------
# Read response
# ------------------------------------------
read_response() {
    timeout 1 cat "$DEVICE"
}

# ------------------------------------------
# Relay control
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

if [ "$1" == "list" ]; then
    list_devices
    exit 0
fi

if [[ "$1" =~ ^ttyUSB[0-9]+$ ]]; then
    DEVICE_OVERRIDE="$1"
    shift
fi

TARGET="$1"
ACTION="$2"

detect_devices
select_device
setup_serial

[ "$DEBUG" -eq 1 ] && echo "DEBUG: Using $DEVICE"

# ------------------------------------------
# Command handling
# ------------------------------------------
case "$TARGET" in
    1|2)
        [ -z "$ACTION" ] && usage
        case "$ACTION" in
            on) relay_on "$TARGET" ;;
            off) relay_off "$TARGET" ;;
            *) usage ;;
        esac
        ;;
    all)
        [ -z "$ACTION" ] && usage
        case "$ACTION" in
            on) all_on ;;
            off) all_off ;;
            *) usage ;;
        esac
        ;;
    status)
        status
        ;;
    *)
        usage
        ;;
esac
