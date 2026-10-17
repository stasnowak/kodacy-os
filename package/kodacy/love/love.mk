################################################################################
#
# love (LÖVE 11.5), the runtime for Kodacy games and the Kodacy launcher
#
################################################################################

LOVE_VERSION = 11.5
LOVE_SOURCE = love-$(LOVE_VERSION)-linux-src.tar.gz
LOVE_SITE = https://github.com/love2d/love/releases/download/$(LOVE_VERSION)
LOVE_LICENSE = Zlib
LOVE_LICENSE_FILES = license.txt
LOVE_DEPENDENCIES = host-pkgconf batocera-luajit sdl2 openal freetype \
	libmodplug libogg libvorbis libtheora mpg123 zlib

# The release tarball ships a generated configure; its AM_PATH_SDL2 wants
# sdl2-config from the staging tree, not the host's.
LOVE_CONF_ENV = SDL2_CONFIG=$(STAGING_DIR)/usr/bin/sdl2-config

# --with-lua=luajit: configure looks for luajit5.1, luajit51 then luajit in
# pkg-config; batocera-luajit installs luajit.pc. No GME (chiptune) support.
LOVE_CONF_OPTS = \
	--with-lua=luajit \
	--with-luaversion=5.1 \
	--disable-gme

$(eval $(autotools-package))
