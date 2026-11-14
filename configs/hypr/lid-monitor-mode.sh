#!/bin/sh

LAPTOP_OUTPUT="eDP-1"
LAPTOP_MODE="1920x1080@165"
HOME_EXTERNAL_MODE="1920x1080@179.96"
PROFILE="$HOME/.config/hypr/monitor-profile.sh"

# Descobre o externo conectado (qualquer porta) e se ele e o monitor de casa.
set -- "$1" $("$PROFILE" detect 2>/dev/null)
ACTION="$1"
KIND="$2"
EXT_OUTPUT="$3"

# Monitor de casa usa o modo fixo; qualquer outro, o modo preferido dele.
if [ "$KIND" = home ]; then
    EXT_MODE="$HOME_EXTERNAL_MODE"
else
    EXT_MODE="preferred"
fi

case "$ACTION" in
    external)
        if [ -n "$EXT_OUTPUT" ]; then
            hyprctl --batch "keyword monitor $EXT_OUTPUT,$EXT_MODE,0x0,1 ; keyword monitor $LAPTOP_OUTPUT,disable ; dispatch workspace 1"
        fi
        ;;
    lid-close)
        if [ -n "$EXT_OUTPUT" ]; then
            hyprctl --batch "keyword monitor $EXT_OUTPUT,$EXT_MODE,0x0,1 ; keyword monitor $LAPTOP_OUTPUT,disable ; dispatch workspace 1"
        else
            systemctl suspend
        fi
        ;;
    presentation|lid-open)
        if [ -n "$EXT_OUTPUT" ]; then
            hyprctl --batch "keyword monitor $LAPTOP_OUTPUT,$LAPTOP_MODE,0x0,1 ; keyword monitor $EXT_OUTPUT,preferred,0x0,1,mirror,$LAPTOP_OUTPUT ; dispatch workspace 1"
        else
            hyprctl --batch "keyword monitor $LAPTOP_OUTPUT,$LAPTOP_MODE,0x0,1 ; dispatch workspace 1"
        fi
        ;;
    laptop)
        if [ -n "$EXT_OUTPUT" ]; then
            hyprctl --batch "keyword monitor $LAPTOP_OUTPUT,$LAPTOP_MODE,0x0,1 ; keyword monitor $EXT_OUTPUT,disable ; dispatch workspace 1"
        else
            hyprctl --batch "keyword monitor $LAPTOP_OUTPUT,$LAPTOP_MODE,0x0,1 ; dispatch workspace 1"
        fi
        ;;
esac
