#!/bin/bash
# @DESC: linux main
# @TAGS: linux, startup
# @USAGE: linux_main.sh
# @STATUS: 사용중

if [ "$1" != "now" ]; then
    sleep 240
fi

#[protection]do not excute DCIM, pictures duplicate
/home/lwh/.local/bin/vault_image.sh 001_lwh
/home/lwh/.local/bin/vault_backup.sh 001_lwh

/home/lwh/.local/bin/rename_screenshot.sh
/home/lwh/.local/bin/move_gemini_img.sh
/home/lwh/.local/bin/opti_img.sh