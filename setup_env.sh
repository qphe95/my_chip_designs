#!/usr/bin/env bash
#
# setup_env.sh
# Installs xschem (schematic capture), ngspice (circuit simulator),
# Magic (VLSI layout editor), netgen (LVS), the SkyWater 130 nm open PDK,
# and (optionally) ALIGN (open-source analog layout generator) on WSL.
# Supports Debian/Ubuntu. Other distros fall back to source builds.
#
# Optional environment variables:
#   INSTALL_ALIGN=no        # skip ALIGN install (default is yes)
#
set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
BUILD_DIR="${BUILD_DIR:-$HOME/.local/src/xschem_ngspice_build}"
USE_PACKAGE_MANAGER="${USE_PACKAGE_MANAGER:-auto}"   # auto | only | no
INSTALL_SKY130_PDK="${INSTALL_SKY130_PDK:-yes}"      # yes | no
INSTALL_ALIGN="${INSTALL_ALIGN:-yes}"                # yes | no (builds ALIGN analog P&R from source)
INSTALL_NETGEN="${INSTALL_NETGEN:-yes}"              # yes | no (installs netgen LVS tool)

# Ensure locally-built tools take precedence over distro packages.
export PATH="$INSTALL_PREFIX/bin:$PATH"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Compare two dotted version strings. Returns 0 if $1 >= $2.
version_ge() {
    local v1 v2
    # Normalize to three numeric components (e.g., 8.3 -> 8.3.0)
    v1=$(echo "$1" | awk -F. '{printf "%d.%d.%d", $1, $2, ($3==""?0:$3)}')
    v2=$(echo "$2" | awk -F. '{printf "%d.%d.%d", $1, $2, ($3==""?0:$3)}')
    # If v1 >= v2, then sorting [v2, v1] is already in ascending order.
    printf '%s\n%s\n' "$v2" "$v1" | sort -V -C
}

# WSL sometimes has trouble with IPv6 during apt update.
fix_wsl_apt_hang() {
    log_info "Applying WSL apt hang workaround (prefer IPv4)..."
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1 || true
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1 || true
    if ! grep -q "Acquire::ForceIPv4" /etc/apt/apt.conf.d/99force-ipv4 2>/dev/null; then
        echo 'Acquire::ForceIPv4 "true";' | sudo tee /etc/apt/apt.conf.d/99force-ipv4 >/dev/null
    fi
}

# -----------------------------------------------------------------------------
# Install dependencies
# -----------------------------------------------------------------------------
install_build_deps_debian() {
    log_info "Installing build dependencies..."
    sudo apt-get install -y \
        build-essential git autoconf automake libtool pkg-config \
        libx11-dev libxpm-dev libxext-dev libxft-dev libfontconfig1-dev \
        libxrender-dev tcl-dev tk-dev \
        libcairo2-dev libjpeg-dev zlib1g-dev flex bison libreadline-dev \
        libncurses-dev libngspice0-dev libblas-dev liblapack-dev \
        libglu1-mesa-dev libgl1-mesa-dev mesa-common-dev \
        wget curl ca-certificates
}

install_build_deps_rhel() {
    log_info "Installing build dependencies (RHEL/Fedora)..."
    sudo dnf groupinstall -y "Development Tools" || true
    sudo dnf install -y \
        git autoconf automake libtool pkgconfig \
        libX11-devel libXpm-devel libXext-devel libXft-devel fontconfig-devel \
        libXrender-devel tcl-devel tk-devel cairo-devel libjpeg-turbo-devel \
        zlib-devel flex bison readline-devel ncurses-devel \
        mesa-libGLU-devel mesa-libGL-devel \
        wget curl blas-devel lapack-devel
}

install_build_deps() {
    local distro
    distro=$(detect_distro)
    case "$distro" in
        ubuntu|debian|linuxmint|pop) install_build_deps_debian ;;
        fedora|rhel|centos|rocky|almalinux|opensuse*) install_build_deps_rhel ;;
        *)
            log_warn "Unknown distro '$distro'. Attempting Debian-style dependencies."
            install_build_deps_debian || true
            ;;
    esac
}

# -----------------------------------------------------------------------------
# ngspice installation
# -----------------------------------------------------------------------------
install_ngspice_from_package() {
    log_info "Attempting to install ngspice via package manager..."
    local distro
    distro=$(detect_distro)
    case "$distro" in
        ubuntu|debian|linuxmint|pop)
            sudo apt-get install -y ngspice libngspice0 libngspice0-dev
            ;;
        fedora|rhel|centos|rocky|almalinux)
            sudo dnf install -y ngspice ngspice-devel
            ;;
        opensuse*)
            sudo zypper install -y ngspice ngspice-devel
            ;;
        *)
            return 1
            ;;
    esac
}

