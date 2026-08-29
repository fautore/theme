package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

Theme :: struct {
	id:                   string,
	display_name:         string,
	nvim_colorscheme:     string,
	nvim_flavour:         string,
	nvim_contrast:        string,
	kde_id:               string,
	kde_accent:           string,
	background_alt:       string,
	background_hard:      string,
	foreground_inactive:  string,
	foreground:           string,
	background:           string,
	selection_foreground: string,
	selection_background: string,
	colors:               [16]string,
}

config_home :: proc() -> string {
	if xdg := os.get_env("XDG_CONFIG_HOME", context.temp_allocator); xdg != "" {
		return xdg
	}
	home := os.get_env("HOME", context.temp_allocator)
	if home == "" {
		return ""
	}
	return fmt.aprintf("%s/.config", home, allocator = context.temp_allocator)
}

theme_root :: proc() -> string {
	return fmt.aprintf("%s/theme", config_home(), allocator = context.temp_allocator)
}

valid_id :: proc(id: string) -> bool {
	if id == "" {
		return false
	}
	for c in id {
		if !(c >= 'a' && c <= 'z') && !(c >= '0' && c <= '9') && c != '-' && c != '_' {
			return false
		}
	}
	return true
}

normalize_id :: proc(id: string) -> string {
	if id == "catpuccin" {
		return "catppuccin"
	}
	return id
}

require_version_directive :: proc(source, path: string) -> bool {
	contents := source
	for raw_line in strings.split_lines_iterator(&contents) {
		line := strings.trim_space(raw_line)
		if line == "" {
			continue
		}
		fields := strings.fields(line)
		if len(fields) == 2 && fields[0] == "version" && fields[1] == "1" {
			return true
		}
		fmt.eprintf("%s must start with: version 1\n", path)
		return false
	}
	fmt.eprintf("%s must start with: version 1\n", path)
	return false
}

selected_theme_path :: proc() -> (string, bool) {
	path := fmt.aprintf("%s/theme.conf", theme_root(), allocator = context.temp_allocator)
	data, err := os.read_entire_file(path, context.allocator)
	if err != nil {
		fmt.eprintf("Could not read %s: %v\n", path, err)
		return "", false
	}
	source := string(data)
	if !require_version_directive(source, path) {
		return "", false
	}
	for raw_line in strings.split_lines_iterator(&source) {
		line := strings.trim_space(raw_line)
		if line == "" || line[0] == '#' {
			continue
		}
		fields := strings.fields(line)
		if len(fields) == 2 &&
		   fields[0] == "include" &&
		   strings.has_prefix(fields[1], "themes/") &&
		   strings.has_suffix(fields[1], ".conf") {
			if strings.contains(fields[1], "..") {
				break
			}
			return fmt.aprintf(
					"%s/%s",
					theme_root(),
					fields[1],
					allocator = context.temp_allocator,
				),
				true
		}
	}
	fmt.eprintf("%s must contain: include themes/<name>.conf\n", path)
	return "", false
}

set_metadata :: proc(theme: ^Theme, key, value: string) {
	switch key {
	case "id":
		theme.id = value
	case "display_name":
		theme.display_name = value
	case "nvim_colorscheme":
		theme.nvim_colorscheme = value
	case "nvim_flavour":
		theme.nvim_flavour = value
	case "nvim_contrast":
		theme.nvim_contrast = value
	case "kde_id":
		theme.kde_id = value
	case "kde_accent":
		theme.kde_accent = value
	case "background_alt":
		theme.background_alt = value
	case "background_hard":
		theme.background_hard = value
	case "foreground_inactive":
		theme.foreground_inactive = value
	}
}

set_palette :: proc(theme: ^Theme, key, value: string) {
	switch key {
	case "foreground":
		theme.foreground = value
	case "background":
		theme.background = value
	case "selection_foreground":
		theme.selection_foreground = value
	case "selection_background":
		theme.selection_background = value
	case:
		if strings.has_prefix(key, "color") {
			index, ok := strconv.parse_int(strings.trim_prefix(key, "color"), 10)
			if ok && index >= 0 && index < len(theme.colors) {
				theme.colors[index] = value
			}
		}
	}
}

