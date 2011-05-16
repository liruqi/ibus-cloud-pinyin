#!/bin/bash

CFLAGFILE=src/c-flags.txt
CFLAGFILE2=src/c-flags-2.txt
VALACFLAGFILE=src/valac-flags.txt
VALACFLAGFILE2=src/valac-flags-2.txt
PACKAGES_PKGCONFIG=''
PACKAGES_PKGCONFIG_2=''
PACKAGES_VALAC=''
PACKAGES_VALAC_2=''

error() {
	rm -f $CFLAGFILE $VALACFLAGFILE 2>/dev/null
	echo -e "\x1b[31;01mERROR: \x1b[33;00m"$@
	exit 1
}

require_program() {
	if ! which "$@" &>/dev/null; then
		error 'Required program '"$@"' not found'
	fi
}

require_pkg() {
	# name, version, valac name [lite (used for request-send)]
	echo -n "    $1: "
	if pkg-config --atleast-version=$2 $1; then
		pkg-config --modversion $1
		PACKAGES_PKGCONFIG="$PACKAGES_PKGCONFIG $1"
		[ -n "$3" ] && PACKAGES_VALAC="$PACKAGES_VALAC --pkg $3"
		if [ -n "$4" ]; then
			PACKAGES_VALAC_2="$PACKAGES_VALAC_2 --pkg $3"
			PACKAGES_PKGCONFIG_2="$PACKAGES_PKGCONFIG_2 $1"
		fi
	else
		echo 'not found'
		error 'Required pkg '"$1"' >= '"$2"' not found'
	fi
}

require_program valac
require_program pkg-config
require_program gcc
require_program sed
require_program grep
require_program touch
require_program wget
require_program tar
require_program lua
require_program sqlite3
require_program xz

[ -e $CFLAGFILE ] && rm $CFLAGFILE
[ -e $VALACFLAGFILE ] && rm $VALACFLAGFILE

touch $VALACFLAGFILE
touch $CFLAGFILE

LUAPKG_NAME=lua5.1

pkg-config lua5.1 && LUAPKG_NAME="lua5.1"
pkg-config lua-5.1 && LUAPKG_NAME="lua-5.1"
pkg-config lua && LUAPKG_NAME="lua"

# debian uses lua5.1 as pkg-config name, while lua is vala pkg name, annoying ...
require_pkg $LUAPKG_NAME 5.1 lua lite
require_pkg glib-2.0 2 glib-2.0
require_pkg gthread-2.0 2 ''
require_pkg gdk-2.0 2 gdk-2.0
require_pkg gtk+-2.0 2 gtk+-2.0
require_pkg ibus-1.0 1.3.4 ibus-1.0
require_pkg atk 1 atk
require_pkg gee-1.0 0 gee-1.0
require_pkg dbus-glib-1 0 dbus-glib-1 lite
require_pkg libnotify 0 libnotify
require_pkg sqlite3 3 sqlite3

# check luasocket
if ! lua -e 'require "socket.http"' 1>/dev/null 2>/dev/null; then
	error 'Runtime-required luasocket not found'
fi

# output results
pkg-config --cflags --libs $PACKAGES_PKGCONFIG > $CFLAGFILE
pkg-config --cflags --libs $PACKAGES_PKGCONFIG_2 > $CFLAGFILE2
echo -n $PACKAGES_VALAC > $VALACFLAGFILE
echo -n $PACKAGES_VALAC_2 > $VALACFLAGFILE2