build_ngspice_from_source() {
    local version="${NGSPICE_VERSION:-44}"
    local src_dir="$BUILD_DIR/ngspice-$version"

    log_info "Building ngspice $version from source..."
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    if [[ ! -d "$src_dir" ]]; then
        wget -q --show-progress "https://github.com/ngspice/ngspice/archive/refs/tags/ngspice-$version.tar.gz" \
            -O "ngspice-$version.tar.gz" || \
        wget -q --show-progress "https://sourceforge.net/projects/ngspice/files/ng-spice-rework/$version/ngspice-$version.tar.gz/download" \
            -O "ngspice-$version.tar.gz"
        tar -xzf "ngspice-$version.tar.gz"
        mv "ngspice-ngspice-$version" "$src_dir" 2>/dev/null || true
    fi

    cd "$src_dir"
    ./autogen.sh || true
    mkdir -p build
    cd build
    ../configure \
        --prefix="$INSTALL_PREFIX" \
        --with-x \
        --with-readline=yes \
        --enable-xspice \
        --enable-cider \
        --with-ngshared \
        --enable-openmp
    make -j"$(nproc)"
    sudo make install
    sudo ldconfig
}

install_ngspice() {
    if command_exists ngspice; then
        log_info "ngspice already installed: $(ngspice --version 2>&1 | head -1)"
        return 0
    fi

    if [[ "$USE_PACKAGE_MANAGER" == "auto" || "$USE_PACKAGE_MANAGER" == "only" ]]; then
        if install_ngspice_from_package; then
            log_info "ngspice installed from package manager."
            return 0
        fi
    fi

    if [[ "$USE_PACKAGE_MANAGER" == "only" ]]; then
        log_error "Package-manager install failed and USE_PACKAGE_MANAGER=only."
        return 1
    fi

    build_ngspice_from_source
}

# -----------------------------------------------------------------------------
# xschem installation
# -----------------------------------------------------------------------------
install_xschem_from_package() {
    log_info "Attempting to install xschem via package manager..."
    local distro
    distro=$(detect_distro)
    case "$distro" in
        ubuntu|debian|linuxmint|pop)
            sudo apt-get install -y xschem xschem-library
            ;;
        fedora)
            sudo dnf install -y xschem xschem-libs
            ;;
        *)
            return 1
            ;;
    esac
}

build_xschem_from_source() {
    log_info "Building xschem from source..."
    local src_dir="$BUILD_DIR/xschem"

    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    if [[ ! -d "$src_dir" ]]; then
        git clone https://github.com/StefanSchippers/xschem.git "$src_dir"
    fi

    cd "$src_dir"
    git pull

    # xschem uses a configure script generated from configure.in
    if [[ ! -x configure ]]; then
        autoreconf -fi
    fi

    ./configure \
        --prefix="$INSTALL_PREFIX"

    make -j"$(nproc)"
    sudo make install
    sudo ldconfig
}

install_xschem() {
    if command_exists xschem; then
        log_info "xschem already installed: $(xschem --version 2>&1 | head -1)"
        return 0
    fi

    if [[ "$USE_PACKAGE_MANAGER" == "auto" || "$USE_PACKAGE_MANAGER" == "only" ]]; then
        if install_xschem_from_package; then
            log_info "xschem installed from package manager."
            return 0
        fi
    fi

    if [[ "$USE_PACKAGE_MANAGER" == "only" ]]; then
        log_error "Package-manager install failed and USE_PACKAGE_MANAGER=only."
        return 1
    fi

    build_xschem_from_source
}

# -----------------------------------------------------------------------------
# Magic installation
# -----------------------------------------------------------------------------
install_magic_from_package() {
    log_info "Attempting to install Magic via package manager..."
    local distro
    distro=$(detect_distro)
    case "$distro" in
        ubuntu|debian|linuxmint|pop)
            sudo apt-get install -y magic
            ;;
        fedora)
            sudo dnf install -y magic
            ;;
        opensuse*)
            sudo zypper install -y magic
            ;;
        *)
            return 1
            ;;
    esac
}

