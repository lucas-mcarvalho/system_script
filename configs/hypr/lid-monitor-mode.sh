#!/bin/sh

LAPTOP_OUTPUT="eDP-1"
HDMI_OUTPUT="HDMI-A-1"
LAPTOP_MODE="1920x1080@165"
HDMI_EXTERNAL_MODE="1920x1080@179.96"
HDMI_PRESENTATION_MODE="1920x1080@60"

has_monitor() {
    hyprctl monitors all 2>/dev/null | grep -q "^Monitor $1"
}

case "$1" in
    external)
        if has_monitor "$HDMI_OUTPUT"; then
            hyprctl --batch "keyword monitor $HDMI_OUTPUT,$HDMI_EXTERNAL_MODE,0x0,1 ; keyword monitor $LAPTOP_OUTPUT,disable ; dispatch workspace 1"
        fi
        ;;
    lid-close)
        if has_monitor "$HDMI_OUTPUT"; then
            hyprctl --batch "keyword monitor $HDMI_OUTPUT,$HDMI_EXTERNAL_MODE,0x0,1 ; keyword monitor $LAPTOP_OUTPUT,disable ; dispatch workspace 1"
        else
            systemctl suspend
        fi
        ;;
    presentation|lid-open)
        if has_monitor "$HDMI_OUTPUT"; then
            hyprctl --batch "keyword monitor $LAPTOP_OUTPUT,$LAPTOP_MODE,0x0,1 ; keyword monitor $HDMI_OUTPUT,$HDMI_PRESENTATION_MODE,0x0,1,mirror,$LAPTOP_OUTPUT ; dispatch workspace 1"
        else
            hyprctl --batch "keyword monitor $LAPTOP_OUTPUT,$LAPTOP_MODE,0x0,1 ; dispatch workspace 1"
        fi
        ;;
    laptop)
        hyprctl --batch "keyword monitor $LAPTOP_OUTPUT,$LAPTOP_MODE,0x0,1 ; keyword monitor $HDMI_OUTPUT,disable ; dispatch workspace 1"
        ;;
esac
