# Pós-instalação do Arch (Acer Nitro V)

Configura um Arch **já instalado** (por exemplo, com o `archinstall`) igual ao sistema atual:
Hyprland + Noctalia/Quickshell, zsh (oh-my-zsh), Graphite-Dark (GTK/Kvantum/KDE),
ícones Tela-dracula, fontes JetBrains Mono Nerd, SDDM com tema silent, polkit-gnome,
NVIDIA RTX 3050 (nvidia-open), Timeshift com snapshots no GRUB, zram, TLP, Dolphin completo e yay com os pacotes do AUR.

## Instalação do Arch (antes do script)
No `archinstall`: bootloader **GRUB**, sistema de arquivos **btrfs** com os subvolumes padrão
(`@`, `@home`...). Sem btrfs `@`, o script pula a parte do Timeshift/grub-btrfs.

## Uso
1. Copie esta pasta para o sistema novo.
2. Logado como seu usuário (não root), com internet:
   ```
   ./pos-instalacao.sh
   ```
3. Reinicie.

Os dotfiles (`~/.config`, `~/.zshrc`, `~/.local/share/themes`...) **não** são restaurados
pelo script. Copie-os do HD externo manualmente, antes ou depois de rodar o script.

## Observações
- As configs de sistema sobrescritas ficam salvas com o sufixo `.antes` em `/etc`.
- O TLP substitui o `power-profiles-daemon`. A config fica em `/etc/tlp.d/10-nitro-bateria.conf`.
  Para ver o estado: `sudo tlp-stat -s -p`.
- O limite de carga (parar em 80%) não está disponível neste Acer.
