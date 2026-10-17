#!/bin/bash -e
# KodacyOS post-build script. BR2_ROOTFS_POST_BUILD_SCRIPT in
# configs/kodacy-board.common lists Batocera's post-build-script.sh first and
# this one second, so everything upstream does to the target tree has
# happened when we run. Overlays can add and replace files but not delete or
# edit them: that is what this script is for.
#
# PWD = source dir, BUILD_DIR, HOST_DIR, BINARIES_DIR, TARGET_DIR as buildroot
# passes them.

CONF="${TARGET_DIR}/usr/share/batocera/datainit/system/batocera.conf"

set_conf() {
    # $1 = key, $2 = value: replace the (possibly commented) line or append
    if grep -qE "^#?[ ]*$1=" "${CONF}"; then
        sed -i -e "s|^#\?[ ]*$1=.*|$1=$2|" "${CONF}"
    else
        printf '%s=%s\n' "$1" "$2" >> "${CONF}"
    fi
}

# Phase 6: Kodacy is the frontend. ES stays installed (debug fallback) but
# S31emulationstation honours system.es.atstartup=0 and does not start it.
set_conf system.es.atstartup 0
set_conf system.hostname kodacy

# Phase 6: fixed root password, from the build environment only (never
# committed). Only the hash lands in the image; S35securepasswd (our copy in
# board/kodacy/fsoverlay) reads it at boot. Unset = stock "linux".
mkdir -p "${TARGET_DIR}/usr/share/kodacy"
if [ -n "${KODACY_ROOT_PASSWD}" ]; then
    openssl passwd -6 "${KODACY_ROOT_PASSWD}" > "${TARGET_DIR}/usr/share/kodacy/root.shadow"
    chmod 0600 "${TARGET_DIR}/usr/share/kodacy/root.shadow"
    echo "kodacy post-build: root password hash installed" >&2
else
    rm -f "${TARGET_DIR}/usr/share/kodacy/root.shadow"
    echo "kodacy post-build: KODACY_ROOT_PASSWD not set, root password stays 'linux'" >&2
fi

# The supervisor and the init script must be executable whatever the
# overlay's file modes were on the host that committed them.
chmod 0755 "${TARGET_DIR}/usr/bin/kodacy-supervisor" \
           "${TARGET_DIR}/etc/init.d/S31kodacy" \
           "${TARGET_DIR}/etc/init.d/S35securepasswd" \
           "${TARGET_DIR}/usr/share/batocera/datainit/roms/ports/Kodacy.sh" 2>/dev/null || true
