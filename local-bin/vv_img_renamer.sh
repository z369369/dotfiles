#!/usr/bin/env bash
# @DESC: target dir의 이미지 파일명을 바꾸고 마크다운 노트에도 이미지 파일명을 수정
# @TAGS: image renamer, note content modifer
# @USAGE: vv_img_renamer.sh [-n|--dry-run]
# @STATUS: 사용중

# ==============================================================================
# vv_img_renamer.sh (고속 버전)
#
# 동작
#   1) 이미지 폴더에서 '확장자 제외 파일명 길이 MIN_LEN~MAX_LEN자'인 이미지만 후보로 수집
#   2) 후보마다 새 이름(랜덤문자열_YYYYMMDDHHMMSS)을 미리 정해 매핑 파일 생성
#   3) perl 한 번으로 노트 폴더의 모든 .md 를 1회만 읽으며 참조를 치환
#        - 모든 후보 파일명을 하나의 정규식(긴 이름 우선)으로 묶어서 처리
#        - 내용이 실제로 바뀐 .md 파일만 다시 저장
#   4) 노트에서 참조가 발견된 이미지만 실제로 mv
#
# 옵션
#   -n, --dry-run : 파일을 바꾸지 않고 어떤 변경이 일어날지만 출력
#
# 환경변수로 경로 덮어쓰기 가능: NOTES_DIR, IMAGES_DIR
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# 설정
# ------------------------------------------------------------------------------
NOTES_DIR="${NOTES_DIR:-/home/lwh/Documents/001_lwh}"
IMAGES_DIR="${IMAGES_DIR:-/home/lwh/Pictures/힣001_lwh}"

# 처리할 파일명(확장자 제외) 길이 범위
MAX_LEN=12
MIN_LEN=2

# 랜덤 문자열 앞부분 길이 (랜덤N자 + _ + 14자 타임스탬프)
RANDOM_PREFIX_LENGTH=12

# 로그 파일 (스크립트와 같은 위치). 빈 문자열이면 파일 로그 비활성화
#LOG_FILE="${LOG_FILE-$(dirname "$0")/rename_images.log}"
LOG_FILE=

DRY_RUN=0
case "${1:-}" in
    -n|--dry-run) DRY_RUN=1 ;;
    "") ;;
    *) echo "사용법: $(basename "$0") [-n|--dry-run]" >&2; exit 2 ;;
esac

# 문자 수 계산(${#var})이 멀티바이트를 문자 단위로 세도록 UTF-8 로케일 보장
if [[ "$(locale charmap 2>/dev/null || true)" != "UTF-8" ]]; then
    export LC_ALL=C.UTF-8
fi

# ------------------------------------------------------------------------------
# 색상 (실제 ESC 문자)
# ------------------------------------------------------------------------------
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

# ------------------------------------------------------------------------------
# 함수: 로그 (터미널엔 색상, 로그 파일엔 색상 코드 제거)
# ------------------------------------------------------------------------------
log() {
    local ts msg
    printf -v ts '%(%Y-%m-%d %H:%M:%S)T' -1
    msg="[$ts] $*"
    printf '%s\n' "$msg"
    if [[ -n "$LOG_FILE" ]]; then
        printf '%s\n' "$msg" | sed $'s/\033\\[[0-9;]*m//g' >> "$LOG_FILE"
    fi
}

# ------------------------------------------------------------------------------
# 사전 확인
# ------------------------------------------------------------------------------
if [[ ! -d "$NOTES_DIR" ]]; then
    echo "${RED}오류: 마크다운 노트 디렉토리가 없습니다: $NOTES_DIR${NC}"
    exit 1
fi
if [[ ! -d "$IMAGES_DIR" ]]; then
    echo "${RED}오류: 이미지 디렉토리가 없습니다: $IMAGES_DIR${NC}"
    exit 1
