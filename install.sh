#!/bin/bash
# Install the Endgame theme into Omarchy (4.0.x). Idempotent; safe to re-run.
#
#   theme/    -> ~/.config/omarchy/themes/endgame           (symlink)
#   plugins/  -> ~/.config/omarchy/plugins/jim.*            (symlinks)
#   hooks/    -> ~/.config/omarchy/hooks/theme-set.d/       (symlink)
#   shell.json: enables the plugins, swaps the bar's omarchy.menu button for jim.brand
#   starship.toml: adds the theme prompt badge module (between marker comments)
#   then: omarchy theme set endgame
#
# Omarchy treats a symlinked user theme as your own working copy, so nothing
# in it is restricted. Undo everything with ./uninstall.sh.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
config="$HOME/.config/omarchy"
omarchy_path=${OMARCHY_PATH:-/usr/share/omarchy}

say() { printf '%s\n' "$*"; }

link() {
  local src="$1" dst="$2"
  if [[ -L $dst && $(readlink -f "$dst") == "$src" ]]; then return; fi
  if [[ -e $dst || -L $dst ]]; then
    say "refusing to replace existing $dst (move it away first)" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  say "linked $dst"
}

# --- 1. files -----------------------------------------------------------------
link "$repo/theme" "$config/themes/endgame"
for plugin in "$repo"/plugins/*/; do
  plugin=${plugin%/}
  link "$plugin" "$config/plugins/$(basename "$plugin")"
done
link "$repo/hooks/theme-menu" "$config/hooks/theme-set.d/theme-menu"

# --- 2. shell plugins ----------------------------------------------------------
if ! omarchy-shell shell ping >/dev/null 2>&1; then
  say "omarchy-shell is not running; log in to a desktop session and re-run." >&2
  exit 1
fi

if [[ ! -f $config/shell.json ]]; then
  cp "$omarchy_path/config/omarchy/shell.json" "$config/shell.json"
  say "created $config/shell.json from Omarchy defaults"
fi

omarchy-shell shell rescanPlugins >/dev/null
sleep 0.5
plugins_json=$(omarchy-shell shell listPlugins)
enabled() { jq -e --arg id "$1" 'any(.[]; .id == $id and .enabled == true)' <<<"$plugins_json" >/dev/null; }

# Clones of built-ins: enabling them replaces the built-in automatically.
for id in jim.lock jim.workspaces; do
  if ! enabled "$id"; then
    omarchy plugin enable "$id" >/dev/null
    say "enabled $id"
  fi
done

# jim.brand replaces the omarchy.menu bar button (not a clone, so swap by hand).
if ! enabled jim.brand; then
  tmp=$(mktemp)
  if jq -e '.bar.layout.left | any(.[]; .id == "omarchy.menu")' "$config/shell.json" >/dev/null; then
    jq '.bar.layout.left |= map(if .id == "omarchy.menu" then {"id":"jim.brand"} else . end)' "$config/shell.json" >"$tmp"
  else
    jq '.bar.layout.left |= ([{"id":"jim.brand"}] + (. // []))' "$config/shell.json" >"$tmp"
  fi
  mv "$tmp" "$config/shell.json"
  omarchy-shell shell reloadConfig >/dev/null || true
  say "placed jim.brand in the bar"
fi

# --- 3. starship prompt badge --------------------------------------------------
starship="$HOME/.config/starship.toml"
marker='# >>> omarchy-endgame prompt badge'
if [[ -f $starship ]] && ! grep -qF "$marker" "$starship"; then
  cat >>"$starship" <<'TOML'

# >>> omarchy-endgame prompt badge (managed by omarchy-endgame install.sh / uninstall.sh)
# Shows the active theme's prompt.txt (Endgame: a knight); hidden for themes without one.
[custom.omarchy_theme_badge]
command = "cat ~/.local/state/omarchy/current/theme/prompt.txt 2>/dev/null"
when = "test -s ~/.local/state/omarchy/current/theme/prompt.txt"
format = "[$output ]($style)"
style = "bold green"
# <<< omarchy-endgame prompt badge
TOML
  if grep -qE '^format = "' "$starship" && ! grep -qF '${custom.omarchy_theme_badge}' "$starship"; then
    sed -i '0,/^format = "/s//format = "${custom.omarchy_theme_badge}/' "$starship"
    say "added prompt badge to $starship"
  else
    say "note: add \${custom.omarchy_theme_badge} to your starship format to show the prompt badge"
  fi
elif [[ ! -f $starship ]]; then
  say "note: no ~/.config/starship.toml; prompt badge skipped"
fi

# --- 4. apply ------------------------------------------------------------------
omarchy theme set endgame
say "Endgame installed. Switch themes freely; every Endgame element falls back to stock on other themes."