valid_hex_color :: proc(value: string) -> bool {
	if len(value) != 7 || value[0] != '#' {
		return false
	}
	_, ok := strconv.parse_uint(value[1:], 16)
	return ok
}

load_theme :: proc(path: string) -> (Theme, bool) {
	theme: Theme
	data, err := os.read_entire_file(path, context.allocator)
	if err != nil {
		fmt.eprintf("Could not read %s: %v\n", path, err)
		return theme, false
	}
	source := string(data)
	if !require_version_directive(source, path) {
		return theme, false
	}
	for raw_line in strings.split_lines_iterator(&source) {
		line := strings.trim_space(raw_line)
		if line == "" {
			continue
		}
		fields := strings.fields(line)
		if fields[0] == "version" {
			continue
		}
		if strings.has_prefix(line, "#@") {
			metadata := strings.trim_space(line[2:])
			metadata_fields := strings.fields(metadata)
			if len(metadata_fields) >= 2 {
				value := strings.trim_space(metadata[len(metadata_fields[0]):])
				set_metadata(&theme, metadata_fields[0], value)
			}
			continue
		}
		if line[0] == '#' || len(fields) < 2 {
			continue
		}
		set_palette(&theme, fields[0], fields[1])
	}

	if !valid_id(theme.id) ||
	   theme.display_name == "" ||
	   theme.nvim_colorscheme == "" ||
	   theme.kde_id == "" ||
	   !valid_hex_color(theme.kde_accent) ||
	   !valid_hex_color(theme.background_alt) ||
	   !valid_hex_color(theme.background_hard) ||
	   !valid_hex_color(theme.foreground_inactive) ||
	   !valid_hex_color(theme.foreground) ||
	   !valid_hex_color(theme.background) ||
	   !valid_hex_color(theme.selection_foreground) ||
	   !valid_hex_color(theme.selection_background) {
		fmt.eprintf("Theme %s is missing required metadata or palette values.\n", path)
		return theme, false
	}
	for color in theme.colors {
		if !valid_hex_color(color) {
			fmt.eprintf("Theme %s must define color0 through color15.\n", path)
			return theme, false
		}
	}
	return theme, true
}

current_theme :: proc() -> (Theme, bool) {
	path, ok := selected_theme_path()
	if !ok {
		return {}, false
	}
	return load_theme(path)
}

hex_to_rgb :: proc(value: string) -> string {
	number, ok := strconv.parse_uint(value[1:], 16)
	if !ok {
		return "0,0,0"
	}
	r := (number >> 16) & 0xff
	g := (number >> 8) & 0xff
	b := number & 0xff
	return fmt.aprintf("%d,%d,%d", r, g, b, allocator = context.temp_allocator)
}

render_tmux :: proc(theme: Theme) {
	fmt.printf("set -g status-style 'fg=%s,bg=%s'\n", theme.foreground, theme.background)
	fmt.printf("set -g message-style 'fg=%s,bg=%s'\n", theme.background, theme.colors[3])
	fmt.printf("set -g message-command-style 'fg=%s,bg=%s'\n", theme.background, theme.colors[3])
	fmt.printf("set -g mode-style 'fg=%s,bg=%s'\n", theme.background, theme.colors[3])
	fmt.printf("set -g pane-border-style 'fg=%s'\n", theme.colors[8])
	fmt.printf("set -g pane-active-border-style 'fg=%s'\n", theme.colors[2])
	fmt.printf(
		"set -g window-status-format '#[fg=%s,bg=%s] #I:#W '\n",
		theme.colors[8],
		theme.background,
	)
	fmt.printf(
		"set -g window-status-current-format '#[fg=%s,bg=%s,bold] #I:#W '\n",
		theme.background,
		theme.colors[3],
	)
	fmt.printf(
		"set -g window-status-bell-style 'fg=%s,bg=%s,bold'\n",
		theme.colors[1],
		theme.background,
	)
	fmt.printf(
		"set -g status-left '#[fg=%s,bg=%s,bold] #S #[fg=%s,bg=%s,nobold]'\n",
		theme.background,
		theme.colors[2],
		theme.colors[2],
		theme.background,
	)
	fmt.printf(
		"set -g status-right '#[fg=%s,bg=%s]#[fg=%s,bg=%s] #{pane_current_path} '\n",
		theme.colors[5],
		theme.background,
		theme.background,
		theme.colors[5],
	)
}

