# Copyright 2025-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop pam xdg

MY_P="${PN}_$(ver_cut 1-3)_$(ver_cut 4)"

DESCRIPTION="Fast and secure remote desktop access"
HOMEPAGE="https://www.nomachine.com/"
SRC_URI="
	amd64? ( https://download.nomachine.com/download/$(ver_cut 1-2)/Linux/${MY_P}_x86_64.tar.gz )
"

S="${WORKDIR}/NX"

LICENSE="nomachine"
SLOT="0"
KEYWORDS="~amd64"
RESTRICT="bindist mirror strip"

RDEPEND="
	acct-group/nx
	acct-user/nx
	dev-libs/glib:2
	net-misc/openssh
	sys-auth/polkit
	|| (
		sys-libs/libxcrypt[compat]
		sys-libs/glibc[crypt(-)]
	)
	x11-apps/xauth
"

QA_PREBUILT="*"

src_install() {
	local pkg_dir="${S}/etc/NX/server/packages"
	local stage="${WORKDIR}/staging"

	mkdir -p "${stage}" || die
	local pkg
	for pkg in nxserver nxnode nxplayer nxrunner; do
		tar xozf "${pkg_dir}/${pkg}.tar.gz" -C "${stage}" || die "Failed to extract ${pkg}"
	done

	dodir /usr
	cp -a "${stage}/NX" "${ED}/usr/NX" || die

	exeinto /usr/NX
	doexe "${S}/nxserver"

	# /etc/NX control scripts
	insinto /etc/NX
	newins "${stage}/NX/scripts/etc/nxserver" nxserver
	fperms 0755 /etc/NX/nxserver
	newins "${stage}/NX/scripts/etc/nxnode" nxnode
	fperms 0755 /etc/NX/nxnode

	# /etc/NX localhost configs (required by nxexec)
	insinto /etc/NX/server/localhost
	newins "${stage}/NX/scripts/etc/localhost/server.cfg" server.cfg
	newins "${stage}/NX/scripts/etc/localhost/runner.cfg" runner.cfg

	insinto /etc/NX/node/localhost
	newins "${stage}/NX/scripts/etc/localhost/node.cfg" node.cfg
	newins "${stage}/NX/scripts/etc/localhost/runner.cfg" runner.cfg

	insinto /etc/NX/player/localhost
	newins "${stage}/NX/scripts/etc/localhost/player.cfg" player.cfg
	newins "${stage}/NX/scripts/etc/localhost/runner.cfg" runner.cfg

	# /usr/NX/etc runtime configs
	insinto /usr/NX/etc
	newins "${stage}/NX/etc/node-redhat.cfg.sample" node.cfg
	newins "${stage}/NX/etc/server-redhat.cfg.sample" server.cfg

	newpamd "${FILESDIR}"/nx.pam nx

	fowners root:root /usr/NX/bin/nxexec
	fperms 4555 /usr/NX/bin/nxexec

	newinitd "${FILESDIR}"/nxserver.initd nxserver

	domenu "${stage}/NX/share/applnk/server/xdg/NoMachine-base.desktop"

	local size
	for size in 16 22 32 48; do
		newicon -s "${size}" \
			"${stage}/NX/share/icons/${size}x${size}/NoMachine-icon.png" \
			NoMachine-icon.png
	done

	insinto /usr/share/polkit-1/actions
	doins "${stage}/NX/share/policy/org.freedesktop.pkexec.nomachine.policy"

	echo 'NX_SYSTEM="/usr/NX"' > "${T}/50nomachine" || die
	doenvd "${T}/50nomachine"

	keepdir /usr/NX/etc/keys
	keepdir /usr/NX/var/log
	keepdir /usr/NX/var/run
	keepdir /usr/NX/var/db/node
	keepdir /var/NX/nx/.nx
}

pkg_postinst() {
	xdg_pkg_postinst

	rm -f /usr/NX/var/run/daemon.stop /usr/NX/var/run/server.shutdown

	chown -R nx:nx /usr/NX/home/nx 2>/dev/null
	chmod 700 /usr/NX/home/nx/.ssh 2>/dev/null

	local d
	for d in /usr/NX/etc /usr/NX/var /var/NX/nx; do
		chown -R nx:nx "${d}" 2>/dev/null
		chmod 755 "${d}" 2>/dev/null
	done

	local nxkeygen="env LD_LIBRARY_PATH=/usr/NX/lib /usr/NX/bin/nxkeygen"

	if [[ ! -f /usr/NX/etc/keys/node.localhost.id_dsa ]]; then
		einfo "Generating NX node DSA key..."
		${nxkeygen} \
			-k /usr/NX/etc/keys/node.localhost.id_dsa \
			-p /usr/NX/etc/keys/node.localhost.id_dsa.pub \
			-t dsa 2>/dev/null
	fi
	if [[ ! -f /usr/NX/etc/keys/node.localhost.id_rsa ]]; then
		einfo "Generating NX node RSA key..."
		${nxkeygen} \
			-k /usr/NX/etc/keys/node.localhost.id_rsa \
			-p /usr/NX/etc/keys/node.localhost.id_rsa.pub \
			-t rsa 2>/dev/null
	fi
	if [[ ! -f /usr/NX/etc/keys/host/nx_host_rsa_key ]]; then
		einfo "Generating NX host certificate..."
		mkdir -p /usr/NX/etc/keys/host
		${nxkeygen} \
			-k /usr/NX/etc/keys/host/nx_host_rsa_key \
			-c /usr/NX/etc/keys/host/nx_host_rsa_key.crt 2>/dev/null
		chown -R nx:nx /usr/NX/etc/keys/host
	fi

	local nx_ssh="/usr/NX/home/nx/.ssh"
	local auth_keys="${nx_ssh}/authorized_keys"
	if [[ -f /usr/NX/etc/keys/node.localhost.id_dsa.pub && ! -f ${auth_keys} ]]; then
		local pubkey
		pubkey=$(cat /usr/NX/etc/keys/node.localhost.id_dsa.pub)
		echo "command=\"/etc/NX/nxserver\" ${pubkey}" > "${auth_keys}"
		chown nx:nx "${auth_keys}"
		chmod 600 "${auth_keys}"
	fi

	if [[ -z ${REPLACING_VERSIONS} ]]; then
		elog
		elog "NoMachine has been installed."
		elog
		elog "To start the NoMachine server:"
		elog "  /etc/init.d/nxserver start"
		elog "  rc-update add nxserver default"
		elog
		elog "The NoMachine client can be started from the desktop menu"
		elog "or by running: /usr/NX/bin/nxplayer"
	fi
}

pkg_prerm() {
	if [[ -f /usr/NX/var/run/server.pid ]]; then
		einfo "Stopping NoMachine server..."
		/etc/NX/nxserver --shutdown 2>/dev/null
	fi
}

pkg_postrm() {
	xdg_pkg_postrm
}
