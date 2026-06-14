# RC Filter ALIGN Layout

This directory contains inputs for the [ALIGN](https://github.com/ALIGN-analoglayout/ALIGN-public) automatic analog layout generator.

## Files

- `rc_filter.sp` — SPICE netlist for ALIGN. Uses the SkyWater 130 nm resistor
  and MIM capacitor models that ALIGN's sky130 PDK adapter recognizes.
- `run_align.sh` — Convenience script that calls `schematic2layout.py` with the
  sky130 PDK adapter.

## Prerequisites

ALIGN is installed by default when you run `setup_env.sh`. The setup script
builds the repo-local `ALIGN-public` fork (it no longer clones ALIGN from
GitHub). The Sky130 PDK adapter is now bundled inside `ALIGN-public/pdks/SKY130_PDK`
along with the custom passive generators. To skip ALIGN:

```bash
cd ~/my_chip_designs
INSTALL_ALIGN=no ./setup_env.sh
```

This builds the local `ALIGN-public` source and adds `schematic2layout.py` to
your PATH.

## Generate the layout

```bash
cd ~/my_chip_designs/rc_filter/align
./run_align.sh
```

Outputs (JSON, LEF, primitive GDS JSON) are written to `align/work/`.

A rendered PNG of the top-level layout is produced by `render_align.py`:

```bash
python3 render_align.py work/3_pnr/RC_FILTER_0.json rc_filter_align_layout.png
```

## Developing ALIGN in this repo

The repo-local `ALIGN-public` is installed in editable mode, so **Python
changes** inside `ALIGN-public/align/` (including the Sky130 PDK generators in
`ALIGN-public/pdks/SKY130_PDK/`) are picked up immediately by `run_align.sh`.

**C++ changes** in `ALIGN-public/PlaceRouteHierFlow/` require rebuilding the
compiled `PnR` extension. Instead of a full `pip install`, run the fast
incremental rebuild helper from the repo root:

```bash
cd ~/my_chip_designs
./rebuild_align_ext.sh
```

This runs `ninja` in the existing scikit-build directory and re-links the
`PnR.*.so` extension next to ALIGN's Python sources. Only remove
`ALIGN-public/.venv` and re-run `setup_env.sh` if the build directory itself is
corrupted or you need to change build options.

## Notes and caveats

- ALIGN's sky130 resistor generator uses an internal simplified sheet-resistance
  model. Verify the extracted resistance with Magic/Netgen LVS.
- The 10 pF MIM capacitor is requested as `w=70u l=70u`, which gives roughly
  4900 µm² (~9.8 pF at ~2 fF/µm²).
- ALIGN is primarily aimed at transistor-level analog circuits. Passive-only
  layouts like this one are at the edge of what it is designed for, so the
  result should be treated as a starting point, not a finished tape-out layout.
