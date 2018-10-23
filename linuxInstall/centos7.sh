#!/bin/bash
# ---------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------[ Configuração ]-----------------------------------------------------
repos=""                                                               # Inicia a variável
pacotes=""                                                             # Inicia a variável
# ------------------------------------------------------[ Configuração ]-----------------------------------------------------
# ---------------------------------------------------------------------------------------------------------------------------
# Checa SELINUX =============================================================================================================
if [ -f $(cat /etc/selinux/config | grep 'SELINUX=disabled') ] ; then
	echo "SELINUX Ativado!"
	echo "Deactive and reboot"
	echo "vim /etc/selinux/config"

	exit 1
fi

# Checa Yum =================================================================================================================
if [ -f $(cat /etc/yum.conf | grep clean_requirements_on_remove) ] ; then
        echo "Configurando yum"
        echo "clean_requirements_on_remove=1" >> /etc/yum.conf
fi

# Seta o timezone ===========================================================================================================
ln -sf ../usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

# Configuração de repositórios ==============================================================================================
repos=""
repos="${repos} https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"
repos="${repos} http://rpms.remirepo.net/enterprise/remi-release-7.rpm"
repos="${repos} http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm"

yum -y install --nogpgcheck ${repos} yum-utils

yum-config-manager --add-repo=http://negativo17.org/repos/epel-negativo17.repo
yum-config-manager --add-repo=https://techmago.sytes.net/rpm/google-chrome.repo
yum-config-manager --add-repo=https://techmago.sytes.net/rpm/techmago-centos.repo

yum-config-manager --enable remi centosplus
yum-config-manager --disable epel-bitcoin epel-cdrtools epel-games epel-multimedia epel-nvidia epel-rar epel-spotify epel-steam epel-uld

# Desabilita serviços desnecessários ========================================================================================
systemctl stop auditd.service
systemctl disable auditd.service
systemctl mask auditd.service
systemctl stop ModemManager.service
systemctl disable ModemManager.service
systemctl mask ModemManager.service

# Da um boost no terminal ===================================================================================================
wget --no-check-certificate http://techmago.sytes.net/rpm/techmago.sh
mv techmago.sh /etc/profile.d/

# Remove programas inuteis ==================================================================================================
yum remove -y PackageKit-yum abrt* postfix crash empathy hypervkvpdy qemu-guest-agent spice-vdagent open-vm-tools

# Executa a primeira atualização de sistema =================================================================================
yum update -y --skip-broken

# Instala pacotes ===========================================================================================================
# Sistema
yum install -y pigz pxz pbzip2 zlib unrar bzip2 xz-lzma-compat xz lrzip p7zip p7zip-plugins lzip cabextract
yum install -y htop iotop iftop pydf bmon pydf inxi nload ntpdate fortune-mod
yum install -y net-tools byobu mlocate psmisc system-config-keyboard hddtemp lm_sensors

# Media
yum install -y vlc spotify-client smplayer
yum install -y gstreamer-plugins-bad gstreamer1-plugins-ugly gstreamer1-libav gstreamer-ffmpeg ffmpeg HandBrake-{gui,cli}
yum install -y libdvdcss gstreamer{,1}-plugins-ugly gstreamer-plugins-bad-nonfree gstreamer1-plugins-bad-freeworld

# Escritorio
yum install -y gnome-disk-utility terminator freetype-freeworld
yum install -y vim flash-plugin google-chrome-stable gparted

# Internet
yum install -y wget curl telnet

# Gnome
yum install -y brasero gnome-tweak-tool gnome-terminal-nautilus gnome-games gnome-games-extra gnome-icon-theme gnome-icon-theme-extras gnome-system-monitor
yum install -y gnome-mplayer gnome-mplayer-nautilus gnome-online-accounts gnome-themes-standard gnome-weather gnome-bluetooth gnome-calculator gnome-disk-utility
yum install -y gnome-shell-extension-pidgin gnome-shell-extension-openweather gnome-shell-browser-plugin

