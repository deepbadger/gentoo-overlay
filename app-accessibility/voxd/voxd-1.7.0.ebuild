# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Нижняя граница задаётся PYTHON_COMPAT'ом dev-python/pyqtgraph (>=3.12).
PYTHON_COMPAT=( python3_{12..14} )

inherit desktop python-single-r1 systemd udev xdg

# Downstream-ревизия форка ('+mir.N'). Не входит в Gentoo-версию PV (она равна
# upstream-версии), поэтому держим суффикс одной переменной — её достаточно
# поменять при обновлении на следующую mir-сборку.
MIR_SUFFIX="mir.3"
MY_PV="${PV}+${MIR_SUFFIX}"

DESCRIPTION="Voice typing for Linux: dictate into any app via whisper.cpp"
HOMEPAGE="https://github.com/deepbadger/voxd"
# Релизный ассет форка — урезанный sdist без packaging/ и Python-источников,
# поэтому забираем автогенерируемый архив тега (имя каталога: '+' → '-').
SRC_URI="https://github.com/deepbadger/voxd/archive/refs/tags/v${PV}%2B${MIR_SUFFIX}.tar.gz -> ${P}+${MIR_SUFFIX}.tar.gz
	gigachat? (
		https://github.com/deepbadger/voxd/releases/download/v${PV}%2B${MIR_SUFFIX}/voxd-${MY_PV}-gigachat-wheels.tar.gz
	)"
S="${WORKDIR}/voxd-${PV}-${MIR_SUFFIX}"

# MIT — собственно исходники приложения.
# all-rights-reserved — иконки/лого (см. ASSETS_LICENSE: разрешено
# распространение без модификации, но trademark сохраняется).
LICENSE="MIT all-rights-reserved"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="gigachat systemd"
RESTRICT="mirror"

REQUIRED_USE="${PYTHON_REQUIRED_USE}"

