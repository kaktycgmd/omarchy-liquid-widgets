# Liquid Widgets

Desktop widgets for the [Omarchy](https://omarchy.org/) Quattro shell, painted with the
[hyprglass](https://github.com/) liquid-glass effect: a clock, a CPU/load monitor, a graphics
card card, a power-profile card and a battery card. They sit on the wallpaper, between it and
your windows, and stay out of the way while you work.

Toggle each widget from the bar popup, drag a widget anywhere with the **right mouse button**,
and resize it by dragging a corner.

## Features

- **Clock** — large time with the date beneath it, or bare glassy digits.
- **Load monitor** — CPU load, an optional bar per thread, and memory.
- **Graphics card** — load, VRAM and temperature for AMD (amdgpu through `/sys`) or NVIDIA
  (through `nvidia-smi`).
- **Power profile** — the active power profile, one click to change it.
- **Battery** — charge level and time remaining.
- Per-widget toggles, screen position, card width, spacing, corner radius and background
  opacity, all from the bar popup.
- Drag to reposition and drag a corner to resize; positions and sizes are remembered per
  widget.

The glass itself comes from the **hyprglass** Hyprland plugin. Without it the widgets are
still fine — just flat translucent cards instead of real liquid glass.

## Requirements

- [Omarchy](https://omarchy.org/) Quattro (the Quickshell-based shell).
- Optional, for the liquid-glass effect: the **hyprglass** Hyprland plugin, enabled for the
  `kaktyc-liquid-widgets` namespace.
- `nvidia-smi` only if you have an NVIDIA GPU. AMD GPUs are read directly from `/sys`.
- `powerprofilesctl` (power-profiles-daemon) only for the power-profile card.

## Install

```sh
omarchy plugin add https://github.com/kaktycgmd/omarchy-liquid-widgets.git --enable
```

Then, if you want the glass, bind the plugin namespace in hyprglass, for example:

```lua
hl.config({ plugin = { hyprglass = {
  layers = { namespaces = { "omarchy-bar", "kaktyc-liquid-widgets" } },
  namespace_presets = { ["kaktyc-liquid-widgets"] = "widget_refract" },
}}})
```

The exact hyprglass configuration is yours to taste; the namespace the widgets use is
`kaktyc-liquid-widgets`.

## Usage

- **Left-click** the bar icon to open the configuration popup.
- **Right-click** the bar icon to hide all widgets, or bring them back.
- **Right-drag** a widget to move it.
- **Drag a corner** of a widget to resize it.
- Use **Reset widget positions and sizes** in the popup to return everything to the default
  stack.

## Remove

```sh
omarchy plugin remove kaktyc.liquid-widgets
```

## License

MIT — see [LICENSE](LICENSE).
