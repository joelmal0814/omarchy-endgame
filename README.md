# omarchy-endgame

**Endgame** — an Omarchy theme: ancient chess strategy reconstructed inside a
modern terminal. Built for Omarchy 4.0.2.

- `theme/` — the theme itself. Linked to `~/.config/omarchy/themes/endgame`.
  Its [README](theme/README.md) documents the palette, wallpapers, lock
  screen, prompt badge, external config edits and limitations.
- `plugins/` — three Omarchy shell plugins (`jim.lock`, `jim.workspaces`,
  `jim.brand`) that render the chess identity from the theme's `[branding]`
  section. Linked into `~/.config/omarchy/plugins/`.
- `hooks/theme-menu` — Omarchy `theme-set` hook that applies a theme's
  `menu.jsonc` to the launcher and removes it when another theme is set.
  Linked into `~/.config/omarchy/hooks/theme-set.d/`.
- `img/` — the original generated wallpaper sources, untouched.
- `install.sh` — creates the symlinks on a fresh machine.

The theme is linked, not copied, so edits here are live: Omarchy re-reads the
theme on `omarchy theme set endgame`, and plugin edits hot-reload (run
`omarchy-shell shell rescanPlugins` if a change through the symlink is missed).
