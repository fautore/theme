# theme CLI

Small Odin CLI that manages the shared configuration in
`~/.config/theme/theme.conf` and applies it to KDE/Qt, SDDM, Kitty, tmux,
Neovim, Firefox, Chrome, and Logseq.

## Installation

Build the CLI:

```sh
make build
```

Run it from the source tree:

```sh
make run ARGS="list"
```

Install it to `~/.local/bin/theme`:

```sh
make install
```

To install somewhere else, override `PREFIX`:

```sh
make install PREFIX=/usr/local
```

Usage:

```sh
theme list
theme current
theme set gruvbox
theme set catppuccin
theme apply
theme apply logseq
theme render logseq
```

SDDM support generates a login-screen theme in
`~/.config/theme/sddm-theme`, installs it to
`/usr/share/sddm/themes/theme-cli`, and selects it through
`/etc/sddm.conf.d/theme-cli.conf` when run as root or when `pkexec` is
available. The new display-manager theme appears on the next login screen.

Logseq support generates `~/.config/theme/logseq.css` (or the equivalent
`$XDG_CONFIG_HOME` path) and adds a `:custom-css-url` import to Logseq's global
`~/.logseq/config/config.edn`. This applies the palette to every graph. If that
setting already contains a user-defined value, the CLI leaves it unchanged and
prints the import path so it can be merged manually. `theme apply logseq`
applies only this integration, while `theme render logseq` prints the generated
stylesheet to standard output. Restart Logseq if a running instance does not
reload the stylesheet automatically.

## Palette reference

The CLI reads the selected palette from `$XDG_CONFIG_HOME/theme/theme.conf`, or
`~/.config/theme/theme.conf` when `XDG_CONFIG_HOME` is unset. That file must
include one theme file:

```conf
version 1
# Shared theme pointer. Managed by the theme CLI.
include themes/gruvbox.conf
```

Theme files live under `~/.config/theme/themes/<id>.conf`. Example theme files
are available in `examples/`. A theme file contains a version directive,
metadata comments beginning with `#@`, optional wallpaper directives, and
palette keys:

```conf
version 1
#@ id gruvbox
#@ display_name Gruvbox Dark
#@ nvim_colorscheme gruvbox
#@ nvim_flavour dark
#@ nvim_contrast hard
#@ kde_id GruvboxDark
#@ kde_accent #d79921
#@ background_alt #282828
#@ background_hard #1d2021
#@ foreground_inactive #928374

desktop_wallpaper ~/Pictures/wallpapers/gruvbox-desktop.png
lock_wallpaper ~/Pictures/wallpapers/gruvbox-lock.png
login_wallpaper ~/Pictures/wallpapers/gruvbox-lock.png

foreground #ebdbb2
background #282828
selection_foreground #282828
selection_background #d79921

color0 #282828
color1 #cc241d
color2 #98971a
color3 #d79921
color4 #458588
color5 #b16286
color6 #689d6a
color7 #a89984
color8 #928374
color9 #fb4934
color10 #b8bb26
color11 #fabd2f
color12 #83a598
color13 #d3869b
color14 #8ec07c
color15 #ebdbb2
```

Required metadata keys:

- `id`: lowercase theme id; must match the filename used by `theme set <id>`.
  Allowed characters are `a-z`, `0-9`, `-`, and `_`.
- `display_name`: human-readable name used in generated KDE metadata.
- `nvim_colorscheme`: Neovim colorscheme name for external config consumers.
- `kde_id`: KDE color scheme and desktop theme id.
- `kde_accent`, `background_alt`, `background_hard`, `foreground_inactive`:
  `#rrggbb` colors used by generated KDE files.

Optional metadata keys:

- `nvim_flavour`
- `nvim_contrast`

Optional directives:

- `desktop_wallpaper`: image applied to the Plasma desktop.
- `lock_wallpaper`: image applied to the Plasma lock screen.
- `login_wallpaper`: image copied into and used by the generated SDDM theme.

Wallpaper directives support absolute paths and paths beginning with `~/`.

Required palette keys:

- `foreground`
- `background`
- `selection_foreground`
- `selection_background`
- `color0` through `color15`, using the standard 16 terminal color slots

All color values must use `#rrggbb` hex format.
