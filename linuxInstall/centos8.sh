#!/bin/bash
# ---------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------[ Configuração ]-----------------------------------------------------
repos=""                                                               # Inicia a variável
pacotes=""                                                             # Inicia a variável
local="true"                                                            # Inicia a variável
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
if [ -f $(cat /etc/yum.conf | grep clean_requirements_on_remove) ] ; then\
        echo "Configurando yum"
        echo "clean_requirements_on_remove=1" >> /etc/yum.conf
fi

# Seta o timezone ===========================================================================================================
ln -sf ../usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

# Configuração de repositórios ==============================================================================================
repos="epel-release"
repos="${repos} https://download1.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm"
repos="${repos} https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-8.noarch.rpm"
repos="${repos} https://extras.getpagespeed.com/release-el8-latest.rpm"

dnf -y install --nogpgcheck ${repos} dnf-utils

dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/x86_64/
dnf config-manager --add-repo https://negativo17.org/repos/epel-spotify.repo
dnf config-manager --add-repo https://techmago.sytes.net/rpm/centos8-techsytes.repo

rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc

dnf config-manager --enable PowerTools

# Desabilita serviços desnecessários ========================================================================================
# systemctl disable wpa_supplicant.service # Notebook?
systemctl stop auditd.service
systemctl mask auditd.service
systemctl stop ModemManager.service
systemctl mask ModemManager.service
systemctl disable firewalld.service
systemctl disable ipmievd.service
systemctl disable lvm2-lvmetad.socket
systemctl disable lvm2-lvmpolld.socket
systemctl disable cryptsetup.target


# Da um boost no terminal ===================================================================================================
wget --no-check-certificate http://techmago.sytes.net/rpm/techmago.sh
mv techmago.sh /etc/profile.d/

# Remove programas inuteis ==================================================================================================
dnf remove -y PackageKit-yum abrt* postfix crash empathy hypervkvpdy qemu-guest-agent spice-vdagent open-vm-tools

# Executa a primeira atualização de sistema =================================================================================
dnf update -y --skip-broken

# Instala pacotes ===========================================================================================================
# Sistema
pacotes="${pacotes} pigz pxz pbzip2 zlib unrar bzip2 xz-lzma-compat xz lrzip p7zip p7zip-plugins lzip cabextract"
pacotes="${pacotes} htop iotop iftop bmon pydf inxi nload ntpdate fortune-mod bash-completion"
pacotes="${pacotes} net-tools byobu mlocate psmisc hddtemp lm_sensors"

# Media
#dnf install -y spotify-client
pacotes="${pacotes} vlc smplayer"
pacotes="${pacotes} gstreamer1-plugins-ugly gstreamer1-libav ffmpeg HandBrake-{gui,cli} gstreamer1-plugins-bad-freeworld"

# Escritorio
pacotes="${pacotes} gnome-disk-utility terminator freetype-freeworld"
pacotes="${pacotes} vim flash-plugin google-chrome-stable gparted"
pacotes="${pacotes} meld"

# Internet
pacotes="${pacotes} wget curl telnet brave-browser google-chrome-stable thunderbird"

# Gnome
pacotes="${pacotes} gnome-tweaks"
pacotes="${pacotes} brasero gnome-tweak-tool gnome-terminal-nautilus gnome-games gnome-games-extra gnome-icon-theme gnome-icon-theme-extras gnome-system-monitor"

