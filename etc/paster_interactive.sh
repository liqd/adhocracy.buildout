#!/bin/sh

if ! cd "$(dirname $(readlink -f $0))/../../"; then
	echo 'Cannot find adhocracy_buildout directory!'
	exit 2
fi
. bin/activate
exec bin/paster serve --reload etc/adhocracy.ini
