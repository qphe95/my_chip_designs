# RC Low-Pass Filter Example

A minimal analog simulation project for the IIC-OSIC-TOOLS container.

## Files

- `rc_filter.spice`   : SPICE netlist for an RC low-pass filter
- `plot_results.py`   : Python script to plot the transient output
- `rc_filter_plot.png`: Generated plot (after running)
- `tran_out`          : Raw numeric output from ngspice
- `rc_filter.log`     : ngspice log file
- `layout/`           : Magic VLSI layout files (see `layout/README.md`)

## The circuit

```
        R1 = 1 kΩ
Vin ----[====]----+---- Vout
                 |
                === C1 = 1 nF
                 |
                GND
```

Time constant: τ = R·C = 1 kΩ × 1 nF = 1 µs  
-3 dB corner frequency: f_c ≈ 1 / (2πRC) ≈ 159 kHz

The input is a 1 kHz square wave (0 V to 1 V). Because 1 kHz is far below
f_c, the square wave passes through, but its edges are rounded by the RC
charging/discharging behavior.

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
R1 in out 10k
C1 out 0  10n
```

This gives τ = 100 µs — the output will look much more rounded at 1 kHz.
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

1. Install the tools (Magic is now included in the top-level script):

   ```bash
   cd ~/my_chip_designs
   ./install_xschem_ngspice_wsl.sh
   ```

2. Install the SkyWater 130 nm PDK (large download, one-time setup):

   ```bash
   cd ~/.local/src
   git clone https://github.com/RTimothyEdwards/open_pdks.git
   cd open_pdks
   ./configure --enable-sky130-pdk --prefix=/usr/local
   make
   sudo make install
   ```

Generate the `.mag` and `.gds` files:

```bash
cd ~/my_chip_designs/rc_filter/layout
./run_layout.sh
```

Open the layout:

```bash
magic rc_filter.mag
```

See `layout/README.md` for details and design notes.
