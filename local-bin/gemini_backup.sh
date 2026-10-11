#!/usr/bin/env bash
# @DESC: GIT repo에 백업
# @TAGS: GIT, xfce, etc, config backup
# @USAGE: gemini_backup.sh
set -e

SYSTEM_PATHS=(
    "/etc/apt"
    "/etc/bluetooth"
    "/etc/conky"
    "/etc/cups"
    "/etc/default/grub"
    "/etc/fstab"
    "/etc/grub.d"
    "/etc/lightdm"
    "/etc/pam.d"
    "/etc/ssh/sshd_config"
    "/etc/ufw"
    "/etc/network"
    "/etc/xdg"
)

CONFIG_PATHS=(
    "autostart"
    "catfish"
    "libreoffice"
    "gtk-2.0"
    "gtk-3.0"
    "gtk-4.0"
    "systemd"
    "syncthing"
    "Thunar"
    "xfce4"
)

SHELL_PATHS=(
    ".bash_aliases"
    ".bash_logout"
    ".bashrc"
    ".conkyrc"
    ".fdignore"
    ".gitconfig"
    ".profile"
    ".rgignore"
    ".xprofile"
)

BACKUP_DIR="/home/lwh/git/dotfiles"
echo "=========================================="
echo " 고도화된 시스템 구성 백업을 시작합니다."
echo "=========================================="

# 기본 디렉토리 생성
mkdir -p "$BACKUP_DIR"

# 1. APT 패키지 리스트 및 저장소 백업
echo "[1/7] APT 패키지 및 저장소(Sources/Keyrings) 백업 중..."
apt-mark showmanual > "$BACKUP_DIR/apt-packages.list"

# 2. Flatpak 애플리케이션 리스트 백업
if command -v flatpak &> /dev/null; then
    echo "[2/7] Flatpak 애플리케이션 리스트 백업 중..."
    flatpak list --app --columns=application > "$BACKUP_DIR/flatpak-packages.list"
fi


# 3. 쉘 환경 설정 파일 백업 (.bashrc, .bash_aliases 등)
echo "[3/7] 터미널 및 쉘 환경 설정 백업 중..."
mkdir -p "$BACKUP_DIR/shell-env"
for file in "${SHELL_PATHS[@]}"; do
    if [ -f "$HOME/$file" ]; then
        cp "$HOME/$file" "$BACKUP_DIR/shell-env/$file"
    fi
done


# 4. 사용자 커스텀 스크립트 및 바이너리 백업 ($HOME/.local/bin)
if [ -d "$HOME/.local/bin" ]; then
    echo "[4/7] 사용자 로컬 바이너리 및 쉘 스크립트($HOME/.local/bin) 백업 중..."
    mkdir -p "$BACKUP_DIR/local-bin"
    rsync -av --delete "$HOME/.local/bin/" "$BACKUP_DIR/local-bin/"
else
    echo "[4/7] $HOME/.local/bin 디렉토리가 없어 건너뜁니다."
fi

echo "[6/6] config 설정(~/.config) 백업 중..."
for c_src in "${CONFIG_PATHS[@]}"; do
    rsync -a "$HOME/.config/$c_src" "$BACKUP_DIR/user-config/"
done

find "$HOME/.config" -maxdepth 1 -type f -exec cp {} "$BACKUP_DIR/user-config/" \;
sudo rm -rf "$BACKUP_DIR/user-config/syncthing/index-v0.14.0.db"


echo "[7/7] 시스템 설정(/etc) 백업 중..."
for src in "${SYSTEM_PATHS[@]}"; do
    if [ ! -e "$src" ]; then
        echo "  - $src 없음, 건너뜁니다."
        continue
    fi

    # /etc/ssh -> $BACKUP_DIR/etc/ssh 처럼 원본 경로 구조를 유지
    dest="$BACKUP_DIR$src"

    echo "  - $src 백업 중..."
    if [ -d "$src" ]; then
        sudo mkdir -p "$dest"
        sudo rsync -a --delete "$src/" "$dest/"
    else
        sudo mkdir -p "$(dirname "$dest")"
        sudo cp -a "$src" "$dest"
    fi
done


# Git 관리를 위해 백업된 파일의 소유권을 현재 사용자로 변경
sudo chown -R "$(whoami):$(whoami)" "$BACKUP_DIR/etc"

echo ""

#dont delete under command 
cd ~/git/dotfiles
git add .
git commit -m "backup"
git push

echo "=========================================="
echo " 백업 Complete "
echo "=========================================="
