#!/usr/bin/env python3
"""Draw a simple schematic from the Magic-extracted RC_FILTER netlist."""

import json
import re
import sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as patches


def parse_pex(pex_path):
    """Return (R_value, C_device_params) from the extracted netlist."""
    with open(pex_path) as f:
        text = f.read()
    # Resistor:  R0 VOUT VIN sky130_fd_pr__res_generic_po w=30 l=10046
    r_match = re.search(r'R0\s+VOUT\s+VIN\s+[^\n]+w=(\d+)\s+l=(\d+)', text)
    r_width = int(r_match.group(1)) if r_match else None
    r_length = int(r_match.group(2)) if r_match else None
    # Capacitor: X0 VOUT VSS sky130_fd_pr__cap_mim_m3_1 l=1940 w=1940
    c_match = re.search(r'X0\s+VOUT\s+VSS\s+[^\n]+l=(\d+)\s+w=(\d+)', text)
    c_l = int(c_match.group(1)) if c_match else None
    c_w = int(c_match.group(2)) if c_match else None
    return (r_width, r_length), (c_l, c_w)


def draw_resistor(ax, x, y, length=1.2, height=0.3, n_zigzag=6):
    """Draw a zig-zag resistor from (x,y) to (x+length,y)."""
    xs = [x]
    ys = [y]
    seg = length / (2 * n_zigzag + 1)
    for i in range(n_zigzag):
        xs.extend([x + (2*i + 1)*seg, x + (2*i + 2)*seg])
        ys.extend([y + height/2 if i % 2 == 0 else y - height/2,
                   y])
    xs.append(x + length)
    ys.append(y)
    ax.plot(xs, ys, color="black", lw=1.5)


def draw_capacitor(ax, x, y, plate_sep=0.12, plate_height=0.4):
    """Draw a capacitor vertically from (x,y) down to (x,y - 1.0)."""
    # top plate
    ax.plot([x - plate_height/2, x + plate_height/2], [y, y],
            color="black", lw=1.5)
    # bottom plate
    ax.plot([x - plate_height/2, x + plate_height/2],
            [y - plate_sep, y - plate_sep], color="black", lw=1.5)
    # vertical wires
    ax.plot([x, x], [y + 0.15, y], color="black", lw=1.0)
    ax.plot([x, x], [y - plate_sep, y - 0.6], color="black", lw=1.0)


def main():
    pex_path = sys.argv[1] if len(sys.argv) > 1 else "work/RC_FILTER_0.pex.spice"
    out_path = sys.argv[2] if len(sys.argv) > 2 else "rc_filter_extracted_schematic.png"

    (rw, rl), (cl, cw) = parse_pex(pex_path)
    scale = 5e-9  # .option scale=5m => each unit is 5 nm
    r_ohms = None
    if rw and rl:
        # Sky130 res_generic_po sheet resistance is ~300 ohm/sq for the abstract model
        r_ohms = 300.0 * rl / rw

    fig, ax = plt.subplots(figsize=(8, 5))
    ax.set_xlim(-0.5, 3.5)
    ax.set_ylim(-1.5, 1.5)
    ax.axis("off")

    # Input -> resistor -> output node
    ax.plot([0, 0.6], [0, 0], color="black", lw=1.5)
    draw_resistor(ax, 0.6, 0, length=1.2, height=0.25, n_zigzag=8)
    ax.plot([1.8, 2.4], [0, 0], color="black", lw=1.5)

    # Output node -> capacitor -> ground
    draw_capacitor(ax, 2.4, 0, plate_sep=0.12, plate_height=0.4)

    # Labels
    ax.text(-0.1, 0.15, "VIN", fontsize=12, ha="right", va="bottom")
    ax.text(2.4, 0.15, "VOUT", fontsize=12, ha="center", va="bottom")
    ax.text(2.7, -0.9, "VSS", fontsize=12, ha="left", va="center")

    # Device labels
    r_text = f"R0\nsky130_fd_pr__res_generic_po\nw={rw} l={rl}"
    if r_ohms:
        r_text += f"\n≈ {r_ohms/1e3:.1f} kΩ"
    ax.text(1.2, 0.45, r_text, fontsize=10, ha="center", va="bottom")

    c_text = f"C0\nsky130_fd_pr__cap_mim_m3_1\nw={cw} l={cl}"
    ax.text(1.45, -0.6, c_text, fontsize=10, ha="center", va="top")

    ax.set_title("Schematic extracted from layout (RC_FILTER_0.pex.spice)",
                 fontsize=13, pad=10)

    plt.tight_layout()
    plt.savefig(out_path, dpi=200, bbox_inches="tight")
    print(f"Wrote extracted schematic to {out_path}")


if __name__ == "__main__":
    main()
