# theme CLI

Small Odin CLI that manages the shared configuration in
`~/.config/theme/theme.conf` and applies it to KDE/Qt, Kitty, tmux, and Neovim.

Build and install:

```sh
odin build . -out:$HOME/.local/bin/theme
```

Usage:

```sh
theme list
theme current
theme set gruvbox
theme set catppuccin
theme apply
```

The shared palette format is documented in `~/.config/theme/README.md`.
