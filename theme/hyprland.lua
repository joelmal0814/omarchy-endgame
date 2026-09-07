-- Endgame window styling. Loaded after Omarchy's defaults and the user's
-- ~/.config/hypr/looknfeel.lua, so these values win while the theme is active.
local active_border_color = { colors = { "rgba(829b7bee)", "rgba(b5a06cee)" }, angle = 45 }
local inactive_border_color = "rgba(202820aa)"

hl.config({
  general = {
    gaps_in = 3,
    gaps_out = 6,
    border_size = 2,
    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },

  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },
  },

  decoration = {
    rounding = 4,
    shadow = {
      enabled = true,
      range = 10,
      render_power = 3,
      color = "rgba(00000066)",
      color_inactive = "rgba(00000033)",
    },
  },
})
