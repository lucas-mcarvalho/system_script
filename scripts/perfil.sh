#!/usr/bin/env bash
# Troca o perfil de energia do firmware (ventoinha/desempenho) do Acer Nitro.
#
#   perfil                      mostra o perfil atual
#   perfil <nome>               troca agora (temporário: até reiniciar ou mexer no carregador)
#   perfil <nome> --fixo        troca agora e salva como padrão no carregador (TLP)
#   perfil padrao               restaura o padrão original no carregador (balanced-performance)
#
# Nomes: quiet, low-power, balanced, balanced-performance, performance
# Atalhos: silencioso, economia, equilibrado, normal, desempenho

set -euo pipefail

PROFILE_FILE=/sys/firmware/acpi/platform_profile
CHOICES_FILE=/sys/firmware/acpi/platform_profile_choices
TLP_CONF=/etc/tlp.d/10-nitro-bateria.conf
ORIGINAL=balanced-performance

current() {
    local fonte="na bateria"
    [[ $(cat /sys/class/power_supply/ACAD/online 2>/dev/null) == 1 ]] && fonte="no carregador"
    echo "Perfil atual: $(cat "$PROFILE_FILE")  ($fonte)"
    echo "Padrão no carregador (TLP): $(grep -oP '^PLATFORM_PROFILE_ON_AC=\K.*' "$TLP_CONF")"
    echo "Disponíveis: $(cat "$CHOICES_FILE")"
}

if [[ $# -eq 0 ]]; then
    current
    exit 0
fi

fixo=0
if [[ ${2:-} == --fixo ]]; then
    fixo=1
fi

case $1 in
    silencioso) alvo=quiet ;;
    economia) alvo=low-power ;;
    equilibrado) alvo=balanced ;;
    normal) alvo=balanced-performance ;;
    desempenho) alvo=performance ;;
    padrao|padrão) alvo=$ORIGINAL; fixo=1 ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) alvo=$1 ;;
esac

if ! grep -qw -- "$alvo" "$CHOICES_FILE"; then
    echo "Perfil inválido: $1" >&2
    echo "Use um destes: $(cat "$CHOICES_FILE")" >&2
    exit 1
fi

echo "$alvo" | sudo tee "$PROFILE_FILE" >/dev/null

if (( fixo )); then
    sudo sed -i "s/^PLATFORM_PROFILE_ON_AC=.*/PLATFORM_PROFILE_ON_AC=$alvo/" "$TLP_CONF"
    echo "Salvo como padrão no carregador: $alvo"
fi

current
