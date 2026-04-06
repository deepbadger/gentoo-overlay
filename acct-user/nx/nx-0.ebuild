# Copyright 2025-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit acct-user

ACCT_USER_ID=-1
ACCT_USER_GROUPS=( nx )
ACCT_USER_HOME=/usr/NX/home/nx
ACCT_USER_SHELL=/bin/bash

acct-user_add_deps
