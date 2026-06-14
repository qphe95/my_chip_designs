#!/usr/bin/env bash
# Run ALIGN to generate the RC filter layout.
# Requires ALIGN to be installed via setup_env.sh with INSTALL_ALIGN=yes.
set -euo pipefail

ALIGN_HOME="${ALIGN_HOME:-$HOME/.local/src/xschem_ngspice_build/ALIGN-public}"
ALIGN_PDK_SKY130="${ALIGN_PDK_SKY130:-$HOME/.local/src/xschem_ngspice_build/ALIGN-pdk-sky130/SKY130_PDK}"

if ! command -v schematic2layout.py >/dev/null 2>&1; then
    echo "ERROR: schematic2layout.py not found. Install ALIGN first:"
    echo "  cd ~/my_chip_designs && INSTALL_ALIGN=yes ./setup_env.sh"
    exit 1
fi

if [[ ! -d "$ALIGN_PDK_SKY130" ]]; then
    echo "ERROR: ALIGN sky130 PDK not found at $ALIGN_PDK_SKY130"
    echo "Set ALIGN_PDK_SKY130 to the SKY130_PDK directory from ALIGN-pdk-sky130."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/work"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "Running ALIGN on $SCRIPT_DIR/rc_filter.sp ..."
schematic2layout.py "$SCRIPT_DIR" -p "$ALIGN_PDK_SKY130" -c

echo "ALIGN run complete. Outputs are in $WORK_DIR"
echo "Look for *.gds and *.lef files."
