# generate_layout.tcl
# Generates a Magic layout for the rc_filter RC low-pass filter using the
# SkyWater 130 nm open PDK (sky130A).
#
# Usage (after installing Magic + sky130A PDK):
#   magic -dnull -noconsole generate_layout.tcl
#
# The layout creates:
#   - A poly resistor for R1 = 100 kOhm (symbolic; use PDK resistor PCell for
#     a production tape-out)
#   - A MIM capacitor for C1 = 10 pF
#   - Metal routing from Vin -> R -> C -> Vout
#   - Ground connection for the capacitor bottom plate
#   - Labels for Vin, Vout, GND

# Load sky130A technology. If this fails, the PDK is not installed.
if {[catch {tech load sky130A} err]} {
    puts stderr "ERROR: Could not load sky130A technology."
    puts stderr "Please install the SkyWater 130 nm PDK, for example:"
    puts stderr "  cd ~/.local/src"
    puts stderr "  git clone https://github.com/RTimothyEdwards/open_pdks.git"
    puts stderr "  cd open_pdks"
    puts stderr "  ./configure --enable-sky130-pdk --prefix=/usr/local"
    puts stderr "  make"
    puts stderr "  sudo make install"
    exit 1
}

cellname create rc_filter
snap internal

# Coordinates are in Magic internal units for sky130A (1 unit = 1 lambda = 0.005 um).

# --- Resistor R1: poly resistor strip --------------------------------------
# sky130 high-resistance poly is ~350 Ohm/square.  A 100 kOhm resistor needs
# about 286 squares.  This layout uses a symbolic 2-lambda-wide poly strip.
# For a real 100 kOhm resistor, use the PDK cell sky130_fd_pr__res_generic_po.
box 100 200 102 260
paint poly
box 100 260 160 262
paint poly
box 158 200 160 260
paint poly

# Contacts from resistor ends to local interconnect (li)
box 98 198 104 204
paint licon
box 98 198 104 204
paint li
box 156 198 162 204
paint licon
box 156 198 162 204
paint li

# --- Capacitor C1: MIM cap (capm between met3 and cap2m) ------------------
# Sky130 MIM density ~2 fF/um^2.  A real 1 nF cap would be ~707 um x 707 um.
# This educational layout draws a small symbolic cap and documents the issue.

# Bottom plate on met3
box 300 150 700 550
paint met3

# MIM top plate
box 302 152 698 548
paint capm
box 302 152 698 548
paint cap2m

# Top-plate contact up to met4 for Vout connection
box 320 170 360 210
paint via3
box 320 170 360 210
paint met4

# Bottom-plate ground contact
box 640 490 680 530
paint via3
box 640 490 680 530
paint met4

# --- Routing ----------------------------------------------------------------
# Vin pad -> resistor start (li -> met1)
box 80 198 104 204
paint mcon
box 80 198 104 204
paint met1
box 80 198 104 250
paint met1

# Resistor end -> Vout node
box 156 198 180 204
paint mcon
box 156 198 180 204
paint met1

# Met1 -> Met2 -> Met3 -> cap top plate
box 156 198 180 204
paint via
box 156 198 180 204
paint met2
box 156 198 340 204
paint met2
box 320 170 340 210
paint via2
box 320 170 340 210
paint met3
box 320 170 360 210
paint via3
box 320 170 360 210
paint met4

# Ground connection from cap bottom plate to GND pad
box 640 490 680 530
paint via4
box 640 490 680 530
paint met5

# --- Labels -----------------------------------------------------------------
label Vin port met1 80 198 104 204
label Vout port met2 156 198 180 204
label GND port met5 640 490 680 530

# --- Probe pads (large met5 rectangles) -------------------------------------
box 50 50 150 150
paint met5
label Vin pad met5 50 50 150 150

box 50 600 150 700
paint met5
label Vout pad met5 50 600 150 700

box 750 300 850 400
paint met5
label GND pad met5 750 300 850 400

# --- Save outputs -----------------------------------------------------------
save rc_filter.mag
gds write rc_filter.gds
puts "Layout saved to rc_filter.mag and rc_filter.gds"

quit
