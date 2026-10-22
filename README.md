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

## Eduroam

O `scripts/eduroam.sh` conecta à rede **eduroam** pelo NetworkManager (WPA2-Enterprise,
EAP-TTLS com PAP). Ele **não** é executado pelo `pos-instalacao.sh`. Rode quando precisar:

```bash
./scripts/eduroam.sh           # conecta (cria o perfil na primeira vez)
./scripts/eduroam.sh --reset   # apaga o perfil e pede usuário/senha de novo
```

Na primeira vez, o script pede o usuário (ex.: `nome@instituicao.br`) e a senha e cria o perfil
`eduroam` com conexão automática. Das próximas vezes, ele só liga o Wi-Fi, procura a rede e
conecta (espera até 30 s). O resultado aparece numa notificação (`notify-send`).

| Variável | Para que serve |
|---|---|
| `EDUROAM_USER` / `EDUROAM_PASS` | Passa o usuário e a senha sem o prompt interativo |
| `EDUROAM_IFACE` | Escolhe a interface Wi-Fi (o padrão é a primeira que o `nmcli` listar) |

| Problema | Solução |
|---|---|
| "Rede 'eduroam' não está ao alcance" | Você está fora da área de cobertura, ou o Wi-Fi ainda está buscando. Tente de novo |
| Falha ao conectar | A senha mudou ou está errada. Rode `./scripts/eduroam.sh --reset` |
| A instituição não usa TTLS/PAP | Veja o método no [eduroam CAT](https://cat.eduroam.org) e ajuste `802-1x.eap` / `802-1x.phase2-auth` no script |

> O perfil **não verifica o certificado do servidor**. Com PAP, isso deixa a senha exposta a um
> ponto de acesso falso chamado "eduroam". Se a sua instituição disponibilizar o certificado da CA
> no eduroam CAT, adicione `802-1x.ca-cert <arquivo>` e `802-1x.domain-suffix-match <domínio>`
> ao `nmcli con add`.

## Secure Boot

Os scripts em `scripts/secureboot/` ativam o Secure Boot sem quebrar o dual boot com o Windows nem
o driver da NVIDIA. O `pos-instalacao.sh` **não** os executa. Rode-os manualmente, com `sudo`.

| Script | Sistema | O que faz |
|---|---|---|
| `arch-1-preparar.sh` | Arch | Fase 1: chaves próprias, GRUB reinstalado e tudo assinado |
| `arch-2-registrar-chaves.sh` | Arch | Fase 2: registra as chaves no firmware (precisa do Setup Mode) |
| `arch-diag.sh` | Arch | Salva o diagnóstico em `~/secureboot/diag.txt` (útil se algo der errado) |
| `ubuntu-nvidia.sh` | Ubuntu e derivados | Assina o módulo da NVIDIA com uma chave MOK |
| `fedora-nvidia.sh` | Fedora | Assina o módulo da NVIDIA (akmods/RPM Fusion) com uma chave MOK |

### Arch Linux

O Arch não traz um bootloader assinado. Por isso, o script cria **chaves próprias** com o `sbctl`
e as registra no firmware **junto com as da Microsoft** (necessárias para o Windows e para a
option ROM da RTX).

> ⚠️ Feito para **esta instalação**. O script assume:
> - ESP em `/boot/efi`, com o GRUB **dentro** dela (`/boot/efi/grub/grub.cfg`), em modo `--removable`
> - kernel `linux` (`/boot/vmlinuz-linux`)
> - UKI em `/boot/efi/EFI/Linux/arch-linux.efi` (usada como entrada de emergência)
>
> Em outra máquina, ou no CachyOS/EndeavourOS, ajuste `ESP`, `CFG`, `UKI` e o nome do kernel no
> topo do `arch-1-preparar.sh`. **Não use em Debian, Fedora ou Ubuntu.**

Passo a passo:

```bash
sudo pacman -S sbctl efibootmgr
sudo ./scripts/secureboot/arch-1-preparar.sh      # com o Secure Boot DESLIGADO
```

1. Reinicie (ainda **sem** Secure Boot) e confirme que o GRUB, o Arch e o Windows sobem.
2. Na BIOS: **Security → Secure Boot → Reset to Setup Mode** (ou *Delete all keys*).
3. De volta no Arch:
   ```bash
   sudo ./scripts/secureboot/arch-2-registrar-chaves.sh
   ```
4. Reinicie, entre na BIOS e **ative o Secure Boot**.
5. Confira com `sbctl status`. Deve aparecer `Secure Boot: ✓ Enabled`.

O que a fase 1 faz:

- Faz backup da ESP inteira em `~/secureboot/esp-backup.tar`.
- Cria as chaves (`sbctl create-keys`) em `/var/lib/sbctl/keys`.
- Reinstala o GRUB com `--disable-shim-lock` e **todos os módulos embutidos**. Com o Secure Boot
  ligado, o GRUB não carrega módulos `.mod` de fora. A lista é calculada a partir do `grub.cfg`
  (e do `grub-btrfs.cfg`, se existir) e salva em `~/secureboot/grub-modules.txt`.
- Assina o `BOOTX64.EFI`, a UKI e o `vmlinuz-linux`.
- Cria a entrada **"Arch Linux (UKI)"** no firmware, que boota a UKI direto, sem o GRUB. Ela fica
  depois do GRUB na ordem de boot e serve de emergência.

Quando o kernel atualiza, o hook do `sbctl` no pacman reassina os arquivos sozinho.

| Problema | Solução |
|---|---|
| `Setup Mode: Disabled` na fase 2 | As chaves da BIOS não foram apagadas. Repita o passo 2 |
| GRUB não abre com Secure Boot ligado | Escolha a entrada "Arch Linux (UKI)" no menu de boot da BIOS (F12) e rode `sudo sbctl verify` |
| `sbctl verify` mostra arquivo não assinado | `sudo sbctl sign -s <arquivo>` |
| Nada dá boot | Desligue o Secure Boot na BIOS. Para voltar a ESP ao estado anterior: `sudo tar -C /boot/efi -xf ~/secureboot/esp-backup.tar` |

### Ubuntu (com NVIDIA)

O Ubuntu já boota com Secure Boot via *shim* assinado pela Microsoft. O problema é o **driver da
NVIDIA**: quando ele é compilado pelo DKMS, o kernel se recusa a carregá-lo sem assinatura, e você
fica sem a GPU.

```bash
sudo ./scripts/secureboot/ubuntu-nvidia.sh
```

O que ele faz:

1. Confere se o sistema é Ubuntu (ou Mint/Pop!_OS), se bootou em UEFI e se tem GPU NVIDIA.
2. Instala `shim-signed`, `mokutil`, `dkms` e os headers do kernel.
3. Se não houver driver NVIDIA, instala o recomendado com `ubuntu-drivers install`. Ele prefere os
   módulos já **assinados pela Canonical** e, nesse caso, nada mais é necessário.
4. Cria (ou reaproveita) a chave MOK em `/var/lib/shim-signed/mok/` e configura o DKMS para
   assinar com ela.
5. Se a chave ainda não estiver registrada, pede uma **senha temporária** e agenda o registro.
6. Recompila e assina os módulos DKMS da NVIDIA e mostra quem assinou cada um.

Depois de rodar:

1. Reinicie. Aparece uma **tela azul** (MOK Manager), e você tem ~10 s para apertar uma tecla.
2. **Enroll MOK → Continue → Yes**, digite a senha e escolha **Reboot**.
3. Se o Secure Boot estiver desligado, ative-o na BIOS.
4. Confira com `mokutil --sb-state` e `nvidia-smi`.

> ⚠️ No Ubuntu, **não** apague as chaves da BIOS (Setup Mode) e **não** use o `sbctl`. O shim
> depende das chaves da Microsoft.

Quando o kernel ou o driver atualiza, o DKMS assina sozinho com a mesma chave. A tela azul só
volta se a chave for trocada.

| Problema | Solução |
|---|---|
| `nvidia-smi`: *couldn't communicate with the NVIDIA driver* | A chave não foi registrada (a tela azul passou). Rode o script de novo e reinicie |
| Módulo aparece como `SEM ASSINATURA` | `sudo dkms install --force nvidia/<versão> -k $(uname -r)` |
| A senha não funciona na tela azul | O teclado lá usa layout americano. Use uma senha só com letras e números |

### Fedora (com NVIDIA)

Igual ao Ubuntu: o Fedora já boota com Secure Boot via *shim*, e o problema é o **driver da NVIDIA**
do RPM Fusion, que o `akmods` compila na própria máquina. Sem assinatura, o kernel não o carrega.

```bash
sudo ./scripts/secureboot/fedora-nvidia.sh
```

O que ele faz:

1. Confere se o sistema é Fedora, se bootou em UEFI e se tem GPU NVIDIA.
2. Habilita o RPM Fusion (free e nonfree), se ainda não estiver.
3. Instala `shim-x64`, `mokutil`, `akmods` e o `kernel-devel` do kernel atual.
4. Cria (ou reaproveita) a chave do akmods com `kmodgenca -a`, em `/etc/pki/akmods/`. O akmods
   assina sozinho com ela.
5. Se a chave ainda não estiver registrada, pede uma **senha temporária** e agenda o registro.
6. Instala o `akmod-nvidia` (se faltar), recompila o módulo com `akmods --force` e mostra quem
   assinou cada um.

Depois de rodar, siga os mesmos passos do Ubuntu: reinicie, **Enroll MOK → Continue → Yes**, digite
a senha, **Reboot**, ative o Secure Boot na BIOS (se estiver desligado) e confira com
`mokutil --sb-state` e `nvidia-smi`.

> ⚠️ Assim como no Ubuntu, **não** apague as chaves da BIOS e **não** use o `sbctl`.

Quando o kernel atualiza, o akmods recompila e assina o módulo no próximo boot (ou ao instalar o
kernel). Espere ele terminar antes de reiniciar: `sudo akmods --kernels <versão>` força a compilação.

| Problema | Solução |
|---|---|
| `nvidia-smi`: *couldn't communicate with the NVIDIA driver* | A chave não foi registrada (a tela azul passou). Rode o script de novo e reinicie |
| Módulo aparece como `SEM ASSINATURA` | O módulo foi compilado antes da chave existir. `sudo akmods --force --kernels $(uname -r)` |
| Após atualizar o kernel, a GPU some | O akmods ainda não compilou para o kernel novo. `sudo akmods --force` e reinicie |

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
├── scripts/
│   ├── eduroam.sh        # conecta à rede eduroam (rodar manualmente, veja "Eduroam")
│   └── secureboot/       # Secure Boot no Arch, Ubuntu+NVIDIA e Fedora+NVIDIA (veja "Secure Boot")
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
