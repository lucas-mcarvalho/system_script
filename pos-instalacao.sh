#!/usr/bin/env bash
# =============================================================================
# pos-instalacao.sh
# Roda num Arch JA INSTALADO (ex: via archinstall), logado como seu usuario
# (NAO root, o script usa sudo quando precisa), com internet.
#
# Pre-requisitos da instalacao:
#   - GRUB como bootloader
#   - raiz em btrfs com subvolumes @ e @home (layout padrao do archinstall)
#     -> necessario para Timeshift + snapshots no GRUB
#   - multilib habilitado ou nao (o script habilita)
#
# O que faz:
#   yay + AUR, todos os pacotes, zsh/oh-my-zsh, Quickshell/Noctalia, fontes,
#   icones, temas GTK/Qt, tema SDDM, polkit, NVIDIA RTX 3050, Timeshift +
#   grub-btrfs, TLP e Dolphin completo.
#   Os dotfiles (~/.config etc.) NAO sao restaurados aqui: copie do HD externo.
# =============================================================================
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

msg()  { printf '\n\e[1;34m==>\e[0m \e[1m%s\e[0m\n' "$*"; }
warn() { printf '\e[1;33m!!\e[0m %s\n' "$*"; }
die()  { printf '\e[1;31mERRO:\e[0m %s\n' "$*" >&2; exit 1; }
confirm() { local r; read -rp "$1 [s/N] " r; [[ $r =~ ^[sSyY]$ ]]; }

[[ $EUID -ne 0 ]] || die "rode como seu usuario normal, nao como root"
ping -c1 -W3 archlinux.org >/dev/null 2>&1 || die "sem internet"

# Pede a senha uma vez e mantem o sudo vivo ate o fim do script
sudo -v
while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &

# --- pacman.conf ---------------------------------------------------------------
msg "Configurando pacman (cores, ILoveCandy, multilib, downloads paralelos)"
PC=/etc/pacman.conf
sudo cp -n $PC $PC.antes
# Descomenta se existir comentado; se nao existir, cria logo abaixo de [options]
sudo sed -i 's/^#\s*Color\s*$/Color/; s/^#\s*ILoveCandy\s*$/ILoveCandy/' $PC
sudo sed -i 's/^#\?\s*ParallelDownloads.*/ParallelDownloads = 20/' $PC
grep -q '^ParallelDownloads' $PC || sudo sed -i '/^\[options\]/a ParallelDownloads = 20' $PC
grep -q '^Color' $PC             || sudo sed -i '/^\[options\]/a Color' $PC
# ILoveCandy: barra de progresso do pacman com o Pac-Man comendo
grep -q '^ILoveCandy' $PC        || sudo sed -i '/^Color/a ILoveCandy' $PC
sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' $PC