write_color_group :: proc(
	builder: ^strings.Builder,
	name,
	background,
	alternate,
	foreground,
	inactive,
	focus,
	hover,
	red,
	orange,
	green,
	link,
	visited: string,
) {
	fmt.sbprintf(builder, "[Colors:%s]\n", name)
	fmt.sbprintf(builder, "BackgroundAlternate=%s\nBackgroundNormal=%s\n", alternate, background)
	fmt.sbprintf(builder, "DecorationFocus=%s\nDecorationHover=%s\n", focus, hover)
	fmt.sbprintf(builder, "ForegroundActive=%s\nForegroundInactive=%s\n", hover, inactive)
	fmt.sbprintf(builder, "ForegroundLink=%s\nForegroundNegative=%s\n", link, red)
	fmt.sbprintf(builder, "ForegroundNeutral=%s\nForegroundNormal=%s\n", orange, foreground)
	fmt.sbprintf(builder, "ForegroundPositive=%s\nForegroundVisited=%s\n\n", green, visited)
}

render_kde_colors :: proc(theme: Theme) -> string {
	bg := hex_to_rgb(theme.background)
	bg_alt := hex_to_rgb(theme.background_alt)
	bg_hard := hex_to_rgb(theme.background_hard)
	fg := hex_to_rgb(theme.foreground)
	inactive := hex_to_rgb(theme.foreground_inactive)
	accent := hex_to_rgb(theme.kde_accent)
	hover := hex_to_rgb(theme.colors[11])
	red := hex_to_rgb(theme.colors[9])
	orange := hex_to_rgb(theme.selection_background)
	green := hex_to_rgb(theme.colors[10])
	link := hex_to_rgb(theme.colors[12])
	visited := hex_to_rgb(theme.colors[13])
	selection_fg := hex_to_rgb(theme.selection_foreground)

	builder: strings.Builder
	fmt.sbprintf(
		&builder,
		"[ColorEffects:Disabled]\nColor=%s\nColorAmount=0\nColorEffect=0\nContrastAmount=0.65\nContrastEffect=1\nIntensityAmount=0.1\nIntensityEffect=2\n\n",
		bg_alt,
	)
	fmt.sbprintf(
		&builder,
		"[ColorEffects:Inactive]\nChangeSelectionColor=false\nColor=%s\nColorAmount=0.025\nColorEffect=2\nContrastAmount=0.1\nContrastEffect=2\nEnable=false\nIntensityAmount=0\nIntensityEffect=0\n\n",
		inactive,
	)
	write_color_group(
		&builder,
		"Button",
		bg_alt,
		bg,
		fg,
		inactive,
		accent,
		hover,
		red,
		orange,
		green,
		link,
		visited,
	)
	write_color_group(
		&builder,
		"Complementary",
		bg_hard,
		bg,
		fg,
		inactive,
		accent,
		hover,
		red,
		orange,
		green,
		link,
		visited,
	)
	write_color_group(
		&builder,
		"Header",
		bg_alt,
		bg,
		fg,
		inactive,
		accent,
		hover,
		red,
		orange,
		green,
		link,
		visited,
	)
	write_color_group(
		&builder,
		"Tooltip",
		bg_hard,
		bg,
		fg,
		inactive,
		accent,
		hover,
		red,
		orange,
		green,
		link,
		visited,
	)
	write_color_group(
		&builder,
		"View",
		bg,
		bg_alt,
		fg,
		inactive,
		accent,
		hover,
		red,
		orange,
		green,
		link,
		visited,
	)
	write_color_group(
		&builder,
		"Window",
		bg,
		bg_alt,
		fg,
		inactive,
		accent,
		hover,
		red,
		orange,
		green,
		link,
		visited,
	)
	write_color_group(
		&builder,
		"Selection",
		orange,
		accent,
		selection_fg,
		inactive,
		accent,
		hover,
		red,
		orange,
		green,
		link,
		visited,
	)
	fmt.sbprintf(
		&builder,
		"[General]\nColorScheme=%s\nName=%s\nTitlebarIsAccentColored=false\nshadeSortColumn=true\n\n",
		theme.kde_id,
		theme.display_name,
	)
	fmt.sbprintf(&builder, "[KDE]\ncontrast=4\n\n")
	fmt.sbprintf(
		&builder,
		"[WM]\nactiveBackground=%s\nactiveBlend=%s\nactiveForeground=%s\ninactiveBackground=%s\ninactiveBlend=%s\ninactiveForeground=%s\n",
		bg_alt,
		fg,
		fg,
		bg,
		bg_alt,
		inactive,
	)
	return strings.to_string(builder)
}

