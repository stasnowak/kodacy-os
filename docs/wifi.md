# WiFi on KodacyOS

Phase 8 of `plans/kodacy-os.md` (kodacy-studio). The OS owns WiFi:

- `wpa_supplicant` on `wlan0` (`-D nl80211`, mainline `rtw88_8821cs`
  driver), started by `/etc/init.d/S08wifi`, configuration in
  `/userdata/system/wpa_supplicant.conf` (`update_config=1`, control socket
  in `/var/run/wpa_supplicant`, `country=PL`); the file is created on the
  first boot if missing.
- `dhcpcd` for the address (hostname `kodacy`), `chronyd` for the clock
  (`S49chronyd`, `/etc/chrony.conf`, `makestep` so the first sync jumps).
- rtw88 quirks kept from Batocera's H700 template: `S09wifi-probe` re-binds
  the driver when the first SDIO firmware download fails,
  `99-wifi-powersave.rules` turns power save off.
- No connman, no D-Bus. The launcher's WiFi screens (launcher redesign plan)
  speak `wpa_cli` exactly as below.

Network blocks carry `key_mgmt=WPA-PSK` (the owner's router advertises
mixed WPA2+WPA3; muOS joined it this way, and rtw88 supports PMF, so no
`ieee80211w=0` should be needed; if it turns out to be, record it here as a
driver fact). Open networks: `key_mgmt=NONE`.

## Join a network over ssh (`wpa_cli`)

```sh
wpa_cli -i wlan0 scan && sleep 3 && wpa_cli -i wlan0 scan_results
id=$(wpa_cli -i wlan0 add_network)                 # prints the new id, e.g. 0
wpa_cli -i wlan0 set_network $id ssid '"My Network"'
wpa_cli -i wlan0 set_network $id psk '"the password"'
wpa_cli -i wlan0 set_network $id key_mgmt WPA-PSK
wpa_cli -i wlan0 set_network $id priority 5         # favourite = 1, default = 5 (the launcher's convention)
wpa_cli -i wlan0 enable_network $id
wpa_cli -i wlan0 save_config
```

Check:

```sh
wpa_cli -i wlan0 status | grep -E '^(wpa_state|ssid|key_mgmt|pmf)='
ip -4 -o addr show dev wlan0
chronyc tracking | head -3; date
curl -sI https://studio.kodacy.pl/console/version.json | head -1
```

Expected: `wpa_state=COMPLETED`, an `inet` line, a current date, `HTTP/2 200`
(or `HTTP/1.1 200`). After `reboot`, within 30 s and without touching ssh,
`wpa_state=COMPLETED` again and `/userdata/kodacy/log.txt` shows the
launcher's sync (`net: GET … ok`).

Other verbs: `list_networks`, `select_network <id>`, `remove_network <id>`,
`disconnect`, `reconnect`, `signal_poll`.

## WPS (push button)

```sh
wpa_cli -i wlan0 wps_pbc
# press the router's WPS button; then poll
wpa_cli -i wlan0 status | grep wpa_state        # COMPLETED within about 2 minutes
wpa_cli -i wlan0 save_config                    # the new network={} block is written
wpa_cli -i wlan0 wps_cancel                     # to abort
```

`grep -c 'network={' /userdata/system/wpa_supplicant.conf` goes up by one
after `save_config`.

## Verification plan (Phase 8, on the final image)

- `pgrep -a connmand || echo no-connman; pgrep -a wpa_supplicant; pgrep -a dhcpcd; pgrep -a chronyd` → `no-connman` and the three daemons.
- The join recipe on the owner's mixed WPA2+WPA3 network, the reboot
  reconnect, the WPS recipe once; `dmesg | grep -i -c 'rtw88.*fail'` is `0`
  or the retry in `S09wifi-probe` recovered it.
