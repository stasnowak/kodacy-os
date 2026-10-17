# Dependencies: what Kodacy needs vs what the H700 build has

Phase 2 of `plans/kodacy-os.md` (kodacy-studio). Two sources: the fork's
config files (desk check, done from `output/h700/.config` of the stock
`h700` build at upstream commit `38fe6e8`, 2026-10-17) and the booted stock
image (device check, `studio/tools/batocera-probe.sh` over ssh; **pending
until a console is at hand**). Rows marked _(device)_ still need the probe.

## Table 1: what Kodacy needs

Verdicts: `present` (already in the stock H700 image), `missing: enable
BR2_…` (an upstream option), `missing: new package`.

| need | why | stock H700 | verdict |
|---|---|---|---|
| LÖVE 11.5 | the only runtime: games and the launcher | no package in Batocera (only `libretro-chailove`) | **missing: new package** `package/kodacy/love` (Phase 4) |
| LuaJIT | LÖVE's Lua | `BR2_PACKAGE_BATOCERA_LUAJIT=y` (OpenResty fork, pulled by `solarus-engine`); buildroot's own `luajit` not enabled | present; `love` selects `BATOCERA_LUAJIT` so it stays when solarus goes |
| SDL2 | LÖVE's window, input, GL context | `BR2_PACKAGE_SDL2=y` via `BATOCERA_SDL2`, with `SDL2_KMSDRM=y`, `SDL2_OPENGLES=y`, `SDL2_WAYLAND=y`, `SDL2_X11=y` (Xwayland pulls Xorg) | present; KMSDRM + OPENGLES are what we need, Wayland only while labwc exists (Phase 5), X11 goes with Xwayland (Phase 7) |
| OpenGL ES 2 + EGL + GBM | LÖVE renders through the ES context SDL hands it | `BATOCERA_PANFROST_MESA3D=y`: `MESA3D_OPENGL_ES=y`, `MESA3D_OPENGL_EGL=y`, `MESA3D_GBM=y`, `MESA3D_GALLIUM_DRIVER_PANFROST=y`, `MESA3D_LLVM=y`; `HAS_LIBGL=y` comes from GLX for Xorg | present. **GL decision**: native GLES2 through stock SDL2 on KMS/DRM + Mesa Panfrost; the supervisor exports `SDL_VIDEODRIVER=kmsdrm` when no compositor runs (`wayland` under labwc). `gl4es` only if LÖVE insists on desktop GL. To be confirmed by `renderer-probe` in Phase 4 _(device)_. Keep `drirc.d/10-h700-panfrost.conf`. |
| libdrm | KMS | `BR2_PACKAGE_LIBDRM=y` | present |
| OpenAL | `love.audio` | `BR2_PACKAGE_OPENAL=y` (ALSA backend; pipewire + pulseaudio are also in the stock image) | present |
| FreeType | `love.font` | `BR2_PACKAGE_FREETYPE=y` | present |
| libmodplug, libvorbis, libogg, libtheora, mpg123, zlib | LÖVE's decoders | all `=y` | present |
| `curl` binary | the launcher downloads games and `version.json` | `BR2_PACKAGE_LIBCURL_CURL=y` (+ `NGHTTP2`) | present |
| `openssl` binary | sha256 in the launcher's self-update, later signatures | `BR2_PACKAGE_LIBOPENSSL_BIN=y` | present |
| ca-certificates | TLS to studio.kodacy.pl | `BR2_PACKAGE_CA_CERTIFICATES=y` | present |
| `unzip` | launcher helpers | `BR2_PACKAGE_UNZIP=y` | present |
| wpa_supplicant + `wpa_cli` + WPS | the OS owns WiFi (Phase 8), the launcher's screens drive `wpa_cli` | `BR2_PACKAGE_WPA_SUPPLICANT=y` with `_NL80211`, `_CLI`, `_CTRL_IFACE`, `_WPA3`, `_EAP`, `_DBUS`, `_WEXT`, `_WIRED`; **no** `_WPS`, **no** `_PASSPHRASE` | present, **missing: enable `BR2_PACKAGE_WPA_SUPPLICANT_WPS=y`, `_PASSPHRASE=y`** (Phase 8) |
| DHCP client | an address on wlan0 without connman | none: `BR2_PACKAGE_DHCPCD` unset, no busybox (`udhcpc`), connman does DHCP today | **missing: enable `BR2_PACKAGE_DHCPCD=y`** (Phase 8) |
| time sync | TLS needs a sane clock; the RG40XX V has no battery RTC | `BR2_PACKAGE_NTP=y` + `NTP_NTPD=y` (stock), `fake-hwclock`; connman also syncs | present as ntpd; plan says `chrony` (**missing: enable `BR2_PACKAGE_CHRONY=y`**, Phase 8) or keep `ntpd` with a reason |
| triggerhappy | power button | `BR2_PACKAGE_TRIGGERHAPPY=y` + `BATOCERA_TRIGGERHAPPY` (H700 conf: `KEY_POWER` → `batocera-shutdown`) | present |
| evtest | pad probes | `BR2_PACKAGE_EVTEST=y` | present |
| dropbear | ssh | `BR2_PACKAGE_DROPBEAR=y` (+ client, small) | present |
| pm-utils | owner of `/etc/pm/sleep.d` (H700 hook `90h700-sleep`) | `BR2_PACKAGE_PM_UTILS=y` | present (keep while sleep is in scope) |
| python3 | only if a kept script needs it | `BR2_PACKAGE_PYTHON3=y` (configgen, ES tooling) | present; drop candidate once ES and configgen are gone (the upgrade script is sh) |
| connman | WiFi until Phase 8 | `BR2_PACKAGE_CONNMAN=y` (+ wifi, client, ethernet, iptables, loopback) | **drop: replaced by wpa_supplicant + dhcpcd + chrony (Phase 8)**; `S08wifi` in our overlay, `S08connman` removed post-build, no D-Bus |
| wpa_supplicant (WPS, WPA3, passphrase, cli, ctrl iface) | the OS owns WiFi; the launcher drives `wpa_cli` | selected by `kodacy-system` | keep: `docs/wifi.md` |
| dhcpcd | address on wlan0 | selected by `kodacy-system` | keep: started by `S08wifi` for wlan0 only |
| chrony | clock for TLS, no battery RTC | selected by `kodacy-system`, `S49chronyd`, `/etc/chrony.conf` | keep: with `fake-hwclock` for the boot-time value |
| rtw88 firmware | `rtw88/rtw8821c_fw.bin` | `BR2_PACKAGE_BATOCERA_LINUX_FIRMWARES=y` (the exact file list is in that package) | present _(device: `ls /lib/firmware/rtw88`)_ |
| regulatory database | `iw reg set` | `BR2_PACKAGE_WIRELESS_REGDB=y`, `BR2_PACKAGE_IW=y` | present |
| Bluetooth blob | only if Bluetooth stays | `BLUEZ5_UTILS=y`, `BATOCERA_BLUETOOTH=y`; the RTL8821CS BT firmware/config availability _(device)_ | present; drop candidate (follow-up F) |

