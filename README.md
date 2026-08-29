# theme CLI

Small Odin CLI that manages the shared configuration in
`~/.config/theme/theme.conf` and applies it to KDE/Qt, Kitty, tmux, and Neovim.

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
```

## Palette reference

The CLI reads the selected palette from `$XDG_CONFIG_HOME/theme/theme.conf`, or
`~/.config/theme/theme.conf` when `XDG_CONFIG_HOME` is unset. That file must
include one theme file:

```conf
# Shared theme pointer. Managed by the theme CLI.
include themes/gruvbox.conf
```

Theme files live under `~/.config/theme/themes/<id>.conf`. A theme file contains
metadata comments beginning with `#@`, followed by palette keys:

```conf
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

Optional metadata keys currently parsed for external config consumers:

- `nvim_flavour`
- `nvim_contrast`

Required palette keys:

- `foreground`
- `background`
- `selection_foreground`
- `selection_background`
- `color0` through `color15`, using the standard 16 terminal color slots

All color values must use `#rrggbb` hex format.
