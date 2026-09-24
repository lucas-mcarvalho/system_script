# Pós-instalação do Arch Linux (Acer Nitro V)

Script que deixa um Arch **recém-instalado** igual ao sistema atual: Hyprland + Noctalia/Quickshell,
zsh, temas, SDDM, NVIDIA, snapshots, TLP e Dolphin. Ele não instala o sistema do zero. Primeiro
você instala o Arch, depois roda o script.

**Hardware alvo:** Acer Nitro V · Intel i5-13420H (UHD Graphics) · NVIDIA RTX 3050 6GB Laptop ·
dual boot com o Windows.

---

## 1. Antes: instalar o Arch

Use o `archinstall` (ou instale manualmente) com:

| Opção | Valor |
|---|---|
| Bootloader | **GRUB** |
| Sistema de arquivos | **btrfs** com os subvolumes padrão (`@`, `@home`, `@log`, `@pkg`…) |
| Compressão btrfs | zstd (recomendado) |
| Perfil | Minimal (o script instala o resto) |
| Rede | NetworkManager |
| Usuário | o seu, com permissão de sudo |

> **Não mexa nas partições do Windows.** No disco atual, o Arch fica na `nvme0n1p6` e a EFI dele
> na `nvme0n1p5`.
> Sem btrfs com o subvolume `@`, o script funciona, mas pula o Timeshift e os snapshots no GRUB.

## 2. Rodar o script

Depois do primeiro boot, logado como **seu usuário** (não root) e com internet:

```bash
cd Script_backup
chmod +x pos-instalacao.sh
./pos-instalacao.sh
```

A senha do sudo é pedida uma vez só. Se algum pacote der conflito, o pacman volta a perguntar de
forma interativa. Nesse caso, responda e o script continua.

## 3. Depois do script

1. Copie o resto das dotfiles do HD externo (`~/.zshrc`, `~/.local/share/themes`,
   `~/.local/state/noctalia`, Kvantum, qt5ct/qt6ct…). As configs do **Hyprland, kitty,
   wlogout, rofi e uwsm já vêm com o script**.
2. Coloque os wallpapers no lugar. O `hyprlock.conf` usa `~/Imagens/Hyprlock/3.jpg`, e o
   `hyprpaper.conf` usa `~/Pictures/Wallpapers/3.jpg`.
3. **Reinicie.**
4. Escolha o wallpaper de novo no Noctalia.

---

## O que o script faz

