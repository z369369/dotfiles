#!/usr/bin/env bash
# @DESC: target dir의 이미지 파일명을 바꾸고 마크다운 노트에도 이미지 파일명을 수정
# @TAGS: image renamer, note content modifer
# @USAGE: vv_img_renamer.sh
# @STATUS: 사용중

# ==============================================================================
# rename_images.sh
# 이미지 파일명(14자→5자 역순)을 마크다운 노트에서 검색하여
# 매칭되면 랜덤문자열_YYYYMMDDHHMMSS 형식으로 rename + 마크다운 참조도 업데이트
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# 설정
# ------------------------------------------------------------------------------
NOTES_DIR="/home/lwh/Documents/001_lwh"
IMAGES_DIR="/home/lwh/Pictures/힣001_lwh"

# 랜덤 문자열 앞부분 길이 (랜덤N자 + _ + 14자 타임스탬프 = 총 N+15자)
RANDOM_PREFIX_LENGTH=12

# 로그 파일 (스크립트와 같은 위치)
LOG_FILE="$(dirname "$0")/rename_images.log"

# ------------------------------------------------------------------------------
# 색상 출력
# ------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------------------
# 함수: 로그 출력
# ------------------------------------------------------------------------------
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    #echo -e "$msg" | tee -a "$LOG_FILE"
    echo "$msg"
}

# ------------------------------------------------------------------------------
# 함수: 랜덤문자열_YYYYMMDDHHMMSS 형식 이름 생성
#   예) k7mxqpba_20260926143052
#   랜덤 앞부분(RANDOM_PREFIX_LENGTH자) + _ + 타임스탬프(14자) = 총 23자 이상
#   기존 파일명과 충돌하지 않도록 확인 (타임스탬프가 달라 실질적으로 충돌 없음)
# ------------------------------------------------------------------------------
generate_random_name() {
    local ext="$1"
    local new_name
    local timestamp

    while true; do
        # 랜덤 앞부분: 소문자+숫자 RANDOM_PREFIX_LENGTH자
        local rand_prefix
        rand_prefix=$(cat /dev/urandom \
            | tr -dc 'abcdfghkmnprstuvwxy23456789' \
            | head -c "$RANDOM_PREFIX_LENGTH")

        # 타임스탬프: YYYYMMDDHHMMSS (14자)
        timestamp=$(date '+%Y%m%d%H%M%S')

        # 최종 이름: 랜덤_타임스탬프
        new_name="${rand_prefix}_${timestamp}"

        local candidate="${IMAGES_DIR}/${new_name}${ext}"
        # 충돌 시 루프 재시도 (타임스탬프 덕분에 사실상 발생 안 함)
        if [[ ! -e "$candidate" ]]; then
            echo "${new_name}"
            return
        fi
    done
}

# ------------------------------------------------------------------------------
# 함수: 문자열 길이 계산 (멀티바이트 안전)
# ------------------------------------------------------------------------------
str_len() {
    echo -n "$1" | wc -m
}

# ------------------------------------------------------------------------------
# 사전 확인
# ------------------------------------------------------------------------------
if [[ ! -d "$NOTES_DIR" ]]; then
    echo -e "${RED}오류: 마크다운 노트 디렉토리가 없습니다: $NOTES_DIR${NC}"
    exit 1
fi

if [[ ! -d "$IMAGES_DIR" ]]; then
    echo -e "${RED}오류: 이미지 디렉토리가 없습니다: $IMAGES_DIR${NC}"
    exit 1
fi

# ------------------------------------------------------------------------------
# 메인 처리
# ------------------------------------------------------------------------------
log "======================================================"
log "시작: 이미지 rename + 마크다운 참조 업데이트"
log "노트 디렉토리  : $NOTES_DIR"
log "이미지 디렉토리: $IMAGES_DIR"
log "======================================================"

# 처리 카운터
count_renamed=0
count_skipped=0
count_no_match=0

