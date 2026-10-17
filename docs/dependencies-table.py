#!/usr/bin/env python3
"""Generate Table 2 of docs/dependencies.md (Phase 2 and Phase 9 of
plans/kodacy-os.md): one row per package of the stock H700 image, with the
KodacyOS verdict, and one row per init script.

    python3 docs/dependencies-table.py <stock packages-file-list.txt> [<kodacy packages-file-list.txt>] > table.md

Rows come from the stock list. KEEP names the packages kept on purpose with
their reason; everything else is `drop`. When the kodacy list is given, a
package that is present there although it is not in KEEP is reported as
`keep: dependency` (buildroot pulled it in for a kept package) so the table
never lies about the image, and the summary at the end counts the drops
against the packages that really left.
"""
import sys
from collections import OrderedDict

KEEP = {
    # hardware template
    "linux": "kernel 7.2.8 + board/batocera/allwinner/h700/linux_patches + DTS",
    "linux-headers": "toolchain",
    "uboot-anbernic-h700": "U-Boot + TF-A + suspend stub, both SPLs",
    "batocera-initramfs": "mounts the squashfs, applies batocera.update",
    "alllinuxfirmwares": "batocera-initramfs copies rtw88/rtw8821c_fw.bin out of it; target tree pruned post-build to rtw88 + regulatory.db + panels",
    "wireless-regdb": "regulatory.db for the WiFi driver",
    "rocknix-joypad": "the H700 pad driver (out-of-tree module)",
    "batocera-image": "genimage/genext2fs on the host",
    "batocera-settings": "batocera-settings-get/set, read by every kept init script",
    "batocera-udev-rules": "pad and device permissions",
    "dosfstools": "FAT boot partition (fsck/mkfs)",
    "e2fsprogs": "ext4 SHARE partition, resize2fs for S02resize",
    "gptfdisk": "S02resize (sgdisk)",
    "parted": "S02resize",
    "dialog": "S02resize progress screen",
    "unzip": "batocera-upgrade, launcher helpers",
    "xz": "batocera-upgrade (boot.tar.xz)",
    "bash": "the kept batocera-* helper scripts",
    "triggerhappy": "power button (kodacy-power)",
    "pm-utils": "pm-suspend, /etc/pm/sleep.d (H700 hook 90h700-sleep)",
    "fake-hwclock": "no battery RTC: clock across reboots",
    "dropbear": "ssh",
    "gesftpserver": "scp/sftp over dropbear",
    "eudev": "device nodes, hotplug",
    "kmod": "modules",
    "alsa-lib": "sound (OpenAL's ALSA backend)",
    "alsa-utils": "amixer for S20-audio-volume and the sleep hook",
    "libdrm": "KMS",
    "mesa3d": "Panfrost GLES2/EGL/GBM for SDL2 KMS/DRM",
    "llvm": "hard dependency of the panfrost driver in this buildroot (MESA3D_LLVM)",
    "sdl2": "LÖVE's window, input and GL context (KMSDRM + GLES)",
    "libcurl": "the launcher downloads (curl binary)",
    "ca-certificates": "TLS to studio.kodacy.pl",
    "libopenssl": "TLS, sha256 checks, S35securepasswd",
    "wpa_supplicant": "the OS owns WiFi, WPS included (docs/wifi.md)",
    "dhcpcd": "address on wlan0 (S08wifi)",
    "chrony": "clock for TLS (S49chronyd)",
    "iw": "wireless tooling, country code",
    "iproute2": "ip link/addr in S08wifi and probes",
    "libnl": "wpa_supplicant nl80211, iw",
    "love": "LÖVE 11.5, the only runtime",
    "kodacy-launcher": "the released kodacy.love + supervisor",
    "batocera-luajit": "LÖVE's Lua",
    "openal": "love.audio",
    "freetype": "love.font",
    "libmodplug": "LÖVE decoder",
    "libogg": "LÖVE decoder",
    "libvorbis": "LÖVE decoder",
    "libtheora": "LÖVE decoder",
    "mpg123": "LÖVE decoder",
    "zlib": "LÖVE, everything",
    "glibc": "toolchain",
    "gcc-final": "toolchain",
    "toolchain": "toolchain",
    "toolchain-buildroot": "toolchain",
    "skeleton": "rootfs skeleton",
    "skeleton-init-common": "rootfs skeleton",
    "skeleton-init-sysv": "rootfs skeleton",
    "initscripts": "rcS/rcK",
    "tzdata": "time zones (Europe/Warsaw)",
    "coreutils": "GNU userland the init scripts rely on",
    "diffutils": "GNU userland",
    "findutils": "GNU userland",
    "gawk": "GNU userland",
    "grep": "GNU userland",
    "gzip": "GNU userland",
    "sed": "GNU userland",
    "tar": "GNU userland",
    "which": "GNU userland",
    "ncurses": "dialog, terminal",
    "procps-ng": "ps, sysctl",
    "psmisc": "killall (S31kodacy)",
    "start-stop-daemon": "init scripts",
    "util-linux": "mount, agetty, login, logger, hwclock",
    "ifupdown": "loopback interface",
    "ifupdown-scripts": "loopback interface (S40network -> S07network)",
    "iputils": "ping for debugging",
    "dash": "/bin/sh",
    "readline": "dependency of bash",
    "libxcrypt": "batocera-initramfs, login",
}

