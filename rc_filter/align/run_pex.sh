#!/usr/bin/env bash
# Run Magic extraction (PEX) on the ALIGN-generated RC_FILTER_0.gds.
#
# NOTE: The ALIGN-generated GDS uses abstract PDK layers, but Magic extracts
# the poly resistor as sky130_fd_pr__res_generic_po and the MIM capacitor as
# sky130_fd_pr__cap_mim_m3_1. Magic also adds parasitic capacitors to the
# substrate (VSUBS), which are ignored during LVS.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/work"
GDS="$WORK_DIR/RC_FILTER_0.gds"

cd "$WORK_DIR"

cat > /tmp/extract_align.tcl <<EOF
set PDKPATH "/usr/local/share/pdk/sky130A"
source "\$PDKPATH/libs.tech/magic/sky130A.magicrc"

catch {gds readonly false}
catch {gds rescale false}
gds read RC_FILTER_0.gds
load RC_FILTER_0
extract all
ext2spice -o RC_FILTER_0.pex.spice RC_FILTER_0
quit
EOF

echo "Running Magic extraction on $GDS ..."
magic -dnull -noconsole /tmp/extract_align.tcl

echo "PEX netlist written to $WORK_DIR/RC_FILTER_0.pex.spice"
