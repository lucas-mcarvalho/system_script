#!/bin/bash
# Diagnóstico do Secure Boot (Arch). Rode com sudo; salva em ~/secureboot/diag.txt.
OUT=${OUT:-$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)/secureboot/diag.txt}
mkdir -p "$(dirname "$OUT")"
{
echo "== sbctl status"; sbctl status
echo "== sbctl verify"; sbctl verify
echo "== efibootmgr"; efibootmgr -v
echo "== efi files"; find /boot/efi -iname '*.efi'
echo "== grub.cfg entries"; grep -hA5 menuentry /boot/efi/grub/grub.cfg /boot/grub/grub.cfg 2>/dev/null | head -60
} > "$OUT" 2>&1
chmod 644 "$OUT"; echo "ok -> $OUT"
