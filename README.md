
# USB Relay Control Script (CH340 based)
Version: 1.0

DESCRIPTION:
  Controls a 2-channel USB relay module that
  uses a CH340 USB-to-Serial microcontroller.

  The CH340 presents the relay board as a
  serial device (/dev/ttyUSB*) and accepts
  raw hexadecimal command frames at 9600 baud.

  This script sends the required command bytes
  to control relay state and query status.

  Supported operations:
    - Individual relay control (1 or 2)
    - Control all relays
    - Query relay status (ASCII response)

HARDWARE:
  - USB relay module with CH340 interface

REQUIREMENTS:
  - stty (coreutils)
  - hexdump (util-linux)

SLACKWARE INSTALL:
  installpkg aaa_base
  installpkg coreutils
  installpkg util-linux

PERMISSIONS:
  User must have access to /dev/ttyUSB*

  Add user to required groups:
    usermod -aG dialout <username>

  Then log out and back in for group changes to apply.

  Temporary workaround (not recommended):
    chmod 666 /dev/ttyUSB0

NOTES:
  - Device appears as /dev/ttyUSB*
  - Default baud rate: 9600
  - Status responses are ASCII (e.g. "CH1: ON")
