# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools

DESCRIPTION="User-level SOCKS and port forwarding proxy for OpenConnect based on lwIP"
HOMEPAGE="https://github.com/cernekee/ocproxy"
SRC_URI="https://github.com/cernekee/ocproxy/archive/v${PV}.tar.gz -> ${P}.tar.gz"

# ocproxy и встроенный lwIP — оба под BSD
LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

DEPEND="dev-libs/libevent:="
RDEPEND="${DEPEND}"

src_prepare() {
	default
	# В тегированном архиве нет configure — только configure.ac
	eautoreconf
}

src_configure() {
	# vpnns — помощник для запуска приложений в отдельном netns (только Linux)
	econf --enable-vpnns
}
