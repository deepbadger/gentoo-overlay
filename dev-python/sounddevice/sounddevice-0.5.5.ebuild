# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{11..14} )

inherit distutils-r1

DESCRIPTION="Play and record sound with Python via PortAudio"
HOMEPAGE="
	https://python-sounddevice.readthedocs.io/
	https://github.com/spatialaudio/python-sounddevice/
"
SRC_URI="https://github.com/spatialaudio/python-sounddevice/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/python-sounddevice-${PV}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="+numpy"
RESTRICT="mirror test"

# cffi нужен и в build-time (cffi_modules в setup.py), и в runtime
# (binding-модуль вызывает ffi.dlopen во время import).
RDEPEND="
	$(python_gen_cond_dep '
		dev-python/cffi[${PYTHON_USEDEP}]
		numpy? ( dev-python/numpy[${PYTHON_USEDEP}] )
	')
	media-libs/portaudio
"
BDEPEND="
	$(python_gen_cond_dep '
		dev-python/cffi[${PYTHON_USEDEP}]
	')
"

# Тестов в sdist/tag-тарболе нет (pyproject.toml: test = []).
