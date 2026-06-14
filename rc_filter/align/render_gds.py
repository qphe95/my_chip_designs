#!/usr/bin/env python3
"""Render an ALIGN python.gds.json to a semi-transparent PNG."""

import json
import sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as patches

LAYER_COLORS = {
    "M1": "#4dabf7",
    "M2": "#51cf66",
    "M3": "#ff922b",
    "M4": "#845ef7",
    "M5": "#ffd43b",
    "V0": "#5c3a21",
    "V1": "#5c3a21",
    "V2": "#fcc419",
    "V3": "#22b8cf",
    "V4": "#868e96",
    "V5": "#be4bdb",
    "Poly": "#ff6b6b",
    "Pc": "#ff6b6b",
    "Active": "#ffa94d",
    "Fin": "#e599f7",
    "Tap": "#94d82d",
    "CapMIMLayer": "#a5d8ff",
    "CapMIMContact": "#74c0fc",
    "PolyRes": "#ff8787",
    "Boundary": "#f8f9fa",
    "Outline": "#f8f9fa",
    "Bbox": "#f8f9fa",
}

LAYER_ZORDER = {
    "Fin": 1,
    "Active": 2,
    "Poly": 3,
    "Pc": 3,
    "PolyRes": 3.5,
    "Tap": 4,
    "M1": 5,
    "V0": 5.5,
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
    "Outline": 0,
    "Bbox": 0,
}


def load_layer_map(layers_json):
    with open(layers_json) as f:
        data = json.load(f)
    mapping = {}
    for entry in data.get("Abstraction", []):
        name = entry["Layer"]
        gds_layer = entry.get("GdsLayerNo")
        if gds_layer is None:
            continue
        dtypes = entry.get("GdsDatatype", {})
        for dtype_name, dtype_num in dtypes.items():
            mapping[(gds_layer, dtype_num)] = name
        # also map draw datatype if present
        if "Draw" in dtypes:
            mapping[(gds_layer, dtypes["Draw"])] = name
    # Some PDK entries share the same GDS layer/datatype; prefer recognizable names.
    for key, name in list(mapping.items()):
        if name == "Pc":
            mapping[key] = "Poly"
    return mapping


def main():
    gds_json = sys.argv[1] if len(sys.argv) > 1 else "3_pnr/RC_FILTER_0.python.gds.json"
    layers_json = sys.argv[2] if len(sys.argv) > 2 else "3_pnr/inputs/layers.json"
    out_path = sys.argv[3] if len(sys.argv) > 3 else "rc_filter_gds_layout.png"

    layer_map = load_layer_map(layers_json)

    with open(gds_json) as f:
        data = json.load(f)

    polys = []
    for lib in data.get("bgnlib", []):
        for struct in lib.get("bgnstr", []):
            for elem in struct.get("elements", []):
                if elem.get("type") != "boundary":
                    continue
                layer = elem.get("layer")
                dtype = elem.get("datatype")
                name = layer_map.get((layer, dtype))
                if name in ("Boundary", "Outline", "Bbox"):
                    continue
                xy = elem.get("xy", [])
                if len(xy) < 6:
                    continue
                xs = xy[0::2]
                ys = xy[1::2]
                polys.append((name, list(zip(xs, ys))))

    if not polys:
        print("No polygons to render.")
        sys.exit(1)

    all_x = [x for _, pts in polys for x, _ in pts]
    all_y = [y for _, pts in polys for _, y in pts]
    min_x, max_x = min(all_x), max(all_x)
    min_y, max_y = min(all_y), max(all_y)

    fig, ax = plt.subplots(figsize=(12, 10))

    for layer_name in LAYER_ZORDER:
        for name, pts in polys:
            if name != layer_name:
                continue
            color = LAYER_COLORS.get(layer_name, "#ced4da")
            ax.add_patch(patches.Polygon(
                pts,
                closed=True,
                linewidth=0.5,
                edgecolor="black",
                facecolor=color,
                alpha=0.5,
                zorder=LAYER_ZORDER.get(layer_name, 5)
            ))

    ax.set_xlim(min_x - 2000, max_x + 2000)
    ax.set_ylim(min_y - 2000, max_y + 2000)
    ax.set_aspect("equal")
    ax.set_xlabel("GDS units (nm)")
    ax.set_ylabel("GDS units (nm)")
    ax.set_title("RC Filter GDS Layout (ALIGN auto-generated)")

    handles = []
    seen = set()
    for layer_name in LAYER_ZORDER:
        if layer_name in {n for n, _ in polys} and layer_name not in seen:
            seen.add(layer_name)
            handles.append(patches.Patch(
                color=LAYER_COLORS.get(layer_name, "#ced4da"),
                label=layer_name
            ))
    if handles:
        ax.legend(handles=handles, loc="upper left", bbox_to_anchor=(1.02, 1), fontsize=8)

    plt.tight_layout()
    plt.savefig(out_path, dpi=300, bbox_inches="tight")
    print(f"Rendered GDS layout to {out_path}")


if __name__ == "__main__":
    main()