remove_old_magic_package() {
    log_info "Removing old distro magic package to avoid conflicts..."
    local distro
    distro=$(detect_distro)
    case "$distro" in
        ubuntu|debian|linuxmint|pop)
            if dpkg -l magic 2>/dev/null | grep -q '^ii'; then
                sudo apt-get remove -y magic || true
            fi
            ;;
        fedora|rhel|centos|rocky|almalinux)
            if rpm -q magic >/dev/null 2>&1; then
                sudo dnf remove -y magic || true
            fi
            ;;
    esac
}

build_magic_from_source() {
    log_info "Building Magic from source..."
    local src_dir="$BUILD_DIR/magic"

    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    if [[ ! -d "$src_dir" ]]; then
        git clone https://github.com/RTimothyEdwards/magic.git "$src_dir"
    fi

    cd "$src_dir"
    git pull

    # Clean previous build state if any
    make clean >/dev/null 2>&1 || true

    ./configure \
        --prefix="$INSTALL_PREFIX"

    make -j"$(nproc)"
    sudo make install
    sudo ldconfig
}

magic_version() {
    # "Magic 8.3 revision 105" -> "8.3.105"
    magic --version 2>&1 | head -1 | sed -E 's/.*Magic ([0-9]+)\.([0-9]+) revision ([0-9]+).*/\1.\2.\3/'
}

install_magic() {
    local required="8.3.411"
    local current

    if command_exists magic; then
        current=$(magic_version)
        if version_ge "$current" "$required"; then
            log_info "Magic $current already installed (>= $required required)."
            return 0
        else
            log_warn "Magic $current is too old; sky130 PDK requires >= $required."
        fi
    fi

    # The Ubuntu/Debian magic package is too old for the current sky130 PDK.
    # Remove it and build a current version from source.
    remove_old_magic_package
    build_magic_from_source

    # Verify the new binary is usable.
    current=$(magic_version)
    if ! version_ge "$current" "$required"; then
        log_error "Magic source build failed: got $current, need >= $required"
        return 1
    fi
    log_info "Magic $current built and installed from source."
}

# -----------------------------------------------------------------------------
# netgen (LVS) installation
# -----------------------------------------------------------------------------
install_netgen_from_package() {
    log_info "Attempting to install netgen via package manager..."
    local distro
    distro=$(detect_distro)
    case "$distro" in
        ubuntu|debian|linuxmint|pop)
            sudo apt-get install -y netgen-lvs
            ;;
        fedora)
            sudo dnf install -y netgen-lvs
            ;;
        opensuse*)
            sudo zypper install -y netgen-lvs
            ;;
        *)
            return 1
            ;;
    esac
}

build_netgen_from_source() {
    log_info "Building netgen from source..."
    local src_dir="$BUILD_DIR/netgen"

    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    if [[ ! -d "$src_dir" ]]; then
        git clone https://github.com/RTimothyEdwards/netgen.git "$src_dir"
    fi

    cd "$src_dir"
    git pull

    make clean >/dev/null 2>&1 || true

    ./configure \
        --prefix="$INSTALL_PREFIX"

    make -j"$(nproc)"
    sudo make install
    sudo ldconfig
}

install_netgen() {
    if [[ "$INSTALL_NETGEN" != "yes" ]]; then
        log_info "Skipping netgen install (INSTALL_NETGEN=$INSTALL_NETGEN)."
        return 0
    fi

    if command_exists netgen-lvs; then
        log_info "netgen-lvs already installed: $(netgen-lvs --version 2>&1 | head -1)"
        return 0
    fi

    if command_exists netgen; then
        log_info "netgen already installed: $(netgen --version 2>&1 | head -1)"
        return 0
    fi

    if [[ "$USE_PACKAGE_MANAGER" == "auto" || "$USE_PACKAGE_MANAGER" == "only" ]]; then
        if install_netgen_from_package; then
            log_info "netgen installed from package manager."
            return 0
        fi
    fi

    if [[ "$USE_PACKAGE_MANAGER" == "only" ]]; then
        log_error "Package-manager install failed and USE_PACKAGE_MANAGER=only."
        return 1
    fi

    build_netgen_from_source

    if command_exists netgen || command_exists netgen-lvs; then
        log_info "netgen built and installed from source."
    else
        log_error "netgen source build failed."
        return 1
    fi
}

# -----------------------------------------------------------------------------
# SkyWater 130 nm PDK installation
# -----------------------------------------------------------------------------
sky130_tech_file() {
    echo "$INSTALL_PREFIX/share/pdk/sky130A/libs.tech/magic/sky130A.tech"
}

