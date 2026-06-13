# RC Filter Layout

This directory contains a starting point for the physical (layout) design of the
RC low-pass filter in `rc_filter.spice`.

## Files

- `generate_layout.tcl` — Magic Tcl script that draws the resistor, capacitor,
  routing, and probe pads.
- `run_layout.sh` — Convenience script that checks for Magic + sky130A and runs
  `generate_layout.tcl`.
- `rc_filter.mag` — Pre-generated Magic layout cell.  Re-created by
  `generate_layout.tcl` when you run the script.
- `rc_filter.gds` — Generated GDSII stream file (created after running the script).

## Prerequisites

1. **Magic VLSI layout editor**

   The top-level install script installs it automatically:

   ```bash
   cd ~/my_chip_designs
   ./install_xschem_ngspice_wsl.sh
   ```

2. **SkyWater 130 nm PDK (sky130A)**

   The layout is drawn in the `sky130A` technology.  Install the PDK with
   `open_pdks`:

   ```bash
   mkdir -p ~/.local/src
   cd ~/.local/src
   git clone https://github.com/RTimothyEdwards/open_pdks.git
   cd open_pdks
   ./configure --enable-sky130-pdk --prefix=/usr/local
   make
   sudo make install
   ```

   This download is large (~several GB) and the build can take 30–60 minutes.

## Generate the layout

```bash
cd ~/my_chip_designs/rc_filter/layout
./run_layout.sh
```

This produces `rc_filter.mag` and `rc_filter.gds`.

## Open the layout in Magic

```bash
cd ~/my_chip_designs/rc_filter/layout
magic rc_filter.mag
```

In WSL you need an X server (WSLg on Windows 11, or VcXsrv/Xming on Windows 10).

## Layout notes

- **R1 (1 kΩ)** is drawn as a symbolic poly resistor strip.  For a real tape-out,
  use the PDK resistor cell `sky130_fd_pr__res_generic_po` to get a calibrated,
  DRC-clean resistor.
- **C1 (1 nF)** is drawn as a small symbolic MIM capacitor.  A real 1 nF MIM
  capacitor in sky130 would occupy roughly 0.5 mm² (~707 µm × 707 µm), which is
  very expensive in silicon area.  In most practical designs a 1 nF capacitor is
  placed off-chip and bonded to the IC pads, or a much smaller on-chip cap is
  used with a correspondingly larger resistor.
- The layout includes large `met5` probe pads labeled `Vin`, `Vout`, and `GND`
  so the circuit can be simulated, probed, or wire-bonded.

## Design-rule check

After opening the layout in Magic, run:

```tcl
drc check
```

Fix any DRC violations before considering the layout complete.
