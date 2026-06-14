#!/usr/bin/env bash
# Run ALIGN to generate the RC filter layout using the Sky130 PDK that is
# bundled inside the repo-local ALIGN-public fork.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Prefer the repo-local ALIGN fork if it has been built.
LOCAL_ALIGN_VENV="$REPO_ROOT/ALIGN-public/.venv"
if [[ -f "$LOCAL_ALIGN_VENV/bin/activate" ]]; then
    echo "Using repo-local ALIGN from $LOCAL_ALIGN_VENV"
    # shellcheck source=/dev/null
    source "$LOCAL_ALIGN_VENV/bin/activate"
    export ALIGN_HOME="$REPO_ROOT/ALIGN-public"
else
    echo "Local ALIGN venv not found; falling back to system ALIGN."
fi

if ! command -v schematic2layout.py >/dev/null 2>&1; then
    echo "ERROR: schematic2layout.py not found. Install ALIGN first:"
    echo "  cd ~/my_chip_designs && INSTALL_ALIGN=yes ./setup_env.sh"
    exit 1
fi

LOCAL_PDK="$REPO_ROOT/ALIGN-public/pdks/SKY130_PDK"
if [[ ! -d "$LOCAL_PDK" ]]; then
    echo "ERROR: Local Sky130 PDK not found at $LOCAL_PDK"
    exit 1
fi

WORK_DIR="$SCRIPT_DIR/work"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "Running ALIGN on $SCRIPT_DIR/rc_filter.sp with local Sky130 PDK ..."
# Note: ALIGN's --skipGDS flag is a negative flag; passing it actually enables GDS output.
schematic2layout.py "$SCRIPT_DIR" -p "$LOCAL_PDK" -s RC_FILTER --skipGDS

echo "ALIGN run complete. Outputs are in $WORK_DIR"
echo "Look for *.gds and *.lef files."