install_sky130_pdk() {
    local tech_file
    tech_file=$(sky130_tech_file)

    if [[ -f "$tech_file" ]]; then
        log_info "SkyWater 130 nm PDK already installed: $tech_file"
        return 0
    fi

    if [[ "$INSTALL_SKY130_PDK" != "yes" ]]; then
        log_info "Skipping SkyWater 130 nm PDK install (INSTALL_SKY130_PDK=$INSTALL_SKY130_PDK)"
        return 0
    fi

    log_info "Installing SkyWater 130 nm PDK via open_pdks..."
    log_warn "This downloads several GB and may take 30-60 minutes."

    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    local src_dir="$BUILD_DIR/open_pdks"
    local tag="${OPEN_PDKS_TAG:-1.0.99}"

    if [[ ! -d "$src_dir" ]]; then
        git clone https://github.com/RTimothyEdwards/open_pdks.git "$src_dir"
    fi

    cd "$src_dir"
    git fetch --tags
    git checkout "$tag"

    # Patch foundry_install.py to enable 'gds ordering on' before reading GDS.
    # This prevents Magic from crashing on GDS files where cells are referenced
    # before they are defined (common in the sky130 I/O library).
    SRC_DIR="$src_dir" python3 - <<'PY'
import os, re
src_dir = os.environ['SRC_DIR']
with open(f"{src_dir}/common/foundry_install.py", "r") as f:
    content = f.read()

# Add 'gds ordering on' after 'gds rescale false' in GDS-to-mag scripts.
# Match the original indentation so the inserted line is aligned correctly.
if "gds ordering on" not in content:
    def add_gds_ordering(match):
        indent = match.group(1)
        return match.group(0) + f"\n{indent}print('gds ordering on', file=ofile)"

    content = re.sub(
        r"^(\s*)print\('gds rescale false', file=ofile\)$",
        add_gds_ordering,
        content,
        flags=re.MULTILINE
    )

with open(f"{src_dir}/common/foundry_install.py", "w") as f:
    f.write(content)
PY

    # Fix a bug in open_pdks 1.0.99 configure where the auto-download check
    # compares FOUND against the wrong string and recursively calls itself,
    # so sky130 is never downloaded.
    SRC_DIR="$src_dir" python3 - <<'PY'
import os
src_dir = os.environ['SRC_DIR']
with open(f"{src_dir}/scripts/configure", "r") as f:
    content = f.read()

# Replace the broken check and recursive call with the correct download call.
content = content.replace(
    'if [ "$FOUND" = "sky130" ]; then\n                echo "Could not found sky130 in standard search paths, manually downloading to ../pdks/sky130 ..."\n                pdk_find\n            fi',
    'if [ "$FOUND" = "0" ]; then\n                echo "Could not find sky130 in standard search paths, downloading to ../pdks/sky130 ..."\n                pdk_get\n            fi'
)

with open(f"{src_dir}/scripts/configure", "w") as f:
    f.write(content)
PY

    # Use system Python (not a venv) because open_pdks configure needs distutils.
    PYTHON=/usr/bin/python3 ./configure \
        --enable-sky130-pdk \
        --with-sky130-local-path="$INSTALL_PREFIX/share/pdk" \
        --prefix="$INSTALL_PREFIX"

    # Clean previous partial build so stale generated files are regenerated
    # with the correct Magic version.
    make clean >/dev/null 2>&1 || true

    make -j"$(nproc)"
    sudo make install

    if [[ -f "$tech_file" ]]; then
        log_info "SkyWater 130 nm PDK installed successfully."
    else
        log_error "SkyWater 130 nm PDK install may have failed; $tech_file not found."
        return 1
    fi
}

# -----------------------------------------------------------------------------
# ALIGN analog layout generator installation
# -----------------------------------------------------------------------------
install_align_build_deps() {
    log_info "Installing ALIGN build dependencies..."
    local distro
    distro=$(detect_distro)
    case "$distro" in
        ubuntu|debian|linuxmint|pop)
            sudo apt-get install -y \
                cmake ninja-build python3-venv python3-dev \
                libboost-all-dev lp-solve liblpsolve55-dev
            ;;
        fedora|rhel|centos|rocky|almalinux)
            sudo dnf install -y \
                cmake ninja-build python3-virtualenv python3-devel \
                boost-devel lp_solve lp_solve-devel
            ;;
        *)
            log_warn "Unknown distro '$distro'. Attempting Debian-style ALIGN deps."
            sudo apt-get install -y \
                cmake ninja-build python3-venv python3-dev \
                libboost-all-dev lp-solve liblpsolve55-dev || true
            ;;
    esac
}

