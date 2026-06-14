#!/usr/bin/env bash
# run_layout.sh
# Generates the rc_filter Magic layout (.mag) and GDS output.
# Requires Magic VLSI and the sky130A PDK to be installed.

set -euo pipefail

if ! command -v magic >/dev/null 2>&1; then
    echo "ERROR: Magic is not installed."
    echo "Run: cd ~/my_chip_designs && ./setup_env.sh"
    exit 1
fi

# Check that sky130A technology is available
cat > /tmp/check_sky130.tcl <<'EOF'
if {[catch {tech load sky130A} err]} {
    puts "MISSING"
} else {
    puts "OK"
}
quit
EOF

TECH_STATUS=$(magic -dnull -noconsole /tmp/check_sky130.tcl 2>/dev/null | tail -1 || echo "MISSING")
if [[ "$TECH_STATUS" != "OK" ]]; then
    echo "ERROR: sky130A technology not found in Magic."
    echo "Install the SkyWater 130 nm PDK:"
    echo "  cd ~/.local/src"
    echo "  git clone https://github.com/RTimothyEdwards/open_pdks.git"
    echo "  cd open_pdks"
    echo "  ./configure --enable-sky130-pdk --prefix=/usr/local"
    echo "  make"
    echo "  sudo make install"
    exit 1
fi

echo "Generating rc_filter layout..."
magic -dnull -noconsole generate_layout.tcl

echo "Done. Files generated:"
ls -l rc_filter.mag rc_filter.gds 2>/dev/null || true