fi
if ! command -v perl >/dev/null 2>&1; then
    echo "${RED}오류: perl 이 필요합니다.${NC}"
    exit 1
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
MAP_FILE="$TMP_DIR/map.bin"        # old\0new\0old\0new\0...
RESULT_FILE="$TMP_DIR/result.bin"  # kind\0value\0count\0...

log "======================================================"
if (( DRY_RUN )); then
    log "시작: 이미지 rename + 마크다운 참조 업데이트 ${YELLOW}[DRY-RUN: 변경 없음]${NC}"
else
    log "시작: 이미지 rename + 마크다운 참조 업데이트"
fi
log "노트 디렉토리  : $NOTES_DIR"
log "이미지 디렉토리: $IMAGES_DIR"
log "대상 파일명 길이: ${MIN_LEN}~${MAX_LEN}자"
log "======================================================"

# ------------------------------------------------------------------------------
# 1) 이미지 후보 수집 + 길이 필터 (외부 프로세스 없이 bash 내장만 사용)
# ------------------------------------------------------------------------------
mapfile -d '' ALL_IMAGE_FILES < <(
    find "$IMAGES_DIR" -maxdepth 1 -type f \
        \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
           -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.svg" \
           -o -iname "*.bmp" -o -iname "*.tiff" -o -iname "*.avif" \) \
        -print0
)

