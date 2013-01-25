#!/bin/sh

DEFAULT_BRANCH=develop
BUILDOUT_URL=https://github.com/liqd/adhocracy.buildout
SERVICE_TEMPLATE=etc/init.d__adhocracy_services.sh.template
SERVICE_TEMPLATE_URL=https://raw.github.com/liqd/adhocracy.buildout/$DEFAULT_BRANCH/$SERVICE_TEMPLATE
CHECK_PORT_FREE_URL=https://raw.github.com/liqd/adhocracy.buildout/$DEFAULT_BRANCH/etc/check_port_free.py
SUPERVISOR_PORTS="5005 5006 5010"
ADHOCRACY_PORT=5001

set -e

usage()
{
cat << EOF
usage: $0 [options]

Install adhocracy on debian.

OPTIONS:
   -h      Show this message
   -M      Install MySQL client libraries
   -c file Use the given buildout config file
   -A      Do not start now
   -S      Do not configure system services
   -s      Install only non-superuser parts
   -u      Install only superuser parts
   -U	   Set the username adhocracy should run as
   -b      Branch to check out
EOF
}

buildout_cfg_file=
autostart=true
setup_services=true
not_use_sudo_commands=false
adhoc_user=$USER
install_mysql_client=false
branch=$DEFAULT_BRANCH

if [ -n "$SUDO_USER" ]; then
	adhoc_user=$SUDO_USER
fi

while getopts DpMmASsuc:U:b: name
do
    case $name in
    M)    install_mysql_client=true;;
    A)    autostart=false;;
    S)    setup_services=false;;
    s)    not_use_sudo_commands=true;;
    u)    not_use_user_commands=true;;
    U)	  adhoc_user=$OPTARG;;
    c)    buildout_cfg_file=$OPTARG;;
    b)    branch=$OPTARG;;
    ?)    usage
          exit 2;;
    esac
done


if [ "${PWD#*/adhocracy_buildout}" != "$PWD" ]; then
	echo "You should not run build_debian.sh from the adhocracy_buildout directory. Instead, run it from the directory which contains adhocracy_buildout."
	exit 34
fi


if [ -n "$buildout_cfg_file" ]; then
	buildout_cfg_file=$(readlink -f "$buildout_cfg_file")
else
	buildout_cfg_file=buildout_development.cfg
fi


if ! $not_use_sudo_commands; then
	SUDO_CMD=sudo
	if [ "$(id -u)" -eq 0 ]; then
		SUDO_CMD=
	fi
	if ! $SUDO_CMD true ; then
		echo 'sudo failed. Is it installed and configured?'
		exit 20
	fi

	$SUDO_CMD apt-get install -yqq libpng-dev libjpeg-dev gcc make build-essential bin86 unzip libpcre3-dev zlib1g-dev git mercurial python python-virtualenv python-dev libsqlite3-dev openjdk-6-jre erlang-dev erlang-mnesia erlang-os-mon xsltproc libpq-dev
	# Not strictly required, but needed to push to github via ssh
	$SUDO_CMD apt-get install -yqq openssh-client

	if $install_mysql_client; then
        $SUDO_CMD apt-get install -yqq libmysqlclient-dev
	fi

	if $setup_services; then
		if [ "$adhoc_user" = "root" ]; then
			echo "You are root. Please use the -U flag to set the user adhocracy should be running as"
			exit 35
		fi

        if [ -r "adhocracy_buildout/adhocracy.buildout/${SERVICE_TEMPLATE}" ]; then
            stmpl=$(cat "adhocracy_buildout/adhocracy.buildout/${SERVICE_TEMPLATE}")
        else
            stmpl=$(wget $SERVICE_TEMPLATE_URL -O- -nv)
        fi
		echo "$stmpl" | \
			sed -e "s#%%USER%%#$adhoc_user#" -e "s#%%DIR%%#$(readlink -f .)/adhocracy_buildout#" | \
			$SUDO_CMD tee /etc/init.d/adhocracy_services >/dev/null

		$SUDO_CMD chmod a+x /etc/init.d/adhocracy_services
		$SUDO_CMD update-rc.d adhocracy_services defaults >/dev/null
	fi
fi


if $not_use_user_commands; then
	exit 0
fi


if [ "$(id -u)" -eq 0 ]; then
	echo "You should not install adhocracy as a root user"
	exit 33
fi

# Create buildout directory
if ! mkdir -p adhocracy_buildout; then
	echo 'Cannot create adhocracy_buildout directory. Please change to a directory where you can create files.'
	exit 21
fi

if [ '!' -w adhocracy_buildout ]; then
	echo 'Cannot write to adhocracy_buildout directory. Change to another directory, remove adhocracy_buildout, or run as another user'
	exit 22
fi
if [ -x adhocracy_buildout/bin/supervisorctl ]; then
	adhocracy_buildout/bin/supervisorctl shutdown >/dev/null 2>/dev/null || true
fi

check_port_free=adhocracy/check_port_free.py
if [ '!' -e "$check_port_free" ]; then
    check_port_free_tmp=$(mktemp)
    check_port_free=$check_port_free_tmp
	if ! wget -q "$CHECK_PORT_FREE_URL" -O "$check_port_free_tmp"; then
        ex=$?
        echo "Download failed. Are you connected to the Internet?"
        exit $ex
    fi
fi
python $check_port_free -g 10 --kill-pid $ADHOCRACY_PORT $SUPERVISOR_PORTS
if [ -n "$check_port_free_tmp" ]; then
    rm -f $check_port_free_tmp
fi


virtualenv --distribute --no-site-packages adhocracy_buildout
ORIGINAL_PWD=$(pwd)
cd adhocracy_buildout
if [ -e adhocracy.buildout ]; then
	(cd adhocracy.buildout && git pull --quiet)
else
	git clone --quiet $BUILDOUT_URL adhocracy.buildout
fi
(cd adhocracy.buildout && git checkout $branch > /dev/null)



for f in adhocracy.buildout/*; do ln -sf $f; done
if echo $buildout_cfg_file | grep "^/" -q; then
	tmp_file=$(mktemp --tmpdir=.)
	cp $buildout_cfg_file $tmp_file
	buildout_cfg_file=$tmp_file
fi

. bin/activate

pip install -U distribute >/dev/null

# TODO write buildout file with configurations (sysv_init:user ...) and use that

bin/python bootstrap.py -c ${buildout_cfg_file}
bin/buildout -Nc ${buildout_cfg_file}

if [ -n "$tmp_file" ]; then
	rm "$tmp_file"
fi

ln -sf adhocracy_buildout/adhocracy.buildout/etc/paster_interactive.sh "$ORIGINAL_PWD"


if $autostart; then
	bin/supervisord
	echo "Use adhocracy_buildout/bin/supervisorctl to control running services."

	python adhocracy.buildout/etc/check_port_free.py -o -g 10 ${SUPERVISOR_PORTS}
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
	echo "Then, navigate to  http://adhocracy.lan:${ADHOCRACY_PORT}/  to see adhocracy!"
	echo "Use the username \"admin\" and password \"password\" to login."
fi