run_process :: proc(command: []string, quiet := false) -> bool {
	// A nil environment inherits the CLI's environment, including the UTF-8
	// locale established in main.
	desc := os.Process_Desc {
		command = command,
	}
	if !quiet {
		desc.stdin = os.stdin
		desc.stdout = os.stdout
		desc.stderr = os.stderr
	}
	process, err := os.process_start(desc)
	if err != nil {
		return false
	}
	state, wait_err := os.process_wait(process)
	return wait_err == nil && state.exited && state.exit_code == 0
}

apply_kde :: proc(theme: Theme) -> bool {
	home := os.get_env("HOME", context.temp_allocator)
	if home == "" {
		fmt.eprintln("HOME is not set; cannot install KDE theme files.")
		return false
	}
	color_dir := fmt.aprintf(
		"%s/.local/share/color-schemes",
		home,
		allocator = context.temp_allocator,
	)
	desktop_dir := fmt.aprintf(
		"%s/.local/share/plasma/desktoptheme/%s",
		home,
		theme.kde_id,
		allocator = context.temp_allocator,
	)
	// make_directory_all reports Exist on this Odin version for an existing
	// directory; the following writes provide the useful error if it is unusable.
	_ = os.make_directory_all(color_dir)
	_ = os.make_directory_all(desktop_dir)

	colors := render_kde_colors(theme)
	defer delete(colors)
	color_path := fmt.aprintf(
		"%s/%s.colors",
		color_dir,
		theme.kde_id,
		allocator = context.temp_allocator,
	)
	desktop_colors_path := fmt.aprintf(
		"%s/colors",
		desktop_dir,
		allocator = context.temp_allocator,
	)
	if err := os.write_entire_file(color_path, colors); err != nil {
		fmt.eprintf("Could not write %s: %v\n", color_path, err)
		return false
	}
	if err := os.write_entire_file(desktop_colors_path, colors); err != nil {
		fmt.eprintf("Could not write %s: %v\n", desktop_colors_path, err)
		return false
	}
	// Odin's formatter treats a literal opening brace as Python-style format
	// syntax, so emit JSON opening braces through %c placeholders.
	metadata := fmt.aprintf(
		`%c
  "KPlugin": %c
    "Authors": [%c"Name": "theme CLI"}],
    "Description": "Shared %s palette with system Plasma assets",
    "EnabledByDefault": false,
    "Id": "%s",
    "License": "MIT",
    "Name": "%s",
    "Version": "1.0"
  }
}
`,
		'{',
		'{',
		'{',
		theme.display_name,
		theme.kde_id,
		theme.display_name,
	)
	defer delete(metadata)
	metadata_path := fmt.aprintf(
		"%s/metadata.json",
		desktop_dir,
		allocator = context.temp_allocator,
	)
	if err := os.write_entire_file(metadata_path, metadata); err != nil {
		fmt.eprintf("Could not write %s: %v\n", metadata_path, err)
		return false
	}

	colors_ok := run_process({"plasma-apply-colorscheme", theme.kde_id}, quiet = false)
	_ = run_process(
		{"plasma-apply-colorscheme", "--accent-color", theme.kde_accent},
		quiet = false,
	)
	desktop_ok := run_process({"plasma-apply-desktoptheme", theme.kde_id}, quiet = false)
	return colors_ok && desktop_ok
}

