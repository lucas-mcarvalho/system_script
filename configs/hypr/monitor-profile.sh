#!/bin/sh
# Decide o layout de monitores do Hyprland.
#
#   detect    imprime uma linha (so le /sys, seguro durante o parse da config):
#               laptop              nenhum externo conectado
#               home <saida>        o monitor de casa esta conectado em <saida>
#               mirror <saida>...   externo(s) desconhecido(s): espelhar o painel
#   learn     se ainda nao ha monitor de casa salvo e um externo conectado
#             oferece o modo de casa (1920x1080@179.96), salva ele como "casa".
#             Sai com 0 somente quando acabou de salvar. Usa hyprctl.
#   set-home  salva o externo conectado agora como monitor de casa
#   forget    esquece o monitor de casa

HOME_ID_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/home-monitor.id"
HOME_MODE_RE='^1920x1080@179\.9'

# Nomes das saidas externas conectadas (ex.: HDMI-A-1, DP-1)
externals() {
    for d in /sys/class/drm/card*-*; do
        case "$d" in *-eDP-*) continue ;; esac
        [ "$(cat "$d/status" 2>/dev/null)" = connected ] || continue
        n=${d##*/}
        echo "${n#card*-}"
    done
}

# Identidade do monitor ligado na saida $1: hash do EDID (vazio se nao houver)
edid_id() {
    for f in /sys/class/drm/card*-"$1"/edid; do
        [ "$(wc -c < "$f" 2>/dev/null || echo 0)" -gt 0 ] || continue
        sha256sum < "$f" | cut -d' ' -f1
        return
    done
}

save_home() {
    id=$(edid_id "$1")
    [ -n "$id" ] || return 1
    echo "$id" > "$HOME_ID_FILE"
}

case "$1" in
    detect)
        exts=$(externals)
        if [ -z "$exts" ]; then
            echo laptop
            exit 0
        fi
        if [ -s "$HOME_ID_FILE" ]; then
            saved=$(cat "$HOME_ID_FILE")
            for e in $exts; do
                if [ "$(edid_id "$e")" = "$saved" ]; then
                    echo "home $e"
                    exit 0
                fi
            done
        fi
        echo "mirror" $exts
        ;;
    learn)
        [ -s "$HOME_ID_FILE" ] && exit 1
        for e in $(externals); do
            if hyprctl monitors all -j 2>/dev/null |
                jq -r --arg n "$e" '.[] | select(.name == $n) | .availableModes[]' |
                grep -q "$HOME_MODE_RE"; then
                save_home "$e" && exit 0
            fi
        done
        exit 1
        ;;
    set-home)
        e=$(externals | head -n1)
        [ -n "$e" ] && save_home "$e" && echo "Monitor de casa salvo ($e)." && exit 0
        echo "Nenhum monitor externo conectado." >&2
        exit 1
        ;;
    forget)
        rm -f "$HOME_ID_FILE"
        ;;
    *)
        echo "uso: $0 detect|learn|set-home|forget" >&2
        exit 2
        ;;
esac
