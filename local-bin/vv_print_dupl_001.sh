#!/bin/bash
# @DESC: 옵시디언 노트 중복 파일 검사, 중복 파일 출력 (gawk 고속 버전)
# @TAGS: obsidian, duplicate, checker
# @USAGE: vv_print_duplicate.sh [볼트경로] [임계값%]
# @STATUS: 사용중

VAULT_DIR="${1:-/home/lwh/phone/Documents/001_Brain_Notes}"
THRESHOLD="${2:-90}"
MIN_WORDS=5          # 이보다 단어가 적은 파일은 제외 (오탐 방지)

# 제외할 폴더 이름 (하위 어느 위치에 있든 해당 이름의 폴더는 통째로 제외)
EXCLUDE_DIRS=(
  "zz_hub"
  "zz_daily"
)

command -v gawk >/dev/null || { echo "gawk가 필요합니다: sudo apt install gawk"; exit 1; }

export LC_ALL=C

echo "=== 마크다운 파일 유사도 분석 (기준: ${THRESHOLD}% 이상) ==="
echo "대상 디렉토리: $VAULT_DIR"
echo "제외 폴더: ${EXCLUDE_DIRS[*]} (+ 숨김 파일/폴더)"
echo "--------------------------------------------------------"

# find 제외 조건 구성: 숨김 폴더 + 지정 폴더는 탐색 자체를 건너뜀(prune)
PRUNE=( -name '.*' )
for d in "${EXCLUDE_DIRS[@]}"; do
  PRUNE+=( -o -name "$d" )
done

find "$VAULT_DIR" -mindepth 1 \
  \( -type d \( "${PRUNE[@]}" \) -prune \) -o \
  \( -type f -name '*.md' ! -name '.*' -print0 \) \
| gawk -v RS='\0' -v T="$THRESHOLD" -v MINW="$MIN_WORDS" '
# 두 파일의 실제 유사도를 계산하고 임계값 이상이면 출력
function verify(i, j,    a, b, mn, mx, c, w, sim) {
  if (C[i] < C[j]) { mn = C[i]; mx = C[j]; a = i; b = j }
  else             { mn = C[j]; mx = C[i]; a = j; b = i }
  if (mn * 100 < T * mx) return          # 크기 차이가 너무 크면 불가능
  c = 0
  for (w in W[a]) if (w in W[b]) c++     # 작은 쪽 기준으로 교집합 계산
  if (c * 100 >= T * mx) {
    sim = int(c * 1000 / mx)
    printf "유사도: %d.%d%%\n", int(sim / 10), sim % 10
    print "  - 파일 A: " P[a]
    print "  - 파일 B: " P[b]
    print "--------------------------------------------------------"
    found++
  }
}

# 1단계: 파일 로드 (RS가 NUL이라 파일 전체가 한 레코드로 읽힘)
{
  f = $0
  if ((getline txt < f) <= 0) { close(f); next }
  close(f)

  m = split(tolower(txt), arr, /[[:space:]]+/)
  delete S
  n = 0
  for (k = 1; k <= m; k++) {
    w = arr[k]
    if (w != "" && !(w in S)) { S[w] = 1; n++ }
  }
  if (n < MINW) next

  id = ++N
  P[id] = f
  C[id] = n
  for (w in S) { W[id][w] = 1; df[w]++ }
}

# 2단계: 접두사 필터링 + 검증
END {
  if (N < 2) { print "비교할 마크다운 파일이 2개 이상 필요합니다."; exit 1 }
  print "비교 대상: " N "개 파일"
  print "--------------------------------------------------------"

  for (i = 1; i <= N; i++) {
    n = C[i]
    need = int((T * n + 99) / 100)       # 필요한 최소 공통 단어 수 (올림)
    pl = n - need + 1                    # 접두사 길이

    # 단어를 희귀한 순(문서빈도 오름차순)으로 정렬
    nk = 0; delete K
    for (w in W[i]) K[++nk] = sprintf("%08d %s", df[w], w)
    asort(K)

    # 앞선 파일들의 색인에서 후보 찾기
    delete seen
    for (p = 1; p <= pl; p++) {
      tok = substr(K[p], 10)
      for (q = 1; q <= pc[tok]; q++) {
        j = post[tok, q]
        if (j in seen) continue
        seen[j] = 1
        verify(i, j)
      }
    }

    # 현재 파일의 접두사 단어를 색인에 등록
    for (p = 1; p <= pl; p++) {
      tok = substr(K[p], 10)
      pc[tok]++
      post[tok, pc[tok]] = i
    }
  }
  print "분석 완료: 유사 파일 쌍 " (found + 0) "개"
}'