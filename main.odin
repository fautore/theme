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
	desktop_wallpaper:    string,
	lock_wallpaper:       string,
	login_wallpaper:      string,
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

set_theme_directive :: proc(theme: ^Theme, key, value: string) -> bool {
	switch key {
	case "desktop_wallpaper":
		theme.desktop_wallpaper = value
	case "lock_wallpaper":
		theme.lock_wallpaper = value
	case "login_wallpaper":
		theme.login_wallpaper = value
	case:
		return false
	}
	return true
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
		value := strings.trim_space(line[len(fields[0]):])
		if set_theme_directive(&theme, fields[0], value) {
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

file_url :: proc(path: string) -> string {
	builder: strings.Builder
	strings.write_string(&builder, "file://")
	for c in path {
		if c <= ' ' || c == '#' || c == '%' || c == '\'' || c == '"' || c == '?' {
			fmt.sbprintf(&builder, "%%%02X", c)
		} else {
			fmt.sbprintf(&builder, "%c", c)
		}
	}
	return strings.to_string(builder)
}

render_logseq :: proc(theme: Theme) -> string {
	builder: strings.Builder
	strings.write_string(
		&builder,
		`/* Generated by theme CLI. */
:root,
html[data-theme="light"],
html[data-theme="dark"],
.light-theme,
.dark-theme {
  color-scheme: dark;
`,
	)
	// Logseq 0.10 uses the newer Radix-based --lx-* scale for its shell,
	// headings, menus, and sidebars, while editor components still use --ls-*.
	gray_scale := [12]string {
		theme.background_hard,
		theme.background,
		theme.background_alt,
		theme.background_alt,
		theme.colors[0],
		theme.colors[8],
		theme.colors[8],
		theme.foreground_inactive,
		theme.foreground_inactive,
		theme.foreground_inactive,
		theme.foreground_inactive,
		theme.foreground,
	}
	accent_scale := [12]string {
		theme.background_hard,
		theme.background,
		theme.background_alt,
		theme.background_alt,
		theme.colors[8],
		theme.kde_accent,
		theme.kde_accent,
		theme.kde_accent,
		theme.kde_accent,
		theme.colors[11],
		theme.colors[11],
		theme.foreground,
	}
	alpha_suffixes := [12]string{"00", "0d", "1a", "26", "33", "40", "4d", "66", "73", "80", "a6", "e6"}
	for color, index in gray_scale {
		fmt.sbprintf(&builder, "  --lx-gray-%02d: %s !important;\n", index + 1, color)
		fmt.sbprintf(
			&builder,
			"  --lx-gray-%02d-alpha: %s%s !important;\n",
			index + 1,
			theme.foreground,
			alpha_suffixes[index],
		)
	}
	for color, index in accent_scale {
		fmt.sbprintf(&builder, "  --lx-accent-%02d: %s !important;\n", index + 1, color)
		fmt.sbprintf(
			&builder,
			"  --lx-accent-%02d-alpha: %s%s !important;\n",
			index + 1,
			theme.kde_accent,
			alpha_suffixes[index],
		)
	}
	fmt.sbprintf(&builder, "  --lx-bg-override: %s !important;\n", theme.background)
	fmt.sbprintf(&builder, "  --lx-popover-bg: %s !important;\n", theme.background_alt)
	fmt.sbprintf(&builder, "  --lx-pdf-container-dark-bg: %s !important;\n", theme.background_hard)
	fmt.sbprintf(&builder, "  --ls-primary-background-color: %s !important;\n", theme.background)
	fmt.sbprintf(&builder, "  --ls-secondary-background-color: %s !important;\n", theme.background_alt)
	fmt.sbprintf(&builder, "  --ls-tertiary-background-color: %s !important;\n", theme.background_hard)
	fmt.sbprintf(&builder, "  --ls-quaternary-background-color: %s !important;\n", theme.background_alt)
	fmt.sbprintf(&builder, "  --ls-table-tr-even-background-color: %s !important;\n", theme.background_alt)
	fmt.sbprintf(&builder, "  --ls-active-primary-color: %s !important;\n", theme.kde_accent)
	fmt.sbprintf(&builder, "  --ls-active-secondary-color: %s !important;\n", theme.colors[11])
	fmt.sbprintf(&builder, "  --ls-block-properties-background-color: %s !important;\n", theme.background_alt)
	fmt.sbprintf(&builder, "  --ls-page-properties-background-color: %s !important;\n", theme.background_alt)
	fmt.sbprintf(&builder, "  --ls-block-ref-link-text-color: %s !important;\n", theme.colors[12])
	fmt.sbprintf(&builder, "  --ls-search-background-color: %s !important;\n", theme.background_hard)
	fmt.sbprintf(&builder, "  --ls-border-color: %s !important;\n", theme.colors[8])
	fmt.sbprintf(&builder, "  --ls-secondary-border-color: %s !important;\n", theme.background_alt)
	fmt.sbprintf(&builder, "  --ls-guideline-color: %s !important;\n", theme.colors[8])
	fmt.sbprintf(&builder, "  --ls-menu-hover-color: %s !important;\n", theme.background_alt)
	fmt.sbprintf(&builder, "  --ls-primary-text-color: %s !important;\n", theme.foreground)
	fmt.sbprintf(&builder, "  --ls-secondary-text-color: %s !important;\n", theme.foreground_inactive)
	fmt.sbprintf(&builder, "  --ls-title-text-color: %s !important;\n", theme.foreground)
	fmt.sbprintf(&builder, "  --ls-link-text-color: %s !important;\n", theme.colors[12])
	fmt.sbprintf(&builder, "  --ls-link-ref-text-color: %s !important;\n", theme.colors[4])
	fmt.sbprintf(&builder, "  --ls-tag-text-color: %s !important;\n", theme.colors[6])
	fmt.sbprintf(&builder, "  --ls-tag-text-hover-color: %s !important;\n", theme.colors[14])
	fmt.sbprintf(&builder, "  --ls-slide-background-color: %s !important;\n", theme.background)
	fmt.sbprintf(&builder, "  --ls-block-bullet-border-color: %s !important;\n", theme.colors[8])
	fmt.sbprintf(&builder, "  --ls-block-bullet-color: %s !important;\n", theme.kde_accent)
	fmt.sbprintf(&builder, "  --ls-block-highlight-color: %s !important;\n", theme.background_alt)
	fmt.sbprintf(&builder, "  --ls-selection-background-color: %s !important;\n", theme.selection_background)
	fmt.sbprintf(&builder, "  --ls-page-checkbox-color: %s !important;\n", theme.colors[2])
	fmt.sbprintf(&builder, "  --ls-page-checkbox-border-color: %s !important;\n", theme.colors[2])
	fmt.sbprintf(&builder, "  --ls-page-blockquote-color: %s !important;\n", theme.foreground_inactive)
	fmt.sbprintf(&builder, "  --ls-page-blockquote-bg-color: %s !important;\n", theme.background_alt)
	fmt.sbprintf(&builder, "  --ls-page-blockquote-border-color: %s !important;\n", theme.kde_accent)
	fmt.sbprintf(&builder, "  --ls-page-mark-color: %s !important;\n", theme.selection_foreground)
	fmt.sbprintf(&builder, "  --ls-page-mark-bg-color: %s !important;\n", theme.selection_background)
	fmt.sbprintf(&builder, "  --ls-page-inline-code-color: %s !important;\n", theme.colors[11])
	fmt.sbprintf(&builder, "  --ls-page-inline-code-bg-color: %s !important;\n", theme.background_hard)
	fmt.sbprintf(&builder, "  --ls-scrollbar-foreground-color: %s !important;\n", theme.foreground_inactive)
	fmt.sbprintf(&builder, "  --ls-scrollbar-background-color: %s !important;\n", theme.background)
	fmt.sbprintf(&builder, "  --ls-cloze-text-color: %s !important;\n", theme.colors[9])
	fmt.sbprintf(&builder, "  --ls-icon-color: %s !important;\n", theme.foreground_inactive)
	fmt.sbprintf(&builder, "  --ls-search-icon-color: %s !important;\n", theme.foreground_inactive)
	fmt.sbprintf(&builder, "  --ls-a-chosen-bg: %s !important;\n", theme.background_alt)
	fmt.sbprintf(&builder, "  --ls-right-sidebar-code-bg-color: %s !important;\n", theme.background_hard)
	fmt.sbprintf(&builder, "  --ls-head-text-color: %s !important;\n", theme.foreground)
	fmt.sbprintf(&builder, "  --left-sidebar-bg-color: %s !important;\n", theme.background_hard)
	fmt.sbprintf(&builder, "  --ls-left-sidebar-text-color: %s !important;\n", theme.foreground)
	fmt.sbprintf(&builder, "  --ls-left-sidebar-border-color: %s !important;\n", theme.colors[0])
	fmt.sbprintf(
		&builder,
		"  --ls-left-sidebar-bottom-gradient: linear-gradient(to bottom, transparent, %s) !important;\n",
		theme.background_hard,
	)
	strings.write_string(
		&builder,
		`}

html,
body,
#root,
.app-container {
  background-color: var(--ls-primary-background-color) !important;
  color: var(--ls-primary-text-color) !important;
}

.cp__sidebar-left-layout,
.left-sidebar-inner,
.cp__right-sidebar,
.cp__right-sidebar .sidebar-item-list {
  background-color: var(--lx-gray-01) !important;
  color: var(--lx-gray-12) !important;
}

h1,
h2,
h3,
h4,
h5,
h6,
.page-title,
.title {
  color: var(--lx-gray-12) !important;
}
`,
	)
	return strings.to_string(builder)
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

resolve_home_path :: proc(path: string) -> string {
	if !strings.has_prefix(path, "~/") {
		return path
	}
	home := os.get_env("HOME", context.temp_allocator)
	if home == "" {
		return path
	}
	return fmt.aprintf(
		"%s/%s",
		home,
		strings.trim_prefix(path, "~/"),
		allocator = context.temp_allocator,
	)
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

apply_kde_wallpapers :: proc(theme: Theme) -> bool {
	desktop_ok := true
	desktop_wallpaper := resolve_home_path(theme.desktop_wallpaper)
	if desktop_wallpaper != "" {
		desktop_ok = run_process(
			{
				"plasma-apply-wallpaperimage",
				"--fill-mode",
				"preserveAspectCrop",
				desktop_wallpaper,
			},
			quiet = false,
		)
	}

	lock_ok := true
	lock_wallpaper := resolve_home_path(theme.lock_wallpaper)
	if lock_wallpaper != "" {
		image_ok := run_process(
			{
				"kwriteconfig6",
				"--file",
				"kscreenlockerrc",
				"--group",
				"Greeter",
				"--group",
				"Wallpaper",
				"--group",
				"org.kde.image",
				"--group",
				"General",
				"--key",
				"Image",
				lock_wallpaper,
			},
			quiet = false,
		)
		preview_ok := run_process(
			{
				"kwriteconfig6",
				"--file",
				"kscreenlockerrc",
				"--group",
				"Greeter",
				"--group",
				"Wallpaper",
				"--group",
				"org.kde.image",
				"--group",
				"General",
				"--key",
				"PreviewImage",
				lock_wallpaper,
			},
			quiet = false,
		)
		lock_ok = image_ok && preview_ok
	}

	return desktop_ok && lock_ok
}

apply_logseq :: proc(theme: Theme) -> bool {
	home := os.get_env("HOME", context.temp_allocator)
	if home == "" {
		fmt.eprintln("HOME is not set; cannot install the Logseq theme.")
		return false
	}

	css := render_logseq(theme)
	defer delete(css)
	css_path := fmt.aprintf("%s/logseq.css", theme_root(), allocator = context.temp_allocator)
	if err := os.write_entire_file(css_path, css); err != nil {
		fmt.eprintf("Could not write %s: %v\n", css_path, err)
		return false
	}

	config_dir := fmt.aprintf("%s/.logseq/config", home, allocator = context.temp_allocator)
	_ = os.make_directory_all(config_dir)
	config_path := fmt.aprintf("%s/config.edn", config_dir, allocator = context.temp_allocator)
	source := "{}\n"
	data: []byte
	defer delete(data)
	if os.exists(config_path) {
		read_data, err := os.read_entire_file(config_path, context.allocator)
		if err != nil {
			fmt.eprintf("Could not read %s: %v\n", config_path, err)
			return false
		}
		data = read_data
		source = string(data)
	}

	// Logseq applies this global setting to every graph. Keep the generated
	// stylesheet separate so selecting another palette only replaces that file.
	css_url := file_url(css_path)
	defer delete(css_url)
	setting := fmt.aprintf(
		":custom-css-url \"@import url('%s');\"",
		css_url,
		allocator = context.temp_allocator,
	)
	has_custom_css := false
	uses_generated_css := false
	map_starts := false
	contents := source
	for raw_line in strings.split_lines_iterator(&contents) {
		line := strings.trim_space(raw_line)
		if line == "" || strings.has_prefix(line, ";") {
			continue
		}
		if !map_starts {
			map_starts = strings.has_prefix(line, "{")
		}
		// Ignore EDN comments when checking whether the setting is active.
		code := line
		if comment := strings.index(code, ";;"); comment >= 0 {
			code = code[:comment]
		}
		if strings.contains(code, ":custom-css-url") {
			has_custom_css = true
			uses_generated_css = strings.contains(code, setting)
			break
		}
	}
	if has_custom_css {
		if !uses_generated_css {
			fmt.eprintf(
				"Logseq already has :custom-css-url in %s; leaving it unchanged. Import %s to enable the generated theme.\n",
				config_path,
				css_path,
			)
			return true
		}
		// Rewriting the config prompts a running Logseq instance to reconsider
		// the imported stylesheet even though the setting itself is unchanged.
		if err := os.write_entire_file(config_path, source); err != nil {
			fmt.eprintf("Could not refresh %s: %v\n", config_path, err)
			return false
		}
		return true
	}

	closing := strings.last_index(source, "}")
	if closing < 0 || !map_starts {
		fmt.eprintf("%s must contain a top-level EDN map; Logseq theme was not enabled.\n", config_path)
		return false
	}
	separator := ""
	if closing > 0 && source[closing - 1] != '\n' {
		separator = "\n"
	}
	updated := fmt.aprintf(
		"%s%s  ;; Generated by theme CLI.\n  %s\n%s",
		source[:closing],
		separator,
		setting,
		source[closing:],
	)
	defer delete(updated)
	temporary := fmt.aprintf("%s.tmp", config_path, allocator = context.temp_allocator)
	if err := os.write_entire_file(temporary, updated); err != nil {
		fmt.eprintf("Could not write %s: %v\n", temporary, err)
		return false
	}
	if err := os.rename(temporary, config_path); err != nil {
		fmt.eprintf("Could not replace %s: %v\n", config_path, err)
		return false
	}
	return true
}

apply_sddm :: proc(theme: Theme) -> bool {
	home := os.get_env("HOME", context.temp_allocator)
	if home == "" {
		fmt.eprintln("HOME is not set; cannot install SDDM theme files.")
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
hover=${11}
wallpaper=${12}

case "$wallpaper" in
  '~/'*) wallpaper="$home/${wallpaper#\~/}" ;;
esac

source_dir="$theme_root/sddm-theme"
mkdir -p "$source_dir"
rm -f "$source_dir/wallpaper.jpg"
if [ -n "$wallpaper" ]; then
  if [ ! -f "$wallpaper" ]; then
    echo "Could not read SDDM wallpaper: $wallpaper" >&2
    exit 1
  fi
  cp "$wallpaper" "$source_dir/wallpaper.jpg"
  chmod 0644 "$source_dir/wallpaper.jpg"
fi
cat > "$source_dir/metadata.desktop" <<EOF
[SddmGreeterTheme]
Name=$display_name (theme CLI)
Description=Generated by theme CLI
Author=theme CLI
Type=sddm-theme
Version=1.0
MainScript=Main.qml
ConfigFile=theme.conf
Theme-Id=theme-cli
Theme-API=2.0
EOF
cat > "$source_dir/theme.conf" <<EOF
[General]
background=$bg
backgroundAlt=$bg_alt
backgroundHard=$bg_hard
foreground=$fg
foregroundInactive=$inactive
accent=$accent
negative=$red
EOF
cat > "$source_dir/Main.qml" <<EOF
import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "$bg_hard"

    property int sessionIndex: session.index

    function submit() {
        sddm.login(nameInput.text, passwordInput.text, sessionIndex)
    }

    TextConstants { id: textConstants }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            clock.text = Qt.formatTime(now, "hh:mm")
            dateText.text = Qt.formatDate(now, "dddd, MMMM d")
        }
    }

    Connections {
        target: sddm
        onLoginSucceeded: {
            statusText.color = "$accent"
            statusText.text = textConstants.loginSucceeded
        }
        onLoginFailed: {
            passwordInput.text = ""
            statusText.color = "$red"
            statusText.text = textConstants.loginFailed
            passwordInput.forceActiveFocus()
        }
    }

    // The wallpaper is copied into the system theme so the SDDM user can
    // read it even when the user's home directory is unavailable.
    Image {
        anchors.fill: parent
        source: "wallpaper.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }

    // Match Plasma's lock-screen treatment while retaining Gruvbox contrast.
    Rectangle { anchors.fill: parent; color: "$bg_hard"; opacity: 0.36 }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.105
        spacing: 2

        Text {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            color: "$fg"
            font.pixelSize: 92
            font.weight: Font.Light
        }

        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            color: "$inactive"
            font.pixelSize: 18
        }
    }

    Column {
        id: loginColumn
        width: 340
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 112
        spacing: 14

        Rectangle {
            width: 96
            height: 96
            radius: 48
            anchors.horizontalCenter: parent.horizontalCenter
            color: "$bg_alt"
            border.color: "$accent"
            border.width: 2

            Text {
                anchors.centerIn: parent
                text: nameInput.text.length > 0 ? nameInput.text.charAt(0).toUpperCase() : "?"
                color: "$accent"
                font.pixelSize: 42
                font.bold: true
            }
        }

        TextInput {
            id: nameInput
            width: parent.width
            height: 34
            text: userModel.lastUser
            color: "$fg"
            selectionColor: "$accent"
            selectedTextColor: "$bg"
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            font.pixelSize: 18
            KeyNavigation.tab: passwordInput
            Keys.onPressed: {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    passwordInput.forceActiveFocus()
                    event.accepted = true
                }
            }
        }

        Row {
            width: parent.width
            height: 42
            spacing: 8

            Rectangle {
                width: parent.width - 50
                height: parent.height
                radius: 4
                color: "$bg_alt"
                opacity: 0.92
                border.color: passwordInput.activeFocus ? "$accent" : "$inactive"
                border.width: 1

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    verticalAlignment: Text.AlignVCenter
                    text: textConstants.password
                    color: "$inactive"
                    opacity: passwordInput.text.length == 0 ? 1.0 : 0.0
                    font.pixelSize: 14
                }

                TextInput {
                    id: passwordInput
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: "$fg"
                    selectionColor: "$accent"
                    selectedTextColor: "$bg"
                    font.pixelSize: 15
                    focus: true
                    KeyNavigation.backtab: nameInput
                    KeyNavigation.tab: session
                    Keys.onPressed: {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.submit()
                            event.accepted = true
                        }
                    }
                }
            }

            Rectangle {
                width: 42
                height: 42
                radius: 4
                color: loginMouse.containsMouse ? "$bg_alt" : "$accent"
                border.color: "$accent"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "→"
                    color: loginMouse.containsMouse ? "$accent" : "$bg"
                    font.pixelSize: 22
                    font.bold: true
                }

                MouseArea {
                    id: loginMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.submit()
                }
            }
        }

        Text {
            id: statusText
            width: parent.width
            text: textConstants.prompt
            color: "$inactive"
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 13
        }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 28
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        spacing: 10

        Rectangle {
            width: 40
            height: 40
            radius: 20
            color: shutdownMouse.containsMouse ? "$red" : "transparent"
            border.color: shutdownMouse.containsMouse ? "$red" : "$inactive"
            Text { anchors.centerIn: parent; text: "⏻"; color: shutdownMouse.containsMouse ? "$bg" : "$fg"; font.pixelSize: 17 }
            MouseArea { id: shutdownMouse; anchors.fill: parent; hoverEnabled: true; onClicked: sddm.powerOff() }
        }

        Rectangle {
            width: 40
            height: 40
            radius: 20
            color: rebootMouse.containsMouse ? "$accent" : "transparent"
            border.color: rebootMouse.containsMouse ? "$accent" : "$inactive"
            Text { anchors.centerIn: parent; text: "↻"; color: rebootMouse.containsMouse ? "$bg" : "$fg"; font.pixelSize: 19 }
            MouseArea { id: rebootMouse; anchors.fill: parent; hoverEnabled: true; onClicked: sddm.reboot() }
        }
    }

    ComboBox {
        id: session
        width: 260
        height: 34
        anchors.right: parent.right
        anchors.rightMargin: 28
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 27
        model: sessionModel
        index: sessionModel.lastIndex
        arrowIcon: ""
        arrowColor: "$bg_alt"
        color: "$bg_alt"
        borderColor: "$inactive"
        focusColor: "$accent"
        hoverColor: "$hover"
        menuColor: "$bg_hard"
        textColor: "$fg"
    }
}
EOF