/*
Firefox support writes `theme.userChrome.css` into each Firefox profile and adds an import to `userChrome.css`.
Chrome support writes an unpacked theme to `~/.config/theme/chrome-theme`; load that directory as an unpacked theme in Chrome if it is not already active.
*/
apply_browsers :: proc(theme: Theme) -> bool {
	home := os.get_env("HOME", context.temp_allocator)
	if home == "" {
		fmt.eprintln("HOME is not set; cannot install browser theme files.")
		return false
	}
	script := `
set -eu
home=$1
theme_root=$2
display_name=$3
fg=$4
bg=$5
accent=$6
bg_alt=$7
bg_hard=$8
inactive=$9
red=${10}
fg_rgb=${11}
bg_rgb=${12}
accent_rgb=${13}
bg_alt_rgb=${14}
bg_hard_rgb=${15}
inactive_rgb=${16}
red_rgb=${17}

firefox_root="$home/.mozilla/firefox"
if [ -f "$firefox_root/profiles.ini" ]; then
  awk -F= '$1 == "Path" { print $2 }' "$firefox_root/profiles.ini" | while IFS= read -r profile_path; do
    case "$profile_path" in
      /*) profile="$profile_path" ;;
      *) profile="$firefox_root/$profile_path" ;;
    esac
    [ -d "$profile" ] || continue
    mkdir -p "$profile/chrome"
    cat > "$profile/chrome/theme.userChrome.css" <<EOF
/* Generated by theme CLI. */
:root {
  color-scheme: dark !important;
  --theme-cli-foreground: $fg !important;
  --theme-cli-background: $bg !important;
  --theme-cli-background-alt: $bg_alt !important;
  --theme-cli-background-hard: $bg_hard !important;
  --theme-cli-accent: $accent !important;
  --theme-cli-inactive: $inactive !important;
  --lwt-accent-color: $bg_hard !important;
  --lwt-text-color: $fg !important;
  --lwt-selected-tab-background-color: $bg !important;
  --toolbar-bgcolor: $bg_hard !important;
  --toolbar-color: $fg !important;
  --toolbar-field-background-color: $bg_alt !important;
  --toolbar-field-color: $fg !important;
  --toolbar-field-focus-background-color: $bg_alt !important;
  --toolbar-field-focus-color: $fg !important;
  --urlbar-box-bgcolor: $bg_alt !important;
  --urlbar-box-text-color: $fg !important;
  --focus-outline-color: $accent !important;
  --tabs-border-color: $accent !important;
  --chrome-content-separator-color: $bg_hard !important;
}

#navigator-toolbox,
#TabsToolbar,
#PersonalToolbar,
toolbar,
#sidebar-box,
#sidebar-main,
#sidebar-header {
  background-color: $bg_hard !important;
  color: $fg !important;
}

#urlbar-background,
.searchbar-textbox {
  background-color: $bg_alt !important;
  color: $fg !important;
  border-color: $accent !important;
}

.tabbrowser-tab[selected] .tab-background {
  background-color: $bg !important;
}

.tabbrowser-tab:not([selected]) .tab-background {
  background-color: $bg_hard !important;
}
EOF
    cat > "$profile/chrome/theme.userContent.css" <<EOF
/* Generated by theme CLI. */
@-moz-document url("about:home"), url("about:newtab"), url("about:privatebrowsing") {
  :root,
  body,
  .outer-wrapper,
  main,
  .activity-stream,
  .top-site-outer,
  .ds-outer-wrapper-search-alignment,
  .search-wrapper,
  .search-inner-wrapper {
    --newtab-background-color: $bg !important;
    --newtab-background-color-secondary: $bg_alt !important;
    --newtab-text-primary-color: $fg !important;
    --newtab-text-secondary-color: $inactive !important;
    --newtab-primary-action-background: $accent !important;
    --newtab-primary-element-text-color: $bg !important;
    background-color: $bg !important;
    color: $fg !important;
  }

  .search-handoff-button,
  input,
  button,
  .tile,
  .card-outer {
    background-color: $bg_alt !important;
    color: $fg !important;
    border-color: $accent !important;
  }

  .logo-and-wordmark .wordmark {
    fill: $fg !important;
  }
}
EOF
    user_chrome="$profile/chrome/userChrome.css"
    touch "$user_chrome"
    if ! grep -qxF '@import url("theme.userChrome.css");' "$user_chrome"; then
      tmp="$user_chrome.tmp"
      printf '@import url("theme.userChrome.css");\n' > "$tmp"
      cat "$user_chrome" >> "$tmp"
      mv "$tmp" "$user_chrome"
    fi
    user_content="$profile/chrome/userContent.css"
    touch "$user_content"
    if ! grep -qxF '@import url("theme.userContent.css");' "$user_content"; then
      tmp="$user_content.tmp"
      printf '@import url("theme.userContent.css");\n' > "$tmp"
      cat "$user_content" >> "$tmp"
      mv "$tmp" "$user_content"
    fi
    user_js="$profile/user.js"
    touch "$user_js"
    tmp="$user_js.tmp"
    grep -Ev 'toolkit.legacyUserProfileCustomizations.stylesheets|browser.theme.content-theme|browser.theme.toolbar-theme' "$user_js" > "$tmp" || true
    printf 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);\n' >> "$tmp"
    printf 'user_pref("browser.theme.content-theme", 2);\n' >> "$tmp"
    printf 'user_pref("browser.theme.toolbar-theme", 2);\n' >> "$tmp"
    mv "$tmp" "$user_js"
  done
fi

chrome_theme_dir="$theme_root/chrome-theme"
mkdir -p "$chrome_theme_dir"
cat > "$chrome_theme_dir/manifest.json" <<EOF
{
  "manifest_version": 2,
  "version": "1.0",
  "name": "$display_name (theme CLI)",
  "theme": {
    "colors": {
      "frame": [$bg_hard_rgb],
      "frame_inactive": [$bg_rgb],
      "toolbar": [$bg_rgb],
      "tab_text": [$fg_rgb],
      "tab_background_text": [$inactive_rgb],
      "bookmark_text": [$fg_rgb],
      "ntp_background": [$bg_rgb],
      "ntp_text": [$fg_rgb],
      "button_background": [$bg_alt_rgb],
      "omnibox_background": [$bg_alt_rgb],
      "omnibox_text": [$fg_rgb],
      "omnibox_selected_background": [$accent_rgb],
      "omnibox_selected_text": [$bg_rgb]
    },
    "tints": {
      "buttons": [0.0, 0.0, 0.9]
    }
  }
}
EOF
`
	return run_process(
		{
			"sh",
			"-c",
			script,
			"theme-browsers",
			home,
			theme_root(),
			theme.display_name,
			theme.foreground,
			theme.background,
			theme.kde_accent,
			theme.background_alt,
			theme.background_hard,
			theme.foreground_inactive,
			theme.colors[9],
			hex_to_rgb(theme.foreground),
			hex_to_rgb(theme.background),
			hex_to_rgb(theme.kde_accent),
			hex_to_rgb(theme.background_alt),
			hex_to_rgb(theme.background_hard),
			hex_to_rgb(theme.foreground_inactive),
			hex_to_rgb(theme.colors[9]),
		},
		quiet = true,
	)
}

