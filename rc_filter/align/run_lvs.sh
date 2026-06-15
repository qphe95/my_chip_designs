#!/usr/bin/env bash
# Run netgen LVS between the ALIGN-generated layout and the schematic.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/work"
PEX_SPICE="$WORK_DIR/RC_FILTER_0.pex.spice"
REF_SPICE="$SCRIPT_DIR/rc_filter_lvs.sp"
SETUP_TCL="$SCRIPT_DIR/netgen_lvs_setup.tcl"
LAYOUT_LVS="$WORK_DIR/RC_FILTER_0_lvs.spice"
REPORT="$WORK_DIR/lvs_report.log"

# Find the netgen binary (distro package is usually netgen-lvs).
NETGEN=""
for bin in netgen-lvs netgen; do
    if command -v "$bin" >/dev/null 2>&1; then
        NETGEN="$bin"
        break
    fi
done

if [[ -z "$NETGEN" ]]; then
    echo "ERROR: netgen not found. Run setup_env.sh first."
    exit 1
fi

if [[ ! -f "$PEX_SPICE" ]]; then
    echo "ERROR: $PEX_SPICE not found. Run ./run_pex.sh first."
    exit 1
fi

if [[ ! -f "$REF_SPICE" ]]; then
    echo "ERROR: $REF_SPICE not found."
    exit 1
fi

mkdir -p "$WORK_DIR"

# Wrap the flat extracted netlist in a subcircuit so netgen can compare it
# against the schematic subckt.
{
    echo "* LVS wrapper for RC_FILTER_0.pex.spice"
    echo ".subckt RC_FILTER_0 VIN VOUT VSS"
    grep -v '^\.option' "$PEX_SPICE" | tail -n +2
    echo ".ends"
} > "$LAYOUT_LVS"

echo "Running netgen LVS..."
rm -f "$REPORT"
"$NETGEN" -batch lvs \
    "${LAYOUT_LVS} RC_FILTER_0" \
    "${REF_SPICE} rc_filter" \
    "$SETUP_TCL" \
    "$REPORT" 2>&1 | tee "$WORK_DIR/lvs_stdout.log"

if grep -q "Circuits match uniquely" "$REPORT" 2>/dev/null || grep -q "Netlists match uniquely" "$WORK_DIR/lvs_stdout.log"; then
    echo ""
    echo "LVS PASSED"
    exit 0
else
    echo ""
    echo "LVS FAILED -- see $REPORT"
    exit 1
fi
