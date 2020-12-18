#!/bin/bash
# ---------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------[ Configuração ]-----------------------------------------------------
repos=""                                                               # Inicia a variável
pacotes=""                                                             # Inicia a variável
local="true"                                                           # Inicia a variável
devel="yes"                                                            # Instala coisas do pseudogrupo "devel"
jogos="yes"                                                            # Instala os jogos básicos
steam="yes"                                                            # Instala a steam
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
repos="${repos} http://linuxdownload.adobe.com/adobe-release/adobe-release-x86_64-1.0-1.noarch.rpm"

dnf -y install --nogpgcheck ${repos} dnf-utils

if ${local} ; then
	dnf config-manager --disable AppStream BaseOS PowerTools fasttrack extras epel
	dnf config-manager --add-repo https://techmago.sytes.net/rpm/centos8-techsytes.repo
else
	dnf config-manager --disable extras
fi

dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/x86_64/
dnf config-manager --add-repo https://negativo17.org/repos/epel-spotify.repo
dnf config-manager --add-repo https://negativo17.org/repos/epel-steam.repo


rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc

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
dnf remove -y abrt* postfix crash empathy hypervkvpdy qemu-guest-agent spice-vdagent open-vm-tools

# Executa a primeira atualização de sistema =================================================================================
dnf update -y --skip-broken

# Instala pacotes ===========================================================================================================
# Utilidades
pacotes=""                                                             # Inicia a variável
pacotes="${pacotes} zlib unrar bzip2 xz-lzma-compat xz p7zip p7zip-plugins lzip lrzip cabextract pigz pxz pbzip2"
pacotes="${pacotes} htop iotop iftop pydf bmon pydf inxi nload"
pacotes="${pacotes} ntpdate fortune-mod gnome-disk-utility terminator bash-completion"
pacotes="${pacotes} net-tools mlocate psmisc hddtemp lm_sensors glances"

if [ "${devel}" = yes ]; then
	pacotes="${pacotes} unison sshfs byobu nfs-utils gparted"
fi

if [$(rpm -q gnome-session > /dev/null) $? -eq 0 ]; then
	pacotes="${pacotes} nautilus-dropbox nautilus-open-terminal evince-nautilus easytag-nautilus nextcloud-client-nautilus"
	pacotes="${pacotes} gnome-tweak-tool chrome-gnome-shell"
fi

if [$(rpm -q gnome-session > /dev/null) $? -eq 0 ]; then
  	pacotes="${pacotes} nautilus-dropbox nautilus-extensions evince-nautilus brasero-nautilus nextcloud-client-nautilus"
  	pacotes="${pacotes} gnome-tweak-tool chrome-gnome-shell"
    pacotes="${pacotes} gnome-shell-extension-apps-menu gnome-shell-extension-top-icons gnome-shell-extension-places-menu gnome-shell-extension-window-list gnome-shell-extension-desktop-icons gnome-shell-extension-no-hot-corner gnome-shell-extension-launch-new-instance"
fi
dnf -y --skip-broken --allowerasing install ${pacotes}


# Internet
pacotes=""                                                             # Inicia a variável
pacotes="${pacotes} wget curl telnet"
pacotes="${pacotes} transmission filezilla youtube-dl"
pacotes="${pacotes} flash-plugin firefox google-chrome-stable brave-browser"
pacotes="${pacotes} thunderbird thunderbird-lightning"
pacotes="${pacotes} remmina remmina-plugins-nx remmina-gnome-session remmina-plugins-rdp remmina-plugins-vnc remmina-plugins-www remmina-plugins-spice remmina-plugins-xdmcp remmina-plugins-kwallet remmina-plugins-st remmina-plugins-secret remmina-plugins-exec"
dnf -y --skip-broken --allowerasing install ${pacotes}

# Multimidia
pacotes=""                                                             # Inicia a variável
pacotes="${pacotes} gstreamer1-libav gstreamer1 gstreamer-plugin-crystalhd gstreamer1-plugins-good PackageKit-gstreamer-plugin gstreamer1-plugins-bad-free gstreamer1-plugins-base gstreamer1-plugins-ugly gstreamer1-plugins-ugly-free gstreamer1-plugins-bad-freeworld gstreamer1-plugins-bad-nonfree gnome-video-effects"
pacotes="${pacotes} mplayer smplayer rhythmbox cheese brasero spotify-client vlc"
pacotes="${pacotes} ffmpeg HandBrake-{gui,cli}"
dnf -y --skip-broken --allowerasing install ${pacotes}