reload_apps :: proc() {
	config := config_home()
	_ = run_process({"pkill", "-USR1", "-x", "kitty"}, quiet = true)
	_ = run_process(
		{
			"tmux",
			"source-file",
			fmt.aprintf("%s/tmux/tmux.conf", config, allocator = context.temp_allocator),
		},
		quiet = true,
	)
}

apply_current :: proc() -> bool {
	theme, ok := current_theme()
	if !ok {
		return false
	}
	kde_ok := apply_kde(theme)
	browsers_ok := apply_browsers(theme)
	reload_apps()
	fmt.printf(
		"Applied %s. Restart existing Neovim, Firefox, and Chrome instances to update them.\n",
		theme.display_name,
	)
	return kde_ok && browsers_ok
}

set_theme :: proc(raw_id: string) -> bool {
	id := normalize_id(raw_id)
	if !valid_id(id) {
		fmt.eprintf("Invalid theme name: %s\n", raw_id)
		return false
	}
	path := fmt.aprintf("%s/themes/%s.conf", theme_root(), id, allocator = context.temp_allocator)
	theme, ok := load_theme(path)
	if !ok {
		return false
	}
	if theme.id != id {
		fmt.eprintf("Theme ID %s does not match filename %s.\n", theme.id, id)
		return false
	}
	pointer := fmt.aprintf(
		"version 1\n# Shared theme pointer. Managed by the theme CLI.\ninclude themes/%s.conf\n",
		id,
	)
	defer delete(pointer)
	conf := fmt.aprintf("%s/theme.conf", theme_root(), allocator = context.temp_allocator)
	temporary := fmt.aprintf("%s.tmp", conf, allocator = context.temp_allocator)
	if err := os.write_entire_file(temporary, pointer); err != nil {
		fmt.eprintf("Could not write %s: %v\n", temporary, err)
		return false
	}
	if err := os.rename(temporary, conf); err != nil {
		fmt.eprintf("Could not replace %s: %v\n", conf, err)
		return false
	}
	return apply_current()
}

