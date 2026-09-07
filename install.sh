#!/bin/bash
# Link the Endgame theme and its shell plugins into Omarchy's user config.
# Idempotent. Omarchy treats a symlinked user theme as your own working copy,
# so nothing in it is restricted (unlike themes cloned with `omarchy theme install`).
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

link() {
  local src="$1" dst="$2"
  if [[ -L $dst && $(readlink -f "$dst") == "$src" ]]; then return; fi
  if [[ -e $dst || -L $dst ]]; then
    echo "refusing to replace existing $dst" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "linked $dst"
}

link "$repo/theme" "$HOME/.config/omarchy/themes/endgame"
for plugin in "$repo"/plugins/*/; do
  plugin=${plugin%/}
  link "$plugin" "$HOME/.config/omarchy/plugins/$(basename "$plugin")"
done
link "$repo/hooks/theme-menu" "$HOME/.config/omarchy/hooks/theme-set.d/theme-menu"

if omarchy-shell shell ping >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins >/dev/null || true
fi

cat <<MSG
Done. Remaining manual steps (see theme/README.md, "Files outside this directory"):
  omarchy plugin enable jim.lock jim.workspaces jim.brand   # and put jim.brand/jim.workspaces in the bar
  starship.toml badge module
  omarchy theme set endgame
MSG