# --- Pacotes oficiais ----------------------------------------------------------
msg "Instalando pacotes oficiais"
EXTRA=(
  # NVIDIA RTX 3050 Laptop (Ampere) -> modulo open + utilitarios 32 bits p/ Steam
  nvidia-open nvidia-utils lib32-nvidia-utils nvidia-settings nvidia-prime
  egl-wayland libva-nvidia-driver
  # Intel UHD (iGPU)
  intel-media-driver vulkan-intel lib32-vulkan-intel
  # Shell / desktop
  hyprland uwsm quickshell noctalia xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
  polkit polkit-gnome gnome-keyring xdg-user-dirs xorg-xhost
  # Tema SDDM silent (dependencias) + X para o Xsetup do SDDM
  sddm qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg xorg-server xorg-xrandr
  # Temas Qt/GTK e icones
  kvantum kvantum-qt5 qt5ct qt6ct nwg-look papirus-icon-theme kde-gtk-config
  # Fontes
  ttf-jetbrains-mono-nerd ttf-hack ttf-dejavu ttf-liberation
  noto-fonts noto-fonts-cjk noto-fonts-emoji adwaita-fonts
  # Dolphin e o essencial para ele funcionar bem fora do Plasma
  dolphin dolphin-plugins          # gerenciador + integracao git/dropbox/etc.
  kio-extras kio-fuse kio-admin    # sftp/smb/mtp/thumbnails, abrir remotos em apps nao-KDE, modo admin
  ffmpegthumbs kdegraphics-thumbnailers kdesdk-thumbnailers  # miniaturas de video, PDF/imagens, codigo
  kimageformats qt6-imageformats icoutils libappimage taglib # mais formatos de imagem, icones .exe, AppImage
  ark konsole                      # compactados e painel de terminal (F4)
  kde-cli-tools archlinux-xdg-menu # menu "Abrir com" funcionando no Hyprland (XDG_MENU_PREFIX=arch-)
  kdenetwork-filesharing udisks2 ntfs-3g baloo breeze-icons
  # Snapshots
  timeshift grub-btrfs inotify-tools cronie
  # Bateria
  tlp tlp-rdw ethtool smartmontools
  # Docker
  docker docker-compose docker-buildx
  # Base para o script
  base-devel git curl rsync zsh
)
mapfile -t WANTED < <(grep -Ev '^\s*(#|$)' "$DIR/packages/pacman.txt"; printf '%s\n' "${EXTRA[@]}")
sudo pacman -Sy
# Filtra o que nao existe mais nos repositorios (senao o pacman aborta tudo)
AVAIL=$(pacman -Slq | sort -u)
mapfile -t PKGS < <(printf '%s\n' "${WANTED[@]}" | sort -u | comm -12 - <(echo "$AVAIL"))
MISSING=$(printf '%s\n' "${WANTED[@]}" | sort -u | comm -23 - <(echo "$AVAIL"))
if [[ -n $MISSING ]]; then warn "Fora dos repositorios (ignorados): $(echo $MISSING)"; fi

sudo pacman -Su --needed --noconfirm "${PKGS[@]}" || {
  warn "Instalacao automatica falhou (provavel conflito). Resolva de forma interativa:"
  sudo pacman -Su --needed "${PKGS[@]}"
}

