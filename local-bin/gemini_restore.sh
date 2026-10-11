#!/usr/bin/env bash
# @DESC: Restore Debian 13 configuration backed up by gemini_backup.sh
# @TAGS: GIT, xfce, etc, config restore
# @USAGE: gemini_restore.sh 
set -u

BACKUP_DIR="/home/lwh/git/dotfiles"
TARGET_USER="lwh"
 
SYSTEM_PATHS=(
    /etc/apt
    /etc/bluetooth
    /etc/conky
    /etc/cups
    /etc/lightdm
    /etc/pam.d
    /etc/ssh/sshd_config
    /etc/ufw
    /etc/hosts
    /etc/network
    /etc/xdg
)
 
ASSUME_YES=0   # -y : auto-answer prompts (the /etc restore prompts default to "N")
ASSUME_ALL=0   # -a : together with -y, also approve the default-"N" prompts
 
for arg in "$@"; do
    case "$arg" in
        -y|--yes) ASSUME_YES=1 ;;
        -a|--all) ASSUME_ALL=1 ;;
        -h|--help)
            sed -n '2,4p' "$0" | sed 's/^# //'
            exit 0
            ;;
        *) BACKUP_DIR="$arg" ;;
    esac
done
 
SAFE_DIR="/var/backups/restore-$(date +%Y%m%d-%H%M%S)"   # existing /etc files are kept here before overwrite
FAILED=()
 
# ------------------------------------------------------------------
# Utilities
# ------------------------------------------------------------------
warn() { echo "  ⚠ $*"; }
 
# confirm "question" [default y|n]
confirm() {
    local prompt="$1" def="${2:-y}" ans hint="[y/N]"
    [ "$def" = "y" ] && hint="[Y/n]"
 
    if [ "$ASSUME_YES" -eq 1 ]; then
        # Default-"N" (risky) items are only auto-approved together with -a
        [ "$def" = "n" ] && [ "$ASSUME_ALL" -eq 0 ] && return 1
        return 0
    fi
 
    read -r -p "  $prompt $hint " ans
    [[ "${ans:-$def}" =~ ^[Yy] ]]
}
 
# restore_system_path /etc/apt
# Restores $BACKUP_DIR/etc/apt -> /etc/apt (existing files are saved to $SAFE_DIR first)
restore_system_path() {
    local dst="$1"
    local src="$BACKUP_DIR$dst"
    local rsync_src="$src" rsync_dst="$dst"

    if [ ! -e "$src" ]; then
        echo "  - $dst : not in backup, skipping."
        return 0
    fi

    # Save the existing files first
    if [ -e "$dst" ]; then
        sudo mkdir -p "$SAFE_DIR$(dirname "$dst")"
        if ! sudo cp -a "$dst" "$SAFE_DIR$(dirname "$dst")/"; then
            warn "Failed to back up existing $dst - skipping restore for safety."
            FAILED+=("backup:$dst")
            return 1
        fi
    fi

    # Directories are synced by contents, single files are copied as-is
    if [ -d "$src" ]; then
        rsync_src="$src/"
        rsync_dst="$dst/"
        sudo mkdir -p "$dst"
    else
        sudo mkdir -p "$(dirname "$dst")"
    fi

    if sudo rsync -a --chown=root:root "$rsync_src" "$rsync_dst"; then
        echo "  - $dst : restored"
    else
        warn "Failed to restore $dst"
        FAILED+=("restore:$dst")
        return 1
    fi
}
 
# sync_user_dir <backup subdir> <destination dir>
sync_user_dir() {
    local src="$BACKUP_DIR/$1" dst="$2"
 
    if [ ! -d "$src" ]; then
        echo "  - No $1 backup, skipping."
        return 0
    fi
 
    mkdir -p "$dst"
    # No --delete: keep files that already exist on the new system
    rsync -av "$src/" "$dst/" || FAILED+=("rsync:$1")
}
 
# ------------------------------------------------------------------
# [1/6] Install APT packages (no confirmation)
# ------------------------------------------------------------------
echo "[1/6] Installing APT packages..."
APT_LIST="$BACKUP_DIR/apt-packages.list"
 