# Jogos
pacotes=""                                                             # Inicia a variável
if [ "${jogos}" = yes ]; then
  pacotes="${pacotes} aisleriot apx five-or-more gnome-klotski gnome-mahjongg vitetris gnome-sudoku gnome-mines gnome-tetravex gnome-nibbles gnome-robots lightsoff"
fi
if [ "${steam}" = yes ]; then
	pacotes="${pacotes} steam"
fi
dnf -y --skip-broken --nobest --allowerasing install ${pacotes}


# Escritorio
pacotes=""                                                             # Inicia a variável
pacotes="${pacotes} meld gimp kolourpaint geany terminator"

pacotes="${pacotes} libreoffice-langpack-pt-BR libreoffice-impress libreoffice-calc libreoffice-draw libreoffice-writer libreoffice-pdfimport"
pacotes="${pacotes} ubuntu-title-fonts freetype-freeworld"
dnf -y --skip-broken --nobest --allowerasing install ${pacotes}

pacotes="${pacotes} texmaker texlive-scheme-small texlive-collection-langportuguese texlive-supertabular texlive-tocloft texlive-hyphenat texlive-moderncv"


if [ "${steam}" = yes ]; then
	pacotes="${pacotes} steam"
fi

# Gnome
dnf install -y gnome-tweaks gnome-disk-utility
dnf install -y brasero gnome-tweak-tool gnome-terminal-nautilus gnome-games gnome-games-extra gnome-icon-theme gnome-icon-theme-extras gnome-system-monitor

# Desenvolvimento
dnf install -y gtk2-immodules
dnf install -y acpid elfutils-libelf-devel
dnf install -y mesa-dri-drivers.i686 mesa-dri-drivers.x86_64 mesa-filesystem.i686 mesa-filesystem.x86_64 mesa-libEGL.i686 mesa-libEGL.x86_64
dnf install -y mesa-libEGL-devel.i686 mesa-libEGL-devel.x86_64 mesa-libGL.i686 mesa-libGL.x86_64 mesa-libGL-devel.i686 mesa-libGL-devel.x86_64
dnf install -y mesa-libGLES.i686 mesa-libGLES.x86_64 mesa-libGLES-devel.i686 mesa-libGLES-devel.x86_64 mesa-libGLU.i686 mesa-libGLU.x86_64 mesa-libGLU-devel.i686
dnf install -y mesa-libGLU-devel.x86_64 mesa-libGLw-devel.i686 mesa-libGLw-devel.x86_64 mesa-libOSMesa.i686 mesa-libOSMesa.x86_64
dnf install -y mesa-libOSMesa-devel.i686 mesa-libOS Mesa-devel.x86_64 mesa-libgbm.i686 mesa-libgbm.x86_64 mesa-libgbm-devel.i686
dnf install -y mesa-libgbm-devel.x86_64 mesa-libglapi.i686 mesa-libglapi.x86_64 mesa-libGLw.x86_64 mesa-libGLw.i686
dnf install -y libdc1394-devel libmodplug-devel libv4l-devel libva-devel openal-soft-devel openjpeg-devel opus-devel schroedinger-devel
dnf install -y soxr-devel texinfo x265-devel ilbc-devel SDL-devel a52dec-devel aalib-devel bzip2-devel alsa-lib-devel enca-devel faad2-devel
dnf install -y ffmpeg-devel fribidi-devel giflib-devel gsm-devel gtk2-devel ladspa-devel lame-devel libXinerama-devel libXScrnSaver-devel
dnf install -y libXv-devel libXvMC-devel libass-devel libbluray-devel libbs2b-devel libcaca-devel libcdio-paranoia-devel libdca-devel
dnf install -y libdv-devel libdvdnav-devel libmpeg2-devel libmpg123-devel librtmp-devel libtheora-devel libvdpau-devel libvorbis-devel
dnf install -y lirc-devel lzo-devel pulseaudio-libs-devel speex-devel twolame-devel x264-devel xvidcore-devel yasm dbus-glib-devel
dnf install -y gtk3-devel libcurl-devel libgda-devel libgpod-devel libmusicbrainz3-devel libnotify-devel nautilus-devel nemo-devel
dnf install -y qt5-linguist qt5-qtbase-devel qt5-qtscript-devel qt5-qttools-devel qt5-qtwebkit-devel qtsingleapplication-qt5-devel
dnf install -y dirac-devel

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
