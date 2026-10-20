#!/bin/bash
# @DESC: vault 실행 (볼트 - 이미지 최적화, 이미지 이동, 백업)
# @TAGS: vault, optimizer, image, backup
# @USAGE: vault_main.sh
# @STATUS: 사용중

#!/bin/bash

if [ "$1" != "now" ]; then
    sleep 240
fi

#[protection]do not excute DCIM, pictures duplicate
/home/lwh/.local/bin/opti_img.sh

/home/lwh/.local/bin/vault_image.sh 001_lwh
/home/lwh/.local/bin/vault_backup.sh 001_lwh