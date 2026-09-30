#!/usr/bin/env bash
# Conecta à rede eduroam via NetworkManager (WPA2-Enterprise, EAP-TTLS/PAP).
#
# Uso:
#   eduroam.sh            # conecta (cria o perfil se não existir)
#   eduroam.sh --reset    # apaga o perfil e pede usuário/senha de novo
#
# Variáveis opcionais: EDUROAM_USER, EDUROAM_PASS, EDUROAM_IFACE

set -euo pipefail

CON="eduroam"
SSID="eduroam"
IFACE="${EDUROAM_IFACE:-$(nmcli -t -f DEVICE,TYPE dev | awk -F: '$2=="wifi"{print $1; exit}')}"

if [[ -z "$IFACE" ]]; then
  echo "Nenhuma interface Wi-Fi encontrada." >&2
  exit 1
fi

if [[ "${1:-}" == "--reset" ]] && nmcli -t -f NAME con show | grep -qx "$CON"; then
  nmcli con delete "$CON" >/dev/null
  echo "Perfil '$CON' removido."
fi

# Cria o perfil caso ainda não exista
if ! nmcli -t -f NAME con show | grep -qx "$CON"; then
  user="${EDUROAM_USER:-}"
  pass="${EDUROAM_PASS:-}"
  [[ -z "$user" ]] && read -rp "Usuário eduroam (ex: nome@instituicao.br): " user
  [[ -z "$pass" ]] && { read -rsp "Senha: " pass; echo; }

  nmcli con add type wifi con-name "$CON" ifname "$IFACE" ssid "$SSID" \
    wifi-sec.key-mgmt wpa-eap \
    802-1x.eap ttls \
    802-1x.phase2-auth pap \
    802-1x.identity "$user" \
    802-1x.password "$pass" \
    connection.autoconnect yes >/dev/null
  echo "Perfil '$CON' criado."
fi

nmcli radio wifi on

echo "Procurando '$SSID'..."
nmcli dev wifi rescan ifname "$IFACE" 2>/dev/null || true
sleep 2
if ! nmcli -t -f SSID dev wifi list ifname "$IFACE" | grep -qx "$SSID"; then
  echo "Rede '$SSID' não está ao alcance." >&2
  exit 1
fi

echo "Conectando em '$SSID' via $IFACE..."
if nmcli --wait 30 con up "$CON" ifname "$IFACE"; then
  command -v notify-send >/dev/null && notify-send "Wi-Fi" "Conectado à eduroam"
else
  echo "Falha ao conectar. Se a senha mudou, rode: $0 --reset" >&2
  command -v notify-send >/dev/null && notify-send -u critical "Wi-Fi" "Falha ao conectar à eduroam"
  exit 1
fi
