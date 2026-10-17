#!/bin/bash -e
# KodacyOS post-image script, second entry of BR2_ROOTFS_POST_IMAGE_SCRIPT
# after Batocera's post-image-script.sh, which built
#   images/batocera/images/<device>/batocera-h700-<device>-<ver>-<date>.img.gz
# plus .md5/.sha256 and the MD5SUMS/SHA256SUMS lists. Phase 9: the files get
# our name, kodacy-h700-<device>-<ver>-<date>.img.gz. boot.tar.xz and the
# file names the initramfs and batocera-upgrade read (batocera.board,
# batocera.version, boot/batocera) keep theirs: those are the template.

IMAGES="${BINARIES_DIR}/batocera/images"
[ -d "${IMAGES}" ] || exit 0

for f in "${IMAGES}"/*/batocera-h700-*.img.gz; do
    [ -e "$f" ] || continue
    d=$(dirname "$f"); b=$(basename "$f")
    n="kodacy-${b#batocera-}"
    mv "$f" "$d/$n"
    for ext in md5 sha256; do
        [ -e "$f.$ext" ] && mv "$f.$ext" "$d/$n.$ext"
    done
    echo "kodacy post-image: $d/$n" >&2
done

# the checksum lists name the files: rebuild them
for list in MD5SUMS SHA256SUMS; do
    sed -i -e 's/  batocera-h700-/  kodacy-h700-/' "${BINARIES_DIR}/batocera/${list}" 2>/dev/null || true
done