install_script='set -eu
src=$1
dst=/usr/share/sddm/themes/theme-cli
rm -rf "$dst"
mkdir -p "$dst"
cp -R "$src/." "$dst/"
chmod -R u=rwX,go=rX "$dst"
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/theme-cli.conf <<CONF
[Theme]
Current=theme-cli
CONF
'

if [ "$(id -u)" -eq 0 ]; then
  sh -c "$install_script" theme-sddm-install "$source_dir"
elif command -v pkexec >/dev/null 2>&1; then
  pkexec sh -c "$install_script" theme-sddm-install "$source_dir" || {
    echo "Could not install SDDM theme; run 'theme apply' in a graphical session or as root." >&2
    exit 0
  }
else
  echo "Generated SDDM theme in $source_dir. Install it as root and set Current=theme-cli in /etc/sddm.conf.d/." >&2
fi
`
	return run_process(
		{
			"sh",
			"-c",
			script,
			"theme-sddm",
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
			theme.colors[11],
			resolve_home_path(theme.login_wallpaper),
		},
		quiet = false,
	)
}

/*
SDDM support writes a generated login-screen theme to `$XDG_CONFIG_HOME/theme/sddm-theme`, then installs it to `/usr/share/sddm/themes/theme-cli` and selects it through `/etc/sddm.conf.d/theme-cli.conf` when root/pkexec is available.
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
	wallpapers_ok := apply_kde_wallpapers(theme)
	sddm_ok := apply_sddm(theme)
	browsers_ok := apply_browsers(theme)
	logseq_ok := apply_logseq(theme)
	reload_apps()
	fmt.printf(
		"Applied %s. Restart existing Neovim, Firefox, Chrome, and Logseq instances to update them. SDDM changes appear on the next login screen.\n",
		theme.display_name,
	)
	return kde_ok && wallpapers_ok && sddm_ok && browsers_ok && logseq_ok
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
	fmt.println("  theme apply [logseq]")
	fmt.println("  theme render <tmux|logseq>")
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
		if len(os.args) == 2 {
			if !apply_current() {
				os.exit(1)
			}
		} else if len(os.args) == 3 && os.args[2] == "logseq" {
			if theme, ok := current_theme(); !ok || !apply_logseq(theme) {
				os.exit(1)
			}
			fmt.println("Applied the current palette to Logseq. Restart Logseq if it does not reload automatically.")
		} else {
			fmt.eprintln("theme apply accepts only the optional 'logseq' target.")
			os.exit(2)
		}
	case "render":
		if len(os.args) != 3 || (os.args[2] != "tmux" && os.args[2] != "logseq") {
			fmt.eprintln("theme render requires 'tmux' or 'logseq'.")
			os.exit(2)
		}
		if theme, ok := current_theme(); ok {
			switch os.args[2] {
			case "tmux":
				render_tmux(theme)
			case "logseq":
				css := render_logseq(theme)
				defer delete(css)
				fmt.print(css)
			}
		} else {
			os.exit(1)
		}
	case:
		fmt.eprintf("Unknown command: %s\n", os.args[1])
		print_help()
		os.exit(2)
	}
}