INIT_KEEP = {
    "S00bootcustom": "runs /boot/custom.sh if the owner puts one there",
    "S01date": "fake-hwclock restore",
    "S02resize": "first-boot resize of SHARE",
    "S02led-status": "battery LED (H700 overlay), useful to a child",
    "S02sysctl": "procps sysctl",
    "S03urandom": "entropy seed",
    "S04populate": "/var layout, ld.so.cache",
    "S05udevd": "eudev (S10udevd renamed by Batocera's post-build)",
    "S06modprobe": "/etc/modules.conf (snd_seq)",
    "S07network": "loopback (ifupdown-scripts' S40network renamed)",
    "S08wifi": "ours: wpa_supplicant + dhcpcd",
    "S09wifi-probe": "rtw88 quirk (H700 overlay)",
    "S11modules": "initscripts",
    "S11share": "mounts /userdata",
    "S12populateshare": "seeds /userdata/system/batocera.conf",
    "S18governor": "CPU governor",
    "S20-audio-volume": "DAC volume (H700 overlay)",
    "S26system": "hostname, timezone",
    "S27brightness": "backlight",
    "S31kodacy": "ours: the supervisor",
    "S35securepasswd": "ours: /etc/shadow at boot",
    "S47fake-hwclock": "fake-hwclock save",
    "S49chronyd": "chrony",
    "S50dropbear": "ssh",
    "S50triggerhappy": "ours: power button",
    "S99userservices": "/userdata/system/services",
    "rcS": "init", "rcK": "init",
}


def packages(path):
    pk = OrderedDict()
    initd = {}
    for line in open(path, encoding="utf-8", errors="replace"):
        line = line.rstrip("\n")
        if "," not in line:
            continue
        p, f = line.split(",", 1)
        pk[p] = pk.get(p, 0) + 1
        f = f.lstrip("./")
        if f.startswith("etc/init.d/"):
            initd[f.split("/")[-1]] = p
    return pk, initd


def packages_from_target_files(stock_list_path, target_files_path):
    """A tree reused across configs keeps every package's file list, so the
    trimmed image's packages-file-list.txt lists packages that are not in
    it. The truth is the assembled target directory: a package counts as
    present when at least one of its stock files exists there."""
    present = set(l.rstrip("\n") for l in open(target_files_path, encoding="utf-8", errors="replace"))
    owners = {}
    rows = []
    for line in open(stock_list_path, encoding="utf-8", errors="replace"):
        line = line.rstrip("\n")
        if "," not in line:
            continue
        p, f = line.split(",", 1)
        f = f.lstrip("./")
        rows.append((p, f))
        owners.setdefault(f, set()).add(p)
    # Only files that exactly one stock package installs count as evidence:
    # paths two packages both write (batocera.arch from batocera-system and
    # kodacy-system, a shared init script, ...) would otherwise mark the
    # dropped package as present.
    pk = OrderedDict()
    for p, f in rows:
        if f in present and len(owners[f]) == 1:
            pk[p] = pk.get(p, 0) + 1
    return pk


def main():
    stock, stock_init = packages(sys.argv[1])
    kodacy = None
    if len(sys.argv) > 2:
        second = open(sys.argv[2], encoding="utf-8", errors="replace").readline()
        if "," in second:
            kodacy = packages(sys.argv[2])[0]
        else:
            kodacy = packages_from_target_files(sys.argv[1], sys.argv[2])
            for p in ("love", "kodacy-launcher", "kodacy-system", "dhcpcd", "chrony"):
                kodacy.setdefault(p, 1)
    print("| package (stock H700 image) | files | verdict |")
    print("|---|---:|---|")
    drops = 0
    wrong = []
    for p, n in stock.items():
        if p in KEEP:
            v = "keep: " + KEEP[p]
        elif kodacy is not None and p in kodacy:
            v = "keep: dependency (buildroot pulled it in for a kept package; name the package when known)"
        else:
            v = "drop"
            drops += 1
            if kodacy is not None and p in kodacy:
                wrong.append(p)
        print(f"| `{p}` | {n} | {v} |")
    if kodacy is not None:
        for p, n in kodacy.items():
            if p not in stock:
                v = "keep: " + KEEP.get(p, "new in KodacyOS")
                print(f"| `{p}` (new) | {n} | {v} |")
    print()
    print("| init script (stock) | package | verdict |")
    print("|---|---|---|")
    for s, p in sorted(stock_init.items()):
        v = ("keep: " + INIT_KEEP[s]) if s in INIT_KEEP else "drop"
        print(f"| `{s}` | `{p}` | {v} |")
    print()
    left = len(stock) - len([p for p in stock if kodacy is not None and p in kodacy]) if kodacy is not None else None
    print(f"Summary: {len(stock)} packages in the stock image, {drops} marked drop"
          + (f", {left} absent from the KodacyOS image, {len(kodacy)} present there." if kodacy is not None else "."))


if __name__ == "__main__":
    main()
