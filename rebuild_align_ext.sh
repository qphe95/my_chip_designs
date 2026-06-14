#!/usr/bin/env bash
# Fast incremental rebuild of ALIGN's compiled C++ extension.
#
# The repo-local ALIGN is installed in editable mode, so Python source changes
# are picked up automatically.  C++ changes in PlaceRouteHierFlow (and its
# dependencies) must be rebuilt.  This script runs ninja in the existing
# scikit-build cmake-build directory and symlinks the resulting PnR extension
# next to ALIGN's Python sources so it is picked up immediately.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALIGN_SRC="$SCRIPT_DIR/ALIGN-public"
VENV_DIR="$ALIGN_SRC/.venv"

if [[ ! -d "$ALIGN_SRC" ]]; then
    echo "ERROR: ALIGN source not found at $ALIGN_SRC"
    exit 1
fi

if [[ ! -f "$VENV_DIR/bin/activate" ]]; then
    echo "ERROR: ALIGN venv not found at $VENV_DIR"
    echo "Run: cd $SCRIPT_DIR && INSTALL_ALIGN=yes ./setup_env.sh"
    exit 1
fi

BUILD_DIR=$(find "$ALIGN_SRC/_skbuild" -path '*/cmake-build' -type d -print -quit 2>/dev/null)
if [[ -z "$BUILD_DIR" ]]; then
    echo "ERROR: ALIGN cmake-build directory not found under $ALIGN_SRC/_skbuild"
    echo "Run a full install first: cd $SCRIPT_DIR && INSTALL_ALIGN=yes ./setup_env.sh"
    exit 1
fi

echo "Incremental rebuild in $BUILD_DIR ..."
cd "$BUILD_DIR"
ninja

BUILT_SO=$(find "$BUILD_DIR/PlaceRouteHierFlow" -name 'PnR.*.so' -type f -print -quit 2>/dev/null)
if [[ -z "$BUILT_SO" ]]; then
    echo "ERROR: Built PnR extension not found in $BUILD_DIR/PlaceRouteHierFlow"
    exit 1
fi

ALIGN_SO="$ALIGN_SRC/align/$(basename "$BUILT_SO")"
rm -f "$ALIGN_SO"
ln -s "$(realpath --relative-to="$ALIGN_SRC/align" "$BUILT_SO")" "$ALIGN_SO"

echo "Linked $ALIGN_SO -> $BUILT_SO"
echo "C++ extension rebuild complete."
