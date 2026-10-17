################################################################################
#
# kodacy-system: what batocera-system.mk installs and the kept helper scripts
#
################################################################################

KODACY_SYSTEM_SOURCE =
KODACY_SYSTEM_DEPENDENCIES = tzdata
KODACY_SYSTEM_INSTALL_IMAGES = YES

# batocera.version must start with digits: post-image-script.sh takes that
# prefix for the image file name, and "-dev" skips the torrent step.
KODACY_SYSTEM_VERSION = 0.1-dev
KODACY_SYSTEM_DATE_TIME = $(shell date "+%Y/%m/%d %H:%M")
KODACY_SYSTEM_VERSION_WITH_DATE = $(KODACY_SYSTEM_VERSION)-$(BATOCERA_GIT_COMMIT) $(KODACY_SYSTEM_DATE_TIME)

BATOCERA_SYSTEM_SRC = $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-system
BATOCERA_SCRIPTS_SRC = $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-scripts/scripts

# The helper scripts the kept init scripts call (S02resize, S11share,
# S18governor, S26system, S27brightness, S99userservices) and the upgrade
# path, all shell, installed straight from upstream's batocera-scripts
# directory so a rebase updates them. batocera-scripts itself is not
# selected: it pulls python3, dbus-python and gobject for Bluetooth.
KODACY_SYSTEM_KEPT_SCRIPTS = \
	batocera-part \
	batocera-mount \
	batocera-storage-manager \
	batocera-format \
	batocera-version \
	batocera-config \
	batocera-encode \
	batocera-brightness \
	batocera-services \
	batocera-timezone \
	batocera-upgrade \
	batocera-architecture-compatibility \
	batocera-save-overlay

define KODACY_SYSTEM_INSTALL_TARGET_CMDS
	# version/arch, read by the initramfs, the upgrade script and post-image-script.sh
	mkdir -p $(TARGET_DIR)/usr/share/batocera
	echo -n '$(BATOCERA_ARCH)' > $(TARGET_DIR)/usr/share/batocera/batocera.arch
	echo '$(KODACY_SYSTEM_VERSION_WITH_DATE)' > $(TARGET_DIR)/usr/share/batocera/batocera.version

	# default batocera.conf, seeded into /userdata/system by S12populateshare;
	# board/kodacy/scripts/post-build.sh edits it (es.atstartup, hostname)
	mkdir -p $(TARGET_DIR)/usr/share/batocera/datainit/system
	cp $(BATOCERA_SYSTEM_SRC)/batocera.conf $(TARGET_DIR)/usr/share/batocera/datainit/system

	# per-board defaults (batocera-settings-get-master): suspend mode for the H700 devices
	mkdir -p $(TARGET_DIR)/usr/share/batocera/sysconfigs
	if test -d $(BATOCERA_SYSTEM_SRC)/sysconfigs/$(BATOCERA_ARCH); then \
		cp -pr $(BATOCERA_SYSTEM_SRC)/sysconfigs/$(BATOCERA_ARCH)/* \
			$(TARGET_DIR)/usr/share/batocera/sysconfigs; \
	fi

	# mount points
	mkdir -p $(TARGET_DIR)/boot $(TARGET_DIR)/overlay $(TARGET_DIR)/userdata

	# XDG_RUNTIME_DIR for the scripts that source it
	mkdir -p $(TARGET_DIR)/etc/profile.d
	cp $(BATOCERA_SYSTEM_SRC)/xdg.sh $(TARGET_DIR)/etc/profile.d/xdg.sh

	# kept helper scripts
	$(foreach s,$(KODACY_SYSTEM_KEPT_SCRIPTS), \
		$(INSTALL) -m 0755 $(BATOCERA_SCRIPTS_SRC)/$(s) $(TARGET_DIR)/usr/bin/$(s);)

	# triggerhappy: the daemon comes from buildroot's package (its S10 script is
	# removed by Batocera's post-build), our S50triggerhappy and conf are in
	# board/kodacy/fsoverlay; the resume hook is upstream's
	mkdir -p $(TARGET_DIR)/etc/pm/sleep.d
	$(INSTALL) -m 0755 $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-triggerhappy/99triggerhappy-resume \
		$(TARGET_DIR)/etc/pm/sleep.d/99triggerhappy-resume
endef

define KODACY_SYSTEM_INSTALL_IMAGES_CMDS
	# batocera-boot.conf lands on the FAT partition (post-image-script.sh copies it)
	$(INSTALL) -D -m 0644 $(BATOCERA_SYSTEM_SRC)/batocera-boot.conf $(BINARIES_DIR)/batocera-boot.conf
endef

$(eval $(generic-package))