# --- yay + AUR -----------------------------------------------------------------
if ! command -v yay >/dev/null; then
  msg "Instalando yay"
  TMP=$(mktemp -d)
  git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$TMP/yay-bin"
  (cd "$TMP/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$TMP"
fi

msg "Pacotes do AUR"
mapfile -t AUR < <(grep -Ev '^\s*(#|$)' "$DIR/packages/aur.txt")
if (( ${#AUR[@]} )); then
  yay -S --needed --noconfirm "${AUR[@]}" || warn "algum pacote do AUR falhou; rode depois: yay -S ${AUR[*]}"
fi

# --- Usuario -------------------------------------------------------------------
msg "Grupos e shell do usuario"
sudo usermod -aG wheel "$USER"
[[ $(getent passwd "$USER" | cut -d: -f7) == /usr/bin/zsh ]] || sudo chsh -s /usr/bin/zsh "$USER"

# --- Docker (sem sudo) ---------------------------------------------------------
msg "Docker"
# Quem esta no grupo "docker" fala direto com o /var/run/docker.sock, sem sudo.
# (Isso equivale a acesso root na maquina; normal para uso pessoal.)
getent group docker >/dev/null || sudo groupadd docker
sudo usermod -aG docker "$USER"
sudo systemctl enable --now docker.service
# Testa como o seu usuario com o grupo docker (o grupo novo so vale na sessao
# depois de relogar; aqui ele e aplicado so para o teste)
if sudo -u "$USER" -g docker docker run --rm hello-world >/dev/null 2>&1; then
  echo "docker sem sudo: OK"
else
  warn "teste do docker falhou; depois de relogar rode: docker run --rm hello-world"
fi

# --- zsh -----------------------------------------------------------------------
msg "oh-my-zsh + plugins"
[[ -d ~/.oh-my-zsh ]] || git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh
ZC=~/.oh-my-zsh/custom/plugins
[[ -d $ZC/zsh-autosuggestions ]]     || git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions "$ZC/zsh-autosuggestions"
[[ -d $ZC/zsh-syntax-highlighting ]] || git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting "$ZC/zsh-syntax-highlighting"

# --- Icones e temas ------------------------------------------------------------
msg "Icones Tela-dracula"
if [[ ! -d ~/.local/share/icons/Tela-dracula ]]; then
  TMP=$(mktemp -d)
  git clone --depth 1 https://github.com/vinceliuice/Tela-icon-theme "$TMP/tela"
  mkdir -p ~/.local/share/icons
  (cd "$TMP/tela" && ./install.sh -d "$HOME/.local/share/icons" dracula)
  rm -rf "$TMP"
fi
# Tema GTK Graphite-Dark (se ja veio do HD externo, pula):
if [[ ! -d ~/.local/share/themes/Graphite-Dark ]]; then
  msg "Tema GTK Graphite-Dark"
  TMP=$(mktemp -d)
  git clone --depth 1 https://github.com/vinceliuice/Graphite-gtk-theme "$TMP/graphite"
  (cd "$TMP/graphite" && ./install.sh -c dark -d "$HOME/.local/share/themes")
  rm -rf "$TMP"
fi
# Kvantum (GraphiteDark), qt5ct/qt6ct e kdeglobals: vem com os dotfiles do HD.

msg "Aplicando temas GTK, icones, cursor e fontes"
gs() { gsettings set org.gnome.desktop.interface "$@" 2>/dev/null || true; }
gs gtk-theme 'Graphite-Dark'
gs icon-theme 'Tela-dracula'
gs cursor-theme 'Adwaita'
gs cursor-size 24
gs color-scheme 'prefer-dark'
gs font-name 'JetBrainsMonoNL Nerd Font Propo Italic 10'
gs document-font-name 'JetBrainsMonoNL Nerd Font Propo Italic 10'
gs monospace-font-name 'JetBrainsMono Nerd Font Mono 10'
gs font-hinting 'slight'
gs font-antialiasing 'grayscale'
fc-cache -f
xdg-user-dirs-update

# --- NVIDIA --------------------------------------------------------------------
msg "NVIDIA (modprobe + mkinitcpio)"
sudo tee /etc/modprobe.d/nvidia.conf >/dev/null <<'EOF'
options nvidia_drm modeset=1 fbdev=1
# RTD3: desliga a RTX 3050 quando ociosa (principal ganho de bateria em notebook hibrido)
options nvidia NVreg_DynamicPowerManagement=0x02
EOF
echo 'options acer_wmi predator_v4=1' | sudo tee /etc/modprobe.d/acer-wmi.conf >/dev/null

sudo cp -n /etc/mkinitcpio.conf /etc/mkinitcpio.conf.antes
sudo sed -i 's/^MODULES=.*/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
# Sem "kms" nos HOOKS (evita carregar o nouveau no initramfs); resto mantido
sudo sed -i '/^HOOKS=/ s/ kms//' /etc/mkinitcpio.conf
sudo mkinitcpio -P

# --- zram ----------------------------------------------------------------------
sudo tee /etc/systemd/zram-generator.conf >/dev/null <<'EOF'
[zram0]
compression-algorithm = zstd
zram-size = ram
swap-priority = 100
EOF

# --- GRUB ----------------------------------------------------------------------
msg "GRUB"
# Descobre onde esta o grub.cfg (archinstall: /boot/grub; sistema atual: /boot/efi/grub)
GRUB_DIR=""
for d in /boot/efi/grub /boot/grub /efi/grub; do
  if sudo test -f "$d/grub.cfg"; then GRUB_DIR=$d; break; fi
done
[[ -n $GRUB_DIR ]] || die "grub.cfg nao encontrado; o sistema foi instalado com GRUB?"
echo "grub.cfg em $GRUB_DIR"

sudo cp -n /etc/default/grub /etc/default/grub.antes
CMDLINE='loglevel=3 quiet nvidia-drm.modeset=1 nvidia-drm.fbdev=1 video=eDP-1:1920x1080@60e video=HDMI-A-1:1920x1080@60e'
sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$CMDLINE\"|" /etc/default/grub
sudo sed -i 's/^#\?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
sudo sed -i 's/^#\?GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub
sudo sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' /etc/default/grub

# --- Timeshift + snapshots no GRUB ---------------------------------------------
if [[ $(findmnt -no FSTYPE /) == btrfs && $(findmnt -no FSROOT /) == /@ ]]; then
  msg "Timeshift (btrfs) + grub-btrfs"

  # subvolid= no fstab quebra o restore do Timeshift (ele troca os subvolumes
  # de lugar e o id muda). Montar so por subvol=.
  sudo cp -n /etc/fstab /etc/fstab.antes
  sudo sed -i 's/subvolid=[0-9]*,//; s/,subvolid=[0-9]*//' /etc/fstab

  ROOT_UUID=$(findmnt -no UUID /)
  sudo mkdir -p /etc/timeshift
  sudo tee /etc/timeshift/timeshift.json >/dev/null <<EOF
{
  "backup_device_uuid" : "$ROOT_UUID",
  "parent_device_uuid" : "",
  "do_first_run" : "false",
  "btrfs_mode" : "true",
  "include_btrfs_home_for_backup" : "false",
  "include_btrfs_home_for_restore" : "false",
  "stop_cron_emails" : "true",
  "schedule_monthly" : "true",
  "schedule_weekly" : "true",
  "schedule_daily" : "true",
  "schedule_hourly" : "true",
  "schedule_boot" : "true",
  "count_monthly" : "30",
  "count_weekly" : "5",
  "count_daily" : "5",
  "count_hourly" : "6",
  "count_boot" : "5",
  "snapshot_size" : "0",
  "snapshot_count" : "0",
  "date_format" : "%Y-%m-%d %H:%M:%S",
  "exclude" : [],
  "exclude-apps" : []
}
EOF
  # Agendamento via cron (mesmos arquivos que o Timeshift gera pela GUI)
  sudo tee /etc/cron.d/timeshift-hourly >/dev/null <<'EOF'
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=""
0 * * * * root timeshift --check --scripted
EOF
  sudo tee /etc/cron.d/timeshift-boot >/dev/null <<'EOF'
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=""
@reboot root sleep 10m && timeshift --create --scripted --tags B
EOF

  # grub-btrfsd observa os snapshots do Timeshift e atualiza o menu sozinho
  sudo sed -i "s|^#\?GRUB_BTRFS_GRUB_DIRNAME=.*|GRUB_BTRFS_GRUB_DIRNAME=\"$GRUB_DIR\"|" /etc/default/grub-btrfs/config
  sudo mkdir -p /etc/systemd/system/grub-btrfsd.service.d
  sudo tee /etc/systemd/system/grub-btrfsd.service.d/override.conf >/dev/null <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/grub-btrfsd --syslog --timeshift-auto
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable --now cronie grub-btrfsd

  sudo timeshift --create --comments "pos-instalacao" --tags D || warn "snapshot inicial falhou"
  TIMESHIFT_OK=1
else
  warn "A raiz nao e btrfs com subvolume @: Timeshift/grub-btrfs NAO configurados."
  TIMESHIFT_OK=0
fi

sudo grub-mkconfig -o "$GRUB_DIR/grub.cfg"

# --- SDDM (tema silent) --------------------------------------------------------
msg "SDDM + tema silent"
TMP=$(mktemp -d)
git clone --depth 1 https://github.com/uiriansan/SilentSDDM "$TMP/silent"
rm -rf "$TMP/silent/.git"
# Suas personalizacoes (qual config esta ativa + configs editadas)
if [[ -d $DIR/etc/sddm-silent ]]; then
  cp -a "$DIR/etc/sddm-silent/metadata.desktop" "$TMP/silent/"
  cp -a "$DIR/etc/sddm-silent/configs/." "$TMP/silent/configs/"
fi
sudo rm -rf /usr/share/sddm/themes/silent
sudo mkdir -p /usr/share/sddm/themes
sudo mv "$TMP/silent" /usr/share/sddm/themes/silent
rm -rf "$TMP"
# Fontes do tema precisam estar no sistema para o greeter
if [[ -d /usr/share/sddm/themes/silent/fonts ]]; then
  sudo cp -r /usr/share/sddm/themes/silent/fonts/. /usr/share/fonts/
  sudo fc-cache -f
fi
sudo tee /etc/sddm.conf >/dev/null <<'EOF'
[Theme]
Current=silent

[General]
InputMethod=qtvirtualkeyboard
GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard
EOF
# Greeter em X11 espelhando eDP/HDMI (Xsetup do sistema atual)
sudo mkdir -p /etc/sddm.conf.d /etc/sddm/scripts
[[ -d $DIR/etc/sddm.conf.d ]] && sudo cp -a "$DIR/etc/sddm.conf.d/." /etc/sddm.conf.d/
if [[ -f $DIR/etc/sddm/scripts/Xsetup ]]; then
  sudo install -m 755 "$DIR/etc/sddm/scripts/Xsetup" /etc/sddm/scripts/Xsetup
fi

# --- TLP -----------------------------------------------------------------------
msg "TLP (bateria)"
sudo tee /etc/tlp.d/10-nitro-bateria.conf >/dev/null <<'EOF'
# Acer Nitro V (i5-13420H + RTX 3050). Ajustes focados em bateria.
# Aplicar mudancas: sudo tlp start   |   Ver estado: sudo tlp-stat -s -p

# CPU: na tomada desempenho normal; na bateria sem turbo e EPP "power"
CPU_DRIVER_OPMODE_ON_AC=active
CPU_DRIVER_OPMODE_ON_BAT=active
CPU_SCALING_GOVERNOR_ON_AC=powersave
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power
CPU_MIN_PERF_ON_AC=0
CPU_MAX_PERF_ON_AC=100
CPU_MIN_PERF_ON_BAT=0
CPU_MAX_PERF_ON_BAT=70
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0
CPU_HWP_DYN_BOOST_ON_AC=1
CPU_HWP_DYN_BOOST_ON_BAT=0

# Perfil do firmware Acer (acer_wmi predator_v4). "performance" e recusado
# por este firmware, por isso balanced-performance na tomada.
PLATFORM_PROFILE_ON_AC=balanced-performance
PLATFORM_PROFILE_ON_BAT=low-power

# Runtime PM: deixa a RTX 3050 e outros PCI dormirem quando ociosos
RUNTIME_PM_ON_AC=auto
RUNTIME_PM_ON_BAT=auto
PCIE_ASPM_ON_AC=default
PCIE_ASPM_ON_BAT=powersupersave

# Wi-Fi, audio, USB
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on
WOL_DISABLE=Y
SOUND_POWER_SAVE_ON_AC=0
SOUND_POWER_SAVE_ON_BAT=1
SOUND_POWER_SAVE_CONTROLLER=Y
USB_AUTOSUSPEND=1
USB_EXCLUDE_BTUSB=1
USB_EXCLUDE_PHONE=1

NMI_WATCHDOG=0

# Limite de carga (ex: parar em 80%) NAO funciona neste Acer: o kernel nao
# expoe charge_control_end_threshold para o BAT1.
EOF

# --- Servicos ------------------------------------------------------------------
msg "Servicos"
# TLP substitui o power-profiles-daemon; rfkill fica com o tlp-rdw
sudo systemctl disable --now power-profiles-daemon.service 2>/dev/null || true
sudo systemctl mask power-profiles-daemon.service systemd-rfkill.service systemd-rfkill.socket
sudo systemctl enable NetworkManager NetworkManager-dispatcher bluetooth cronie cups.socket \
  nvidia-powerd systemd-timesyncd ufw tlp
# TLP >= 1.9 traz o tlp-pd (API compativel com power-profiles-daemon), assim o
# botao de perfil de energia do noctalia continua funcionando
if systemctl cat tlp-pd.service &>/dev/null; then sudo systemctl enable tlp-pd.service; fi
if systemctl cat proton.VPN.service &>/dev/null; then sudo systemctl enable proton.VPN.service; fi

# Troca o display manager atual (gdm, plasma-login-manager...) pelo SDDM
sudo systemctl disable display-manager.service 2>/dev/null || true
sudo systemctl enable sddm

sudo tlp start || true

msg "Firewall (ufw)"
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw --force enable

msg "Pronto!"
(( TIMESHIFT_OK )) || warn "Timeshift/grub-btrfs ficaram de fora (raiz nao e btrfs @)."
echo "Backups das configs originais: /etc/*.antes"
echo "Reinicie para aplicar NVIDIA, GRUB, SDDM, TLP e o grupo docker (docker sem sudo)."