# Desenvolvimento
yum install -y gtk2-immodules im-chooser
yum install -y mesa-dri-drivers.i686 mesa-dri-drivers.x86_64 mesa-filesystem.i686 mesa-filesystem.x86_64 mesa-libEGL.i686 mesa-libEGL.x86_64
yum install -y mesa-libEGL-devel.i686 mesa-libEGL-devel.x86_64 mesa-libGL.i686 mesa-libGL.x86_64 mesa-libGL-devel.i686 mesa-libGL-devel.x86_64
yum install -y mesa-libGLES.i686 mesa-libGLES.x86_64 mesa-libGLES-devel.i686 mesa-libGLES-devel.x86_64 mesa-libGLU.i686 mesa-libGLU.x86_64 mesa-libGLU-devel.i68
yum install -y mesa-libGLU-devel.x86_64 mesa-libGLw-devel.i686 mesa-libGLw-devel.x86_64 mesa-libOSMesa.i686 mesa-libOSMesa.x86_64
yum install -y mesa-libOSMesa-devel.i686 mesa-libOSMesa-devel.x86_64 mesa-libgbm.i686 mesa-libgbm.x86_64 mesa-libgbm-devel.i686
yum install -y mesa-libgbm-devel.x86_64 mesa-libglapi.i686 mesa-libglapi.x86_64mesa-libGLw.x86_64 mesa-libGLw.i686
yum install -y libdc1394-devel libmodplug-devel libv4l-devel libva-devel openal-soft-devel openjpeg-devel opus-devel schroedinger-devel
yum install -y soxr-devel texinfo x265-devel ilbc-devel SDL-devel a52dec-devel aalib-devel bzip2-devel alsa-lib-devel enca-devel faad2-devel
yum install -y ffmpeg-devel fribidi-devel giflib-devel gsm-devel gtk2-devel ladspa-devel lame-devel libXinerama-devel libXScrnSaver-devel
yum install -y libXv-devel libXvMC-devel libass-devel libbluray-devel libbs2b-devel libcaca-devel libcdio-paranoia-devel libdca-devel
yum install -y libdv-devel libdvdnav-devel libmpeg2-devel libmpg123-devel librtmp-devel libtheora-devel libvdpau-devel libvorbis-devel
yum install -y lirc-devel lzo-devel pulseaudio-libs-devel speex-devel twolame-devel x264-devel xvidcore-devel yasm dbus-glib-devel
yum install -y gtk3-devel libcurl-devel libgda-devel libgpod-devel libmusicbrainz3-devel libnotify-devel nautilus-devel nemo-devel
yum install -y qt5-linguist qt5-qtbase-devel qt5-qtscript-devel qt5-qttools-devel qt5-qtwebkit-devel qtsingleapplication-qt5-devel
yum install -y dirac-devel texi2html

# Atom ======================================================================================================================
wget https://atom.io/download/rpm -O atom.rpm
yum -y install atom.rpm
rm -f atom.rpm

# Instala um pacote de senhas do windows ====================================================================================
wget --no-check-certificate http://techmago.sytes.net/rpm/fontesWindows.tar.bz2
tar -xjf fontesWindows.tar.bz2
mv fontesWindows /usr/share/fonts/
rm -f fontesWindows.tar.bz2

# Fluendo mp3 codecs ========================================================================================================
wget --no-check-certificate http://techmago.sytes.net/rpm/fluendo-codecs-mp3-17-3.i386.rpm
yum -y install --nogpgcheck fluendo-codecs-mp3-17-3.i386.rpm
rm -f fluendo-codecs-mp3-17-3.i386.rpm

# Java =====================================================================================================================================
wget --no-check-certificate http://techmago.sytes.net/rpm/jre.rpm
yum -y install --nogpgcheck jre.rpm
rm -f jre.rpm

alternatives --install /usr/bin/java java /usr/java/latest/bin/java 20000
alternatives --install /usr/bin/javaws javaws /usr/java/latest/bin/javaws 20000

alternatives --config java
alternatives --config javaws