# Desenvolvimento
pacotes="${pacotes} gtk2-immodules"
pacotes="${pacotes} acpid elfutils-libelf-devel"
pacotes="${pacotes} mesa-dri-drivers.i686 mesa-dri-drivers.x86_64 mesa-filesystem.i686 mesa-filesystem.x86_64 mesa-libEGL.i686 mesa-libEGL.x86_64"
pacotes="${pacotes} mesa-libEGL-devel.i686 mesa-libEGL-devel.x86_64 mesa-libGL.i686 mesa-libGL.x86_64 mesa-libGL-devel.i686 mesa-libGL-devel.x86_64"
pacotes="${pacotes} mesa-libGLES.i686 mesa-libGLES.x86_64 mesa-libGLES-devel.i686 mesa-libGLES-devel.x86_64 mesa-libGLU.i686 mesa-libGLU.x86_64 mesa-libGLU-devel.i686"
pacotes="${pacotes} mesa-libGLU-devel.x86_64 mesa-libGLw-devel.i686 mesa-libGLw-devel.x86_64 mesa-libOSMesa.i686 mesa-libOSMesa.x86_64"
pacotes="${pacotes} mesa-libOSMesa-devel.i686 mesa-libOS Mesa-devel.x86_64 mesa-libgbm.i686 mesa-libgbm.x86_64 mesa-libgbm-devel.i686"
pacotes="${pacotes} mesa-libgbm-devel.x86_64 mesa-libglapi.i686 mesa-libglapi.x86_64 mesa-libGLw.x86_64 mesa-libGLw.i686"
pacotes="${pacotes} libdc1394-devel libmodplug-devel libv4l-devel libva-devel openal-soft-devel openjpeg-devel opus-devel schroedinger-devel"
pacotes="${pacotes} soxr-devel texinfo x265-devel ilbc-devel SDL-devel a52dec-devel aalib-devel bzip2-devel alsa-lib-devel enca-devel faad2-devel"
pacotes="${pacotes} ffmpeg-devel fribidi-devel giflib-devel gsm-devel gtk2-devel ladspa-devel lame-devel libXinerama-devel libXScrnSaver-devel"
pacotes="${pacotes} libXv-devel libXvMC-devel libass-devel libbluray-devel libbs2b-devel libcaca-devel libcdio-paranoia-devel libdca-devel"
pacotes="${pacotes} libdv-devel libdvdnav-devel libmpeg2-devel libmpg123-devel librtmp-devel libtheora-devel libvdpau-devel libvorbis-devel"
pacotes="${pacotes} lirc-devel lzo-devel pulseaudio-libs-devel speex-devel twolame-devel x264-devel xvidcore-devel yasm dbus-glib-devel"
pacotes="${pacotes} gtk3-devel libcurl-devel libgda-devel libgpod-devel libmusicbrainz3-devel libnotify-devel nautilus-devel nemo-devel"
pacotes="${pacotes} qt5-linguist qt5-qtbase-devel qt5-qtscript-devel qt5-qttools-devel qt5-qtwebkit-devel qtsingleapplication-qt5-devel"
pacotes="${pacotes} dirac-devel"

yum install -y --skip-broken ${pacotes}

# Atom ======================================================================================================================
wget https://atom.io/download/rpm -O atom.rpm
dnf -y install atom.rpm
rm -f atom.rpm

# Hack para deletar arquivos
echo '#!/usr/bin/env bash
# GVFS updated and dropped gvfs-trash to gio, but Atom didnt update.
# https://github.com/atom/tree-view/issues/1237
/usr/bin/gio trash "$@"
' | tee /usr/local/bin/gvfs-trash && chmod +x /usr/local/bin/gvfs-trash

# Instala um pacote de senhas do windows ====================================================================================
wget --no-check-certificate http://techmago.sytes.net/rpm/fontesWindows.txz
tar -xJf fontesWindows.txz
mv fontesWindows /usr/share/fonts/
rm -f fontesWindows.txz

# Fluendo mp3 codecs ========================================================================================================
wget --no-check-certificate http://techmago.sytes.net/rpm/fluendo-codecs-mp3-17-3.i386.rpm
dnf -y install --nogpgcheck fluendo-codecs-mp3-17-3.i386.rpm
rm -f fluendo-codecs-mp3-17-3.i386.rpm

# Java =====================================================================================================================================
wget --no-check-certificate http://techmago.sytes.net/rpm/jre.rpm
dnf -y install --nogpgcheck jre.rpm
rm -f jre.rpm

alternatives --install /usr/bin/java java /usr/java/latest/bin/java 20000
alternatives --install /usr/bin/javaws javaws /usr/java/latest/bin/javaws 20000

alternatives --config java
alternatives --config javaws