# 이미지 파일 목록 수집 (확장자 기준: jpg jpeg png gif webp svg bmp tiff)
mapfile -d '' ALL_IMAGE_FILES < <(
    find "$IMAGES_DIR" -maxdepth 1 -type f \
        \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
           -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.svg" \
           -o -iname "*.bmp"  -o -iname "*.tiff" -o -iname "*.avif" \) \
        -print0
)

if [[ ${#ALL_IMAGE_FILES[@]} -eq 0 ]]; then
    log "${YELLOW}이미지 파일이 없습니다. 종료합니다.${NC}"
    exit 0
fi

log "발견된 이미지 파일 수: ${#ALL_IMAGE_FILES[@]}"
log ""

# ------------------------------------------------------------------------------
# 14자 → 5자 역순으로 파일명 길이별 처리
# (긴 이름 먼저 처리하여 짧은 이름이 긴 이름의 일부를 잘못 대체하는 것 방지)
# ------------------------------------------------------------------------------
for target_len in $(seq 12 -1 2); do

    log "------------------------------------------------------"
    log "파일명 길이 ${target_len}자 검사 중..."
    log "------------------------------------------------------"

    for img_path in "${ALL_IMAGE_FILES[@]}"; do
        # 파일이 이미 rename되어 사라진 경우 스킵
        [[ -f "$img_path" ]] || continue

        local_filename=$(basename "$img_path")
        local_ext="${local_filename##*.}"
        local_basename="${local_filename%.*}"

        # 확장자 제외 basename의 문자 수 계산
        name_len=$(str_len "$local_basename")

        # 현재 검사 길이와 일치하지 않으면 스킵
        if [[ "$name_len" -ne "$target_len" ]]; then
            continue
        fi

        log "${CYAN}검사: $local_filename (basename ${name_len}자)${NC}"

        # 마크다운 파일에서 해당 파일명(확장자 포함) 참조 검색
        # grep -rl: 해당 문자열이 포함된 파일 목록 반환
        # fgrep 사용: 특수문자를 정규식으로 해석하지 않음
        matched_md_files=()
        while IFS= read -r md_file; do
            matched_md_files+=("$md_file")
        done < <(
            grep -rl --include="*.md" -F "$local_filename" "$NOTES_DIR" 2>/dev/null || true
        )

        if [[ ${#matched_md_files[@]} -eq 0 ]]; then
            log "  → 마크다운 참조 없음. 스킵."
            (( count_no_match++ )) || true
            continue
        fi

        # 랜덤 새 이름 생성
        new_basename=$(generate_random_name ".${local_ext}")
        new_filename="${new_basename}.${local_ext}"
        new_img_path="${IMAGES_DIR}/${new_filename}"

        log "  ${GREEN}매칭된 마크다운 파일 수: ${#matched_md_files[@]}${NC}"
        log "  이름 변경: $local_filename → $new_filename"

        # ── 이미지 파일 rename ──
        mv "$img_path" "$new_img_path"
        log "  ✓ 이미지 rename 완료"

        # ── 매칭된 마크다운 파일 내 참조 교체 ──
        for md_file in "${matched_md_files[@]}"; do
            # sed -i: 인플레이스 교체 (-F 플래그 없으므로 특수문자 이스케이프 필요)
            # perl로 대체 (문자열 리터럴 치환, 정규식 미사용)
            perl -i -p -e "s/\Q${local_filename}\E/${new_filename}/g" "$md_file"
            log "  ✓ 마크다운 업데이트: $(basename "$md_file")"
        done

        (( count_renamed++ )) || true
    done
done

# ------------------------------------------------------------------------------
# 결과 요약
# ------------------------------------------------------------------------------
log ""
log "======================================================"
log "완료 요약"
log "  rename 처리: ${count_renamed}건"
log "  마크다운 참조 없어 스킵: ${count_no_match}건"
log "  로그 파일: $LOG_FILE"
log "======================================================"
