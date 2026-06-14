#!/usr/bin/env python3
"""Render a Magic .mag file to a PNG using matplotlib."""

import re
import sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as patches

# Sky130 layer colors (approximate)
LAYER_COLORS = {
    "poly": "#ff6b6b",
    "polycont": "#c92a2a",
    "viali": "#5c3a21",
    "metal1": "#4dabf7",
    "via1": "#845ef7",
    "metal2": "#51cf66",
    "via2": "#fcc419",
    "metal3": "#ff922b",
    "via3": "#22b8cf",
    "mimcap": "#a5d8ff",
    "capm": "#a5d8ff",
    "cap2m": "#74c0fc",
    "via4": "#868e96",
    "metal5": "#ffd43b",
    "met5": "#ffd43b",
    "checkpaint": "#f8f9fa",
}

LAYER_ZORDER = {
    "checkpaint": 0,
    "poly": 1,
    "polycont": 2,
    "viali": 3,
    "metal1": 4,
    "via1": 5,
    "metal2": 6,
    "via2": 7,
    "metal3": 8,
    "mimcap": 8.5,
    "capm": 8.5,
    "cap2m": 8.6,
    "via3": 9,
    "via4": 10,
    "metal5": 11,
    "met5": 11,
}


def parse_mag(path):
    layers = {}
    current = None
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line.startswith("<< ") and line.endswith(" >>"):
                current = line[3:-3].strip()
                layers.setdefault(current, [])
            elif current and line.startswith("rect "):
                parts = line.split()
                if len(parts) == 5:
                    _, x1, y1, x2, y2 = parts
                    layers[current].append((int(x1), int(y1), int(x2), int(y2)))
    return layers


def main():
    mag_path = sys.argv[1] if len(sys.argv) > 1 else "rc_filter.mag"
    out_path = sys.argv[2] if len(sys.argv) > 2 else "rc_filter_layout.png"

    layers = parse_mag(mag_path)

    # Determine bounds from non-checkpaint layers
    # Skip Magic's internal checkpaint border
    render_layers = {k: v for k, v in layers.items() if k != "checkpaint"}
    all_rects = [r for rects in render_layers.values() for r in rects]
    if not all_rects:
        print("No rectangles found to render.")
        sys.exit(1)

    min_x = min(r[0] for r in all_rects)
    min_y = min(r[1] for r in all_rects)
    max_x = max(r[2] for r in all_rects)
    max_y = max(r[3] for r in all_rects)

    # Magic internal units: 2 units = 1 lambda; 1 lambda = 0.005 um
    # So 1 internal unit = 0.0025 um = 2.5 nm
    SCALE = 0.0025  # um per internal unit

    fig, ax = plt.subplots(figsize=(10, 8))

    for layer_name, rects in sorted(render_layers.items(), key=lambda x: LAYER_ZORDER.get(x[0], 5)):
        color = LAYER_COLORS.get(layer_name, "#ced4da")
        for (x1, y1, x2, y2) in rects:
            w = (x2 - x1) * SCALE
            h = (y2 - y1) * SCALE
            x = x1 * SCALE
            y = y1 * SCALE
            ax.add_patch(patches.Rectangle((x, y), w, h, linewidth=0,
                                            edgecolor="none", facecolor=color,
                                            zorder=LAYER_ZORDER.get(layer_name, 5),
                                            label=layer_name if layer_name not in [p.get_label() for p in ax.patches] else ""))

    # Add labels for Vin, Vout, GND based on known pad locations
    ax.text(0.125, 0.125, "Vin", fontsize=12, ha="center", va="center",
            color="black", fontweight="bold", zorder=20)
    ax.text(0.125, 0.8125, "Vout", fontsize=12, ha="center", va="center",
            color="black", fontweight="bold", zorder=20)
    ax.text(1.0, 0.4375, "GND", fontsize=12, ha="center", va="center",
            color="black", fontweight="bold", zorder=20)

    ax.set_xlim(min_x * SCALE - 0.2, max_x * SCALE + 0.2)
    ax.set_ylim(min_y * SCALE - 0.2, max_y * SCALE + 0.2)
    ax.set_aspect("equal")
    ax.set_xlabel("um")
    ax.set_ylabel("um")
    ax.set_title("RC Low-Pass Filter Layout (sky130A)")

    # Build legend from unique rendered layer colors
    handles = []
    seen = set()
    for layer_name in LAYER_ZORDER:
        if layer_name in render_layers and layer_name not in seen:
            seen.add(layer_name)
            handles.append(patches.Patch(color=LAYER_COLORS.get(layer_name, "#ced4da"), label=layer_name))
    if handles:
        ax.legend(handles=handles, loc="upper left", bbox_to_anchor=(1.02, 1), fontsize=8)

    plt.tight_layout()
    plt.savefig(out_path, dpi=300, bbox_inches="tight")
    print(f"Rendered layout to {out_path}")


if __name__ == "__main__":
    main()
