#!/bin/sh
# sxmo device profile for the Google Pixel 4a (sunfish) on mainline.
# Install to: /usr/bin/sxmo_deviceprofile_google,sunfish.sh  (chmod +x)
export SXMO_VOLUME_BUTTON="1:1:gpio-keys 0:0:pm8941_resin"
export SXMO_POWER_BUTTON="0:0:pm8941_pwrkey"
export SXMO_MONITOR="DSI-1"
export SXMO_TOUCHSCREEN_ID="STMicroelectronics FTM5"
export SXMO_SWAY_SCALE="2.5"
