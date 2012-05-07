#!/bin/sh

cd "$(dirname $(readlink -f $0))/.."
. bin/activate
exec bin/paster serve --reload etc/adhocracy.ini