if [[ ${#ALL_IMAGE_FILES[@]} -eq 0 ]]; then
    log "${YELLOW}이미지 파일이 없습니다. 종료합니다.${NC}"
    exit 0
fi
log "발견된 이미지 파일 수: ${#ALL_IMAGE_FILES[@]}"

# ------------------------------------------------------------------------------
# 2) 새 이름 미리 생성 + 매핑 파일 작성 (서브셸/외부 명령 없음)
# ------------------------------------------------------------------------------
CHARSET='abcdfghkmnprstuvwxy23456789'
CHARSET_LEN=${#CHARSET}
printf -v RUN_TS '%(%Y%m%d%H%M%S)T' -1

declare -A NEW_OF=()      # old filename -> new filename
declare -A USED_NEW=()    # 이번 실행에서 이미 배정한 새 이름
candidates=0

: > "$MAP_FILE"
for img_path in "${ALL_IMAGE_FILES[@]}"; do
    name="${img_path##*/}"
    ext="${name##*.}"
    base="${name%.*}"
    len=${#base}

    (( len >= MIN_LEN && len <= MAX_LEN )) || continue

    while true; do
        rand=""
        for (( i = 0; i < RANDOM_PREFIX_LENGTH; i++ )); do
            rand+="${CHARSET:RANDOM % CHARSET_LEN:1}"
        done
        new_name="${rand}_${RUN_TS}.${ext}"
        if [[ -z "${USED_NEW[$new_name]:-}" && ! -e "${IMAGES_DIR}/${new_name}" ]]; then
            USED_NEW[$new_name]=1
            break
        fi
    done

    NEW_OF[$name]="$new_name"
    printf '%s\0%s\0' "$name" "$new_name" >> "$MAP_FILE"
    (( candidates++ )) || true
done

log "길이 조건에 맞는 후보: ${candidates}개"
if (( candidates == 0 )); then
    log "${YELLOW}처리할 후보가 없습니다. 종료합니다.${NC}"
    exit 0
fi

# ------------------------------------------------------------------------------
# 3) perl 1회 실행: 모든 .md 를 한 번만 읽으며 일괄 치환
#    - 파일명 앞 경계: [ ( / 공백 | " ' = < 또는 줄 시작
#      (예: 9_2.png 가 19_2.png, xx9_2.png 의 일부로 오인되는 것 방지)
#    - 파일명 뒤 경계: 영숫자/_ 가 이어지지 않을 것
#    - 정규식 alternation 은 긴 이름 우선
# ------------------------------------------------------------------------------
read -r -d '' PERL_SRC <<'PERL' || true
use strict;
use warnings;

my $map_file = $ENV{VV_MAP};
my $dry      = $ENV{VV_DRY};

my %map;
open my $mf, '<:raw', $map_file or die "매핑 파일 열기 실패: $!";
{
    local $/ = "\0";
    while (defined(my $o = <$mf>)) {
        chomp $o;
        my $n = <$mf>;
        last unless defined $n;
        chomp $n;
        $map{$o} = $n;
    }
}
close $mf;
exit 0 unless %map;

my $alt = join '|', map { quotemeta } sort { length($b) <=> length($a) or $a cmp $b } keys %map;
my $re  = qr/(?:(?<=[\[(\/\s|"\x27=<])|^)($alt)(?![A-Za-z0-9_])/m;

my %hit;
{
    local $/ = "\0";
    while (defined(my $f = <STDIN>)) {
        chomp $f;
        my $c;
        {
            open my $fh, '<:raw', $f or do { warn "읽기 실패: $f\n"; next };
            local $/;
            $c = <$fh> // '';
            close $fh;
        }

        my $cnt = 0;
        $c =~ s/$re/$cnt++; $hit{$1}++; $map{$1}/ge;
        next unless $cnt;

        unless ($dry) {
            my $mode = (stat $f)[2] & 07777;
            my $tmp  = "$f.vvtmp.$$";
            open my $out, '>:raw', $tmp or do { warn "쓰기 실패: $tmp\n"; next };
            print {$out} $c;
            close $out or do { warn "닫기 실패: $tmp\n"; unlink $tmp; next };
            chmod $mode, $tmp;
            rename $tmp, $f or do { warn "교체 실패: $f\n"; unlink $tmp; next };
        }
        print "U\0$f\0$cnt\0";
    }
}
print "H\0$_\0$hit{$_}\0" for sort keys %hit;
PERL

log "노트 스캔 중..."
find "$NOTES_DIR" -type f -name '*.md' -print0 \
    | VV_MAP="$MAP_FILE" VV_DRY="$DRY_RUN" perl -e "$PERL_SRC" > "$RESULT_FILE"

# ------------------------------------------------------------------------------
# 4) 결과 처리: 갱신된 노트 로그 + 참조 발견된 이미지만 mv
# ------------------------------------------------------------------------------
mapfile -d '' RESULT < "$RESULT_FILE"

count_renamed=0
count_failed=0
count_md=0
hit_names=()

for (( k = 0; k + 2 < ${#RESULT[@]}; k += 3 )); do
    kind="${RESULT[k]}"
    val="${RESULT[k+1]}"
    cnt="${RESULT[k+2]}"
    if [[ "$kind" == "U" ]]; then
        log "  ✓ 마크다운 업데이트: ${val#"$NOTES_DIR"/} (${cnt}곳)"
        (( count_md++ )) || true
    else
        hit_names+=("$val")
    fi
done

log ""
for old in "${hit_names[@]}"; do
    new="${NEW_OF[$old]}"
    log "${CYAN}${old}${NC} → ${GREEN}${new}${NC}"
    if (( DRY_RUN )); then
        (( count_renamed++ )) || true
        continue
    fi
    if mv -n -- "${IMAGES_DIR}/${old}" "${IMAGES_DIR}/${new}"; then
        (( count_renamed++ )) || true
    else
        log "  ${RED}✗ rename 실패: $old${NC}"
        (( count_failed++ )) || true
    fi
done

count_no_match=$(( candidates - ${#hit_names[@]} ))

# ------------------------------------------------------------------------------
# 결과 요약
# ------------------------------------------------------------------------------
log ""
log "======================================================"
log "완료 요약$( (( DRY_RUN )) && echo ' [DRY-RUN]' )"
log "  rename 처리: ${count_renamed}건"
log "  rename 실패: ${count_failed}건"
log "  수정된 마크다운 파일: ${count_md}개"
log "  마크다운 참조 없어 스킵: ${count_no_match}건"
log "  로그 파일: ${LOG_FILE:-없음}"
log "======================================================"