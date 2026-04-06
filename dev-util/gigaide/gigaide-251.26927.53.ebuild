# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg

DESCRIPTION="GigaIDE Community Edition — IDE for JVM languages by SberTech (based on IntelliJ IDEA)"
HOMEPAGE="https://gigaide.ru/"
SRC_URI="https://gigaide.ru/downloadlast/gigaideCE-${PV}.tar.gz"

LICENSE="GigaIDE-EULA"
SLOT="0"
KEYWORDS="~amd64"
RESTRICT="bindist mirror strip"

# Тарболл содержит bundled JBR — системный Java не нужен.
# Перечислены системные библиотеки, загружаемые IDE в рантайме.
RDEPEND="
	dev-libs/glib:2
	media-libs/fontconfig
	media-libs/freetype
	media-libs/mesa
	x11-libs/cairo
	x11-libs/gtk+:3
	x11-libs/libX11
	x11-libs/libXScrnSaver
	x11-libs/libXext
	x11-libs/libXi
	x11-libs/libXrender
	x11-libs/libXtst
	x11-libs/libxcb
	x11-libs/pango
	x11-libs/xcb-util-wm
"

# Тарболл распаковывается в каталог gigaideCE-<version>
S="${WORKDIR}/gigaide-CE-${PV}"

QA_PREBUILT="*"

# Bundled JBR uses relative RPATH (.:$ORIGIN) — expected for self-contained distribution
QA_FLAGS_IGNORED="
	opt/gigaide/jbr/lib/jcef_helper
	opt/gigaide/jbr/lib/libjcef.so
"

# ARM64 helper binary inside Python plugin — aarch64 libs not present on amd64, expected
QA_SONAME_NO_SYMLINK="opt/gigaide/plugins/python-ce/helpers/pydev/pydevd_attach_to_process/attach_linux_aarch64.so"

src_install() {
	dodir /opt/gigaide
	cp -a . "${ED}"/opt/gigaide/ || die

	# Иконки — стандартные пути в тарболле JetBrains/IntelliJ
	if [[ -f bin/idea128.png ]]; then
		newicon -s 128 bin/idea128.png gigaide.png
	fi
	if [[ -f bin/idea.png ]]; then
		newicon -s 32 bin/idea.png gigaide.png
	fi
	if [[ -f bin/idea.svg ]]; then
		insinto /usr/share/icons/hicolor/scalable/apps
		newins bin/idea.svg gigaide.svg
	fi

	# Тарболл не содержит системного .desktop файла — создаём его
	make_desktop_entry \
		/opt/gigaide/bin/idea \
		"GigaIDE Community Edition" \
		gigaide \
		"Development;IDE;" \
		"StartupWMClass=jetbrains-idea-ce\nStartupNotify=true"

	dosym ../../opt/gigaide/bin/idea /usr/bin/gigaide
}

pkg_postinst() {
	xdg_desktop_database_update
	xdg_icon_cache_update
}

pkg_postrm() {
	xdg_desktop_database_update
	xdg_icon_cache_update
}
