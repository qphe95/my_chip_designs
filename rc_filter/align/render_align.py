#!/usr/bin/env python3
"""Render an ALIGN layout JSON to a PNG using matplotlib."""

import json
import sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as patches

# Approximate colors for ALIGN layer names
LAYER_COLORS = {
    "M1": "#4dabf7",
    "M2": "#51cf66",
    "M3": "#ff922b",
    "M4": "#845ef7",
    "M5": "#ffd43b",
    "V1": "#5c3a21",
    "V2": "#fcc419",
    "V3": "#22b8cf",
    "V4": "#868e96",
    "V5": "#be4bdb",
    "Poly": "#ff6b6b",
    "Active": "#ffa94d",
    "Fin": "#e599f7",
    "Tap": "#94d82d",
    "CapMIMLayer": "#a5d8ff",
    "CapMIMContact": "#74c0fc",
    "Rboundary": "#f8f9fa",
    "Boundary": "#f8f9fa",
}

LAYER_ZORDER = {
    "Fin": 1,
    "Active": 2,
    "Poly": 3,
    "Tap": 4,
    "M1": 5,
    "V1": 6,
    "M2": 7,
    "V2": 8,
    "M3": 9,
    "V3": 10,
    "M4": 11,
    "CapMIMLayer": 11.5,
    "CapMIMContact": 11.6,
    "V4": 12,
    "M5": 13,
    "V5": 14,
    "Boundary": 0,
    "Rboundary": 0,
}


def main():
    json_path = sys.argv[1] if len(sys.argv) > 1 else "3_pnr/RC_FILTER_0.json"
    out_path = sys.argv[2] if len(sys.argv) > 2 else "rc_filter_align_layout.png"

    with open(json_path) as f:
        data = json.load(f)

    terminals = [t for t in data.get("terminals", [])
                 if t.get("layer") not in ("Boundary", "Rboundary", "boundary")]

    if not terminals:
        print("No terminals to render.")
        sys.exit(1)

    min_x = min(r[0] for t in terminals for r in [t["rect"]])
    min_y = min(r[1] for t in terminals for r in [t["rect"]])
    max_x = max(r[2] for t in terminals for r in [t["rect"]])
    max_y = max(r[3] for t in terminals for r in [t["rect"]])

    # ALIGN internal units; with ScaleFactor=1 this is roughly nm / 10 ?
    # The sky130 layers.json ScaleFactor is 1; coordinates appear to be in
    # Magic-internal-like units. We just label the axis in "ALIGN units".

    fig, ax = plt.subplots(figsize=(12, 10))

    for layer_name in LAYER_ZORDER:
        for t in terminals:
            if t.get("layer") != layer_name:
                continue
            x1, y1, x2, y2 = t["rect"]
            color = LAYER_COLORS.get(layer_name, "#ced4da")
            ax.add_patch(patches.Rectangle(
                (x1, y1), x2 - x1, y2 - y1,
                linewidth=0.5, edgecolor="black",
                facecolor=color,
                alpha=0.5,
                zorder=LAYER_ZORDER.get(layer_name, 5)
            ))

    ax.set_xlim(min_x - 2000, max_x + 2000)
    ax.set_ylim(min_y - 2000, max_y + 2000)
    ax.set_aspect("equal")
    ax.set_xlabel("ALIGN internal units")
    ax.set_ylabel("ALIGN internal units")
    ax.set_title("RC Filter Layout (ALIGN auto-generated)")

    handles = []
    seen = set()
    for layer_name in LAYER_ZORDER:
        if layer_name in {t.get("layer") for t in terminals} and layer_name not in seen:
            seen.add(layer_name)
            handles.append(patches.Patch(
                color=LAYER_COLORS.get(layer_name, "#ced4da"),
                label=layer_name
            ))
    if handles:
        ax.legend(handles=handles, loc="upper left", bbox_to_anchor=(1.02, 1), fontsize=8)

    plt.tight_layout()
    plt.savefig(out_path, dpi=300, bbox_inches="tight")
    print(f"Rendered ALIGN layout to {out_path}")


if __name__ == "__main__":
    main()
