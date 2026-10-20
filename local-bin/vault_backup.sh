#!/bin/bash
# @DESC: backup dir에 src_dir의 파일을 압축하여 저장
# @TAGS: obsidian, backup
# @USAGE: vault_backup.sh
# @STATUS: 사용중

# ==========================================
# 사용자 설정 영역
# ==========================================

# 백업 대상 폴더 배열 (추후 폴더 추가 가능)
TARGET_DIRS=(
    "/home/lwh/Documents/001_lwh"
)

# 백업 파일이 저장될 기본 최상위 경로
BACKUP_BASE_DIR="/media/lwh/lwh_backup/Backup"

# 오늘 날짜 (YYYY-MM-DD 형식)
TODAY=$(date +%Y-%m-%d)

# 유지할 백업 파일 최대 개수
MAX_BACKUPS=10

# ==========================================
# 백업 수행 로직
# ==========================================

# 스크립트 실행 시작 시점의 현재 경로 저장
ORIGINAL_DIR=$(pwd)

# 와일드카드(*) 확장 시 숨김 파일/폴더(.)도 포함하도록 설정
shopt -s dotglob

for TARGET in "${TARGET_DIRS[@]}"; do
    # 경로 끝의 슬래시 제거
    TARGET_CLEAN="${TARGET%/}"
    FOLDER_NAME=$(basename "$TARGET_CLEAN")

    # 대상 폴더 존재 여부 확인
    if [ ! -d "$TARGET_CLEAN" ]; then
        echo "[경고] 대상 폴더가 존재하지 않습니다: $TARGET_CLEAN"
        continue
    fi

    # 저장될 백업 디렉토리 설정 및 생성
    DEST_DIR="${BACKUP_BASE_DIR}/${FOLDER_NAME}"
    mkdir -p "$DEST_DIR"

    # 백업 파일 경로 설정
    ARCHIVE_PATH="${DEST_DIR}/${TODAY}.tar"

    echo "----------------------------------------"
    echo "백업 시작: $FOLDER_NAME"
    echo "대상 경로: $TARGET_CLEAN"
    echo "저장 경로: $ARCHIVE_PATH"

    # 대상 디렉토리로 직접 이동
    cd "$TARGET_CLEAN" || continue

    # tar 압축 실행 (dotglob 설정으로 인해 숨김 파일/폴더도 * 에 포함됨)
    tar -cf "$ARCHIVE_PATH" *

    if [ $? -eq 0 ]; then
        echo "백업 완료 (숨김 파일 포함): $ARCHIVE_PATH"
    else
        echo "[오류] 백업 실패: $TARGET_CLEAN"
    fi

    # 작업 후 원래 실행 디렉토리로 복귀
    cd "$ORIGINAL_DIR" || exit

    # ==========================================
    # 오래된 백업 파일 정리 (최근 10개만 유지)
    # ==========================================
    BACKUP_COUNT=$(ls -1 "${DEST_DIR}"/*.tar 2>/dev/null | wc -l)

    if [ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]; then
        REMOVE_COUNT=$((BACKUP_COUNT - MAX_BACKUPS))
        echo "백업 개수 초과 ($BACKUP_COUNT/$MAX_BACKUPS). 오래된 백업 $REMOVE_COUNT개 삭제 진행."

        ls -1t "${DEST_DIR}"/*.tar | tail -n "$REMOVE_COUNT" | while read -r OLD_FILE; do
            rm -f "$OLD_FILE"
            echo "삭제됨: $OLD_FILE"
        done
    fi
done

# dotglob 설정 원복
shopt -u dotglob

echo "----------------------------------------"
echo "모든 백업 작업 완료."
