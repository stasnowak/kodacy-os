################################################################################
#
# kodacy-launcher: the released kodacy.love, pinned by version and sha256
#
################################################################################

# The tag of kodacy-studio whose deploy published this kodacy.love; its
# sha256 is the one from https://studio.kodacy.pl/console/version.json at
# that tag and lives in kodacy-launcher.hash. Bump both together.
#
# Decision (Phase 5): the file is fetched from studio.kodacy.pl/console/,
# which serves only the latest deploy under one name. Buildroot keeps the
# downloaded copy in dl/kodacy-launcher/kodacy.love and re-downloads only
# when the hash changes, so a given version stays buildable while that copy
# (or a backup of it) exists. If old versions must stay fetchable, the
# deploy workflow can attach kodacy.love + version.json to the tag's GitHub
# release and KODACY_LAUNCHER_SITE moves there; nothing else changes.
KODACY_LAUNCHER_VERSION = v0.24.2
KODACY_LAUNCHER_SOURCE = kodacy.love
KODACY_LAUNCHER_SITE = https://studio.kodacy.pl/console
KODACY_LAUNCHER_LICENSE = Proprietary (Kodacy)

# kodacy.love is a zip archive used as-is: no extraction, just copy it.
define KODACY_LAUNCHER_EXTRACT_CMDS
	cp $(KODACY_LAUNCHER_DL_DIR)/$(KODACY_LAUNCHER_SOURCE) $(@D)/kodacy.love
endef

define KODACY_LAUNCHER_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0644 $(@D)/kodacy.love $(TARGET_DIR)/usr/share/kodacy/kodacy.love
	echo '$(KODACY_LAUNCHER_VERSION)' > $(TARGET_DIR)/usr/share/kodacy/kodacy.version
endef

$(eval $(generic-package))
