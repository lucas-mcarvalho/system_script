#!/bin/sh
# Sai com 0 se houver algum monitor externo (não eDP) conectado
for s in /sys/class/drm/card*-*/status; do
    case "$s" in *-eDP-*) continue ;; esac
    [ "$(cat "$s" 2>/dev/null)" = connected ] && exit 0
done
exit 1
