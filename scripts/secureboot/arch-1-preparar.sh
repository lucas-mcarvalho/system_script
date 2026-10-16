#!/bin/bash
# Fase 1 (Secure Boot ainda DESLIGADO): cria chaves, reinstala o GRUB com
# todos os módulos embutidos e assina tudo. Não mexe nas chaves do firmware.
set -euo pipefail
[ "$EUID" -eq 0 ] || { echo "rode com sudo"; exit 1; }

ESP=/boot/efi
CFG=$ESP/grub/grub.cfg
MODDIR=/usr/lib/grub/x86_64-efi
UKI=$ESP/EFI/Linux/arch-linux.efi
OUT=${OUT:-$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)/secureboot}

mkdir -p "$OUT"
echo "==> Backup da ESP em $OUT/esp-backup.tar"
tar -C "$ESP" -cf "$OUT/esp-backup.tar" .

echo "==> Chaves do sbctl"
[ -d /var/lib/sbctl/keys/db ] || sbctl create-keys

echo "==> Calculando módulos do GRUB"
# Base recomendada pela ArchWiki para GRUB sem shim
mods="all_video boot btrfs cat chain configfile echo efifwsetup efinet ext2 fat
font gettext gfxmenu gfxterm gfxterm_background gzio halt help iso9660 jpeg
keystatus loadenv loopback linux ls lsefi lsefimmap lsefisystab memdisk minicmd
normal ntfs part_msdos part_gpt password_pbkdf2 png probe reboot regexp search
search_fs_uuid search_fs_file search_label serial sleep smbios test tpm true
video bli blsuki efibootnext"
cfgs="$CFG"; [ -f $ESP/grub/grub-btrfs.cfg ] && cfgs="$cfgs $ESP/grub/grub-btrfs.cfg"
# módulos citados via insmod
mods="$mods $(grep -hoP '^\s*insmod\s+\K\S+' $cfgs | tr -d '"' || true)"
# módulos que fornecem cada comando usado no cfg
for cmd in $(awk '{print $1}' $cfgs | grep -E '^[a-z_][a-z0-9_.-]*$' | sort -u); do
  m=$(grep -E "^\*?${cmd//./\\.}: " $MODDIR/command.lst | head -1 | cut -d' ' -f2 || true)
  [ -n "$m" ] && mods="$mods $m"
done
# só os que existem
final=""
for m in $(echo $mods | tr ' ' '\n' | sort -u); do
  [ -f "$MODDIR/$m.mod" ] && final="$final $m"
done
echo "$final" > "$OUT/grub-modules.txt"
echo "    $(echo $final | wc -w) módulos (lista em $OUT/grub-modules.txt)"

echo "==> Reinstalando GRUB (removable, igual ao atual)"
grub-install --target=x86_64-efi --efi-directory=$ESP --boot-directory=$ESP \
  --removable --disable-shim-lock --modules="$final"
grub-mkconfig -o "$CFG"

echo "==> Assinando"
sbctl sign -s $ESP/EFI/BOOT/BOOTX64.EFI
sbctl sign -s "$UKI"
sbctl sign -s /boot/vmlinuz-linux

echo "==> Entrada de emergência no firmware (UKI direto, sem GRUB)"
if ! efibootmgr | grep -q 'Arch Linux (UKI)'; then
  src=$(findmnt -no SOURCE $ESP)
  disk=/dev/$(lsblk -no PKNAME "$src")
  part=$(cat /sys/class/block/$(basename "$src")/partition)
  order=$(efibootmgr | awk '/^BootOrder/{print $2}')
  efibootmgr --create --disk "$disk" --part "$part" \
    --label 'Arch Linux (UKI)' --loader '\EFI\Linux\arch-linux.efi' >/dev/null
  new=$(efibootmgr | grep 'Arch Linux (UKI)' | grep -oP '^Boot\K[0-9A-F]{4}')
  efibootmgr -o "$order,$new" >/dev/null   # mantém GRUB primeiro
fi

echo "==> Verificação"
sbctl verify
efibootmgr | head -4
echo
echo "OK. Reinicie (Secure Boot ainda desligado) e confirme que GRUB, Arch e Windows sobem."
