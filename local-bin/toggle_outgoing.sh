#!/bin/bash
# @DESC: ufw incoming 정책 토글 (allow <-> deny), outgoing은 항상 allow. 'print' 인자를 주면 conky용 상태만 출력
# @TAGS: ufw, toggler, conky
# @USAGE: toggle_outgoing.sh [print]

KEY_FILE=~/.key

# ---------- print 모드: conky용 상태 출력 (sudo 불필요) ----------
print_state() {
  local enabled incoming
  enabled=$(grep -oP '^ENABLED=\K\w+' /etc/ufw/ufw.conf)
  incoming=$(grep -oP '^DEFAULT_INPUT_POLICY="\K[A-Z]+' /etc/default/ufw)

  if [[ $enabled != "yes" ]]; then
    echo '${color grey}⚪ UFW 꺼짐${color}'
  elif [[ $incoming == "ACCEPT" ]]; then
    echo '${color red}UFW Weak${color}'
  else
    echo '${color cyan}UFW Safe${color}'
  fi
}

# ---------- 토글 모드 ----------
# sudo 호출 (비밀번호는 ~/.key에서 읽음)
ufw_sudo() {
  sudo -S ufw "$@" < "$KEY_FILE"
}

# 현재 incoming 기본 정책을 출력: "allow" / "deny" / ""(알 수 없음)
get_incoming_policy() {
  ufw_sudo status verbose 2>/dev/null \
    | sed -n 's/^Default: \([a-z]*\) (incoming).*/\1/p'
}

set_policy() {
  local incoming=$1
  ufw_sudo default allow outgoing > /dev/null
  ufw_sudo default "$incoming" incoming > /dev/null
}

toggle() {
  if [[ $(get_incoming_policy) == "allow" ]]; then
    set_policy deny
    notify-send 'Incoming 차단' 'Safe - 강화 🛡️ 되었습니다'
  else
    set_policy allow
    notify-send 'Incoming 허용' 'Weak - 약화 🤪 되었습니다'
  fi
}

# ---------- 진입점 ----------
case "$1" in
  print) print_state ;;
  "")    toggle ;;
  *)     echo "사용법: ${0##*/} [print]" >&2; exit 1 ;;
esac