## Table 2: everything else the stock image installs

Generated by `docs/dependencies-table.py` (18 Oct 2026) from the Phase 6
build's `packages-file-list.txt` (the stock H700 package set plus our five:
848 packages) checked against the file list of the trimmed image's rootfs
(`images/kodacy/meta/target-files.txt`, 3752 files, 356 MB uncompressed,
112.7 MB squashfs). A stock package counts as present only through files no
other package installs. Rows marked `keep: dependency` are packages
buildroot pulled in for a kept one: `popt` for gptfdisk, `linux-pam` for
util-linux login, `readline`/`expat`/`libcap`/`libusb`/`libzlib`/
`debianutils`/`sysvinit` for the base userland, `clang`/`libclc`/
`spirv-*` for Mesa's Panfrost compiler, `usb_modeswitch`/`jimtcl` by
eudev-side selects (small; their databases are removed post-build);
`batocera-system`/`batocera-scripts`/`batocera-triggerhappy` show up
through the files `kodacy-system.mk` installs from their directories;
`bluez5_utils` only through two configs of Batocera's base overlay, removed
post-build.

| package (stock H700 image) | files | verdict |
|---|---:|---|
| `abuse` | 1 | drop |
| `acl` | 59 | drop |
| `adwaita-icon-theme-light` | 3309 | drop |
| `aelightgun` | 2 | drop |
| `aimtrak-guns` | 2 | drop |
| `alllinuxfirmwares` | 4757 | keep: batocera-initramfs copies rtw88/rtw8821c_fw.bin out of it; target tree pruned post-build to rtw88 + regulatory.db + panels |
| `alsa-lib` | 140 | keep: sound (OpenAL's ALSA backend) |
| `alsa-plugins` | 51 | drop |
| `alsa-ucm-conf` | 831 | drop |
| `alsa-utils` | 104 | keep: amixer for S20-audio-volume and the sleep hook |
| `amiberry` | 31 | drop |
| `at-spi2-core` | 213 | drop |
| `attr` | 29 | drop |
| `avahi` | 157 | drop |
| `b43-firmware` | 117 | drop |
| `bash` | 113 | keep: the kept batocera-* helper scripts |
| `batocera-audio` | 13 | drop |
| `batocera-backglass` | 4 | drop |
| `batocera-battery-checker` | 2 | drop |
| `batocera-bezel` | 613 | drop |
| `batocera-bezel-overlay` | 13 | drop |
| `batocera-bluetooth` | 2 | drop |
| `batocera-controlcenter` | 36 | drop |
| `batocera-controller-overlays` | 57 | drop |
| `batocera-desktopapps` | 38 | drop |
| `batocera-drminfo` | 1 | drop |
| `batocera-emulationstation` | 207 | drop |
| `batocera-es-system` | 293 | drop |
| `batocera-es-web-ui` | 3 | drop |
| `batocera-ethtool` | 1 | drop |
| `batocera-gun-calibrator` | 3 | drop |
| `batocera-labwc` | 14 | drop |
| `batocera-launch-cdogs` | 6 | drop |
| `batocera-launch-cgenius` | 6 | drop |
| `batocera-launch` | 130 | drop |
| `batocera-launch-drastic` | 6 | drop |
| `batocera-launch-fallout` | 8 | drop |
| `batocera-launch-flycast` | 8 | drop |
| `batocera-launch-kodi` | 7 | drop |
| `batocera-launch-libretro` | 89 | drop |
| `batocera-launch-libretro-mame` | 9 | drop |
| `batocera-launch-mame-common` | 21 | drop |
| `batocera-launch-mame` | 10 | drop |
| `batocera-launch-mupen64plus` | 7 | drop |
| `batocera-launch-openjazz` | 6 | drop |
| `batocera-led-handheld` | 4 | drop |
| `batocera-luajit` | 31 | keep: LÖVE's Lua |
| `batocera-nfc` | 4 | drop |
| `batocera-notice` | 1 | drop |
| `batocera-onscreen-keyboard` | 4 | drop |
| `batocera-pygame` | 23 | drop |
| `batocera-resolution` | 4 | drop |
| `batocera-retroachievements-sounds` | 8 | drop |
| `batocera-scripts` | 55 | keep: dependency (buildroot pulled it in for a kept package; name the package when known) |
| `batocera-settings` | 3 | keep: batocera-settings-get/set, read by every kept init script |
| `batocera-shaders` | 18 | drop |
| `batocera-splash` | 6 | drop |
| `batocera-system` | 19 | keep: dependency (buildroot pulled it in for a kept package; name the package when known) |
| `batocera-test` | 1 | drop |
| `batocera-torrent` | 2 | drop |
| `batocera-triggerhappy` | 4 | keep: dependency (buildroot pulled it in for a kept package; name the package when known) |
| `batocera-udev-rules` | 17 | keep: pad and device permissions |
| `batocera-userdatainit` | 20 | drop |
| `batocera-wheel-calibrator` | 1 | drop |
| `bc` | 4 | drop |
| `bento4` | 146 | drop |
| `blamcon` | 2 | drop |
| `bluez5_utils` | 81 | drop |
| `boost` | 16044 | drop |
| `box64` | 33 | drop |
| `bstone` | 5 | drop |
| `btop` | 32 | drop |
| `btrfs-progs` | 34 | drop |
| `bzip2` | 24 | drop |
| `c-ares` | 163 | drop |
| `ca-certificates` | 144 | keep: TLS to studio.kodacy.pl |
| `cairo` | 54 | drop |
| `cannonball` | 4 | drop |
| `cargs` | 7 | drop |
| `cdogs` | 1 | drop |
| `cgenius` | 47 | drop |
| `chronic-concepts-insert-coin` | 2 | drop |
| `cifs-utils` | 4 | drop |
| `cjson` | 10 | drop |
| `clang` | 1017 | keep: dependency (buildroot pulled it in for a kept package; name the package when known) |
| `cmocka` | 11 | drop |
| `common-shaders` | 1350 | drop |
| `connman` | 23 | drop |
| `coreutils` | 303 | keep: GNU userland the init scripts rely on |
| `corsixth` | 364 | drop |
| `cpuinfo` | 9 | drop |
| `cryptsetup` | 75 | drop |
| `dash` | 1 | keep: /bin/sh |
| `dav1d` | 11 | drop |
| `dbus` | 51 | drop |
| `dbus-python` | 69 | drop |
| `debianutils` | 65 | keep: dependency (buildroot pulled it in for a kept package; name the package when known) |
| `dejavu` | 27 | drop |
| `devilutionx` | 8 | drop |
| `dht` | 2 | drop |
| `dialog` | 62 | keep: S02resize progress screen |
| `diffutils` | 45 | keep: GNU userland |
| `dmd-play-rust` | 2 | drop |
| `dmd-simulator` | 24 | drop |
| `dolphinbar-guns` | 1 | drop |
| `dos2unix` | 112 | drop |
| `dosbox-staging` | 381 | drop |
| `dosbox-x` | 70 | drop |
| `dosfstools` | 8 | keep: FAT boot partition (fsck/mkfs) |
| `double-conversion` | 19 | drop |
| `drastic` | 13 | drop |
| `dropbear` | 9 | keep: ssh |
| `duckstation` | 183 | drop |
| `dxx-rebirth` | 3 | drop |
| `e2fsprogs` | 121 | keep: ext4 SHARE partition, resize2fs for S02resize |
| `easyrpg-player` | 8 | drop |
| `ecwolf` | 4 | drop |
| `edid-decode` | 2 | drop |
| `eduke32` | 2 | drop |
| `elfutils` | 119 | drop |
| `enet` | 15 | drop |
| `es-background-musics` | 14 | drop |
| `es-theme-carbon` | 2271 | drop |
| `espeak` | 276 | drop |
| `ethtool` | 4 | drop |
| `etlegacy` | 2 | drop |
| `eudev` | 79 | keep: device nodes, hotplug |
| `evmapy` | 15 | drop |
| `evsieve` | 3 | drop |
| `evtest` | 1 | drop |
| `exfat` | 3 | drop |
| `exfat-utils` | 12 | drop |
| `expat` | 15 | keep: dependency (buildroot pulled it in for a kept package; name the package when known) |
| `faad2` | 11 | drop |
| `fake-hwclock` | 4 | keep: no battery RTC: clock across reboots |
| `fallout1-ce` | 1 | drop |
| `fallout2-ce` | 1 | drop |
| `fbdump` | 1 | drop |
| `fbgrab` | 1 | drop |
| `fbv` | 2 | drop |
| `fdk-aac` | 12 | drop |
| `fdupes` | 2 | drop |
| `ffmpeg` | 196 | drop |
| `ffmpeg4` | 173 | drop |
| `findutils` | 52 | keep: GNU userland |
| `flac` | 34 | drop |
| `flatbuffers` | 46 | drop |
| `fluid-soundfont` | 2 | drop |
| `fluidsynth` | 28 | drop |
| `flycast` | 1 | drop |
| `fmt` | 22 | drop |
| `fontconfig` | 92 | drop |
| `fping` | 2 | drop |
| `freetype` | 63 | keep: love.font |
| `fstrcmp` | 1 | drop |
| `fusion-lightguns` | 2 | drop |
| `gametank-emulator` | 1 | drop |
| `gawk` | 107 | keep: GNU userland |
| `gcc-final` | 12 | keep: toolchain |
| `gdk-pixbuf` | 155 | drop |
| `gesftpserver` | 3 | keep: scp/sftp over dropbear |
| `giflib` | 5 | drop |
| `glibc` | 16 | keep: toolchain |
| `glsl-shaders` | 1471 | drop |
| `glslang` | 27 | drop |
| `gmp` | 17 | drop |
| `gnupg` | 41 | drop |
| `gnutls` | 48 | drop |
| `gobject-introspection` | 161 | drop |
| `gptfdisk` | 1 | keep: S02resize (sgdisk) |
| `grep` | 50 | keep: GNU userland |
| `grim` | 1 | drop |
| `gsettings-desktop-schemas` | 93 | drop |
| `gsplus` | 4 | drop |
| `gst1-plugins-bad` | 425 | drop |
| `gst1-plugins-base` | 380 | drop |
| `gst1-plugins-good` | 65 | drop |
| `gst1-plugins-ugly` | 54 | drop |
| `gstreamer1` | 224 | drop |
| `gtk-layer-shell` | 8 | drop |
| `gun4ir-guns` | 2 | drop |
| `guncon3` | 5 | drop |
| `gvfs` | 128 | drop |
| `gzip` | 24 | keep: GNU userland |
| `harfbuzz` | 93 | drop |
| `hatari` | 1 | drop |
| `hcl` | 1 | drop |
| `hid-t150` | 1 | drop |
| `hid-tmff2` | 1 | drop |
| `hidapi` | 14 | drop |
| `hlsdk-xash3d` | 2 | drop |
| `hlsdk-xash3d-dmc` | 2 | drop |
| `hlsdk-xash3d-opfor` | 2 | drop |
| `hotkeygen` | 37 | drop |
| `htop` | 5 | drop |
| `hurrican` | 2 | drop |
| `hwdata` | 3 | drop |
| `hypseus-singe-bezels` | 73 | drop |
| `hypseus-singe` | 122 | drop |
| `i2c-tools` | 31 | drop |
| `icu` | 255 | drop |
| `ifupdown` | 6 | keep: loopback interface |
| `ifupdown-scripts` | 4 | keep: loopback interface (S40network -> S07network) |
| `iir` | 23 | drop |
| `inih` | 10 | drop |
| `initscripts` | 3 | keep: rcS/rcK |
| `innoextract` | 2 | drop |
| `inotify-tools` | 12 | drop |
| `ioquake3` | 4 | drop |
| `iortcw` | 10 | drop |
| `iproute2` | 169 | keep: ip link/addr in S08wifi and probes |
| `iptables` | 155 | drop |
| `iputils` | 21 | keep: ping for debugging |
| `iw` | 2 | keep: wireless tooling, country code |
| `janet` | 11 | drop |
| `jazz2-native` | 359 | drop |
| `jimtcl` | 4 | keep: dependency (buildroot pulled it in for a kept package; name the package when known) |
| `jitterentropy-library` | 6 | drop |
| `joycond` | 4 | drop |
| `jpeg-turbo` | 35 | drop |
| `jq` | 14 | drop |
| `json-c` | 24 | drop |
| `jsoncpp` | 16 | drop |
| `jstest2` | 4 | drop |
| `kbd` | 716 | drop |
| `keyboardtopads` | 12 | drop |
| `keyutils` | 60 | drop |
| `kmod` | 13 | keep: modules |
| `kodacy-launcher` | 2 | keep: the released kodacy.love + supervisor |
| `kodi` | 2010 | drop |
| `kodi-audiodecoder-modplug` | 82 | drop |
| `kodi-audiodecoder-nosefart` | 85 | drop |
| `kodi-audiodecoder-sidplay` | 82 | drop |
| `kodi-audiodecoder-snesapu` | 82 | drop |
| `kodi-audiodecoder-stsound` | 82 | drop |
| `kodi-audiodecoder-timidity` | 85 | drop |
| `kodi-audiodecoder-vgmstream` | 83 | drop |
| `kodi-audioencoder-flac` | 83 | drop |
| `kodi-audioencoder-lame` | 84 | drop |
| `kodi-audioencoder-vorbis` | 83 | drop |
| `kodi-audioencoder-wav` | 82 | drop |
| `kodi-imagedecoder-heif` | 82 | drop |
| `kodi-imagedecoder-raw` | 82 | drop |
| `kodi-inputstream-adaptive` | 81 | drop |
| `kodi-inputstream-ffmpegdirect` | 81 | drop |
| `kodi-inputstream-rtmp` | 78 | drop |
| `kodi-peripheral-joystick` | 233 | drop |
| `kodi-pvr-argustv` | 82 | drop |
| `kodi-pvr-dvblink` | 82 | drop |
| `kodi-pvr-dvbviewer` | 82 | drop |
| `kodi-pvr-filmon` | 82 | drop |
| `kodi-pvr-hdhomerun` | 83 | drop |
| `kodi-pvr-hts` | 83 | drop |
| `kodi-pvr-iptvsimple` | 90 | drop |
| `kodi-pvr-mediaportal-tvserver` | 100 | drop |
| `kodi-pvr-mythtv` | 86 | drop |
| `kodi-pvr-nextpvr` | 83 | drop |
| `kodi-pvr-njoy` | 82 | drop |
| `kodi-pvr-pctv` | 82 | drop |
| `kodi-pvr-stalker` | 83 | drop |
| `kodi-pvr-vbox` | 84 | drop |
| `kodi-pvr-vdr-vnsi` | 91 | drop |
| `kodi-pvr-vuplus` | 94 | drop |
| `kodi-pvr-wmc` | 82 | drop |
| `kodi-screensaver-asteroids` | 81 | drop |
| `kodi-screensaver-asterwave` | 90 | drop |
| `kodi-screensaver-biogenesis` | 82 | drop |
| `kodi-screensaver-cpblobs` | 85 | drop |
| `kodi-screensaver-greynetic` | 82 | drop |
| `kodi-screensaver-matrixtrails` | 84 | drop |
| `kodi-screensaver-pingpong` | 78 | drop |
| `kodi-screensaver-pyro` | 80 | drop |
| `kodi-screensaver-stars` | 82 | drop |
| `kodi-vfs-libarchive` | 82 | drop |
| `kodi-vfs-rar` | 84 | drop |
| `kodi-vfs-sftp` | 82 | drop |
| `kodi-visualisation-fishbmc` | 84 | drop |
| `kodi-visualisation-matrix` | 89 | drop |
| `kodi-visualisation-shadertoy` | 141 | drop |
| `kodi-visualisation-spectrum` | 82 | drop |
| `kodi-visualisation-starburst` | 80 | drop |
| `kodi-visualisation-waveform` | 81 | drop |
| `kodi21-pvr-freebox` | 8 | drop |
| `kodi21-resource-language-de_de` | 4 | drop |
| `kodi21-resource-language-el_gr` | 4 | drop |
| `kodi21-resource-language-es_es` | 4 | drop |
| `kodi21-resource-language-eu_es` | 4 | drop |
| `kodi21-resource-language-fr_fr` | 4 | drop |
| `kodi21-resource-language-it_it` | 4 | drop |
| `kodi21-resource-language-pt_br` | 4 | drop |
| `kodi21-resource-language-sv_se` | 4 | drop |
| `kodi21-resource-language-tr_tr` | 4 | drop |
| `kodi21-resource-language-zh_cn` | 4 | drop |
| `l3afpad` | 57 | drop |
| `labwc` | 55 | drop |
| `lame` | 22 | drop |
| `lcms2` | 17 | drop |
| `ledspicer` | 55 | drop |
| `less` | 6 | drop |
| `lexaloffle-pico8` | 1 | drop |
| `libaacs` | 10 | drop |
| `libabseil-cpp` | 790 | drop |
| `libaio` | 5 | drop |
| `libao` | 53 | drop |
| `libarchive` | 55 | drop |
| `libargon2` | 6 | drop |
| `libass` | 8 | drop |
| `libassuan` | 8 | drop |
| `libatomic_ops` | 79 | drop |
| `libavif` | 9 | drop |
| `libb2` | 7 | drop |
| `libbacktrace` | 7 | drop |
| `libbluray` | 17 | drop |
| `libcap` | 12 | keep: dependency (buildroot pulled it in for a kept package; name the package when known) |
| `libcap-ng` | 43 | drop |
| `libcapsimage` | 4 | drop |
| `libcdio` | 86 | drop |
| `libcdio-paranoia` | 18 | drop |
| `libcec` | 28 | drop |
| `libclc` | 130 | keep: dependency (buildroot pulled it in for a kept package; name the package when known) |
| `libcrossguid` | 9 | drop |
| `libcurl` | 21 | keep: the launcher downloads (curl binary) |
| `libdaemon` | 15 | drop |
| `libde265` | 10 | drop |
| `libdecor` | 7 | drop |
| `libdeflate` | 11 | drop |
| `libdisplay-info` | 14 | drop |
| `libdmdutil` | 15 | drop |
| `libdovi` | 6 | drop |
| `libdrm` | 32 | keep: KMS |
| `libdvdcss` | 12 | drop |
| `libenet` | 15 | drop |
| `libepoxy` | 12 | drop |
| `libevdev` | 14 | drop |
| `libevent` | 62 | drop |
| `libffi` | 12 | drop |
| `libfm` | 174 | drop |
| `libfm-extra` | 10 | drop |
| `libfreeaptx` | 7 | drop |
| `libfreeimage` | 5 | drop |
| `libfribidi` | 60 | drop |
| `libfuse3` | 19 | drop |
| `libgcrypt` | 11 | drop |
| `libgdiplus` | 6 | drop |
| `libglew` | 8 | drop |
| `libglfw` | 10 | drop |
| `libglib2` | 478 | drop |
| `libglib2-bootstrap` | 464 | drop |
| `libglu` | 6 | drop |
| `libgpg-error` | 33 | drop |
| `libgpgme` | 68 | drop |
| `libgpiod2` | 35 | drop |
| `libgraphene` | 30 | drop |
| `libgtk3` | 731 | drop |
| `libgudev` | 14 | drop |
| `libhdhomerun` | 1 | drop |
| `libheif` | 32 | drop |
| `libinput` | 106 | drop |
| `liblc3` | 7 | drop |
| `liblcf` | 110 | drop |
| `libldac` | 10 | drop |
| `libmad` | 6 | drop |
| `libmicrohttpd` | 7 | drop |
| `libminiupnpc` | 23 | drop |
| `libmodplug` | 8 | keep: LÖVE decoder |
| `libmpeg2` | 16 | drop |
| `libnatpmp` | 5 | drop |
| `libnfs` | 23 | drop |
| `libnl` | 165 | keep: wpa_supplicant nl80211, iw |
| `libnspr` | 77 | drop |
| `libnss` | 149 | drop |
| `libogg` | 95 | keep: LÖVE decoder |
| `libopenh264` | 9 | drop |
| `libopenmpt` | 28 | drop |
| `libopenssl` | 160 | keep: TLS, sha256 checks, S35securepasswd |
| `libpcap` | 103 | drop |
| `libplacebo` | 38 | drop |
| `libplatform` | 21 | drop |
| `libplist` | 28 | drop |
| `libpng` | 19 | drop |
| `libportmidi` | 11 | drop |
| `libpsl` | 10 | drop |
| `libpthread-stubs` | 1 | drop |
| `libpupdmd` | 3 | drop |
| `libraw` | 23 | drop |
| `libretro-81` | 3 | drop |
| `libretro-anybor` | 2 | drop |
| `libretro-arduous` | 2 | drop |
| `libretro-atari800` | 2 | drop |
| `libretro-beetle-lynx` | 2 | drop |
| `libretro-beetle-ngp` | 2 | drop |
| `libretro-beetle-pce` | 2 | drop |
| `libretro-beetle-pce-fast` | 2 | drop |
| `libretro-beetle-psx` | 2 | drop |
| `libretro-beetle-supergrafx` | 2 | drop |
| `libretro-beetle-vb` | 2 | drop |
| `libretro-beetle-wswan` | 2 | drop |
| `libretro-bennugd` | 1 | drop |
| `libretro-bk` | 2 | drop |
| `libretro-bluemsx` | 304 | drop |
| `libretro-cap32` | 3 | drop |
| `libretro-core-info` | 315 | drop |
| `libretro-dice` | 2 | drop |
| `libretro-dosbox-pure` | 2 | drop |
| `libretro-easyrpg` | 2 | drop |
| `libretro-emuscv` | 2 | drop |
| `libretro-ep128emu-core` | 1 | drop |
| `libretro-fake08` | 2 | drop |
| `libretro-fbneo` | 22 | drop |
| `libretro-fceumm` | 2 | drop |
| `libretro-flycast` | 2 | drop |
| `libretro-fmsx` | 2 | drop |
| `libretro-freechaf` | 2 | drop |
| `libretro-freeintv` | 2 | drop |
| `libretro-fuse` | 2 | drop |
| `libretro-gambatte` | 2 | drop |
| `libretro-gearcoleco` | 1 | drop |
| `libretro-gearsystem` | 2 | drop |
| `libretro-genesisplusgx` | 2 | drop |
| `libretro-genesisplusgx-expanded` | 1 | drop |
| `libretro-gp32emu` | 3 | drop |
| `libretro-gw` | 2 | drop |
| `libretro-handy` | 2 | drop |
| `libretro-hatari` | 2 | drop |
| `libretro-holani` | 3 | drop |
| `libretro-lowresnx` | 2 | drop |
| `libretro-lutro` | 2 | drop |
| `libretro-mame` | 866 | drop |
| `libretro-mame2003-plus` | 14 | drop |
| `libretro-melonds` | 2 | drop |
| `libretro-melonds-ds` | 3 | drop |
| `libretro-mgba` | 2 | drop |
| `libretro-minivmac` | 2 | drop |
| `libretro-mrboom` | 2 | drop |
| `libretro-mupen64plus-next` | 2 | drop |
| `libretro-neocd` | 2 | drop |
| `libretro-nestopia` | 3 | drop |
| `libretro-nxengine` | 2 | drop |
| `libretro-o2em` | 2 | drop |
| `libretro-pc88` | 2 | drop |
| `libretro-pc98` | 2 | drop |
| `libretro-pcsx` | 2 | drop |
| `libretro-pd777` | 2 | drop |
| `libretro-picodrive` | 2 | drop |
| `libretro-pokemini` | 2 | drop |
| `libretro-ppsspp` | 192 | drop |
| `libretro-prboom` | 2 | drop |
| `libretro-prosystem` | 2 | drop |
| `libretro-puae` | 2 | drop |
| `libretro-px68k` | 3 | drop |
| `libretro-reminiscence` | 2 | drop |
| `libretro-same-cdi` | 2 | drop |
| `libretro-sameduck` | 2 | drop |
| `libretro-scummvm` | 216 | drop |
| `libretro-smsplus-gx` | 2 | drop |
| `libretro-snes9x` | 2 | drop |
| `libretro-snes9x-next` | 2 | drop |
| `libretro-stella` | 2 | drop |
| `libretro-superbroswar` | 2 | drop |
| `libretro-swanstation` | 2 | drop |
| `libretro-tgbdual` | 2 | drop |
| `libretro-theodore` | 2 | drop |
| `libretro-tic80` | 2 | drop |
| `libretro-tyrquake` | 2 | drop |
| `libretro-uae4arm` | 2 | drop |
| `libretro-uzem` | 2 | drop |
| `libretro-vba-m` | 2 | drop |
| `libretro-vecx` | 2 | drop |
| `libretro-vice` | 8 | drop |
| `libretro-vitaquake2` | 5 | drop |
| `libretro-watara` | 2 | drop |
| `libretro-xmil` | 2 | drop |
| `libretro-xrick` | 2 | drop |
| `libretro-yabasanshiro` | 2 | drop |
| `libretro-zc210` | 2 | drop |
| `librsvg` | 11 | drop |
| `libsamplerate` | 23 | drop |
| `libserialport` | 7 | drop |
| `libserum` | 5 | drop |
| `libsfdo` | 21 | drop |
| `libshairplay` | 8 | drop |
| `libsidplay2` | 43 | drop |
| `libsndfile` | 8 | drop |
| `libsodium` | 83 | drop |
| `libsoundtouch` | 17 | drop |
| `libssh` | 14 | drop |
| `libtalloc` | 11 | drop |
| `libtasn1` | 7 | drop |
| `libtheora` | 124 | keep: LÖVE decoder |
| `libtirpc` | 59 | drop |
| `libtool` | 9 | drop |
| `libudfread` | 8 | drop |
| `libunistring` | 52 | drop |
| `libusb` | 7 | keep: dependency (buildroot pulled it in for a kept package; name the package when known) |
| `libusb-compat` | 17 | drop |
| `libutp` | 10 | drop |
| `libuv` | 12 | drop |
| `libv4l` | 280 | drop |
| `libvni` | 3 | drop |
| `libvorbis` | 158 | keep: LÖVE decoder |
| `libvpx` | 17 | drop |
| `libxcb` | 2496 | drop |
| `libxcrypt` | 18 | keep: batocera-initramfs, login |
| `libxkbcommon` | 45 | drop |
| `libxml2` | 55 | drop |
| `libxmp` | 8 | drop |
| `libyaml` | 7 | drop |
| `libzedmd` | 5 | drop |
| `libzip` | 18 | drop |
| `libzlib` | 8 | keep: dependency (buildroot pulled it in for a kept package; name the package when known) |
| `lightgun-controllers-art` | 14 | drop |
| `lightguns-games-precalibrations` | 108 | drop |
| `lightspark` | 5 | drop |
| `linux` | 319 | keep: kernel 7.2.8 + board/batocera/allwinner/h700/linux_patches + DTS |
| `linux-pam` | 164 | keep: dependency (buildroot pulled it in for a kept package; name the package when known) |
| `linuxconsoletools` | 25 | drop |
| `llvm` | 2443 | keep: hard dependency of the panfrost driver in this buildroot (MESA3D_LLVM) |
| `logi-wheel` | 4 | drop |
| `logitech-trueforce` | 2 | drop |
| `love` | 10 | keep: LÖVE 11.5, the only runtime |
| `lpeg` | 6 | drop |
| `lsof` | 1 | drop |
| `lua` | 12 | drop |
| `luafilesystem` | 11 | drop |
| `luasec` | 76 | drop |
| `luasocket` | 101 | drop |
| `lvm2` | 157 | drop |
| `lz4` | 10 | drop |
| `lzo` | 29 | drop |
| `mame` | 1965 | drop |
| `mangohud` | 10 | drop |
| `mariadb` | 469 | drop |
| `mc` | 356 | drop |
| `mdadm` | 6 | drop |
| `menu-cache` | 9 | drop |
| `mergerfs` | 2 | drop |
| `mesa3d` | 92 | keep: Panfrost GLES2/EGL/GBM for SDL2 KMS/DRM |
| `mesa3d-demos` | 53 | drop |
| `mjpegtools` | 161 | drop |
| `mono` | 3327 | drop |
| `moonlight-qt` | 2 | drop |
| `mosquitto` | 49 | drop |
| `mpg123` | 33 | keep: LÖVE decoder |
| `mpv` | 18 | drop |
| `munt` | 29 | drop |
| `mupen64plus-audio-sdl` | 1 | drop |
| `mupen64plus-core` | 5 | drop |
| `mupen64plus-gliden64` | 3 | drop |
| `mupen64plus-input-sdl` | 1 | drop |
| `mupen64plus-rsp-hle` | 1 | drop |
| `mupen64plus-ui-console` | 5 | drop |
| `mupen64plus-video-glide64mk2` | 2 | drop |
| `mupen64plus-video-rice` | 2 | drop |
| `nano` | 1 | drop |
| `nanum-font` | 1 | drop |
| `ncdu` | 2 | drop |
| `ncurses` | 60 | keep: dialog, terminal |
| `net-tools` | 33 | drop |
| `netcat` | 6 | drop |
| `nettle` | 88 | drop |
| `nfs-utils` | 82 | drop |
| `nghttp2` | 13 | drop |
| `noto-cjk-fonts` | 5 | drop |
| `nss-mdns` | 12 | drop |
| `ntfs-3g` | 84 | drop |
| `ntp` | 3 | drop |
| `od-commander` | 10 | drop |
| `onehit-guns` | 2 | drop |
| `openal` | 23 | keep: love.audio |
| `openbor4432` | 1 | drop |
| `openbor6412` | 1 | drop |
| `openbor7142` | 1 | drop |
| `openbor7530` | 1 | drop |
| `opencv4` | 439 | drop |
| `openfire-guns` | 2 | drop |
| `openjazz` | 1 | drop |
| `openjpeg` | 14 | drop |
| `openresolv` | 12 | drop |
| `openvpn` | 19 | drop |
| `opus` | 13 | drop |
| `opusfile` | 16 | drop |
| `orc` | 35 | drop |
| `p7zip` | 4 | drop |
| `pacman` | 235 | drop |
| `pango` | 75 | drop |
| `parted` | 59 | keep: S02resize |
| `pciutils` | 19 | drop |
| `pcmanfm` | 65 | drop |
| `pcre2` | 236 | drop |
| `physfs` | 8 | drop |
| `pigpio` | 10 | drop |
| `pipewire` | 470 | drop |
| `pipewire-ffmpeg-plugins` | 3 | drop |
| `pixman` | 7 | drop |
| `pm-utils` | 45 | keep: pm-suspend, /etc/pm/sleep.d (H700 hook 90h700-sleep) |
| `poppler` | 168 | drop |
| `popt` | 44 | keep: dependency (buildroot pulled it in for a kept package; name the package when known) |
| `portaudio` | 33 | drop |
| `ppsspp` | 191 | drop |
| `procps-ng` | 179 | keep: ps, sysctl |
| `protobuf` | 315 | drop |
| `psmisc` | 106 | keep: killall (S31kodacy) |
| `pugixml` | 10 | drop |
| `pulseaudio` | 289 | drop |
| `pysdl2` | 193 | drop |
| `python-aiodns` | 9 | drop |
| `python-aiohappyeyeballs` | 10 | drop |
| `python-aiohttp` | 82 | drop |
| `python-aiosignal` | 7 | drop |
| `python-attrs` | 35 | drop |
| `python-batocera-common` | 35 | drop |
| `python-brotli` | 7 | drop |
| `python-certifi` | 10 | drop |
| `python-cffi` | 30 | drop |
| `python-charset-normalizer` | 23 | drop |
| `python-cryptography` | 115 | drop |
| `python-dbus-fast` | 52 | drop |
| `python-evdev` | 24 | drop |
| `python-frozenlist` | 9 | drop |
| `python-gobject` | 57 | drop |
| `python-hidapi` | 10 | drop |
| `python-httplib2` | 11 | drop |
| `python-idna` | 13 | drop |
| `python-lazy-loader` | 6 | drop |
| `python-libevdev` | 10 | drop |
| `python-libusb1` | 16 | drop |
| `python-multidict` | 11 | drop |
| `python-ndeflib` | 16 | drop |
| `python-nfcpy` | 41 | drop |
| `python-numpy` | 1295 | drop |
| `python-packaging` | 27 | drop |
| `python-pillow` | 120 | drop |
| `python-propcache` | 13 | drop |
| `python-protobuf` | 61 | drop |
| `python-psutil` | 16 | drop |
| `python-pycares` | 12 | drop |
| `python-pycparser` | 13 | drop |
| `python-pycryptodomex` | 350 | drop |
| `python-pydes` | 6 | drop |
| `python-pygame2` | 201 | drop |
| `python-pyopenssl` | 13 | drop |
| `python-pyparsing` | 23 | drop |
| `python-pyudev` | 29 | drop |
| `python-pyyaml` | 24 | drop |
| `python-qrcode` | 40 | drop |
| `python-requests` | 24 | drop |
| `python-ruamel-yaml` | 39 | drop |
| `python-setuptools` | 512 | drop |
| `python-six` | 6 | drop |
| `python-toml` | 15 | drop |
| `python-typing-extensions` | 5 | drop |
| `python-urllib3` | 42 | drop |
| `python-uvloop` | 63 | drop |
| `python-websockets` | 59 | drop |
| `python-yarl` | 17 | drop |
| `python3` | 932 | drop |
| `python3-configobj` | 9 | drop |
| `qt6base` | 4526 | drop |
| `qt6declarative` | 4807 | drop |
| `qt6multimedia` | 484 | drop |
| `qt6shadertools` | 42 | drop |
| `qt6svg` | 107 | drop |
| `qt6tools` | 133 | drop |
| `qt6wayland` | 537 | drop |
| `qt6websockets` | 70 | drop |
| `qtsixa` | 8 | drop |
| `qtsixa-shanwan` | 5 | drop |
| `raze` | 3 | drop |
| `read-edid` | 6 | drop |
| `readline` | 30 | keep: dependency of bash |
| `redream` | 1 | drop |
| `retroarch` | 128 | drop |
| `retroarch-assets` | 1898 | drop |
| `retroshooter-guns` | 4 | drop |
| `rng-tools` | 6 | drop |
| `rocknix-joypad` | 1 | keep: the H700 pad driver (out-of-tree module) |
| `rpcbind` | 5 | drop |
| `rsync` | 5 | drop |
| `rtl8192eu` | 1 | drop |
| `rtmidi` | 10 | drop |
| `rtmpdump` | 9 | drop |
| `samba4` | 1061 | drop |
| `samco-guns` | 2 | drop |
| `sbc` | 7 | drop |
| `scummvm` | 242 | drop |
| `sdl2` | 91 | keep: LÖVE's window, input and GL context (KMSDRM + GLES) |
| `sdl2-touch-test` | 1 | drop |
| `sdl2_gfx` | 10 | drop |
| `sdl2_image` | 13 | drop |
| `sdl2_mixer` | 21 | drop |
| `sdl2_net` | 9 | drop |
| `sdl2_ttf` | 9 | drop |
| `sdl3` | 99 | drop |
| `sdl3_image` | 10 | drop |
| `sdl3_mixer` | 37 | drop |
| `sdl3_ttf` | 15 | drop |
| `sdlpop` | 1037 | drop |
| `seatd` | 5 | drop |
| `sed` | 43 | keep: GNU userland |
| `shared-mime-info` | 1 | drop |
| `simcoupe` | 14 | drop |
| `sinden-guns` | 10 | drop |
| `sinden-guns-libs` | 1 | drop |
| `skeleton-init-common` | 17 | keep: rootfs skeleton |
| `skeleton-init-sysv` | 9 | keep: rootfs skeleton |
| `slang-shaders` | 4172 | drop |
| `slirp` | 17 | drop |
| `smartmontools` | 28 | drop |
| `sockpp` | 35 | drop |
| `solarus-engine` | 5 | drop |
| `sonic-mania` | 11 | drop |
| `sonic2013` | 1 | drop |
| `sonic3-air` | 856 | drop |
| `soniccd` | 1 | drop |
| `spdlog` | 98 | drop |
| `speexdsp` | 13 | drop |
| `spirv-cross` | 49 | drop |
| `spirv-llvm-translator` | 7 | keep: dependency (buildroot pulled it in for a kept package; name the package when known) |
| `spirv-tools` | 45 | keep: dependency (buildroot pulled it in for a kept package; name the package when known) |
| `sqlite` | 9 | drop |
| `squashfs` | 4 | drop |
| `start-stop-daemon` | 1 | keep: init scripts |
| `stenzek-shaderc` | 8 | drop |
| `swaybg` | 1 | drop |
| `syncthing` | 2 | drop |
| `syslog-ng` | 471 | drop |
| `sysvinit` | 8 | keep: dependency (buildroot pulled it in for a kept package; name the package when known) |
| `taglib` | 140 | drop |
| `tar` | 47 | keep: GNU userland |
| `taradino` | 7 | drop |
| `thextech` | 4 | drop |
| `tic80` | 1 | drop |
| `tiff` | 16 | drop |
| `tinyxml` | 96 | drop |
| `tinyxml2` | 9 | drop |
| `tmux` | 2 | drop |
| `toolchain` | 1 | keep: toolchain |
| `transmission` | 67 | drop |
| `tree` | 1 | drop |
| `triggerhappy` | 4 | keep: power button (kodacy-power) |
| `trx` | 716 | drop |
| `tyrian` | 1 | drop |
| `tzdata` | 1264 | keep: time zones (Europe/Warsaw) |
| `umtool` | 36 | drop |
| `unrar` | 1 | drop |
| `unzip` | 1 | keep: batocera-upgrade, launcher helpers |
| `upower` | 40 | drop |
| `usb_modeswitch` | 6 | keep: dependency (buildroot pulled it in for a kept package; name the package when known) |
| `usb_modeswitch_data` | 514 | keep: dependency (buildroot pulled it in for a kept package; name the package when known) |
| `usbutils` | 8 | drop |
| `util-linux` | 334 | keep: mount, agetty, login, logger, hwclock |
| `util-linux-libs` | 82 | drop |
| `ux500-firmware` | 39 | drop |
| `uzdoom` | 9 | drop |
| `vice` | 415 | drop |
| `vim` | 1821 | drop |
| `vlc` | 1022 | drop |
| `vo-aacenc` | 13 | drop |
| `vulkan-headers` | 66 | drop |
| `vulkan-loader` | 7 | drop |
| `watchdog` | 8 | drop |
| `wayland` | 36 | drop |
| `wayland-utils` | 2 | drop |
| `waylandpp` | 74 | drop |
| `webp` | 44 | drop |
| `wf-recorder` | 3 | drop |
| `wget` | 84 | drop |
| `which` | 3 | keep: GNU userland |
| `wii-u-gc-adapter` | 13 | drop |
| `wiimote-3rdparty` | 2 | drop |
| `wiimotes-rules` | 4 | drop |
| `wilc-firmware` | 1 | drop |
| `wildmidi` | 33 | drop |
| `wireguard-service` | 2 | drop |
| `wireguard-tools` | 6 | drop |
| `wireless-regdb` | 2 | keep: regulatory.db for the WiFi driver |
| `wireless_tools` | 7 | drop |
| `wireplumber` | 195 | drop |
| `wlr-randr` | 1 | drop |
| `wlrctl` | 1 | drop |
| `wlroots` | 125 | drop |
| `wpa_supplicant` | 7 | keep: the OS owns WiFi, WPS included (docs/wifi.md) |
| `wsdd` | 2 | drop |
| `wtype` | 2 | drop |
| `x16emu` | 2 | drop |
| `x264` | 6 | drop |
| `x265` | 6 | drop |
| `xapp_xinput` | 2 | drop |
| `xapp_xinput-calibrator` | 5 | drop |
| `xapp_xkbcomp` | 3 | drop |
| `xash3d-fwgs` | 6 | drop |
| `xcb-proto` | 62 | drop |
| `xcb-util` | 13 | drop |
| `xcb-util-cursor` | 7 | drop |
| `xcb-util-image` | 9 | drop |
| `xcb-util-keysyms` | 7 | drop |
| `xcb-util-renderutil` | 7 | drop |
| `xcb-util-wm` | 14 | drop |
| `xfont_encodings` | 52 | drop |
| `xgunner-lightguns` | 2 | drop |
| `xkeyboard-config` | 340 | drop |
| `xlib_libICE` | 13 | drop |
| `xlib_libSM` | 9 | drop |
| `xlib_libX11` | 1169 | drop |
| `xlib_libXScrnSaver` | 19 | drop |
| `xlib_libXau` | 16 | drop |
| `xlib_libXaw` | 133 | drop |
| `xlib_libXcomposite` | 19 | drop |
| `xlib_libXcursor` | 67 | drop |
| `xlib_libXdamage` | 7 | drop |
| `xlib_libXdmcp` | 7 | drop |
| `xlib_libXext` | 88 | drop |
| `xlib_libXfixes` | 8 | drop |
| `xlib_libXfont2` | 7 | drop |
| `xlib_libXft` | 86 | drop |
| `xlib_libXi` | 85 | drop |
| `xlib_libXinerama` | 13 | drop |
| `xlib_libXmu` | 35 | drop |
| `xlib_libXpm` | 52 | drop |
| `xlib_libXpresent` | 16 | drop |
| `xlib_libXrandr` | 22 | drop |
| `xlib_libXrender` | 8 | drop |
| `xlib_libXt` | 329 | drop |
| `xlib_libXtst` | 21 | drop |
| `xlib_libXv` | 33 | drop |
| `xlib_libXxf86vm` | 30 | drop |
| `xlib_libfontenc` | 7 | drop |
| `xlib_libxcvt` | 8 | drop |
| `xlib_libxkbfile` | 12 | drop |
| `xlib_libxshmfence` | 7 | drop |
| `xone` | 14 | drop |
| `xpad-noone` | 1 | drop |
| `xpadneo` | 4 | drop |
| `xroar` | 3 | drop |
| `xterm` | 26 | drop |
| `xwayland` | 6 | drop |
| `xwiimote` | 12 | drop |
| `xz` | 298 | keep: batocera-upgrade (boot.tar.xz) |
| `yad` | 24 | drop |
| `yquake2` | 7 | drop |
| `yquake2-rogue` | 1 | drop |
| `yquake2-xatrix` | 1 | drop |
| `yquake2-zaero` | 1 | drop |
| `zd1211-firmware` | 6 | drop |
| `zip` | 8 | drop |
| `zmusic` | 6 | drop |
| `zramswap` | 1 | drop |
| `zstd` | 23 | drop |
| `kodacy-system` (new) | 1 | keep: new in KodacyOS |
| `dhcpcd` (new) | 1 | keep: address on wlan0 (S08wifi) |
| `chrony` (new) | 1 | keep: clock for TLS (S49chronyd) |

| init script (stock) | package | verdict |
|---|---|---|
| `S01syslog-ng` | `syslog-ng` | drop |
| `S02sysctl` | `procps-ng` | keep: procps sysctl |
| `S03system-splash` | `batocera-splash` | drop |
| `S05avahi-setup.sh` | `avahi` | drop |
| `S06audio` | `batocera-audio` | drop |
| `S10udevd` | `eudev` | drop |
| `S11modules` | `initscripts` | keep: initscripts |
| `S12mergerfs` | `mergerfs` | drop |
| `S14labwc` | `batocera-emulationstation` | drop |
| `S15virtualevents` | `batocera-udev-rules` | drop |
| `S19binfmt` | `box64` | drop |
| `S21led-handheld` | `batocera-led-handheld` | drop |
| `S21rngd` | `rng-tools` | drop |
| `S27audioconfig` | `batocera-audio` | drop |
| `S28splash` | `batocera-splash` | drop |
| `S29namebluetooth` | `batocera-bluetooth` | drop |
| `S30dbus-daemon` | `dbus` | drop |
| `S30hotkeygen` | `hotkeygen` | drop |
| `S30rpcbind` | `rpcbind` | drop |
| `S30splashscreencontrol` | `batocera-splash` | drop |
| `S31emulationstation` | `batocera-emulationstation` | drop |
| `S32bluetooth` | `batocera-bluetooth` | drop |
| `S35iptables` | `iptables` | drop |
| `S40bluetoothd` | `bluez5_utils` | drop |
| `S40network` | `ifupdown-scripts` | drop |
| `S45connman` | `connman` | drop |
| `S47fake-hwclock` | `fake-hwclock` | keep: fake-hwclock save |
| `S49ntp` | `ntp` | drop |
| `S50avahi-daemon` | `avahi` | drop |
| `S50dropbear` | `dropbear` | keep: ssh |
| `S50kodi` | `kodi` | drop |
| `S50triggerhappy` | `triggerhappy` | keep: ours: power button |
| `S60nfs` | `nfs-utils` | drop |
| `S90battery_checker` | `batocera-battery-checker` | drop |
| `S91smb` | `samba4` | drop |
| `S93wsdd` | `wsdd` | drop |
| `fuse3` | `libfuse3` | drop |
| `rcK` | `initscripts` | keep: init |
| `rcS` | `initscripts` | keep: init |

Summary: 848 packages in the stock image, 759 marked drop, 759 absent from the KodacyOS image, 92 present there.
