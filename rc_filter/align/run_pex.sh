#!/usr/bin/env bash
# Run Magic extraction (PEX) on the ALIGN-generated RC_FILTER_0.gds.
#
# NOTE: The ALIGN-generated GDS uses abstract PDK layers, so Magic can only
# extract a partial netlist. The MIM capacitor is usually recognized, but the
# custom poly resistor is not extracted as a device because its abstract Poly/
# V0 layers do not map to Sky130 resistor recognition layers. Use this result
# as a starting point, not a production PEX sign-off.
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
