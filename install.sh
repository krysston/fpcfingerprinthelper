#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-quick}"

echo "[*] libfprint installer ($MODE mode)"

# ---------- helpers ----------
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "${ID:-unknown}"
    else
        echo "unknown"
    fi
}

detect_pkg_manager() {
    if command_exists pacman; then echo pacman; return; fi
    if command_exists apt; then echo apt; return; fi
    if command_exists dnf; then echo dnf; return; fi
    if command_exists zypper; then echo zypper; return; fi
    echo unknown
}

detect_fpc_sensor() {
    if ! command_exists lsusb; then
        return 1
    fi

    if lsusb | grep -qiE 'fingerprint|fpc'; then
        return 0
    else
        return 1
    fi
}

install_arch_fpc() {
    echo "[*] Installing libfprint-fpcmoh-git (AUR)"

    sudo pacman -S --needed --noconfirm base-devel git

    TMPDIR="$(mktemp -d)"
    git clone https://aur.archlinux.org/libfprint-fpcmoh-git.git "$TMPDIR"
    cd "$TMPDIR"
    makepkg -si --noconfirm
}

install_libfprint() {
    case "$1" in
        pacman)
            sudo pacman -S --needed --noconfirm libfprint fprintd
            ;;
        apt)
            sudo apt update
            sudo apt install -y libfprint-2-2 fprintd
            ;;
        dnf)
            sudo dnf install -y libfprint fprintd
            ;;
        zypper)
            sudo zypper install -y libfprint fprintd
            ;;
        *)
            echo "[!] Unsupported package manager"
            exit 1
            ;;
    esac
}

# ---------- main ----------
DISTRO="$(detect_distro)"
PKG_MANAGER="$(detect_pkg_manager)"

echo "[*] Detected distro: $DISTRO"
echo "[*] Package manager: $PKG_MANAGER"

HAS_FPC=false
if detect_fpc_sensor; then
    HAS_FPC=true
    echo "[*] FPC fingerprint sensor detected"
else
    echo "[*] No FPC fingerprint sensor detected"
fi

if [ "$MODE" = "advanced" ]; then
    echo
    echo "Advanced options:"
    echo "1) Force libfprint"
    echo "2) Force libfprint-fpcmoh-git (Arch only)"
    echo "3) Auto (recommended)"
    read -rp "Select option [1-3]: " CHOICE
else
    CHOICE=3
fi

case "$CHOICE" in
    1)
        install_libfprint "$PKG_MANAGER"
        ;;
    2)
        if [ "$PKG_MANAGER" != "pacman" ]; then
            echo "[!] fpcmoh only works on Arch-based systems"
            exit 1
        fi
        install_arch_fpc
        ;;
    3)
        if [ "$PKG_MANAGER" = "pacman" ] && [ "$HAS_FPC" = true ]; then
            install_arch_fpc
        else
            install_libfprint "$PKG_MANAGER"
        fi
        ;;
    *)
        echo "[!] Invalid choice"
        exit 1
        ;;
esac

echo
echo "[✓] Done"
echo "Run: fprintd-enroll"
