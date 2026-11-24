# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Phonotype требует Python >= 3.12.
PYTHON_COMPAT=( python3_{12..14} )

inherit desktop python-single-r1 systemd udev xdg

DESCRIPTION="Voice typing for Linux: dictate into any app (whisper.cpp / Parakeet)"
HOMEPAGE="https://github.com/deepbadger/phonotype"
# Берём автогенерируемый архив тега: в нём есть packaging/ и исходники целиком.
SRC_URI="https://github.com/deepbadger/phonotype/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	gigachat? (
		https://github.com/deepbadger/phonotype/releases/download/v${PV}/${P}-gigachat-wheels.tar.gz
	)"

LICENSE="MIT"
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
		dev-python/pysocks[${PYTHON_USEDEP}]
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
	!app-accessibility/voxd
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

	# В исходниках wrapper'а нет: на Gentoo Python и все модули приходят через
	# RDEPEND, поэтому генерируем его под интерпретатор, выбранный
	# python-single-r1.
	cat > packaging/phonotype.wrapper <<-EOF || die
		#!/usr/bin/env bash
		set -euo pipefail
		APPDIR=/opt/phonotype
		export YDOTOOL_SOCKET="\${YDOTOOL_SOCKET:-\$HOME/.ydotool_socket}"
		export PYTHONPATH="\$APPDIR/src\${PYTHONPATH:+:\$PYTHONPATH}"
		CFG_FILE="\${XDG_CONFIG_HOME:-\$HOME/.config}/phonotype/config.yaml"
		if [[ ! -f "\$CFG_FILE" ]]; then
		    ${EPYTHON} -m phonotype --setup || true
		fi
		# На Wayland поднимаем ydotoold; user-юнит ставится только с USE=systemd,
		# поэтому действуем мягко и пропускаем шаг, если systemctl недоступен.
		if [[ \${XDG_SESSION_TYPE:-} == wayland* ]] && command -v systemctl >/dev/null; then
		    systemctl --user is-active --quiet ydotoold.service || \\
		        systemctl --user enable --now ydotoold.service || true
		fi
		exec ${EPYTHON} -m phonotype "\$@"
	EOF
}

src_install() {
	# Python-приложение целиком ложится в /opt/phonotype (как ожидает wrapper).
	dodir /opt/phonotype
	cp -a src "${ED}"/opt/phonotype/ || die
	# pyproject.toml читается в рантайме, чтобы определить версию,
	# когда git/metadata недоступны — повторяем поведение nfpm-пакета.
	insinto /opt/phonotype
	doins pyproject.toml

	exeinto /usr/bin
	newexe packaging/phonotype.wrapper phonotype
	doexe packaging/phonotype-ydotoold

	# Изолированный bundle с langchain-gigachat и его транзитивными deps:
	# распаковываем wheels из релизного ассета и `pip install --target` в
	# приватный site-packages — в системный Python ничего не утекает.
	# aipp.run_gigachat_aipp подменяет sys.path только перед импортом
	# langchain_gigachat, поэтому bundle-версии pydantic/httpx/langsmith
	# не затеняют системные пакеты для остального кода phonotype.
	if use gigachat; then
		local sp="${ED}/opt/phonotype/aipp/gigachat/site-packages"
		dodir /opt/phonotype/aipp/gigachat
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
		systemd_douserunit packaging/phonotype-tray.service
		systemd_douserunit packaging/ydotoold.service
	fi

	# OpenRC user-services (sys-apps/openrc >= 0.62.6, стабильно с 2025-09).
	# Системные init-скрипты для пользовательских сервисов лежат в
	# /etc/user/init.d/ и подхватываются `rc-* --user`.
	exeinto /etc/user/init.d
	newexe "${FILESDIR}"/phonotype-ydotoold.user-initd phonotype-ydotoold
	newexe "${FILESDIR}"/phonotype-tray.user-initd phonotype-tray

	# udev-правило: доступ к /dev/uinput из группы input для ydotoold.
	udev_dorules packaging/99-uinput.rules

	# Тот же файл иконки, который upstream-installer кладёт в hicolor.
	newicon -s 256 src/phonotype/assets/phonotype-0.png phonotype.png

	# Системные .desktop-записи (upstream создаёт их только в $HOME).
	make_desktop_entry "phonotype --tray" "Phonotype" phonotype "AudioVideo;Utility;Accessibility;"
}

pkg_postinst() {
	xdg_pkg_postinst
	udev_reload

	elog "Переезд с app-accessibility/voxd: при первом запуске Phonotype сам"
	elog "заберёт настройки, ключи и модели из ~/.config/voxd и"
	elog "~/.local/share/voxd (старые каталоги не удаляются). Вручную нужно:"
	elog " - в глобальном хоткее заменить команду на 'phonotype --trigger-record'"
	elog " - заменить сервисы автозапуска voxd-* на phonotype-* (см. ниже)"
	elog ""
	elog "Phonotype требует в рантайме:"
	elog " - whisper-cli и parakeet-cli (whisper.cpp): соберите их скриптом"
	elog "   setup.sh из репозитория Phonotype ('./setup.sh --gpu=cuda --no-venv'),"
	elog "   он положит ссылки в ~/.local/bin"
	elog " - доступ к /dev/uinput для ydotoold — добавьте пользователя"
	elog "   в группу input:  gpasswd -a <user> input"
	elog " - на Wayland: emerge x11-misc/ydotool, daemon ydotoold нужно"
	elog "   запускать в пользовательской сессии."
	elog ""
	elog "Автозапуск (OpenRC user services, нужен >=sys-apps/openrc-0.62.6"
	elog "и pam_openrc; XDG_RUNTIME_DIR должен быть установлен в сессии):"
	elog "       rc-update --user add phonotype-ydotoold default"
	elog "       rc-update --user add phonotype-tray default"
	elog "       rc-service --user phonotype-ydotoold start"
	elog "       rc-service --user phonotype-tray start"
	elog ""
	elog "AI-постпроцессинг через облачных провайдеров: ключ API и прокси"
	elog "(HTTP/SOCKS5) задаются в 'Settings → AI processing'; ключ хранится"
	elog "в ~/.config/phonotype/keys.env."
	if use systemd; then
		elog ""
		elog "Альтернатива через systemd user-юниты (USE=systemd):"
		elog "       systemctl --user enable --now ydotoold.service"
		elog "       systemctl --user enable --now phonotype-tray.service"
	fi
	if use gigachat; then
		elog ""
		elog "AI-постпроцессинг через GigaChat (USE=gigachat):"
		elog "       export GIGACHAT_CREDENTIALS='<base64 client_id:secret>'"
		elog "       # затем в \${XDG_CONFIG_HOME:-~/.config}/phonotype/config.yaml:"
		elog "       #   aipp_provider: gigachat"
		elog "Bundle с langchain-gigachat и зависимостями развёрнут в"
		elog "/opt/phonotype/aipp/gigachat/site-packages — системный Python не"
		elog "затрагивается."
	fi
}

pkg_postrm() {
	xdg_pkg_postrm
	udev_reload
}
