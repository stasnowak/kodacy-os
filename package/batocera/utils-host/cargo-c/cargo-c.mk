################################################################################
#
# cargo-c
#
################################################################################

# The crates.io package, not the GitHub tag: the tag has no Cargo.lock, so a
# cold vendoring resolves today's crates (which need rustc 1.97, buildroot
# ships 1.95); the published crate carries the lockfile of its release day
# and vendors --locked.
CARGO_C_VERSION = 0.10.19+cargo-0.93.0
CARGO_C_SOURCE = cargo-c-$(CARGO_C_VERSION).crate
CARGO_C_SITE = https://static.crates.io/crates/cargo-c
CARGO_C_LICENSE = MIT License
CARGO_C_LICENSE_FILES = LICENSE

HOST_CARGO_C_DEPENDENCIES = host-pkgconf host-rustc host-openssl

# buildroot has no extractor for the .crate suffix (it is a gzipped tar)
define HOST_CARGO_C_EXTRACT_CMDS
	$(INFLATE.gz) $(HOST_CARGO_C_DL_DIR)/$(HOST_CARGO_C_SOURCE) | 		$(TAR) --strip-components=1 -C $(@D) $(TAR_OPTIONS) -
endef

$(eval $(host-cargo-package))
