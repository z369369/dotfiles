#!/usr/bin/env bash
# @DESC: pictures의 루트 이미지를 정리
# @TAGS: move, gemini, image
# @USAGE: move_gemini_img.sh
# @STATUS: 사용중


# 경로 설정
SRC_DIR="/home/lwh/phone/Pictures"
DEST_DIR="${SRC_DIR}/gemini"

# 대상 디렉토리가 없으면 생성
mkdir -p "${DEST_DIR}"

# 처리할 이미지 확장자 (대소문자 구분 없이 처리하기 위함)
shopt -s nullglob nocaseglob

# SRC_DIR 바로 아래에 있는 파일만 탐색 (하위 디렉토리 및 gemini 폴더 제외)
for file in "${SRC_DIR}"/*.{jpg,jpeg,png,webp,avif,gif}; do
    # 파일이 실제로 존재하는지 확인 (매칭되는 파일이 없을 경우 대비)
    [[ -f "${file}" ]] || continue

    # 파일 확장자 추출 (소문자로 변환하여 통일)
    ext="${file##*.}"
    ext_lc=$(echo "${ext}" | tr '[:upper:]' '[:lower:]')

    # 8자리 영문 소문자/숫자 난수 생성
    rand_str=$(head /dev/urandom | tr -dc 'a-z0-9' | head -c 8)

    # 타임스탬프 생성 (년월일시분초: YYYYMMDD_hhmmss)
    timestamp=$(date +"%Y%m%m%H%M%S")

    # 새로운 파일명 구성: 난수문자8자리_년월일시분초.확장자
    new_filename="${rand_str}_${timestamp}.${ext_lc}"
    dest_path="${DEST_DIR}/${new_filename}"

    # 파일 이동 실행
    mv -- "${file}" "${dest_path}"
    echo "이동 완료: $(basename "${file}") -> ${new_filename}"
done

echo "gemini 이미지 이동 작업이 완료되었습니다."
