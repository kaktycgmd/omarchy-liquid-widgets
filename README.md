# Liquid Widgets

Desktop widgets for the [Omarchy](https://omarchy.org/) Quattro shell, painted with the
[hyprglass](https://github.com/hyprnux/hyprglass) liquid-glass effect: a clock, a CPU/load monitor, a graphics
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

## Liquid glass (optional)

The glass effect is drawn by the **[hyprglass](https://github.com/hyprnux/hyprglass)** Hyprland
plugin, which is installed separately. Without it the widgets still work — they are just flat
translucent cards instead of real liquid glass.

The easiest way to get it is from the widget itself: open the bar popup and click **Install
hyprglass**. A terminal opens and runs `hyprpm`, which builds the plugin against your exact
Hyprland version (and asks for your password when its cache needs `sudo`). This is exactly the
manual command, if you prefer to run it yourself:

```sh
hyprpm add https://github.com/hyprnux/hyprglass
hyprpm enable hyprglass
hyprctl reload
```

Finally, bind the widget layer to a hyprglass preset in your Hyprland config, so hyprglass knows
this surface may be glassed. For example, in `~/.config/hypr/hyprland.lua`:

```lua
if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass
    hg.config({ layers = { enabled = true,
        namespaces = "omarchy-bar, kaktyc-liquid-widgets",
        namespace_presets = "kaktyc-liquid-widgets:widget_refract",
        namespace_mask_thresholds = "omarchy-bar=0.0, kaktyc-liquid-widgets=0.1",
    }})
    hg.preset("widget_refract", {
        blur_strength = 0.5, refraction_strength = 1.2, chromatic_aberration = 0.2,
        lens_distortion = 0.12, fresnel_strength = 0.55, specular_strength = 0.55,
        glass_opacity = 1.0, edge_thickness = 0.12, brightness = 1.0,
    })
end
```

The namespace the widgets use is `kaktyc-liquid-widgets`; the preset is yours to taste.

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
