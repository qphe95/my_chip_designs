#!/usr/bin/env bash
# Run ALIGN to generate the RC filter layout using the custom Sky130
# passive generators stored in this repo.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CUSTOM_PDK_WRAPPER="$REPO_ROOT/align_pdk_sky130_custom/align_with_custom_pdk.py"

if [[ ! -x "$CUSTOM_PDK_WRAPPER" ]]; then
    echo "ERROR: Custom PDK wrapper not found at $CUSTOM_PDK_WRAPPER"
    exit 1
fi

if ! command -v schematic2layout.py >/dev/null 2>&1; then
    echo "ERROR: schematic2layout.py not found. Install ALIGN first:"
    echo "  cd ~/my_chip_designs && INSTALL_ALIGN=yes ./setup_env.sh"
    exit 1
fi

WORK_DIR="$SCRIPT_DIR/work"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "Running ALIGN on $SCRIPT_DIR/rc_filter.sp with custom Sky130 generators ..."
"$CUSTOM_PDK_WRAPPER" "$SCRIPT_DIR" -s RC_FILTER

echo "ALIGN run complete. Outputs are in $WORK_DIR"
echo "Look for *.gds and *.lef files."
