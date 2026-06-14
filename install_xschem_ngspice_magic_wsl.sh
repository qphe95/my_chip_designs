#!/usr/bin/env bash
#
# install_xschem_ngspice_wsl.sh
# Installs xschem (schematic capture), ngspice (circuit simulator), and
# Magic (VLSI layout editor) on WSL.
# Supports Debian/Ubuntu. Other distros fall back to source builds.
#
set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
BUILD_DIR="${BUILD_DIR:-$HOME/.local/src/xschem_ngspice_build}"
USE_PACKAGE_MANAGER="${USE_PACKAGE_MANAGER:-auto}"   # auto | only | no

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

    ./configure \
        --prefix="$INSTALL_PREFIX"

    make -j"$(nproc)"
    sudo make install
    sudo ldconfig
}

install_magic() {
    if command_exists magic; then
        log_info "Magic already installed: $(magic --version 2>&1 | head -1)"
        return 0
    fi

    if [[ "$USE_PACKAGE_MANAGER" == "auto" || "$USE_PACKAGE_MANAGER" == "only" ]]; then
        if install_magic_from_package; then
            log_info "Magic installed from package manager."
            return 0
        fi
    fi

    if [[ "$USE_PACKAGE_MANAGER" == "only" ]]; then
        log_error "Package-manager install failed and USE_PACKAGE_MANAGER=only."
        return 1
    fi

    build_magic_from_source
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
    log_info "Installing xschem + ngspice + magic on WSL..."
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
    setup_xschem_env

    log_info "Installation complete. Verifying binaries..."
    echo "---"
    command -v ngspice && ngspice --version 2>&1 | head -3 || log_warn "ngspice not in PATH"
    echo "---"
    command -v xschem && xschem --version 2>&1 | head -3 || log_warn "xschem not in PATH"
    echo "---"
    command -v magic && magic --version 2>&1 | head -3 || log_warn "magic not in PATH"
    echo "---"
    log_info "Please restart your shell or run: source ~/.bashrc"
}

main "$@"
