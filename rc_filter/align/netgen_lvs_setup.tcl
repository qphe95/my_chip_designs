# Source the Sky130 netgen setup for device/property matching
source /usr/local/share/pdk/sky130A/libs.tech/netgen/sky130A_setup.tcl

# The extracted layout contains parasitic capacitors to the substrate (class "c")
# that are not in the schematic reference.  Ignore them for LVS.
ignore class c
