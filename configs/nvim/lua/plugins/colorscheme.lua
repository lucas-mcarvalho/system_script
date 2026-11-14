-- Gruvbox com fundo transparente: deixa aparecer o fundo do kitty
-- (background_opacity), que o Hyprland desfoca.
return {
  {
    "ellisonleao/gruvbox.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      transparent_mode = true,
    },
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "gruvbox" },
  },
}
