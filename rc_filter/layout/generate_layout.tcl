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

# Set up the PDK path and source the PDK magicrc so the sky130A tech file is found.
set PDKPATH "/usr/local/share/pdk/sky130A"
if {![file exists "$PDKPATH/libs.tech/magic/sky130A.tech"]} {
    puts stderr "ERROR: Could not find sky130A technology at $PDKPATH"
    puts stderr "Please install the SkyWater 130 nm PDK, for example:"
    puts stderr "  cd ~/my_chip_designs"
    puts stderr "  ./setup_env.sh"
    exit 1
}
source "$PDKPATH/libs.tech/magic/sky130A.magicrc"

# Remove any previous layout so cellname create works.
catch {cellname delete rc_filter}
if {[file exists rc_filter.mag]} {
    file delete rc_filter.mag
}
if {[file exists rc_filter.gds]} {
    file delete rc_filter.gds
}

cellname create rc_filter
load rc_filter
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
paint pc
box 98 198 104 204
paint li
box 156 198 162 204
paint pc
box 156 198 162 204
paint li

# --- Capacitor C1: MIM cap (capm top plate over met3 bottom plate) ---------
# Sky130 MIM density ~2 fF/um^2.  A 10 pF cap is ~70 um x 70 um.

# Bottom plate on met3
box 300 150 700 550
paint met3

# MIM top plate (capm)
box 302 152 698 548
paint capm

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

catch {
    gds readonly false
    gds rescale false
}
gds write rc_filter.gds
puts "Layout saved to rc_filter.mag and rc_filter.gds"

# Print a summary of the layout extents
box
quit
