#!/bin/sh

cd "$(dirname $(readlink -f $0))/.."
. bin/activate
bin/paster serve --reload etc/adhocracy.ini
