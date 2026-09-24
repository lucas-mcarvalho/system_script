-- ==========================================
-- Hyprland Native Lua Configuration
-- ==========================================

------------------
---- MONITORS ----
------------------
--[[hl.monitor({
    output = "eDP-1",
   mode = "preferred",
    position = "0x0",
    scale = "1",
})

hl.monitor({
    output = "HDMI-A-1",
    mode = "preferred",
    position = "0x0",
    scale = "1",
    mirror = "eDP-1", 
})


]]

-- Layout condicional. Com o monitor externo conectado, o painel interno fica
-- DESLIGADO (e nao espelhado: espelho nao ganha wl_output proprio, o que quebra
-- a barra e bloqueia direct scanout). Sem o externo, o painel assume sozinho.
local LAPTOP = "eDP-1"
local EXTERNAL = "HDMI-A-1"
local LAPTOP_MODE = "1920x1080@165"
local EXTERNAL_MODE = "1920x1080@179.96"

-- Fail-safe: qualquer erro na deteccao cai em "sem externo", que mantem o
-- painel ligado. Nunca deve sobrar zero monitor ativo (vira FALLBACK headless).
local function external_connected()
	local ok, pipe = pcall(io.popen,
		"grep -lx connected /sys/class/drm/card*-*/status 2>/dev/null | grep -v eDP")
	if not ok or not pipe then
		return false
	end
	local out = pipe:read("*a") or ""
	pipe:close()
	return out:match("%S") ~= nil
end

if external_connected() then
	hl.monitor({
		output = LAPTOP,
		disabled = true,
	})
	hl.monitor({
		output = EXTERNAL,
		mode = EXTERNAL_MODE,
		position = "0x0",
		scale = 1,
	})
else
	hl.monitor({
		output = LAPTOP,
		mode = LAPTOP_MODE,
		position = "0x0",
		scale = 1,
	})
end

-- hl.monitor so vale no parse da config, entao hotplug = reload (que re-avalia
-- external_connected). A guarda vive em arquivo porque o reload recria o estado
-- Lua e zeraria uma variavel local, abrindo recursao reload -> evento -> reload.
local RELAYOUT_STAMP = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/hypr-relayout.stamp"

local function relayout()
	local f = io.open(RELAYOUT_STAMP, "r")
	if f then
		local t = tonumber(f:read("*l") or "") or 0
		f:close()
		if os.time() - t < 5 then
			return
		end
	end
	local w = io.open(RELAYOUT_STAMP, "w")
	if w then
		w:write(tostring(os.time()))
		w:close()
	end
	hl.exec_cmd("hyprctl reload")
end

hl.on("monitor.added", relayout)
hl.on("monitor.removed", relayout)
---- MY PROGRAMS ----
---------------------
local terminal = "kitty"
local fileManager = "dolphin"
local menu = "rofi -show drun"
local browser = "firefox"
local editor = "code"
local logout = "wlogout"

-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function()
	hl.exec_cmd("nm-applet &")
	hl.exec_cmd("kbuildsycoca6 --noincremental")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("waypaper --restore")
	hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
	hl.exec_cmd("/usr/lib/xdg-desktop-portal-hyprland")
	hl.exec_cmd("/usr/lib/xdg-desktop-portal")
	hl.exec_cmd("noctalia")
	hl.exec_cmd("xhost si:localuser:root")
	--[[[hl.exec_cmd("hyprctl keyword workspace 1,monitor:HDMI-A-1,default:true")
    hl.exec_cmd("hyprctl keyword workspace 2,monitor:HDMI-A-1,default:true")
    hl.exec_cmd("hyprctl keyword workspace 3,monitor:HDMI-A-1,default:true")
    hl.exec_cmd("hyprctl keyword workspace 4,monitor:HDMI-A-1,default:true")
    hl.exec_cmd("hyprctl keyword workspace 5,monitor:HDMI-A-1,default:true")
   -- hl.exec_cmd("kanshi &")
    --hl.exec_cmd("hyprctl keyword source ~/.config/hypr/monitors.conf")
    --hl.exec_cmd("hyprctl keyword source ~/.config/hypr/workspaces.conf.conf")
    ]]
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
--hl.env("GTK_THEME", "Adwaita")
hl.env("GTK_APPLICATION_PREFER_DARK_THEME", "1")

-----------------------
---- LOOK AND FEEL ----
-----------------------
hl.config({
	cursor = {
		-- false = cursor por hardware (nao bloqueia direct scanout em tela cheia)
		no_hardware_cursors = false,
		-- use_cpu_buffer foi testado aqui contra o "cursor blit failed" do setup
		-- multi-GPU e nao mudou nada; a raiz e resolvida por AQ_DRM_DEVICES em
		-- ~/.config/uwsm/env-hyprland. Reativar so se o erro voltar.
	},

	render = {
		-- 1 = direct scanout: video/jogo em tela cheia vai direto pro display
		direct_scanout = 1,
	},

	ecosystem = {
		no_update_news = true,
	},

	general = {
		gaps_in = 5,
		gaps_out = 10,
		border_size = 2,

		col = {
			active_border = { colors = { "rgba(3a3a3aff)", "rgba(222222ff)" }, angle = 45 },
			inactive_border = "rgba(595959aa)",
		},

		resize_on_border = false,
		allow_tearing = false,
		layout = "dwindle",
	},

	decoration = {
		rounding = 10,
		active_opacity = 1.0,
		inactive_opacity = 1.0,

		shadow = {
			enabled = true,
			range = 4,
			render_power = 3,
			color = 0xee1a1a1a, -- Formato HexARGB para Lua
		},

		blur = {
			enabled = true,
			size = 3,
			passes = 1,
			vibrancy = 0.1696,
		},
	},

	animations = {
		enabled = true,
	},

	master = {
		new_status = "master",
	},

	misc = {
		force_default_wallpaper = -1,
		disable_hyprland_logo = false,
		-- 0 = VRR desligado: este painel (BOE 0x0D39) nao e vrr_capable,
		-- e com vrr=2 o Hyprland tentava ligar adaptive sync ao entrar em
		-- tela cheia, falhando o commit atomico e travando a imagem.
		vrr = 0,
	},

	input = {
		kb_layout = "us,br",
		accel_profile = flat,
		follow_mouse = 1,
		sensitivity = 0,
		touchpad = {
			natural_scroll = true,
		},
	},
})

--------------------
---- ANIMATIONS ----
--------------------
-- Replicando a sua curva "fast, 0.15, 0.85, 0.25, 1"
hl.curve("fast", { type = "bezier", points = { { 0.15, 0.85 }, { 0.25, 1 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "fast", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "fast", style = "popin 90%" })
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "fast" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "fast", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "fast", style = "slide" })

-----------------
---- DEVICES ----
-----------------
hl.device({
	name = "epic-mouse-v1",
	sensitivity = -0.5,
})

---------------------
---- KEYBINDINGS ----
---------------------
local mainMod = "SUPER"

-- Aplicativos
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(editor))
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(logout))

