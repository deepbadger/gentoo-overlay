# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
inherit desktop unpacker xdg

DESCRIPTION="R7-Office Desktop Editors is an application for editing office documents"
HOMEPAGE="https://r7-office.ru/"
LICENSE="AGPL-3"
SLOT="0"

KEYWORDS="~amd64"
#IUSE=""
RESTRICT="bindist strip mirror"

MY_PV=$(ver_rs 3 '-')

SRC_URI="
	amd64? ( https://download.r7-office.ru/debian/${PN}_${MY_PV}~stretch_amd64.deb )
"

RDEPEND="
	media-libs/alsa-lib

	|| (
		net-misc/curl
		net-misc/wget
	)

	media-plugins/gst-plugins-libav
	media-libs/gst-plugins-ugly

	dev-libs/atk
	dev-util/desktop-file-utils
	sys-devel/gcc
	x11-base/xorg-server
	x11-libs/gtk+:3
	x11-libs/cairo
	x11-libs/libXScrnSaver
	x11-misc/xdg-utils

	media-fonts/dejavu
	media-fonts/liberation-fonts
	media-fonts/crosextrafonts-carlito
	media-fonts/corefonts
	media-fonts/takao-fonts
"

S=${WORKDIR}
R7="opt/${PN}"

src_unpack() {
	unpack_deb ${A}
}

src_prepare() {
	mkdir -p usr/share/mime/application
	sed -i 's/version="1.0"?>/version="1.0" encoding="utf-8"?>/' ${R7}/desktopeditors/mimetypes/*.xml
	cp -r ${R7}/desktopeditors/mimetypes/*.xml usr/share/mime/application

	# Исправляем ссылки на иконки
	sed -i -E -e 's/^Icon='${PN}'/Icon=\/opt\/'${PN}'\/mediaviewer\/ivapp.ico/' \
		usr/share/applications/${PN}-imageviewer.desktop
	sed -i -E -e 's/^Icon='${PN}'/Icon=\/opt\/'${PN}'\/mediaviewer\/mvapp.ico/' \
		usr/share/applications/${PN}-videoplayer.desktop

	# Удаляем службу, специфичную для Астра Линукс
	rm -rf usr/lib/systemd/system

	default
}

src_install() {
	mv * "${D}" || die

	for icon in "${D}/${R7}/desktopeditors/asc-de-"*.png; do
		size="${icon##*/asc-de-}"
		size=${size%.png}
		dodir "/usr/share/icons/hicolor/${size}x${size}/apps"
		newicon -s ${size} "$icon" ${PN}.png
	done
}

pkg_postinst() {
	xdg_mimeinfo_database_update
	xdg_desktop_database_update
}

pkg_postrm() {
	xdg_desktop_database_update
}
