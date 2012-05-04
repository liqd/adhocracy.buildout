#!/bin/sh

BUILDOUT_URL=https://bitbucket.org/phihag/adhocracy.buildout
SUPERVISOR_PORTS="5005 5006 5010"
PORTS="5001 ${SUPERVISOR_PORTS}"

set -e

usage()
{
cat << EOF
usage: $0 [options]

Install adhocracy on debian.

OPTIONS:
   -h      Show this message
   -D      Install a DNS server to answer *.adhocracy.lan
   -p      Use postgres (for automated performance/integration tests)
   -m      Use MySQL
   -A      Do not start automatically
EOF
}

use_postgres=false
use_mysql=false
install_geo=false
buildout_variant=development
modify_dns=false
developer_mode=false
autostart=true
while getopts dDpmA name
do
    case $name in
    d)    developer_mode=true;;
    D)    modify_dns=true;;
    p)    use_postgres=true;;
    m)    use_mysql=true;;
    A)    autostart=false;;
    ?)   usage
          exit 2;;
    esac
done

if $use_postgres && $use_mysql; then
	echo 'Cannot use Postgres AND MySQL.'
	exit 3
fi

if $use_postgres; then
	buildout_variant=development_postgres
elif $use_mysql; then
	buildout_variant=development_mysql
	MYSQL_ROOTPW="sqlrootpw"
else
	buildout_variant=development
fi


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

$SUDO_CMD apt-get install -yqq libpng-dev libjpeg-dev gcc make build-essential bin86 unzip libpcre3-dev zlib1g-dev mercurial python python-virtualenv python-dev libsqlite3-dev openjdk-6-jre erlang-dev erlang-mnesia erlang-os-mon xsltproc libapache2-mod-proxy-html libpq-dev

# Not strictly required, but needed to push to bitbucket via ssh
$SUDO_CMD apt-get install -yqq openssh-client

if $use_postgres; then
	$SUDO_CMD apt-get install -yqq postgresql-8.4 postgresql-server-dev-8.4 postgresql-8.4-postgis
fi
if $use_mysql; then
	echo "mysql mysql-server/root_password string ${MYSQL_ROOTPW}" | $SUDO_CMD debconf-set-selections
        echo "mysql mysql-server/root_password_again string ${MYSQL_ROOTPW}" | $SUDO_CMD debconf-set-selections
	$SUDO_CMD apt-get install -yqq mysql-server libmysqld-dev python-mysqldb
	$SUDO_CMD sed -i "s%^bind-address.*%\#bind-address = 127.0.0.1\nskip-networking%" /etc/mysql/my.cnf
        $SUDO_CMD /etc/init.d/mysql restart
fi
$SUDO_CMD a2enmod proxy proxy_http proxy_html >/dev/null

if $use_postgres; then
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
fi

if $use_mysql; then
	echo "CREATE DATABASE IF NOT EXISTS adhocracy; \
              GRANT ALL PRIVILEGES ON adhocracy . * TO 'adhocracy'@'localhost' IDENTIFIED BY 'adhoc'; \
              FLUSH PRIVILEGES;" \
          | mysql --user root --password=${MYSQL_ROOTPW}

fi

if [ -x adhocracy_buildout/bin/supervisorctl ]; then
	adhocracy_buildout/bin/supervisorctl shutdown >/dev/null
fi

if [ '!' -e ./test-port-free.py ]; then
	wget -q $BUILDOUT_URL/raw/default/etc/test-port-free.py -O ./test-port-free.py
fi
python ./test-port-free.py -g 10 --kill-pid $PORTS


virtualenv --distribute --no-site-packages adhocracy_buildout
ORIGINAL_PWD=$(pwd)
cd adhocracy_buildout
if [ -e adhocracy.buildout ]; then
	hg pull --quiet -u -R adhocracy.buildout
else
	hg clone --quiet $BUILDOUT_URL adhocracy.buildout
fi

for f in adhocracy.buildout/*; do ln -sf $f; done


. bin/activate

bin/python bootstrap.py -c buildout_${buildout_variant}.cfg
bin/buildout -Nc buildout_${buildout_variant}.cfg

bin/paster setup-app etc/adhocracy.ini --name=content

ln -sf adhocracy_buildout/adhocracy.buildout/paster_interactive.sh "$ORIGINAL_PWD"
ln -sf adhocracy_buildout/src/adhocracy adhocracy

# Set up DNS names
if $modify_dns; then
	$SUDO_CMD apt-get install -qqy dnsmasq
	/bin/echo -e 'address=/.adhocracy.lan/127.0.0.1\nresolv-file=/etc/dnsmasq.resolv.conf' | $SUDO_CMD tee /etc/dnsmasq.d/adhocracy.lan.conf >/dev/null
	/bin/echo -e 'nameserver 8.8.8.8\nnameserver 8.8.4.4\n' | $SUDO_CMD tee /etc/dnsmasq.resolv.conf >/dev/null
	$SUDO_CMD sed -i 's/^#IGNORE_RESOLVCONF=yes$/IGNORE_RESOLVCONF=yes/' /etc/default/dnsmasq >/dev/null
	# This is hack-ish, but it works no matter how exotic the configuration is
	if $SUDO_CMD test -w /etc/resolv.conf; then
		echo 'nameserver 127.0.0.1' | $SUDO_CMD tee /etc/resolv.conf >/dev/null
		$SUDO_CMD chattr +i /etc/resolv.conf
	fi
	$SUDO_CMD /etc/init.d/dnsmasq restart
else
	if ! grep -q adhocracy.lan /etc/hosts; then
		$SUDO_CMD sh -c 'echo 127.0.0.1 adhocracy.lan test.adhocracy.lan >> /etc/hosts'
	fi
fi

if $autostart; then
	bin/supervisord
	echo "Use adhocracy_buildout/bin/supervisorctl to control running services. Current status:"
	bin/supervisorctl status
	python adhocracy.buildout/etc/test-port-free.py -o -g 10 ${SUPERVISOR_PORTS}
	if bin/supervisorctl status | grep -vq RUNNING; then
		echo "Failed to start all services!"
		bin/supervisorctl status
		exit 31
	else
		echo
		echo
		echo "Type  ./paster_interactive.sh  to run the interactive paster daemon."
		echo "Then, navigate to  http://adhocracy.lan:5001/  to see adhocracy!"
	fi
fi

