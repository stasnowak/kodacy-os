# KodacyOS

KodacyOS = Batocera's Allwinner H700 **hardware template** + LÖVE 11.5 + the
Kodacy launcher. It boots the Anbernic RG40XX V and RG35XX H straight into
`kodacy.love` (released by [kodacy-studio](https://github.com/stasnowak/kodacy-studio)),
with the emulators, Kodi, the Wayland desktop and PortMaster gone from the
image. The plan that drives this repo is `plans/kodacy-os.md` in
`kodacy-studio`; this README records the facts the plan asks for.

## What this repo is

A fork of [batocera-linux/batocera.linux](https://github.com/batocera-linux/batocera.linux)
(GPL stays), pinned to upstream `master` commit
**`38fe6e8bcce84c9b815692ec4da5b6b310cc4e6d`** (2026-10-17, "Merge pull
request #17135"): Linux 7.2.8 + 46 H700 patches, mainline U-Boot 2026.04 +
TF-A + SRAM suspend stub (firmware deep sleep), Panfrost/Mesa, mainline
`rtw88_8821cs`, buildroot `2026.05-git` (submodule commit `2976d683`).
Rebase onto the `batocera-44` tag when v44 is released (planned November
2026).

Batocera is the template, not a base to inherit: we keep what makes the
H700 boards boot and work (kernel + `linux_patches/` + DTS, U-Boot, firmware,
partition layout, image assembly, initramfs, the buildroot tree and the
toolchain). Everything else is dropped unless `docs/dependencies.md` gives a
reason to keep it.

## Where our changes live

So that merges with upstream stay cheap, everything KodacyOS adds lives in:

- `configs/kodacy-board.common` and `configs/batocera-kodacy-h700.board`
  (the `batocera-` prefix is what the upstream `Makefile` hard-codes for
  `configs/<prefix><target>.board`; with it, `make kodacy-h700-build` works
  with **no** Makefile change and builds into `output/kodacy-h700/`),
- `board/kodacy/` (per-device image definitions, the root overlay, the
  post-build script),
- `package/kodacy/` (LÖVE, the launcher, later `kodacy-system`),
- `docs/`,
- one `source` line in `Config.in` and one `include` line in `external.mk`
  that register `package/kodacy/`.

Nothing else in the upstream tree is edited. `README.md` is ours.

On Windows, clone with `git config core.autocrlf false` (set before the
first checkout, or re-checkout afterwards): the upstream tree is LF-only and
U-Boot's `extlinux.conf` parser, genimage and kconfig do not tolerate CR.

## Build host

Any Linux with Docker works; this is the host the first builds ran on:

- Windows 11 Pro, Docker Desktop 29.6 (WSL2 backend), 32 CPUs and 30 GiB RAM
  given to the Docker VM, 62 GiB RAM physical, 734 GB free on `C:`.
- The buildroot tree is **not** on a Windows path (a bind-mounted Windows
  folder is far too slow for buildroot). It lives in the Docker volume
  `kodacy-os-build`, mounted at `/build` in a persistent container
  `kodacy-os-build` made from this repo's `docker/Dockerfile`
  (`docker build -t batoceralinux/batocera.linux-build docker/`), started
  as uid 1000 (`-e HOST_UID=1000 -e HOST_GID=1000`, the image's
  `entry-point.sh` switches user) with `sleep infinity`.
- Inside the container the build is **direct** (the upstream Makefile's
  `DIRECT_BUILD=1`, since there is no Docker inside Docker), with
  `PARALLEL_BUILD=y` and `BATCH_MODE=1` as Batocera's own
  `scripts/linux/batoceraBuild` uses. Upstream's direct path leaks
  `MAKEFLAGS=r` (`--no-builtin-rules`) into buildroot and breaks packages
  such as `host-xxhash`; this fork's `Makefile` clears `MAKEFLAGS` for the
  sub-make (one line, commit "upstream fix: DIRECT_BUILD").
- A cold build of upstream master drifts within months. Two more labelled
  "upstream fix" commits were needed on 17 Oct 2026: the ten Kodi language
  packs upstream pins had vanished from `mirrors.kodi.tv`, and
  `host-cargo-c` (GitHub tag without `Cargo.lock`) vendored crates that need
  rustc 1.97 on buildroot's 1.95, fixed by fetching the crates.io package
  with its lockfile. Drop or re-check these at every rebase.
- ccache: `buildroot-ccache/` in the repo (direct builds), kept between
  builds (`make <target>-ccache-stats`). Downloads: `dl/`.
- Rule (owner, 17 Oct 2026): build **once** per phase ladder, at the end,
  incrementally in the one `output/kodacy-h700` tree. Never start a second
  output tree, never build between phases.
- Disk: a full stock tree (`output/h700/`) is **430 GB** with per-package
  directories, and the kodacy tree is the same size until Phase 7 trims the
  image. Keep one tree at a time: the stock images are copied out and the
  tree deleted (`rm -rf output/h700`, it rebuilds in under five hours).
  Docker Desktop's `docker_data.vhdx` never shrinks by itself; space freed
  inside it is reused, and to give it back to Windows stop Docker and run
  `Optimize-VHD` / diskpart `compact vdisk` on the file.

Commands, from a Windows shell (`MSYS_NO_PATHCONV=1` for Git Bash):

```sh
# one-time
docker volume create kodacy-os-build
docker build -t batoceralinux/batocera.linux-build docker/
docker run --rm -v kodacy-os-build:/build batoceralinux/batocera.linux-build chown 1000:1000 /build
docker run -d --name kodacy-os-build --init --restart unless-stopped \
  -e HOST_UID=1000 -e HOST_GID=1000 -v kodacy-os-build:/build -w /build \
  batoceralinux/batocera.linux-build sleep infinity
docker exec -u 1000:1000 -e HOME=/home/batocera kodacy-os-build bash -c \
  'cd /build && git clone https://github.com/stasnowak/kodacy-os.git && cd kodacy-os && git submodule update --init --depth 1 buildroot'

# every build (stock Batocera for the H700: Phase 1 baseline)
docker exec -u 1000:1000 -e HOME=/home/batocera -w /build/kodacy-os kodacy-os-build bash -c \
  'PARALLEL_BUILD=y BATCH_MODE=1 DIRECT_BUILD=1 make h700-build'
# KodacyOS
docker exec -u 1000:1000 -e HOME=/home/batocera -w /build/kodacy-os kodacy-os-build bash -c \
  'PARALLEL_BUILD=y BATCH_MODE=1 DIRECT_BUILD=1 make kodacy-h700-build'
# one package only (exact syntax: make help)
docker exec -u 1000:1000 -e HOME=/home/batocera -w /build/kodacy-os kodacy-os-build bash -c \
  'PARALLEL_BUILD=y BATCH_MODE=1 DIRECT_BUILD=1 make kodacy-h700-pkg PKG=love-rebuild'
# copy the images out
docker cp kodacy-os-build:/build/kodacy-os/output/kodacy-h700/images/batocera/images ./images
```

On a plain Linux host with Docker, the upstream way works unchanged:
`make build-docker-image` (or `make pull-docker-image`), then
`make h700-build` / `make kodacy-h700-build`.

Outputs: `output/<target>/images/batocera/images/<device>/batocera-h700-<device>-<version>-<date>.img.gz`
(+ `.sha256`, `boot.tar.xz`, `batocera.version`).

### Stock build (Phase 1 baseline)

| | |
|---|---|
| started | 2026-10-17 14:18 CEST, `make h700-build` (after the three drift fixes; `dl/` already filled, ccache cold) |
| wall time | **4 h 39 min** (`real 278m58s`, `user 4109m`, 32 cores, `PARALLEL_BUILD=y`) |
| disk | `output/h700/` **430 GB** after the build (per-package directories hard-link a lot of it), `dl/` 34 GB, `buildroot-ccache/` 5.1 GB; 846 packages in `packages-file-list.txt`; version string `44-dev-8b2ed549b1` |
| output | `output/h700/images/batocera/images/<device>/batocera-h700-<device>-44-20261017.img.gz`, 37 device directories |
| image | 2.41 GB `.img.gz` per device; inside: `boot/batocera` squashfs **1.88 GB** + `boot/rufomaculata` (libretro cores) **518 MB**, `boot/linux` 26.3 MB, `boot/initrd.lz4` 1.1 MB, one `.dtb`, `u-boot-sunxi-with-spl.bin` 680 KB |
| checked | `gzip -t` passes on all eight `anbernic-rg40xx-v*` and `anbernic-rg35xx-h*` images; copies in `images/stock/` of the Windows clone (git-ignored) |

### KodacyOS build (Phases 3 to 9, built once at the end)

KodacyOS = Batocera's H700 hardware template + LÖVE 11.5 + the Kodacy
launcher. Image names: `kodacy-h700-<device>-<version>-<date>.img.gz`
(`board/kodacy/scripts/post-image.sh`); the file names the initramfs and
`batocera-upgrade` read (`batocera.board`, `batocera.version`,
`boot/batocera`, `batocera-boot.conf`) keep their upstream names.

| | |
|---|---|
| wall time | _(filled when the trimmed build completes)_ |
| squashfs / image | _(filled when the trimmed build completes; stock was 1.88 GB + 518 MB cores)_ |
| boot to Home | _(measured on the console)_ |
| processes at Home | _(from `ps -o comm= \| sort -u` on the console)_ |

## Flashing

The `.img.gz` is a whole-card image: MBR, U-Boot SPL at byte offset 8192,
partition 1 FAT32 `BATOCERA` (8 GB, holds `boot/batocera` = the squashfs
rootfs, the kernel, the DTBs, `extlinux/extlinux.conf`), partition 2 ext4
`SHARE` (512 MB, grown to the rest of the card at first boot = `/userdata`).
Nothing is formatted by hand: write the image raw to the whole card
(Etcher / Rufus "DD mode" / `gzip -dc … | dd of=/dev/sdX bs=4M`), a 16 GB
card or larger. Windows afterwards shows only the FAT32 partition, which is
fine; `extlinux/extlinux.conf` on it is editable from Windows.

Which image: the SoC's DRAM type picks the SPL, so it picks the image
directory. `anbernic-rg40xx-v` = LPDDR4, `anbernic-rg40xx-v-ddr3` = LPDDR3
(same for `anbernic-rg35xx-h` / `-ddr3`). The wrong SPL hangs the SoC with a
black screen and no console. Check before flashing, on the unit's current
OS over ssh (the stock Anbernic boot0 at sector 16 declares the DRAM type):

```sh
dd if=/dev/mmcblk0 bs=512 skip=16 count=128 of=/tmp/boot0.bin
od -A x -t x4 -j 0x38 -N 8 /tmp/boot0.bin
# second word: 7 = LPDDR3 (-ddr3 image), 8 = LPDDR4 (plain image)
```

The panel revision is a DTB, not an SPL: a garbled screen on a unit that
otherwise boots (ssh works) means the other panel. From Phase 3 on every
KodacyOS image carries both DTBs and switching is one line in
`extlinux/extlinux.conf` (`FDT /boot/sun50i-h700-anbernic-rg40xx-v.dtb` ↔
`…-v2-panel.dtb`; `rg35xx-h` ↔ `rg35xx-h-rev6-panel`). The stock Phase 1
images have one DTB each: flash the `-v2-panel` / `-rev6-panel` sibling
instead.

First boot: the SHARE partition is resized (one reboot), then
EmulationStation (stock) or Kodacy (from Phase 6). ssh: `root@<ip>`,
password `linux` (dropbear). On stock, WiFi can be set without the UI by
putting `wifi.enabled=1`, `wifi.ssid=…`, `wifi.key=…` into
`system/batocera.conf` on the SHARE partition.

## Rebasing on upstream

```sh
git fetch upstream
git merge <tag or commit>      # e.g. batocera-44
git submodule update --init --depth 1 buildroot
```

Conflicts can only come from `Config.in`, `external.mk` and `README.md`
(the three upstream files we touch) plus the copies in `configs/kodacy-*`
and `board/kodacy/` that need a manual diff against their upstream
originals (`configs/batocera-board.common`, `configs/batocera-h700.board`,
`board/batocera/allwinner/h700/<device>/`).