-- Gerenciamento de Janelas
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + X", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + W", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.exec_cmd("hyprctl dispatch fullscreen"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("hyprshot -m region -o clipboard"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))

-- Scripts de Monitor (Lid Mode)
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("~/.config/hypr/lid-monitor-mode.sh external"))
hl.bind(mainMod .. " + SHIFT + I", hl.dsp.exec_cmd("~/.config/hypr/lid-monitor-mode.sh laptop"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("~/.config/hypr/lid-monitor-mode.sh presentation"))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("~/.config/hypr/lid-monitor-mode.sh presentation"))
hl.bind(mainMod .. " + CTRL + M", hl.dsp.exec_cmd("~/.config/hypr/lid-monitor-mode.sh external"))

-- Switch da Tampa do Notebook
-- Ao fechar a tampa: Desativa a tela do notebook. O HDMI assume como monitor principal e recebe as workspaces.
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("hyprctl keyword monitor 'eDP-1,disable'"), { locked = true })
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("hyprctl keyword monitor 'eDP-1,preferred,0x0,1'"), { locked = true })
-- Sistema
hl.bind(mainMod .. " + ESCAPE", hl.dsp.exec_cmd("pkill waybar || waybar"))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("hyprctl switchxkblayout at-translated-set-2-keyboard next"))
hl.bind(
	mainMod .. " + F8",
	hl.dsp.exec_cmd("pactl set-default-sink \"$(pactl list short sinks | grep hdmi | awk '{print $1}')\"")
)

-- Foco nas Janelas
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "d" }))

-- Workspaces (Alternar e Mover Janelas)
for i = 1, 10 do
	local key = i % 10
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = tostring(i) }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(i) }))
end

-- Workspace Especial (Scratchpad)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll de Workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Mouse Binds (Mover e Redimensionar)
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Multimídia e Volume
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
-- Brilho
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

-- Media Players
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------
hl.window_rule({
	name = "alacritty-float",
	match = { class = "^alacritty$", title = "^alacritty$" },
	float = true,
})

hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

-- Força o Pavucontrol a abrir flutuante (ignora maiúsculas e prefixos)
hl.window_rule({
	name = "pavucontrol-float",
	match = { class = ".*[Pp]avucontrol.*" },
	float = true,
})

-- Força a Steam a abrir flutuante
hl.window_rule({
	name = "steam-float",
	match = { class = "^steam$" },
	float = true,
})

-- Jogos da Steam/Proton sem V-Sync do compositor (tearing = menos input lag)
hl.window_rule({
	name = "steam-games-tearing",
	match = { class = "^steam_app_.*" },
	immediate = true,
})

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Definir o Desktop para os Portals funcionarem corretamente
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Prefixo do menu XDG para corrigir associações de arquivos no Dolphin
hl.env("XDG_MENU_PREFIX", "arch-")

-- Forçar Firefox a usar Wayland
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- Configurações GTK (Descomente e coloque o nome exato do seu tema escuro)
hl.env("GTK_THEME", "Adwaita:dark") -- Exemplo: forçando a variante dark do Adwaita
hl.env("GTK_APPLICATION_PREFER_DARK_THEME", "1")

-- Remova o hl.env("QT_QPA_PLATFORMTHEME", "qt5ct") e substitua por:
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
