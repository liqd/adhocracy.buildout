#!/bin/sh

# Test adhocracy in a chroot, on a debian(-ish) system
BUILDOUT_URL=


set -e

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 chroot_path"
	exit 21
fi
chroot_path=$1

SUDO_CMD=sudo
if [ "$(id -u)" -eq 0 ]; then
	SUDO_CMD=
fi
if ! $SUDO_CMD true ; then
	echo 'sudo failed. Is it installed and configured?'
	exit 20
fi

$SUDO_CMD apt-get install -yqq debootstrap

if [ '!' -d $chroot_path/proc ]; then
	# Use HHU mirror if available
	MIRROR=
	if wget -q http://mirror.cs.uni-duesseldorf.de/debian/ -O /dev/null; then
		MIRROR=http://mirror.cs.uni-duesseldorf.de/debian
	fi
	$SUDO_CMD debootstrap squeeze $chroot_path $MIRROR
fi

echo adhocracy-chroot | $SUDO_CMD tee $chroot_path/etc/debian_chroot >/dev/null


$SUDO_CMD tee $chroot_path/test_in_chroot.sh >/dev/null <<EOF
#!/bin/sh
set -e


if ! mountpoint -q /proc; then
	mount -t proc proc /proc
fi
if ! id -u adhocracy >/dev/null 2>&1; then
	useradd adhocracy --create-home
fi

echo '
Defaults        env_reset
Defaults        mail_badpass
Defaults        secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

root    ALL=(ALL:ALL) ALL

adhocracy ALL=(ALL:ALL) NOPASSWD:ALL
' > /etc/sudoers
chmod 0440 /etc/sudoers

hostname adhocracy-chroot
grep -q adhocracy-chroot /etc/hosts || echo 127.0.0.1 adhocracy-chroot >> /etc/hosts

# Configure initial packages for the system
apt-get update -qq
if [ ! -d /usr/lib/locale ]; then
	echo 'locales locales/locales_to_be_generated string de_DE.UTF-8 UTF-8, en_US.UTF-8 UTF-8' | LC_ALL=C debconf-set-selections
	echo 'locales locales/default_environment_locale string en_US' | LC_ALL=C debconf-set-selections
	LC_ALL=C apt-get install -yqq locales
	dpkg-reconfigure --default-priority locales
fi
apt-get install -yqq make sudo ca-certificates


cd /home/adhocracy
su adhocracy -c 'wget -nv https://bitbucket.org/phihag/adhocracy.buildout/raw/default/build_debian.sh -O build_debian.sh && sh build_debian.sh -A'

rm -f /etc/sudoers

# TODO start services


umount /proc
EOF

$SUDO_CMD chroot $chroot_path sh /test_in_chroot.sh