install_align() {
    if [[ "$INSTALL_ALIGN" != "yes" ]]; then
        log_info "Skipping ALIGN install (INSTALL_ALIGN=$INSTALL_ALIGN)."
        return 0
    fi

    # Use the repo-local ALIGN-public fork instead of cloning from GitHub.
    local script_path
    script_path=$(readlink -f "${BASH_SOURCE[0]}")
    local repo_root
    repo_root=$(dirname "$script_path")
    local align_src="$repo_root/ALIGN-public"
    local venv_dir="$align_src/.venv"

    if [[ ! -d "$align_src" ]]; then
        log_error "Local ALIGN source not found at $align_src."
        log_error "Clone or place your ALIGN fork in $align_src and re-run."
        return 1
    fi

    # Use the Sky130 PDK that is bundled with the repo-local ALIGN fork.
    local pdk_src="$align_src/pdks"

    if [[ ! -d "$pdk_src/SKY130_PDK" ]]; then
        log_error "Local Sky130 PDK not found at $pdk_src/SKY130_PDK."
        return 1
    fi

    # Patch the bundled Sky130 PDK layers.json so the resistor primitive
    # generator can read the metal pitch/width values it expects from the Cap
    # layer, and the capacitor layers have direction information for the DRC
    # engine. This is idempotent, so run it every time.
    PDK_DIR="$pdk_src/SKY130_PDK" python3 - <<'PY'
import json
import os
pdk_dir = os.environ['PDK_DIR']
path = os.path.join(pdk_dir, 'layers.json')
with open(path) as f:
    data = json.load(f)

metal = {}
for layer in data['Abstraction']:
    name = layer.get('Layer')
    if name in ('M1', 'M2', 'M3'):
        metal[name] = layer

for layer in data['Abstraction']:
    name = layer.get('Layer')
    if name == 'Cap':
        layer.setdefault('m1Pitch', metal['M1']['Pitch'])
        layer.setdefault('m1Width', metal['M1']['Width'])
        layer.setdefault('m2Pitch', metal['M2']['Pitch'])
        layer.setdefault('m2Width', metal['M2']['Width'])
        layer.setdefault('m3Pitch', metal['M3']['Pitch'])
        layer.setdefault('m3Width', metal['M3']['Width'])
    elif name == 'CapMIMLayer':
        layer.setdefault('Direction', 'V')
        layer.setdefault('Pitch', metal['M3']['Pitch'])
        layer.setdefault('Width', metal['M3']['Width'])
    elif name == 'CapMIMContact':
        layer.setdefault('Direction', '*')

with open(path, 'w') as f:
    json.dump(data, f, indent=2)
PY

    if [[ -x "$venv_dir/bin/schematic2layout.py" ]]; then
        log_info "Local ALIGN already installed in $venv_dir."
        log_info "Remove $venv_dir to force a rebuild from source."
        return 0
    fi

    log_info "Installing repo-local ALIGN analog layout generator..."
    log_warn "This builds ALIGN from $align_src. It may take 15-30 minutes."

    install_align_build_deps

    # Create a dedicated Python venv inside the local ALIGN source tree.
    python3 -m venv "$venv_dir"
    # shellcheck source=/dev/null
    source "$venv_dir/bin/activate"

    pip install --upgrade pip setuptools wheel

    # Install ALIGN's Python dependencies. Some version pins are relaxed so the
    # install works on newer distributions (e.g. Python 3.12).
    pip install \
        pybind11 scikit-build cmake ninja \
        'networkx>=2.4' python-gdsii gdspy pyyaml \
        'pydantic>=1.9.2,<2' z3-solver mip more-itertools \
        colorlog plotly numpy pandas werkzeug dash \
        typing_extensions memory_profiler flatdict \
        pytest pytest-cov pytest-xdist pytest-timeout \
        pytest-rerunfailures pytest-cpp

    # Build and install ALIGN in editable mode from the local source so that
    # Python changes made to ALIGN-public are picked up without re-running
    # setup_env.sh. Editable scikit-build installs do not copy the compiled
    # extension next to the source, so copy it after the build finishes.
    cd "$align_src"
    pip install -v -e . --no-build-isolation

    local built_so
    built_so=$(find "$align_src/_skbuild" -path '*/cmake-build/PlaceRouteHierFlow/PnR.*.so' -print -quit 2>/dev/null)
    if [[ -n "$built_so" ]]; then
        local align_so="$align_src/align/$(basename "$built_so")"
        rm -f "$align_so"
        ln -s "$(realpath --relative-to="$align_src/align" "$built_so")" "$align_so"
        log_info "Linked compiled ALIGN extension: $align_so"
    else
        log_warn "Could not locate compiled ALIGN extension (PnR.*.so) to link."
    fi

    deactivate

    # Create a system wrapper that activates the local ALIGN venv.
    sudo tee "$INSTALL_PREFIX/bin/schematic2layout.py" >/dev/null <<EOF
#!/usr/bin/env bash
# Wrapper for ALIGN's schematic2layout.py. Activates the repo-local ALIGN venv.
source "$venv_dir/bin/activate"
exec "$venv_dir/bin/schematic2layout.py" "\$@"
EOF
    sudo chmod +x "$INSTALL_PREFIX/bin/schematic2layout.py"

    # Create an environment setup snippet for the user's shell.
    local shell_rc="$HOME/.bashrc"
    [[ "$SHELL" == */zsh ]] && shell_rc="$HOME/.zshrc"
    local marker="# ALIGN environment"
    if ! grep -q "$marker" "$shell_rc" 2>/dev/null; then
        cat >> "$shell_rc" <<EOF

$marker
export ALIGN_HOME="$align_src"
export ALIGN_PDK_SKY130="$pdk_src/SKY130_PDK"
export PATH="$INSTALL_PREFIX/bin:\$PATH"
EOF
        log_info "Added ALIGN environment variables to $shell_rc"
    fi

    if command_exists schematic2layout.py; then
        log_info "Local ALIGN installed successfully from $align_src."
    else
        log_error "ALIGN install failed; schematic2layout.py not found in PATH."
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Post-install: set up xschem environment
# -----------------------------------------------------------------------------
setup_xschem_env() {
    log_info "Setting up xschem environment..."

    local shell_rc="$HOME/.bashrc"
    [[ "$SHELL" == */zsh ]] && shell_rc="$HOME/.zshrc"

    local marker="# xschem environment"
    if ! grep -q "$marker" "$shell_rc" 2>/dev/null; then
        cat >> "$shell_rc" << EOF

$marker
export PATH="$INSTALL_PREFIX/bin:\$PATH"
export XSCHEM_SHAREDIR="$INSTALL_PREFIX/share/xschem"
export XSCHEM_LIBRARY_PATH="$INSTALL_PREFIX/share/xschem/xschem_library/devices:$INSTALL_PREFIX/share/pdk"
EOF
        log_info "Added xschem environment variables to $shell_rc"
    else
        log_info "xschem environment already present in $shell_rc"
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    log_info "Installing xschem + ngspice + magic + netgen + sky130 PDK on WSL..."
    log_info "Detected distro: $(detect_distro)"

    fix_wsl_apt_hang

    local distro
    distro=$(detect_distro)
    case "$distro" in
        ubuntu|debian|linuxmint|pop)
            log_info "Updating package lists..."
            sudo apt-get update || log_warn "apt-get update failed, continuing anyway..."
            ;;
    esac

    install_build_deps
    install_ngspice
    install_xschem
    install_magic
    install_netgen
    install_sky130_pdk
    install_align
    setup_xschem_env

    log_info "Installation complete. Verifying binaries..."
    echo "---"
    command -v ngspice && ngspice --version 2>&1 | head -3 || log_warn "ngspice not in PATH"
    echo "---"
    command -v xschem && xschem --version 2>&1 | head -3 || log_warn "xschem not in PATH"
    echo "---"
    command -v magic && magic --version 2>&1 | head -3 || log_warn "magic not in PATH"
    echo "---"
    command -v netgen-lvs && netgen-lvs --version 2>&1 | head -3 || \
        command -v netgen && netgen --version 2>&1 | head -3 || \
        log_warn "netgen not in PATH"
    echo "---"
    if [[ -f $(sky130_tech_file) ]]; then
        log_info "Sky130 PDK OK: $(sky130_tech_file)"
    else
        log_warn "Sky130 PDK not found at $(sky130_tech_file)"
    fi
    echo "---"
    if [[ "$INSTALL_ALIGN" == "yes" ]]; then
        command -v schematic2layout.py && schematic2layout.py -h 2>&1 | head -3 || log_warn "schematic2layout.py not in PATH"
        echo "---"
    fi
    log_info "Please restart your shell or run: source ~/.bashrc"
}

main "$@"
