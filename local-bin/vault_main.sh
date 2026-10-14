#!/bin/bash
# @DESC: vault 실행 (볼트 - 이미지 최적화, 이미지 이동, 백업)
# @TAGS: vault, optimizer, image, backup
# @USAGE: vault_main.sh
# @STATUS: 사용중

#!/bin/bash

if [ "$1" != "now" ]; then
    sleep 240
fi

/home/lwh/.local/bin/opti_img.sh
/home/lwh/.local/bin/vault_image_001.sh
/home/lwh/.local/bin/vault_image_002.sh
/home/lwh/.local/bin/vault_backup.sh