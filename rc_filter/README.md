# RC Low-Pass Filter Example

A minimal analog simulation project for the IIC-OSIC-TOOLS container.

## Files

- `rc_filter.spice`   : SPICE netlist for an RC low-pass filter
- `plot_results.py`   : Python script to plot the transient output
- `rc_filter_plot.png`: Generated plot (after running)
- `rc_filter_layout.png`: Rendered chip layout image (generated in `layout/`)
- `tran_out`          : Raw numeric output from ngspice
- `rc_filter.log`     : ngspice log file
- `layout/`           : Magic VLSI layout files (see `layout/README.md`)
- `align/`            : ALIGN automatic analog layout input (optional)

## The circuit

```
        R1 = 100 kΩ
Vin ----[====]----+---- Vout
                 |
                === C1 = 10 pF
                 |
                GND
```

Time constant: τ = R·C = 100 kΩ × 10 pF = 1 µs  
-3 dB corner frequency: f_c ≈ 1 / (2πRC) ≈ 159 kHz

The input is a 1 kHz square wave (0 V to 1 V). Because 1 kHz is far below
f_c, the square wave passes through, but its edges are rounded by the RC
charging/discharging behavior. These R/C values are practical for an on-chip
passive RC filter using a SkyWater 130 nm poly resistor and MIM capacitor.

## Run the simulation from inside the container

1. Open the container desktop in your browser:

   ```
   http://localhost:8085
   ```

2. Inside the desktop, open a terminal and run:

   ```bash
   cd /headless/designs/rc_filter
   /foss/tools/ngspice/bin/ngspice -b rc_filter.spice -o rc_filter.log
   ```

3. Generate the plot:

   ```bash
   python3 plot_results.py
   ```

4. Open `rc_filter_plot.png` in the image viewer (double-click it in the file manager).

## What you should see

- **Full transient plot:** a 1 kHz square wave at both input and output.
- **Zoomed edge plot:** the output rises exponentially and reaches ~63 % of
  the final value after τ = 1 µs.

## Edit the circuit

Open `rc_filter.spice` in a text editor and change R1 or C1. For example:

```spice
R1 in out 1meg
C1 out 0  1p
```

This also gives τ = 1 µs with a smaller capacitor and a longer resistor.
Re-run the simulation and plot to see the difference.

## Command reference

```bash
# Run simulation
/foss/tools/ngspice/bin/ngspice -b rc_filter.spice -o rc_filter.log

# View log
cat rc_filter.log

# Plot results
python3 plot_results.py
```


## Generate the chip layout (optional)

A starting Magic VLSI layout is provided in the `layout/` directory.  It targets
the SkyWater 130 nm open PDK (`sky130A`).

Prerequisites:

1. Install the tools and PDK (Magic and the full SkyWater 130 nm PDK are now
   included in the top-level script):

   ```bash
   cd ~/my_chip_designs
   ./setup_env.sh
   ```

   To skip the PDK install entirely:

   ```bash
   INSTALL_SKY130_PDK=no ./setup_env.sh
   ```

Generate the `.mag` and `.gds` files:

```bash
cd ~/my_chip_designs/rc_filter/layout
./run_layout.sh
```

Render a PNG image of the layout (no X server required):

```bash
python3 render_layout.py
```

Open the layout interactively in Magic:

```bash
magic rc_filter.mag
```

See `layout/README.md` for details and design notes.

## Generate the layout with ALIGN (optional, experimental)

ALIGN is an open-source analog layout generator and is installed by default
when you run `setup_env.sh`. To skip it:

```bash
cd ~/my_chip_designs
INSTALL_ALIGN=no ./setup_env.sh
```

Then generate the RC filter layout automatically:

```bash
cd ~/my_chip_designs/rc_filter/align
./run_align.sh
```

Outputs appear in `align/work/`. This flow is experimental: ALIGN's sky130
passive-device generators are simplified, so you should verify the resulting
layout with Magic DRC and Netgen LVS before considering it tape-out ready.
