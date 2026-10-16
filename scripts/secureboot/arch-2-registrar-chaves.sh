#!/bin/bash
# Fase 2: rodar DEPOIS de colocar o firmware em Setup Mode na BIOS.
set -euo pipefail
[ "$EUID" -eq 0 ] || { echo "rode com sudo"; exit 1; }

if ! sbctl status | grep -q 'Setup Mode:.*Enabled'; then
  echo "Firmware NÃO está em Setup Mode. Entre na BIOS e apague as chaves"
  echo "(Security > Secure Boot > Reset to Setup Mode / Delete all keys)."
  sbctl status; exit 1
fi

# -m mantém as chaves da Microsoft: necessárias para o Windows e para as
# option ROMs da GPU NVIDIA.
sbctl enroll-keys -m
sbctl status
sbctl verify
echo
echo "OK. Reinicie, entre na BIOS e ATIVE o Secure Boot."
