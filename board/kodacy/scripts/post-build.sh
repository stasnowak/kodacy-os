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

# Phase 6: Kodacy is the frontend. system.es.atstartup=0 is kept even though
# ES is gone since Phase 7 (harmless, and stock scripts may read it).
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

# Phase 7: firmware. batocera-initramfs needs the alllinuxfirmwares build dir
# for rtw88/rtw8821c_fw.bin, so the package stays, but the target copy of the
# whole linux-firmware tree (hundreds of MB) is cut down to what the H700
# hardware loads: the rtw88 WiFi firmware, the regulatory database
# (wireless-regdb) and the panel timing files (H700 overlay).
FW="${TARGET_DIR}/lib/firmware"
if [ -d "${FW}" ]; then
    find "${FW}" -mindepth 1 -maxdepth 1 \
        ! -name rtw88 ! -name panels ! -name 'regulatory.db*' \
        -exec rm -rf {} +
    if [ -d "${FW}/rtw88" ]; then
        find "${FW}/rtw88" -type f ! -name 'rtw8821c*' -delete
    fi
    echo "kodacy post-build: /lib/firmware kept: $(ls "${FW}" | tr '\n' ' ')" >&2
fi

# Phase 7/8: init scripts of dropped packages that still arrive through
# overlays or kept packages (overlays cannot delete files): S15virtualevents
# (evsieve, batocera-udev-rules), S08connman (Batocera's base overlay; connman
# is not built since Phase 8), S41dhcpcd (buildroot's dhcpcd package; S08wifi
# runs dhcpcd for wlan0 itself).
for s in \
    S15virtualevents \
    S08connman \
    S41dhcpcd \
    ; do
    rm -f "${TARGET_DIR}/etc/init.d/${s}"
done
rm -rf "${TARGET_DIR}/etc/connman" "${TARGET_DIR}/var/lib/connman"

# The supervisor and the init scripts must be executable whatever the
# overlay's file modes were on the host that committed them.
chmod 0755 "${TARGET_DIR}/usr/bin/kodacy-supervisor" \
           "${TARGET_DIR}/usr/bin/kodacy-power" \
           "${TARGET_DIR}/etc/init.d/S31kodacy" \
           "${TARGET_DIR}/etc/init.d/S35securepasswd" \
           "${TARGET_DIR}/etc/init.d/S50triggerhappy" \
           "${TARGET_DIR}/etc/init.d/S08wifi" 2>/dev/null || true
