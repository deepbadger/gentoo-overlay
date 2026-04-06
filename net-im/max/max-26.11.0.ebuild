# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit rpm xdg

MY_BUILD="54111"

DESCRIPTION="MAX — desktop client for communication and collaboration"
HOMEPAGE="https://max.ru"
SRC_URI="https://download.max.ru/linux/rpm/el/9/x86_64/MAX-${PV}.${MY_BUILD}.rpm"

LICENSE="MAX-EULA"
SLOT="0"
KEYWORDS="~amd64"
RESTRICT="bindist mirror strip"

RDEPEND="
	x11-libs/libXres
	x11-libs/libXScrnSaver
	x11-libs/libXaw
	x11-libs/libnotify
	media-libs/libva
	x11-libs/libxcb
	x11-libs/xcb-util-wm
"

S="${WORKDIR}"

QA_PREBUILT="*"

src_install() {
	dodir /opt/max
	cp -a usr/share/max/. "${ED}"/opt/max/ || die

	sed -e 's|/usr/share/max/bin/max|/opt/max/bin/max|g' \
		usr/share/applications/max.desktop \
		> "${T}"/max.desktop || die
	insinto /usr/share/applications
	doins "${T}"/max.desktop

	insinto /usr/share/pixmaps
	doins usr/share/pixmaps/max.png

	local size
	for size in 16 24 32 48 64 128 256 512; do
		insinto /usr/share/icons/hicolor/${size}x${size}/apps
		doins usr/share/icons/hicolor/${size}x${size}/apps/max.png
	done

	dosym ../../opt/max/bin/max /usr/bin/max
}
