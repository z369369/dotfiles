#!/bin/bash
# @DESC: download 폴더 정리, rsync로 백업디스크로 복사
# @TAGS: download, organizer, backup
# @USAGE: organize.sh

#organize download folder
cd ~/Downloads
mv *.NSP *.nsp *.xci /media/lwh/lwh_backup/Games/nintendo_nsp 2> /dev/null
mv *.png *.jpg *.jpeg *.tif *.tiff *.bpm *.gif *.eps *.raw "/home/lwh/phone/DCIM/Screenshots" 2> /dev/null
mv *.mp3 *.m4a *.flac *.aac *.ogg *.wav ~/Music 2> /dev/null
mv *.mp4 *.mov *.avi *.mpg *.mpeg *.webm *.mp4 *.mpv *.mp2 *.wmv ~/Videos 2> /dev/null
mv *.pdf *.doc *.ppt *.xls *.xlsx ~/Documents 2> /dev/null
mv *.iso ~/Downloads/iso 2> /dev/null

cd ~/Downloads/Download_phone
mv *.NSP *.nsp *.xci /media/lwh/lwh_backup/Games/nintendo_nsp 2> /dev/null
mv *.png *.jpg *.jpeg *.tif *.tiff *.bpm *.gif *.eps *.raw "/home/lwh/phone/DCIM/Screenshots" 2> /dev/null
mv *.mp3 *.m4a *.flac *.aac *.ogg *.wav ~/Music 2> /dev/null
mv *.mp4 *.mov *.avi *.mpg *.mpeg *.webm *.mp4 *.mpv *.mp2 *.wmv ~/Videos 2> /dev/null
mv *.pdf *.doc *.ppt *.xls *.xlsx ~/Documents 2> /dev/null
mv *.iso ~/Downloads/iso 2> /dev/null

DEST=/media/lwh/lwh_backup

# Verify that the target disk is mounted (to prevent `--delete` from operating on the wrong location if it is unmounted).
mountpoint -q "$DEST" || { echo "백업 디스크가 마운트되지 않았습니다: $DEST" >&2; exit 1; }

cd ~

# -R(--relative): "./" Process in a single call while preserving the relative path.
# Since bash expands globs, non-existent entries are ignored as nullglobs.
shopt -s nullglob

SRC=(
  ./.bash*
  ./.conkyrc ./.config ./.key ./.mozilla ./.ssh ./.xfce4 ./.xprofile
  ./.fonts ./.icons ./.themes
  ./Desktop ./git ./phone
  ./Downloads/program*
  ./.local
)

#nice -n 10 ionice -c3 rsync -aRh --delete \
nice -n 10 ionice -c3 rsync -aRh --delete \
  --info=stats1,progress2 \
  --exclude='/.local/share/Trash/' \
  --exclude='/.local/share/flatpak/' \
  --exclude='/.config/*/Cache/' \
  --exclude='/.config/*/Code Cache/' \
  --exclude='/.config/*/GPUCache/' \
  --exclude='node_modules/' \
  "${SRC[@]}" "$DEST/"

notify-send '파일 정리' '파일 정리가 완료되었습니다!'