| Etapa | Detalhes |
|---|---|
| **pacman** | `Color`, `ILoveCandy`, `ParallelDownloads = 20`, habilita o `multilib` |
| **Pacotes** | Tudo de `packages/pacman.txt` + os essenciais listados no script. Pacotes que sumiram dos repositórios são ignorados, com aviso |
| **yay + AUR** | Compila o `yay-bin` e instala `packages/aur.txt` (Spotify, VS Code, Heroic, wlogout, Ventoy, ícones Dracula) |
| **zsh** | Define o zsh como shell padrão e instala o oh-my-zsh + `zsh-autosuggestions` e `zsh-syntax-highlighting` |
| **Desktop** | Hyprland, uwsm, Quickshell, Noctalia, portais xdg, polkit-gnome, gnome-keyring |
| **Temas** | GTK Graphite-Dark, ícones Tela-dracula (do GitHub, se ainda não existirem), Kvantum, qt5ct/qt6ct, nwg-look. Aplica o tema, os ícones, o cursor e as fontes via `gsettings` |
| **Fontes** | JetBrains Mono Nerd, Hack, Noto (+ CJK e emoji), DejaVu, Liberation, Adwaita |
| **Dolphin** | Plugins, kio-extras/fuse/admin, miniaturas (vídeo, PDF, código), formatos de imagem, Ark, Konsole (F4), menu "Abrir com" funcionando no Hyprland |
| **Docker** | `docker`, `docker-compose`, `docker-buildx`. Adiciona o seu usuário ao grupo `docker` (**docker sem sudo**), ativa o serviço e testa com `hello-world` |
| **NVIDIA** | `nvidia-open`, módulos no initramfs, `modeset=1 fbdev=1`, RTD3 (desliga a RTX quando ociosa), `nvidia-powerd` |
| **Acer** | `acer_wmi predator_v4=1` (perfis de energia do firmware) |
| **zram** | Swap em RAM comprimida com zstd |
| **GRUB** | Detecta sozinho onde está o `grub.cfg`, ajusta os parâmetros do kernel e ativa o os-prober (Windows no menu) |
| **Timeshift** | Modo btrfs: 6 snapshots por hora, 5 diários, 5 semanais, 30 mensais e 5 de boot. Cria um snapshot inicial |
| **grub-btrfs** | Snapshots do Timeshift aparecem no menu do GRUB automaticamente (`grub-btrfsd --timeshift-auto`) |
| **Configs** | Restaura `~/.config/hypr`, `kitty`, `wlogout` (com os ícones), `rofi` e `uwsm` da pasta `configs/`. O que já existir vira `*.antes` |
| **SDDM** | Tema [SilentSDDM](https://github.com/uiriansan/SilentSDDM) com as suas configs e o fundo `pillars-of-creation` (`etc/sddm-silent`), teclado virtual e o espelhamento eDP/HDMI no login (`Xsetup`) |
| **TLP** | Substitui o power-profiles-daemon (veja abaixo) |
| **Serviços** | NetworkManager, Bluetooth, CUPS, Docker, cronie, timesyncd, ufw, TLP, SDDM |
| **Firewall** | ufw: bloqueia conexões de entrada e libera as de saída |

## Bateria (TLP)

Config em `/etc/tlp.d/10-nitro-bateria.conf`.

| | Na tomada | Na bateria |
|---|---|---|
| Turbo da CPU | ligado | **desligado** |
| Política de energia (EPP) | balance_performance | **power** |
| Desempenho máximo | 100% | **70%** |
| Perfil do firmware | balanced-performance | **low-power** |
| RTX 3050 / PCIe | suspende quando ociosa | suspende + ASPM powersupersave |
| Wi-Fi / áudio / USB | normal | economia ligada |

Comandos úteis:

```bash
sudo tlp-stat -s -p     # estado geral e processador
sudo tlp start          # reaplicar depois de editar a config
cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status   # "suspended" = RTX desligada
```

> O limite de carga (parar em 80%) **não** está disponível neste Acer, porque o kernel não
> oferece `charge_control_end_threshold`. O pacote AUR `acer-wmi-battery-dkms` pode resolver isso.

## Docker

Depois de reiniciar (ou sair e entrar de novo na sessão), o docker funciona sem `sudo`:

```bash
groups                        # deve listar "docker"
docker run --rm hello-world
docker compose version
```

> Estar no grupo `docker` equivale a ter acesso root na máquina. Para uso pessoal, isso é normal.
> Portas publicadas com `-p` **passam por cima do ufw**. Para expor só na própria máquina, use
> `-p 127.0.0.1:8080:80`.

## Snapshots

```bash
sudo timeshift --list                   # listar snapshots
sudo timeshift --create --comments "x"  # criar um manualmente
sudo timeshift --restore                # restaurar (interativo)
```

Se o sistema não der boot, escolha **"Arch Linux snapshots"** no GRUB, inicie por um snapshot
e rode `sudo timeshift --restore`.

## Arquivos da pasta

```
Script_backup/
├── pos-instalacao.sh     # o script
├── README.md
├── configs/              # copiado para ~/.config/
│   ├── hypr/             # hyprland.lua, hypridle, hyprlock, monitores, scripts
│   ├── kitty/            # kitty.conf + temas
│   ├── wlogout/          # layout, css e ícones
│   ├── rofi/             # config.rasi, tema e paletas de cores
│   └── uwsm/             # env-hyprland (NVIDIA como GPU primária com HDMI)
├── packages/
│   ├── pacman.txt        # pacotes oficiais (um por linha, pode editar)
│   └── aur.txt           # pacotes do AUR
└── etc/
    ├── sddm-silent/      # configs + imagem de fundo do tema silent (usado pelo script)
    ├── sddm.conf.d/      # greeter em X11 (usado pelo script)
    ├── sddm/scripts/Xsetup  # espelha eDP/HDMI no login (usado pelo script)
    ├── grub.default      # /etc/default/grub antigo (só referência)
    ├── sddm.conf         # só referência
    └── timeshift.json    # só referência
```

Para adicionar ou remover programas, edite `packages/pacman.txt` ou `packages/aur.txt`.

## Backups que o script cria

Antes de alterar os arquivos abaixo, o script guarda o original com o sufixo `.antes`:
`/etc/pacman.conf`, `/etc/mkinitcpio.conf`, `/etc/default/grub`, `/etc/fstab` e os arquivos de
`~/.config/{hypr,kitty,wlogout,rofi,uwsm}` que já existiam.

## Problemas comuns

| Problema | Solução |
|---|---|
| Conflito de pacote no início | Responda o prompt do pacman (normalmente, aceitar remover o conflitante) |
| Pacote do AUR falhou | `yay -S <pacote>` depois |
| Tela preta após reiniciar | No GRUB, aperte `e` e tire `quiet` para ver os logs. Confira se `nvidia-open` está instalado e rode `sudo mkinitcpio -P` |
| Windows não aparece no GRUB | `sudo grub-mkconfig -o /boot/grub/grub.cfg` (ou `/boot/efi/grub/grub.cfg`) |
| "Abrir com" do Dolphin vazio | Rode `kbuildsycoca6` (o `hyprland.lua` já define `XDG_MENU_PREFIX=arch-`) |
| `permission denied ... docker.sock` | Ainda não relogou depois do script. Saia e entre de novo (ou reinicie). Confira com `groups` |
| Botão de energia do Noctalia não funciona | O `power-profiles-daemon` foi trocado pelo TLP. Veja se `tlp-pd.service` existe: `systemctl status tlp-pd` |
