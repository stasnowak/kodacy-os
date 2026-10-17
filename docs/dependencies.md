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

To be generated from `output/h700/build/packages-file-list.txt`,
`make h700-show-build-order` and the device probe (`ls /etc/init.d`, `ps`,
`du`) once the stock build has finished and a console has booted it. Every
package and every `/etc/init.d/S*` script gets one row; default is `drop`;
"Batocera ships it" is not a reason. The verdicts below are the expected
ones from the plan, written from the desk check; they become final with the
inventory.

| item | verdict |
|---|---|
| kernel + `board/batocera/allwinner/h700/linux_patches` + DTS + modules | keep: hardware template |
| `uboot-anbernic-h700` (U-Boot + TF-A + suspend stub, both SPLs) | keep: hardware template |
| `batocera-linux-firmwares` (rtw88, regdb), `lib/firmware/panels/*.panel` | keep: WiFi and the panel driver read them |
| `batocera-initramfs` | keep: mounts the squashfs, applies `batocera.update` |
| `batocera-settings` (`batocera-settings-get/set`) | keep: boot conf reader used by every kept init script |
| `S02resize`, `S11share` | keep: first-boot resize and the `/userdata` mount |
| `S18governor`, `S27brightness` | keep: CPU governor, backlight |
| `S09wifi-probe`, `99-wifi-powersave.rules` | keep: rtw88 quirks |
| `90h700-sleep` + pm-utils | keep: sleep (follow-up E) |
| eudev + `batocera-udev-rules` | keep: device nodes, pad permissions |
| ALSA + `S20-audio-volume` | keep: sound |
| dropbear | keep: ssh |
| triggerhappy | keep: power button |
| connman | keep **until Phase 8**, then drop |
| Mesa Panfrost + libdrm + SDL2 | keep: LÖVE |
| curl + openssl + ca-certificates | keep: the launcher downloads |
| `S02led-status` / `battery_led_status` | decide: a battery LED is useful to a child |
| EmulationStation, ES web UI, theme Carbon, background musics, `batocera-es-system`, `batocera-launch`, configgen, `hotkeygen`, `batocera-controlcenter` | drop (Phase 7) |
| every emulator and core (`BR2_PACKAGE_BATOCERA_ALL_SYSTEMS`), the `rufomaculata` squashfs, RetroArch, PortMaster | drop (Phase 7) |
| Kodi 21 (+ language packs, PVR/screensaver add-ons) | drop (Phase 7) |
| labwc / Wayland / Xwayland / Xorg | drop (Phase 7) |
| `batocera-splash` (mpv) | drop (Phase 7; boot logo is follow-up F) |
| Samba (`S91smb`), avahi, wsdd, syncthing, openvpn, wireguard, nfs-utils, cifs-utils | drop (Phase 9) |
| Bluetooth stack (`S31sixad`, `batocera-bluetooth`, bluez) | drop (Phase 9; revisit in follow-up F) |
| `S97joycond`, `S25lircd`, `S61cec`, `S12populateshare` (emulator seeding), `batocera-userdatainit` beyond `/userdata/system` | drop (Phase 9) |
| python3, `python-batocera-common` | drop in Phase 9 if no keep needs them |
| fonts, themes, musics, `batocera-desktopapps`, `batocera-notice`, pacman, flatpak, box64, btop, tmux, espeak, … | drop (Phase 9) |