if [ -f "$APT_LIST" ]; then
    apt_install=(sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends)
 
    sudo apt-get update
 
    # Split the list into packages available in the current repositories and the rest
    INSTALLABLE=()
    MISSING=()
    while IFS= read -r pkg; do
        if apt-cache show "$pkg" &>/dev/null; then
            INSTALLABLE+=("$pkg")
        else
            MISSING+=("$pkg")
        fi
    done < <(grep -vE '^\s*(#|$)' "$APT_LIST")
 
    echo "  - To install: ${#INSTALLABLE[@]} / Not in repositories: ${#MISSING[@]}"
    [ "${#MISSING[@]}" -gt 0 ] && warn "Packages not found in repositories (skipped): ${MISSING[*]}"
 
    if [ "${#INSTALLABLE[@]}" -gt 0 ] && ! "${apt_install[@]}" "${INSTALLABLE[@]}"; then
        warn "Bulk install failed - installing packages one by one."
        for pkg in "${INSTALLABLE[@]}"; do
            "${apt_install[@]}" "$pkg" || FAILED+=("apt:$pkg")
        done
    fi
else
    echo "  - $APT_LIST not found, skipping."
fi
 
# ------------------------------------------------------------------
# [2/6] Install Flatpak apps
# ------------------------------------------------------------------
FLATPAK_LIST="$BACKUP_DIR/flatpak-packages.list"

echo "[2/6] Installing Flatpak applications..."
if [ ! -f "$FLATPAK_LIST" ]; then
    echo "  - No Flatpak list found, skipping."
elif ! confirm "Install Flatpak applications?" "y"; then
    echo "  - Flatpak : skipped."
else
    if ! command -v flatpak &>/dev/null; then
        echo "  - flatpak is not installed, installing it."
        sudo apt-get install -y flatpak
    fi

    if command -v flatpak &>/dev/null; then
        # Use a per-user flathub remote only (drop the system-wide one if present)
        sudo flatpak remote-delete --system flathub 2>/dev/null
        flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo \
            || warn "Failed to add flathub repository"

        while IFS= read -r app; do
            [ -z "$app" ] && continue
            echo "  - Installing $app ..."
            flatpak install --user -y --noninteractive flathub "$app" || FAILED+=("flatpak:$app")
        done < "$FLATPAK_LIST"
    fi
fi
 
# ------------------------------------------------------------------
# [3/6] Restore shell environment settings
# ------------------------------------------------------------------
echo "[3/6] Restoring terminal and shell environment settings..."
sync_user_dir "shell-env" "$HOME"
 
# ------------------------------------------------------------------
# [4/6] Restore user local binaries/scripts
# ------------------------------------------------------------------
echo "[4/6] Restoring user local binaries and shell scripts ($HOME/.local/bin)..."
if sync_user_dir "local-bin" "$HOME/.local/bin"; then
    # git only stores the executable bit, so explicitly make scripts executable to be safe
    find "$HOME/.local/bin" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod +x {} +
fi
 
# ------------------------------------------------------------------
# [5/6] Restore ~/.config
# ------------------------------------------------------------------
echo "[5/6] Restoring ~/.config..."
sync_user_dir "user-config" "$HOME/.config"
 
# ------------------------------------------------------------------
# [6/6] Restore system settings (/etc)
# ------------------------------------------------------------------
echo "[6/6] Restoring system settings (/etc)..."
echo "  (Existing files are saved to $SAFE_DIR before being overwritten)"
for path in "${SYSTEM_PATHS[@]}"; do
    restore_system_path "$path"
done
 
# ------------------------------------------------------------------
# Autologin group
# ------------------------------------------------------------------
getent group autologin >/dev/null || sudo groupadd -r autologin
sudo usermod -aG autologin "$TARGET_USER"
 
# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
echo ""
echo "=========================================="
if [ "${#FAILED[@]}" -eq 0 ]; then
    echo " Restore complete (no errors)"
else
    echo " Restore complete (some failures)"
    echo " Failed items:"
    printf '   - %s\n' "${FAILED[@]}"
fi
echo " Previous /etc files saved at: $SAFE_DIR"
echo " Some settings (XFCE, shell, services) take effect after re-login or reboot."
echo "=========================================="
 
