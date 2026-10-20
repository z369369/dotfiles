#!/bin/bash
# @DESC: note dir 의 이미지를 dest dir 로 이동 시켜주고 노트 컨텐츠를 수정
# @TAGS: note, image mover, content modifier
# @USAGE: vault_image.sh
# @STATUS: 사용중

SUB_DIR="${1:-001_lwh}"

# 1. 경로 설정
SRC_DIR="/home/lwh/phone/Documents/${SUB_DIR}/zz_hub/attach"
DEST_DIR="/home/lwh/phone/Pictures/힣${SUB_DIR}"
NOTES_DIR="/home/lwh/phone/Documents/${SUB_DIR}"

# Target 디렉토리 생성
mkdir -p "$DEST_DIR"

if [ -d "$SRC_DIR" ]; then
    # 2. 이미지 파일 수집 (공백/특수문자 파일명 안전 처리)
    find "$SRC_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.avif" -o -iname "*.gif" \) -print0 | while IFS= read -r -d '' img_path; do
        
        orig_filename=$(basename "$img_path")
        target_filename="$orig_filename"
        
        # 3. 중복 파일명 체크 및 새 이름 생성 루틴 (예: image.png -> image_1.png)
        if [ -f "$DEST_DIR/$target_filename" ]; then
            name="${orig_filename%.*}"
            ext="${orig_filename##*.}"
            count=1
            
            while [ -f "$DEST_DIR/${name}_${count}.${ext}" ]; do
                count=$((count + 1))
            done
            
            target_filename="${name}_${count}.${ext}"
            echo "[중복 감지] '$orig_filename' -> '$target_filename' 로 이름 변경"
        fi

        # 4. Perl 정규표현식을 사용한 마크다운 파일 내용 수정
        # orig_filename 패턴을 찾아 변경된 target_filename 기반의 group:img/target_filename으로 교체
        find "$NOTES_DIR" -type f -name "*.md" -print0 | xargs -0 perl -s -pi -e '
            BEGIN { $esc_orig = quotemeta($old_fname); }
            
            # 패턴 A: 절대경로 형태 매칭 및 치환
            s|/home/lwh/Documents/001_lwh/zz_hub/attach/$esc_orig(?![a-zA-Z0-9_\.])|group:img/$new_fname|g;
            
            # 패턴 B: 단일 파일명 형태 완전 일치 매칭 (뒤에 글자/확장자가 이어지는 경우 제외)
            s|(?<!group:img/)(?<![a-zA-Z0-9_\./])$esc_orig(?![a-zA-Z0-9_\.])|group:img/$new_fname|g;
        ' -- -old_fname="$orig_filename" -new_fname="$target_filename"

        # 5. 파일 이동 (이름이 변경된 경우 변경된 이름으로 이동)
        mv "$img_path" "$DEST_DIR/$target_filename"
        echo "[이동 완료] '$target_filename' -> $DEST_DIR/"
        echo "------------------------------------------------"
    done
fi

echo "모든 작업이 완료되었습니다."