list_themes :: proc() {
	theme_ids := [?]string{"gruvbox", "catppuccin"}
	for id in theme_ids {
		path := fmt.aprintf(
			"%s/themes/%s.conf",
			theme_root(),
			id,
			allocator = context.temp_allocator,
		)
		if theme, ok := load_theme(path); ok {
			fmt.printf("%s\t%s\n", id, theme.display_name)
		}
	}
}

print_help :: proc() {
	fmt.println("Usage:")
	fmt.println("  theme list")
	fmt.println("  theme current")
	fmt.println("  theme set <gruvbox|catppuccin>")
	fmt.println("  theme apply")
	fmt.println("  theme render tmux")
}

main :: proc() {
	// KDE's Qt tools require UTF-8. Force a portable UTF-8 locale for child
	// processes even when the interactive locale references missing locales.
	_ = os.set_env("LC_ALL", "C.UTF-8")

	if config_home() == "" {
		fmt.eprintln("Could not determine the configuration directory.")
		os.exit(1)
	}
	if len(os.args) < 2 || os.args[1] == "help" || os.args[1] == "--help" || os.args[1] == "-h" {
		print_help()
		return
	}

	switch os.args[1] {
	case "list":
		list_themes()
	case "current":
		if theme, ok := current_theme(); ok {
			fmt.println(theme.id)
		} else {
			os.exit(1)
		}
	case "set":
		if len(os.args) != 3 {
			fmt.eprintln("theme set requires a theme name.")
			os.exit(2)
		}
		if !set_theme(os.args[2]) {
			os.exit(1)
		}
	case "apply":
		if !apply_current() {
			os.exit(1)
		}
	case "render":
		if len(os.args) != 3 || os.args[2] != "tmux" {
			fmt.eprintln("Only 'theme render tmux' is supported.")
			os.exit(2)
		}
		if theme, ok := current_theme(); ok {
			render_tmux(theme)
		} else {
			os.exit(1)
		}
	case:
		fmt.eprintf("Unknown command: %s\n", os.args[1])
		print_help()
		os.exit(2)
	}
}
