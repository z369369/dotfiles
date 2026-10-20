#!/bin/bash
# @DESC: 노트의 내용을 검사하여 빠진 이미지 파일을 target dir 로 이동
# @TAGS: image file organizer
# @USAGE: vv_unlink_img_mover.sh
# @STATUS: 사용중

# check_filenames.sh
#
# 목적:
#   SRC_DIR 안의 파일명들이 NOTES_DIR(하위 폴더 포함)의 마크다운(.md) 파일들
#   본문 텍스트 어딘가에 언급되어 있는지 검사한다.
#   - 언급되어 있으면: 통과 (건너뜀)
#   - 언급되어 있지 않으면: BACKUP_DIR로 이동시켜 정리한다.
#
# 매칭 기준:
#   1) 파일명 전체(확장자 포함)가 md 파일 본문에 그대로 있으면 통과
#   2) 아니면 확장자를 뗀 이름이 본문에 있어도 통과
#      (노트에서 확장자 없이 파일명만 언급하는 경우가 많기 때문)
#
# 사용법:
#   chmod +x check_filenames.sh
#   ./check_filenames.sh
#
# 결과:
#   - 화면에 이동된(누락) 파일명 목록 출력
#   - 누락된 파일들은 BACKUP_DIR로 이동됨 (삭제 아님, 복구 가능)

set -uo pipefail

SRC_DIR="/home/lwh/phone/Pictures/힣001_lwh"
NOTES_DIR="/home/lwh/phone/Documents/001_lwh"
BACKUP_DIR="$SRC_DIR/backup"
echo $BACKUP_DIR;
exit 1
# ---- 사전 검사 ----
if [ ! -d "$SRC_DIR" ]; then
    echo "오류: SRC_DIR 폴더가 없습니다 -> $SRC_DIR"
    exit 1
fi
if [ ! -d "$NOTES_DIR" ]; then
    echo "오류: NOTES_DIR 폴더가 없습니다 -> $NOTES_DIR"
    exit 1
fi

mkdir -p "$BACKUP_DIR"

# ---- 모든 md 파일 내용을 하나로 합쳐서 검색 속도를 높임 ----
COMBINED_MD=$(mktemp)
trap 'rm -f "$COMBINED_MD"' EXIT

find "$NOTES_DIR" -type f -iname "*.md" -print0 |
    xargs -0 cat -- 2>/dev/null > "$COMBINED_MD"

if [ ! -s "$COMBINED_MD" ]; then
    echo "경고: $NOTES_DIR 안에서 md 파일을 하나도 찾지 못했습니다."
fi

# ---- 검사 및 이동 ----
total=0
moved=0

while IFS= read -r -d '' file; do
    filename=$(basename -- "$file")
    name_no_ext="${filename%.*}"
    total=$((total + 1))

    # 1) 파일명 전체(확장자 포함)로 검색
    if grep -qF -- "$filename" "$COMBINED_MD"; then
        continue
    fi

    # 2) 확장자를 뗀 이름으로 검색
    if [ "$name_no_ext" != "$filename" ] && grep -qF -- "$name_no_ext" "$COMBINED_MD"; then
        continue
    fi

    # 둘 다 실패하면 backup 폴더로 이동
    # 이름 충돌 시 덮어쓰지 않도록 처리
    dest="$BACKUP_DIR/$filename"
    if [ -e "$dest" ]; then
        dest="$BACKUP_DIR/${name_no_ext}_$(date +%s)_${RANDOM}.${filename##*.}"
    fi

    mv -- "$file" "$dest"
    echo "[이동됨] $filename"
    moved=$((moved + 1))

done < <(find "$SRC_DIR" -maxdepth 1 -type f -print0)

echo ""
echo "-----------------------------------"
echo "전체 파일 수 : $total"
echo "이동된 파일 수 : $moved"
echo "이동 위치 : $BACKUP_DIR"
echo "-----------------------------------"
