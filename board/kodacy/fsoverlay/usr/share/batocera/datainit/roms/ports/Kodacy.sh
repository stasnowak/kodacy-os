#!/bin/bash
# KodacyOS Phase 5: Kodacy as an EmulationStation port (Ports → Kodacy).
# S12populateshare copies this file to /userdata/roms/ports/ on the first boot
# of a fresh SHARE partition; on an existing one copy it there over ssh.
# One pass of the launcher/game loop, then back to ES.
export KODACY_ONESHOT=1
exec /usr/bin/kodacy-supervisor
