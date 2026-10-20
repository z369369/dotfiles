#!/usr/bin/env bash
# @DESC: 사진 폴더 이미지 사이즈, 용량 최적화 (v2: 품질 우선 압축, 병렬, 드라이런)
# @TAGS: image, resizer, optimizer
# @USAGE: opti_img.sh [-n] [-j 작업수] [vault-subdir]
# @STATUS: 사용중

set -u

# ==========================================
# 1. 설정 항목
# ==========================================
DRY_RUN=0
JOBS="$(nproc 2>/dev/null || echo 2)"

while getopts "nj:" opt; do
    case "$opt" in
        n) DRY_RUN=1 ;;
        j) JOBS="$OPTARG" ;;
        *) echo "사용법: $(basename "$0") [-n 드라이런] [-j 병렬작업수] [vault-subdir]"; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

SUB_DIR="${1:-001_lwh}"

TARGET_DIRS=(
    "/home/lwh/phone/DCIM"
    "/home/lwh/phone/Pictures"
    "/home/lwh/phone/Documents/${SUB_DIR}"
)

MAX_KB=1000                    # 목표 상한 (KB)
MAX_BYTES=$((MAX_KB * 1024))
JPEG_QUALITY=85                # 85면 육안 차이 거의 없음
STRIP_META=0                   # 1이면 EXIF(촬영일/GPS 등) 제거
MAX_TRIES=6                    # 리사이즈 재시도 최대 횟수

# ==========================================
# 2. 사전 점검
# ==========================================
if command -v magick &> /dev/null; then
    IMG_CMD="magick"
elif command -v convert &> /dev/null; then
    IMG_CMD="convert"
else
    echo "[오류] ImageMagick이 설치되어 있지 않습니다."
    exit 1
fi

if ! command -v pngquant &> /dev/null; then
    echo "[오류] pngquant가 설치되어 있지 않습니다. 'sudo apt install pngquant'를 실행해주세요."
    exit 1
fi

TMP_ROOT="$(mktemp -d)"
RESULTS="$TMP_ROOT/results.txt"
: > "$RESULTS"
trap 'rm -rf "$TMP_ROOT"' EXIT

# ==========================================
# 3. 함수
# ==========================================

# 현재 비율($1)과 결과 크기($2)를 보고 다음 리사이즈 비율(%)을 계산
# (용량은 대략 픽셀 수에 비례 → 비율은 길이 기준이라 sqrt)
next_pct() {
    awk -v p="$1" -v m="$MAX_BYTES" -v c="$2" 'BEGIN {
        n = int(p * sqrt(m * 0.9 / c))
        if (n >= p) n = p - 1
        if (n < 10) n = 10
        print n
    }'
}

# JPG: 항상 "원본"에서 다시 인코딩 (90% 반복 축소 시 생기는 재압축 열화 방지)
compress_jpg() {
    local in="$1" out="$2" pct=100 try=0 cur
    local rs=() st=()
    (( STRIP_META )) && st=(-strip)

    while (( try < MAX_TRIES )); do
        rs=()
        (( pct < 100 )) && rs=(-resize "${pct}%")

        "$IMG_CMD" "$in" -auto-orient "${rs[@]}" "${st[@]}" \
            -sampling-factor 4:2:0 -interlace JPEG -quality "$JPEG_QUALITY" "$out" || return 1

        cur=$(stat -c%s -- "$out" 2>/dev/null) || return 1
        (( cur <= MAX_BYTES )) && return 0

        pct=$(next_pct "$pct" "$cur")
        ((try++))
    done
    return 0
}

# PNG: pngquant 색상 압축 우선, 안 되면 리사이즈 + 재압축 (역시 원본에서 재시작)
compress_png() {
    local in="$1" out="$2" pct=100 try=0 cur q
    local step="$out.step.png"

    while (( try < MAX_TRIES )); do
        if (( pct == 100 )); then
            cp -- "$in" "$step"
        else
            "$IMG_CMD" "$in" -auto-orient -resize "${pct}%" "$step" || return 1
        fi

        q="65-80"
        (( try > 0 )) && q="45-80"

        pngquant --quality="$q" --skip-if-larger --strip --force \
            --output "$out" -- "$step" 2>/dev/null || cp -- "$step" "$out"

        cur=$(stat -c%s -- "$out" 2>/dev/null) || return 1
        (( cur <= MAX_BYTES )) && return 0

        pct=$(next_pct "$pct" "$cur")
        ((try++))
    done
    return 0
}

process_file() {
    local file="$1" orig cur ext out wd mtime

    orig=$(stat -c%s -- "$file" 2>/dev/null) || return
    (( orig > MAX_BYTES )) || return

    ext="${file##*.}"
    ext="${ext,,}"

    if (( DRY_RUN )); then
        printf '[DRY] %s (%d KB)\n' "$file" $((orig / 1024))
        return
    fi

    wd="$(mktemp -d "$TMP_ROOT/w.XXXXXX")" || return
    out="$wd/out.$ext"

    case "$ext" in
        jpg|jpeg) compress_jpg "$file" "$out" ;;
        png)      compress_png "$file" "$out" ;;
        *)        rm -rf "$wd"; return ;;
    esac

    cur=$(stat -c%s -- "$out" 2>/dev/null) || cur=0

    # 결과가 원본보다 작을 때만 교체
    if (( cur > 0 && cur < orig )); then
        mtime=$(stat -c%Y -- "$file")
        if cat -- "$out" > "$file"; then
            touch -d "@$mtime" -- "$file"   # 수정시간 유지(갤러리 정렬 보존)
            printf '[완료] %s  %d KB → %d KB\n' "$file" $((orig / 1024)) $((cur / 1024))
            echo "$orig $cur" >> "$RESULTS"
        else
            printf '[실패] %s (쓰기 오류)\n' "$file"
        fi
    else
        printf '[건너뜀] %s (더 줄일 수 없음)\n' "$file"
    fi

    rm -rf "$wd"
}

# ==========================================
# 4. 메인
# ==========================================
echo "=== 이미지 최적화 시작 (목표 ${MAX_KB}KB, 병렬 ${JOBS}, 드라이런=${DRY_RUN}) ==="

EXISTING=()
for dir in "${TARGET_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        EXISTING+=("$dir")
    else
        echo "[경고] 존재하지 않는 디렉터리입니다: $dir"
    fi
done

if (( ${#EXISTING[@]} == 0 )); then
    echo "[오류] 처리할 디렉터리가 없습니다."
    exit 1
fi

export -f process_file compress_jpg compress_png next_pct
export IMG_CMD MAX_BYTES JPEG_QUALITY STRIP_META MAX_TRIES DRY_RUN TMP_ROOT RESULTS

# 숨김 파일/폴더(.thumbnails, .trashed-*, .stfolder 등)는 제외
find "${EXISTING[@]}" -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) \
    -size +"${MAX_BYTES}"c -not -path '*/.*' -print0 \
    | nice -n 10 xargs -0 -r -P "$JOBS" -n1 bash -c 'process_file "$1"' _

echo ""
awk '{ n++; o += $1; c += $2 }
     END {
        if (n == 0) { print "=== 작업 완료 (처리된 파일 없음) ==="; exit }
        printf "=== 작업 완료: %d개 처리, %.1f MB → %.1f MB (%.1f MB 절약) ===\n",
               n, o/1048576, c/1048576, (o-c)/1048576
     }' "$RESULTS"