# RC Filter Layout

This directory contains a starting point for the physical (layout) design of the
RC low-pass filter in `rc_filter.spice`.

## Files

- `generate_layout.tcl` — Magic Tcl script that draws a 100 kΩ poly resistor,
  a 10 pF MIM capacitor, routing, and probe pads.
- `run_layout.sh` — Convenience script that checks for Magic + sky130A and runs
  `generate_layout.tcl`.
- `render_layout.py` — Renders `rc_filter.mag` to a PNG using matplotlib
  (works without an X server).
- `rc_filter.mag` — Pre-generated Magic layout cell.  Re-created by
  `generate_layout.tcl` when you run the script.
- `rc_filter.gds` — Generated GDSII stream file (created after running the script).
- `rc_filter_layout.png` — Rendered layout image produced by `render_layout.py`.

## Prerequisites

1. **Magic VLSI layout editor**

   Installed automatically by `setup_env.sh`.  The script always builds Magic
   from source because the Ubuntu package is too old for the current sky130
   PDK.

2. **SkyWater 130 nm PDK (sky130A)**

   Also installed automatically by `setup_env.sh`.  The full PDK (primitives,
   I/O pads, and standard cells) is built.  If you want to skip the PDK install
   entirely, run:

   ```bash
   INSTALL_SKY130_PDK=no ./setup_env.sh
   ```

## Generate the layout

```bash
cd ~/my_chip_designs/rc_filter/layout
./run_layout.sh
```

This produces `rc_filter.mag` and `rc_filter.gds`.

## Render a PNG of the layout

```bash
python3 render_layout.py
```

This creates `rc_filter_layout.png` without needing a display or X server.

## Open the layout in Magic

```bash
cd ~/my_chip_designs/rc_filter/layout
magic rc_filter.mag
```

In WSL you need an X server (WSLg on Windows 11, or VcXsrv/Xming on Windows 10).

## Layout notes

- **R1 (100 kΩ)** is drawn as a symbolic poly resistor strip.  A SkyWater 130 nm
  high-resistance poly resistor is roughly 350 Ω/square, so 100 kΩ needs about
  286 squares (~143 µm long at 0.5 µm width).  For a real tape-out, use the PDK
  resistor cell `sky130_fd_pr__res_generic_po` to get a calibrated, DRC-clean
  resistor.
- **C1 (10 pF)** is drawn as a MIM capacitor.  At ~2 fF/µm² a 10 pF MIM cap
  occupies roughly 70 µm × 70 µm, which is a practical on-chip size.
- The layout includes large `met5` probe pads labeled `Vin`, `Vout`, and `GND`
  so the circuit can be simulated, probed, or wire-bonded.

## Design-rule check

After opening the layout in Magic, run:

```tcl
drc check
```

Fix any DRC violations before considering the layout complete.
