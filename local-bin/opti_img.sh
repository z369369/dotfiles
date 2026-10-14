#!/usr/bin/env bash
# @DESC: 사진 폴더 이미지 사이즈, 용량 최적화
# @TAGS: image, resizer, optimizer
# @USAGE: opti_img.sh
# @STATUS: 사용중

# ==========================================
# 1. 설정 항목
# ==========================================
TARGET_DIRS=(
    "/home/lwh/phone/DCIM"
    "/home/lwh/phone/Pictures"
    "/home/lwh/phone/Documents/001_Brain_Notes/zz_hub/attach"
    
)

# 기준 용량 (700KB = 716800 Bytes)
MAX_BYTES=1016800

# 명령어 체크
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

echo "=== 이미지 차등 압축 작업 시작 (Debian 13) ==="
processed_count=0

# ==========================================
# 2. 이미지 처리 함수
# ==========================================
process_file() {
    local file="$1"
    local current_size
    current_size=$(stat -c\%s "$file" 2>/dev/null)

    if [[ -z "$current_size" ]] || [[ "$current_size" -le "$MAX_BYTES" ]]; then
        return
    fi

    # 안전하게 확장자 추출 (소문자 변환)
    local filename
    filename=$(basename -- "$file")
    local ext="${filename##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

    local size_kb=$((current_size / 1024))

    echo "[대상 발견] $file (${size_kb} KB) - 포맷:${ext^^}"

    # ------------------------------------------
    # [Case 1] JPG / JPEG : 해상도 축소 (Resize)
    # ------------------------------------------
    if [[ "$ext" == "jpg" ]] || [[ "$ext" == "jpeg" ]]; then
        while [[ "$current_size" -gt "$MAX_BYTES" ]]; do
            $IMG_CMD "$file" -resize 90\% "$file"
            current_size=$(stat -c\%s "$file" 2>/dev/null)
            if [[ -z "$current_size" ]]; then break; fi
        done
        local new_kb=$((current_size / 1024))
        echo "  └ [JPG 완료] 해상도 축소 성공: ${new_kb} KB"
        ((processed_count++))

    # ------------------------------------------
    # [Case 2] PNG : 화질/해상도 손실 최소화 압축 (pngquant)
    # ------------------------------------------
    elif [[ "$ext" == "png" ]]; then
        # pngquant로 품질 범위를 조정하며 덮어쓰기 압축
        pngquant --quality=65-80 --skip-if-larger --strip --ext .png --force "$file" 2>/dev/null
        
        current_size=$(stat -c\%s "$file" 2>/dev/null)

        # 1차 압축 후에도 700KB 초과 시 품질을 조금 더 낮춰 추가 압축 시도
        if [[ "$current_size" -gt "$MAX_BYTES" ]]; then
            pngquant --quality=45-65 --skip-if-larger --strip --ext .png --force "$file" 2>/dev/null
            current_size=$(stat -c\%s "$file" 2>/dev/null)
        fi

        # 만약 pngquant 압축으로도 700KB 이하 실패 시 최후의 수단으로 해상도 90% 축소
        if [[ "$current_size" -gt "$MAX_BYTES" ]]; then
            echo "  └ [알림] PNG 색상 압축만으로 700KB 미달성 -> 리사이징 병행"
            while [[ "$current_size" -gt "$MAX_BYTES" ]]; do
                $IMG_CMD "$file" -resize 90\% "$file"
                current_size=$(stat -c\%s "$file" 2>/dev/null)
                if [[ -z "$current_size" ]]; then break; fi
            done
        fi

        local new_kb=$((current_size / 1024))
        echo "  └ [PNG 완료] 용량 최적화 성공: ${new_kb} KB"
        ((processed_count++))
    fi
}

# ==========================================
# 3. 메인 탐색 루프
# ==========================================
for dir in "${TARGET_DIRS[@]}"; do
    if [[ ! -d "$dir" ]]; then
        echo "[경고] 존재하지 않는 디렉터리입니다: $dir"
        continue
    fi

    echo ""
    echo "📂 탐색 중: $dir"

    while IFS= read -r -d '' file; do
        process_file "$file"
    done < <(find "$dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -size +1000k -print0)
done

echo ""
echo "=== 작업 완료 (총 ${processed_count}개 파일 처리됨) ==="
