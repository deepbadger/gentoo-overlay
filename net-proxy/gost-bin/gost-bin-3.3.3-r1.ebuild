# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit systemd

DESCRIPTION="GO Simple Tunnel — multi-protocol proxy and tunnel (HTTP, SOCKS5, TLS, WS, QUIC...)"
HOMEPAGE="https://gost.run/ https://github.com/go-gost/gost"
SRC_URI="
	amd64? ( https://github.com/go-gost/gost/releases/download/v${PV}/gost_${PV}_linux_amd64.tar.gz -> ${P}-amd64.tar.gz )
	arm64? ( https://github.com/go-gost/gost/releases/download/v${PV}/gost_${PV}_linux_arm64.tar.gz -> ${P}-arm64.tar.gz )
"

# Архив без вложенного каталога: gost, LICENSE, README*.md
S="${WORKDIR}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"
RESTRICT="bindist mirror strip"

RDEPEND="
	acct-group/gost
	acct-user/gost
"

# Статически собранный Go-бинарник
QA_PREBUILT="*"

src_install() {
	dobin gost
	dodoc README.md README_en.md

	insinto /etc/gost
	newins "${FILESDIR}"/gost.yml.example gost.yml.example
	fowners -R root:gost /etc/gost
	fperms 0750 /etc/gost

	newinitd "${FILESDIR}"/gost.initd gost
	newconfd "${FILESDIR}"/gost.confd gost
	systemd_dounit "${FILESDIR}"/gost.service
}

pkg_postinst() {
	if [[ ! -e "${EROOT}"/etc/gost/gost.yml ]]; then
		elog "Создайте конфигурацию перед запуском сервиса:"
		elog "  cp /etc/gost/gost.yml.example /etc/gost/gost.yml"
		elog "  chown root:gost /etc/gost/gost.yml && chmod 0640 /etc/gost/gost.yml"
		elog
		elog "Пример — локальный HTTP-прокси 127.0.0.1:8118 поверх внешнего SOCKS5."
		elog "Быстрый запуск без конфига:"
		elog "  gost -L http://127.0.0.1:8118 -F socks5://user:pass@host:1080"
	fi
}
