#!/bin/sh
set -e

usage()
{
cat << EOF
usage: $0 [options]

Install adhocracy on debian.

OPTIONS:
   -h      Show this message
   -d      Developer mode; (i.e. configured bitbucket account)
   -D      Modify DNS configuration
EOF
}

install_geo=false
buildout_variant=testing
modify_dns=false
while getopts dD name
do
    case $name in
    d)    buildout_variant=development;;
    D)    modify_dns=true;;
    ?)   usage
          exit 2;;
    esac
done


if [ "$buildout_variant" = "development" ]; then
	BITBUCKET_PREFIX=ssh://hg@bitbucket.org
else
	BITBUCKET_PREFIX=https://bitbucket.org
fi
BUILDOUT_URL=${BITBUCKET_PREFIX}/phihag/adhocracy.buildout

SUDO_CMD=sudo
if [ "$(id -u)" -eq 0 ]; then
	SUDO_CMD=
fi
if ! $SUDO_CMD true ; then
	echo 'sudo failed. Is it installed and configured?'
	exit 20
fi

if ! mkdir -p adhocracy_buildout; then
	echo 'Cannot create adhocracy_buildout directory. Please change to a directory where you can create files.'
	exit 21
fi

if [ '!' -w adhocracy_buildout ]; then
	echo 'Cannot write to adhocracy_buildout directory. Change to another directory, remove adhocracy_buildout, or run as another user'
	exit 22
fi

$SUDO_CMD apt-get install -yqq libpng-dev libjpeg-dev gcc make build-essential bin86 unzip libpcre3-dev zlib1g-dev mercurial python python-virtualenv python-dev libsqlite3-dev postgresql-8.4 postgresql-server-dev-8.4 openjdk-6-jre erlang-dev erlang-mnesia erlang-os-mon xsltproc libapache2-mod-proxy-html postgresql-8.4-postgis
$SUDO_CMD a2enmod proxy proxy_http proxy_html

# Set up postgreSQL
# Since we're using postgreSQL 8.4 which doesn't have CREATE USER IF NOT EXISTS, we're using the following hack ...
echo "DROP ROLE IF EXISTS adhocracy; CREATE USER adhocracy PASSWORD 'adhoc';" | $SUDO_CMD su postgres -c 'psql'
$SUDO_CMD su postgres -c 'createdb adhocracy --owner adhocracy;' || true
if $install_geo; then
	$SUDO_CMD su postgres -c '
		createlang plpgsql adhocracy;
		psql -d adhocracy -f /usr/share/postgresql/8.4/contrib/postgis-1.5/postgis.sql  >/dev/null 2>&1;
		psql -d adhocracy -f /usr/share/postgresql/8.4/contrib/postgis-1.5/spatial_ref_sys.sql  >/dev/null 2>&1;
		psql -d adhocracy -f /usr/share/postgresql/8.4/contrib/postgis_comments.sql >/dev/null 2>&1;'
fi

if [ -x adhocracy_buildout/bin/supervisorctl ]; then
	adhocracy_buildout/bin/supervisorctl stop all
	adhocracy_buildout/bin/supervisorctl shutdown
fi

virtualenv --distribute --no-site-packages adhocracy_buildout
ORIGINAL_PWD=$(pwd)
cd adhocracy_buildout
if [ -e adhocracy.buildout ]; then
	hg pull -u -R adhocracy.buildout
else
	hg clone $BUILDOUT_URL adhocracy.buildout
fi

for f in adhocracy.buildout/*; do ln -sf $f; done


. bin/activate

bin/python bootstrap.py -c buildout_${buildout_variant}.cfg
bin/buildout -Nc buildout_${buildout_variant}.cfg

bin/paster setup-app etc/adhocracy.ini --name=content

ln -sf adhocracy_buildout/adhocracy.buildout/paster_interactive.sh "$ORIGINAL_PWD"

bin/supervisord

# Set up DNS names
if $modify_dns; then
	$SUDO_CMD apt-get install -qqy dnsmasq
	/bin/echo -e 'address=/.adhocracy.lan/127.0.0.1\nresolv-file=/etc/dnsmasq.resolv.conf' | $SUDO_CMD tee /etc/dnsmasq.d/adhocracy.lan.conf >/dev/null
	/bin/echo -e 'nameserver 8.8.8.8\nnameserver 8.8.4.4\n' | $SUDO_CMD tee /etc/dnsmasq.resolv.conf >/dev/null
	$SUDO_CMD sed -i 's/^#IGNORE_RESOLVCONF=yes$/IGNORE_RESOLVCONF=yes/' /etc/default/dnsmasq >/dev/null
	#/bin/echo -e '#!/bin/sh\nmake_resolv_conf(){}' | $SUDO_CMD tee /etc/dhcp3/dhclient-enter-hooks.d/disable_make_resolv_conf  >/dev/null
	# This is hack-ish, but it works no matter how exotic the configuration is
	if $SUDO_CMD test -w /etc/resolv.conf; then
		echo 'nameserver 127.0.0.1' | $SUDO_CMD tee /etc/resolv.conf >/dev/null
		$SUDO_CMD chattr +i /etc/resolv.conf
	fi
	$SUDO_CMD /etc/init.d/dnsmasq restart
fi


echo 'Use adhocracy_buildout/bin/supervisorctl to control running services. Current status:'
bin/supervisorctl status
sleep 10
if bin/supervisorctl status | grep -vq RUNNING; then
	echo 'Failed to start all services!'
	bin/supervisorctl status
	exit 31
else
	echo ''
	echo ''
	echo 'Type  ./paster_interactive.sh  to run the interactive paster daemon.'
	echo 'Then, navigate to  http://adhocracy.lan:5001/  to see adhocracy!'
fi

