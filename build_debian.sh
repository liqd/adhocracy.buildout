#!/bin/sh

#BUILDOUT_URL=https://bitbucket.org/liqd/adhocracy.buildout
#SERVICE_TEMPLATE=https://bitbucket.org/liqd/adhocracy.buildout/raw/46fcef386019/etc/init.d__adhocracy_services.sh.template
BUILDOUT_URL=https://bitbucket.org/chrisprobst/adhocracy.buildout
SERVICE_TEMPLATE=https://bitbucket.org/chrisprobst/adhocracy.buildout/raw/580573af8714/etc/init.d__adhocracy_services.sh.template
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
   -A      Do not start now
   -S      Do not configure system services
   -s      Do not use sudo commands
   -u      Do not use user commands
EOF
}

use_postgres=false
use_mysql=false
install_geo=false
buildout_variant=development
modify_dns=false
developer_mode=false
autostart=true
setup_services=true
not_use_sudo_commands=false
not_use_user_commands=false

while getopts dDpmASsu name
do
    case $name in
    d)    developer_mode=true;;
    D)    modify_dns=true;;
    p)    use_postgres=true;;
    m)    use_mysql=true;;
    A)    autostart=false;;
    S)    setup_services=false;;
    s)    not_use_sudo_commands=true;;
    u)    not_use_user_commands=true;;
    ?)    usage
          exit 2;;
    esac
done

if $not_use_sudo_commands && $autostart && $setup_services; then
	echo 'ERROR: You can\'t setup services without sudo!'
	exit 33
fi

if $not_use_sudo_commands; then
	echo '****** NO SUDO COMMANDS ******'
fi

if $not_use_user_commands; then
	echo '****** NO USER COMMANDS ******'
fi

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

########### nur sudo
if ! $not_use_sudo_commands; then

	SUDO_CMD=sudo
	if [ "$(id -u)" -eq 0 ]; then
		SUDO_CMD=
	fi
	if ! $SUDO_CMD true ; then
		echo 'sudo failed. Is it installed and configured?'
		exit 20
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
	
	# This is only executed when sudo-commands are enabled since mysql will only
	# install with sudo-commands.
	if $use_mysql; then
	echo "CREATE DATABASE IF NOT EXISTS adhocracy; \
              GRANT ALL PRIVILEGES ON adhocracy . * TO 'adhocracy'@'localhost' IDENTIFIED BY 'adhoc'; \
              FLUSH PRIVILEGES;" \
          | mysql --user root --password=${MYSQL_ROOTPW}

	fi
	
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
	
	# Setup system service
	if $setup_services; then
		wget $SERVICE_TEMPLATE -O- -nv | \
			sed -e "s#%%USER%%#$USER#" -e "s#%%DIR%%#$(readlink -f .)#" | \
			$SUDO_CMD tee /etc/init.d/adhocracy_services >/dev/null

		$SUDO_CMD chmod a+x /etc/init.d/adhocracy_services
		$SUDO_CMD update-rc.d adhocracy_services defaults >/dev/null
	fi
	
fi
############## nur sudo ende



# NUR USER
if ! $not_use_user_commands; then
	# Create buildout directory
	if ! mkdir -p adhocracy_buildout; then
		echo 'Cannot create adhocracy_buildout directory. Please change to a directory where you can create files.'
		exit 21
	fi

	# Directory buildout was not created
	if [ '!' -w adhocracy_buildout ]; then
		echo 'Cannot write to adhocracy_buildout directory. Change to another directory, remove adhocracy_buildout, or run as another user'
		exit 22
	fi
	if [ -x adhocracy_buildout/bin/supervisorctl ]; then
		adhocracy_buildout/bin/supervisorctl shutdown >/dev/null
	fi

	test_port_free_tmp=$(mktemp)
	if [ '!' -e ./test-port-free.py ]; then
		wget -q $BUILDOUT_URL/raw/default/etc/test-port-free.py -O $test_port_free_tmp
	fi
	python $test_port_free_tmp -g 10 --kill-pid $PORTS
	rm -f $test_port_free_tmp


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

	ln -sf adhocracy_buildout/adhocracy.buildout/etc/paster_interactive.sh "$ORIGINAL_PWD"
	ln -sf adhocracy_buildout/src/adhocracy "$ORIGINAL_PWD"

fi
#NUR USER ENDE



if $autostart; then
	if $setup_service; then
			$SUDO_CMD /etc/init.d/adhocracy_services start
	else
		bin/supervisord
		echo "Use adhocracy_buildout/bin/supervisorctl to control running services."
	fi
	
	if ! $not_use_user_commands; then
		python adhocracy.buildout/etc/test-port-free.py -o -g 10 ${SUPERVISOR_PORTS}
		if bin/supervisorctl status | grep -vq RUNNING; then
			echo 'Failed to start all services:'
			bin/supervisorctl status
			exit 31
		fi

		pasterOutput=$(bin/paster setup-app etc/adhocracy.ini --name=content)
		if echo "$pasterOutput" | grep -q ERROR; then
			echo "$pasterOutput"
			echo 'Error in paster setup'
			exit 32
		fi

		echo
		echo
		echo "Type  ./paster_interactive.sh  to run the interactive paster daemon."
		echo "Then, navigate to  http://adhocracy.lan:5001/  to see adhocracy!"
		echo "Use the username \"admin\" and password \"password\" to login."
	fi
fi