RDEPEND="
	${PYTHON_DEPS}
	$(python_gen_cond_dep '
		dev-python/numpy[${PYTHON_USEDEP}]
		dev-python/platformdirs[${PYTHON_USEDEP}]
		dev-python/psutil[${PYTHON_USEDEP}]
		dev-python/pyperclip[${PYTHON_USEDEP}]
		dev-python/pyqt6[${PYTHON_USEDEP},gui,widgets]
		dev-python/pyqtgraph[${PYTHON_USEDEP}]
		dev-python/pyyaml[${PYTHON_USEDEP}]
		dev-python/requests[${PYTHON_USEDEP}]
		dev-python/sounddevice[${PYTHON_USEDEP},numpy]
		dev-python/tqdm[${PYTHON_USEDEP}]
	')
	media-libs/portaudio
	media-video/ffmpeg
	net-misc/curl
	virtual/udev
	|| ( x11-misc/xclip x11-misc/xsel gui-apps/wl-clipboard )
	|| ( x11-misc/ydotool x11-misc/xdotool )
"

BDEPEND="
	gigachat? (
		$(python_gen_cond_dep '
			dev-python/pip[${PYTHON_USEDEP}]
		')
	)
"

pkg_setup() {
	python-single-r1_pkg_setup
}

src_prepare() {
	default

	# Upstream-wrapper рассчитан на дистрибутивы с устаревшим Python и
	# самостоятельно бутстрапит venv с pip-зависимостями. На Gentoo Python
	# и все модули предоставлены через RDEPEND, поэтому переписываем wrapper
	# под фиксированный интерпретатор, выбранный python-single-r1.
	cat > packaging/voxd.wrapper <<-EOF || die
		#!/usr/bin/env bash
		set -euo pipefail
		APPDIR=/opt/voxd
		export YDOTOOL_SOCKET="\${YDOTOOL_SOCKET:-\$HOME/.ydotool_socket}"
		export PYTHONPATH="\$APPDIR/src\${PYTHONPATH:+:\$PYTHONPATH}"
		CFG_FILE="\${XDG_CONFIG_HOME:-\$HOME/.config}/voxd/config.yaml"
		if [[ ! -f "\$CFG_FILE" ]]; then
		    ${EPYTHON} -m voxd --setup || true
		fi
		# На Wayland поднимаем ydotoold; user-юнит ставится только с USE=systemd,
		# поэтому действуем мягко и пропускаем шаг, если systemctl недоступен.
		if [[ \${XDG_SESSION_TYPE:-} == wayland* ]] && command -v systemctl >/dev/null; then
		    systemctl --user is-active --quiet ydotoold.service || \\
		        systemctl --user enable --now ydotoold.service || true
		fi
		exec ${EPYTHON} -m voxd "\$@"
	EOF
}

src_install() {
	# Python-приложение целиком ложится в /opt/voxd (как ожидает wrapper).
	dodir /opt/voxd
	cp -a src "${ED}"/opt/voxd/ || die
	# pyproject.toml читается в рантайме, чтобы определить версию,
	# когда git/metadata недоступны — повторяем поведение nfpm-пакета.
	insinto /opt/voxd
	doins pyproject.toml

	exeinto /usr/bin
	newexe packaging/voxd.wrapper voxd
	doexe packaging/voxd-ydotoold

	# Изолированный bundle с langchain-gigachat и его транзитивными deps:
	# распаковываем wheels из релизного ассета и `pip install --target` в
	# приватный site-packages — в системный Python ничего не утекает.
	# aipp.run_gigachat_aipp подменяет sys.path только перед импортом
	# langchain_gigachat, поэтому bundle-версии pydantic/httpx/langsmith
	# не затеняют системные пакеты для остального кода voxd.
	if use gigachat; then
		local sp="${ED}/opt/voxd/aipp/gigachat/site-packages"
		dodir /opt/voxd/aipp/gigachat
		"${EPYTHON}" -m pip install \
			--no-index \
			--no-compile \
			--no-warn-script-location \
			--disable-pip-version-check \
			--target="${sp}" \
			--find-links="${WORKDIR}/wheels" \
			'langchain-gigachat>=0.5,<0.6' \
			|| die "pip install of gigachat bundle failed"
		# Удаляем ненужные исполняемые скрипты, которые pip кладёт в
		# bin/ внутри --target — wrapper их не использует.
		rm -rf "${sp}/bin" || die
		python_optimize "${sp}"
	fi

	# systemd user-юниты — только при USE=systemd.
	if use systemd; then
		systemd_douserunit packaging/voxd-tray.service
		systemd_douserunit packaging/ydotoold.service
	fi

	# OpenRC user-services (sys-apps/openrc >= 0.62.6, стабильно с 2025-09).
	# Системные init-скрипты для пользовательских сервисов лежат в
	# /etc/user/init.d/ и подхватываются `rc-* --user`.
	exeinto /etc/user/init.d
	newexe "${FILESDIR}"/voxd-ydotoold.user-initd voxd-ydotoold
	newexe "${FILESDIR}"/voxd-tray.user-initd voxd-tray

	# udev-правило: доступ к /dev/uinput из группы input для ydotoold.
	udev_dorules packaging/99-uinput.rules

	# Тот же файл иконки, который upstream-installer кладёт в hicolor.
	newicon -s 512 src/voxd/assets/voxd-1.png voxd.png

	# Системные .desktop-записи (upstream создаёт их только в $HOME).
	make_desktop_entry "voxd --gui" "VOXD" voxd "AudioVideo;Utility;Accessibility;"
	make_desktop_entry "voxd --tray" "VOXD (Tray)" voxd "AudioVideo;Utility;Accessibility;"
	make_desktop_entry "voxd --flux" "VOXD (Flux)" voxd "AudioVideo;Utility;Accessibility;"
}

pkg_postinst() {
	xdg_pkg_postinst
	udev_reload

	elog "VOXD требует в рантайме:"
	elog " - whisper-cli (whisper.cpp): первый запуск 'voxd --setup'"
	elog "   автоматически скачает/соберёт его в ~/.local/bin/whisper-cli"
	elog " - доступ к /dev/uinput для ydotoold — добавьте пользователя"
	elog "   в группу input:  gpasswd -a <user> input"
	elog " - на Wayland: emerge x11-misc/ydotool, daemon ydotoold нужно"
	elog "   запускать в пользовательской сессии."
	elog ""
	elog "Автозапуск (OpenRC user services, нужен >=sys-apps/openrc-0.62.6"
	elog "и pam_openrc; XDG_RUNTIME_DIR должен быть установлен в сессии):"
	elog "       rc-update --user add voxd-ydotoold default"
	elog "       rc-update --user add voxd-tray default"
	elog "       rc-service --user voxd-ydotoold start"
	elog "       rc-service --user voxd-tray start"
	if use systemd; then
		elog ""
		elog "Альтернатива через systemd user-юниты (USE=systemd):"
		elog "       systemctl --user enable --now ydotoold.service"
		elog "       systemctl --user enable --now voxd-tray.service"
	fi
	if use gigachat; then
		elog ""
		elog "AI-постпроцессинг через GigaChat (USE=gigachat):"
		elog "       export GIGACHAT_CREDENTIALS='<base64 client_id:secret>'"
		elog "       # затем в \${XDG_CONFIG_HOME:-~/.config}/voxd/config.yaml:"
		elog "       #   aipp_provider: gigachat"
		elog "Bundle с langchain-gigachat и зависимостями развёрнут в"
		elog "/opt/voxd/aipp/gigachat/site-packages — системный Python не"
		elog "затрагивается."
	fi
}

pkg_postrm() {
	xdg_pkg_postrm
	udev_reload
}
