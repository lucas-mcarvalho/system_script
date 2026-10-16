#!/bin/bash
# Secure Boot + NVIDIA no Ubuntu.
# O Ubuntu já boota com Secure Boot via shim (assinado pela Microsoft).
# O problema é o módulo da NVIDIA: se ele foi compilado por DKMS, precisa
# ser assinado com uma chave MOK registrada no shim. Este script:
#   1. instala o driver pelo ubuntu-drivers (prefere módulos já assinados pela Canonical)
#   2. cria/usa a chave MOK do DKMS e a agenda para registro
#   3. recompila e assina os módulos DKMS da NVIDIA
# NÃO apague as chaves da BIOS e NÃO use sbctl aqui: o shim depende das chaves da Microsoft.
set -euo pipefail
[ "$EUID" -eq 0 ] || { echo "rode com sudo"; exit 1; }

. /etc/os-release
[[ "$ID" == ubuntu || "${ID_LIKE:-}" == *ubuntu* ]] || { echo "isto é para Ubuntu (e derivados como Mint/Pop)"; exit 1; }
[ -d /sys/firmware/efi ] || { echo "sistema não bootou em modo UEFI; Secure Boot não se aplica"; exit 1; }

KVER=$(uname -r)
MOKDIR=/var/lib/shim-signed/mok
MOK_DER=$MOKDIR/MOK.der
MOK_PRIV=$MOKDIR/MOK.priv

echo "==> Pacotes necessários"
apt-get update -q
apt-get install -y shim-signed grub-efi-amd64-signed mokutil openssl dkms ubuntu-drivers-common "linux-headers-$KVER"

echo "==> Estado atual"
mokutil --sb-state || true

echo "==> Driver NVIDIA"
if ! lspci | grep -qi 'nvidia'; then
  echo "nenhuma GPU NVIDIA encontrada"; exit 1
fi
if ! dpkg -l | grep -qE '^ii\s+nvidia-driver-[0-9]+'; then
  echo "    nenhum driver instalado; instalando o recomendado"
  ubuntu-drivers install
fi
dpkg -l | grep -E '^ii\s+(nvidia-driver-|linux-modules-nvidia-)' | awk '{print "    "$2" "$3}'

echo "==> Chave MOK"
if [ ! -f "$MOK_DER" ] || [ ! -f "$MOK_PRIV" ]; then
  mkdir -p "$MOKDIR"
  openssl req -new -x509 -newkey rsa:2048 -nodes -days 36500 -outform DER \
    -keyout "$MOK_PRIV" -out "$MOK_DER" \
    -subj "/CN=$(hostname) DKMS module signing key/"
  chmod 600 "$MOK_PRIV"
  echo "    chave criada em $MOKDIR"
else
  echo "    usando chave existente em $MOKDIR"
fi

# Garante que o DKMS assina com essa chave
FW=/etc/dkms/framework.conf
if [ -f "$FW" ] && ! grep -qE '^\s*mok_signing_key=' "$FW"; then
  printf '\nmok_signing_key=%s\nmok_certificate=%s\n' "$MOK_PRIV" "$MOK_DER" >> "$FW"
fi

PRECISA_REGISTRAR=0
if mokutil --test-key "$MOK_DER" 2>&1 | grep -q 'already enrolled'; then
  echo "    chave já registrada no shim"
else
  PRECISA_REGISTRAR=1
  echo
  echo "    Agora defina uma senha TEMPORÁRIA (só para a tela azul do próximo boot)."
  echo "    Use algo simples: o teclado lá pode estar em layout americano."
  mokutil --import "$MOK_DER"
fi

echo "==> Recompilando e assinando módulos DKMS da NVIDIA"
dkms_nvidia=$(dkms status 2>/dev/null | grep -i '^nvidia' | cut -d, -f1 | sort -u || true)
if [ -z "$dkms_nvidia" ]; then
  echo "    nenhum módulo NVIDIA via DKMS (driver pré-compilado e assinado pela Canonical)"
else
  for mv in $dkms_nvidia; do
    echo "    $mv"
    dkms install --force "$mv" -k "$KVER"
  done
fi

echo "==> Verificação"
for m in nvidia nvidia_modeset nvidia_drm nvidia_uvm; do
  signer=$(modinfo -F signer "$m" 2>/dev/null || true)
  printf '    %-15s %s\n' "$m" "${signer:-SEM ASSINATURA}"
done
mokutil --list-new 2>/dev/null | grep -m1 'Subject:' | sed 's/^/    pendente: /' || true

echo
if [ "$PRECISA_REGISTRAR" = 1 ]; then
  cat <<'EOF'
Próximos passos:
  1. Reinicie. Vai aparecer uma TELA AZUL (MOK Manager); você tem ~10 s para apertar uma tecla.
  2. Enroll MOK -> Continue -> Yes -> digite a senha que você definiu -> Reboot.
  3. Se o Secure Boot estiver desligado, ative-o na BIOS (sem apagar as chaves).
  4. Já no Ubuntu, confira:  mokutil --sb-state   e   nvidia-smi
EOF
else
  cat <<'EOF'
Chave já registrada. Se o Secure Boot estiver desligado, ative-o na BIOS (sem apagar as chaves).
Depois confira:  mokutil --sb-state   e   nvidia-smi
EOF
fi
