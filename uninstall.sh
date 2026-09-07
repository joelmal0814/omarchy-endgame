#!/bin/bash
# Remove the Endgame theme from Omarchy, restoring the stock lock screen,
# workspace numbers, menu button, launcher headers and prompt.
# Usage: ./uninstall.sh [theme-to-switch-to]   (default: tokyo-night)
# The repository itself is left untouched.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
config="$HOME/.config/omarchy"
next_theme=${1:-tokyo-night}

say() { printf '%s\n' "$*"; }
unlink_if_ours() {
  local dst="$1" src="$2"
  if [[ -L $dst && $(readlink -f "$dst") == "$src" ]]; then rm -f "$dst"; say "unlinked $dst"; fi
}

# 1. Leave the theme first; the theme-set hook removes the launcher block.
if [[ $(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null) == "endgame" ]]; then
  omarchy theme set "$next_theme"
fi

# 2. Launcher block (belt and braces, then drop the hook).
if [[ -x $repo/hooks/theme-menu && ! -f $HOME/.local/state/omarchy/current/theme/menu.jsonc ]]; then
  bash "$repo/hooks/theme-menu" "$next_theme"
fi
unlink_if_ours "$config/hooks/theme-set.d/theme-menu" "$repo/hooks/theme-menu"

# 3. Plugins. Removing an enabled clone switches Omarchy back to the built-in.
if omarchy-shell shell ping >/dev/null 2>&1; then
  if [[ -f $config/shell.json ]] && jq -e '.bar.layout.left | any(.[]; .id == "jim.brand")' "$config/shell.json" >/dev/null; then
    tmp=$(mktemp)
    jq '.bar.layout.left |= map(if .id == "jim.brand" then {"id":"omarchy.menu"} else . end)' "$config/shell.json" >"$tmp"
    mv "$tmp" "$config/shell.json"
    omarchy-shell shell reloadConfig >/dev/null || true
    say "restored omarchy.menu in the bar"
  fi
  for id in jim.brand jim.workspaces jim.lock; do
    [[ -L $config/plugins/$id ]] && omarchy plugin remove "$id" --yes
  done
else
  for id in jim.brand jim.workspaces jim.lock; do unlink_if_ours "$config/plugins/$id" "$repo/plugins/$id"; done
  say "omarchy-shell not running: plugin links removed, shell.json left as is"
fi

# 4. Prompt badge.
starship="$HOME/.config/starship.toml"
if [[ -f $starship ]] && grep -qF '# >>> omarchy-endgame prompt badge' "$starship"; then
  sed -i '/^# >>> omarchy-endgame prompt badge/,/^# <<< omarchy-endgame prompt badge/d' "$starship"
  sed -i 's/\${custom\.omarchy_theme_badge}//' "$starship"
  # drop the blank line the install left before the block
  sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$starship"
  say "removed prompt badge from $starship"
fi

# 5. Theme link.
unlink_if_ours "$config/themes/endgame" "$repo/theme"
say "Endgame removed. Re-install any time with $repo/install.sh"
