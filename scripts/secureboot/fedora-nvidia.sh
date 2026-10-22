#!/bin/bash
# Secure Boot + NVIDIA no Fedora.
# O Fedora já boota com Secure Boot via shim (assinado pela Microsoft).
# O problema é o módulo da NVIDIA do RPM Fusion: ele é compilado na máquina
# pelo akmods e precisa ser assinado com uma chave MOK registrada no shim. Este script:
#   1. habilita o RPM Fusion e instala o akmod-nvidia
#   2. cria/usa a chave do akmods (kmodgenca) e a agenda para registro
#   3. recompila e assina o módulo da NVIDIA para o kernel atual
# NÃO apague as chaves da BIOS e NÃO use sbctl aqui: o shim depende das chaves da Microsoft.
set -euo pipefail
[ "$EUID" -eq 0 ] || { echo "rode com sudo"; exit 1; }

. /etc/os-release
[[ "$ID" == fedora ]] || { echo "isto é para Fedora"; exit 1; }
[ -d /sys/firmware/efi ] || { echo "sistema não bootou em modo UEFI; Secure Boot não se aplica"; exit 1; }

KVER=$(uname -r)
FEDORA=$(rpm -E %fedora)
KEY_DER=/etc/pki/akmods/certs/public_key.der

echo "==> Estado atual"
mokutil --sb-state || true

if ! lspci | grep -qi 'nvidia'; then
  echo "nenhuma GPU NVIDIA encontrada"; exit 1
fi

echo "==> RPM Fusion"
if ! rpm -q rpmfusion-free-release rpmfusion-nonfree-release >/dev/null 2>&1; then
  dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$FEDORA.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$FEDORA.noarch.rpm"
else
  echo "    já habilitado"
fi

echo "==> Pacotes necessários"
dnf install -y shim-x64 grub2-efi-x64 mokutil openssl akmods kmodtool "kernel-devel-$KVER"

# A chave precisa existir ANTES de compilar o módulo, senão ele sai sem assinatura
echo "==> Chave MOK (akmods)"
if [ ! -f "$KEY_DER" ]; then
  kmodgenca -a
  echo "    chave criada em /etc/pki/akmods"
else
  echo "    usando chave existente em /etc/pki/akmods"
fi

PRECISA_REGISTRAR=0
if mokutil --test-key "$KEY_DER" 2>&1 | grep -q 'already enrolled'; then
  echo "    chave já registrada no shim"
else
  PRECISA_REGISTRAR=1
  echo
  echo "    Agora defina uma senha TEMPORÁRIA (só para a tela azul do próximo boot)."
  echo "    Use algo simples: o teclado lá pode estar em layout americano."
  mokutil --import "$KEY_DER"
fi

echo "==> Driver NVIDIA"
if ! rpm -q akmod-nvidia >/dev/null 2>&1; then
  echo "    instalando akmod-nvidia"
  dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
fi
rpm -q akmod-nvidia xorg-x11-drv-nvidia | sed 's/^/    /'

echo "==> Recompilando e assinando o módulo da NVIDIA (pode levar alguns minutos)"
akmods --force --kernels "$KVER"

echo "==> Verificação"
for m in nvidia nvidia_modeset nvidia_drm nvidia_uvm; do
  signer=$(modinfo -k "$KVER" -F signer "$m" 2>/dev/null || true)
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
  4. Já no Fedora, confira:  mokutil --sb-state   e   nvidia-smi
EOF
else
  cat <<'EOF'
Chave já registrada. Se o Secure Boot estiver desligado, ative-o na BIOS (sem apagar as chaves).
Depois confira:  mokutil --sb-state   e   nvidia-smi
EOF
fi
