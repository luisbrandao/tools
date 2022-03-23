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
repos="${repos} http://linuxdownload.adobe.com/adobe-release/adobe-release-x86_64-1.0-1.noarch.rpm"

dnf -y install --nogpgcheck ${repos} dnf-utils

if ${local} ; then
  dnf config-manager --disable appstream baseos powertools extras epel
	dnf config-manager --add-repo https://legacy.techsytes.com/rpm/centos8-techsytes.repo
else
	dnf config-manager --disable extras
fi

dnf config-manager --add-repo https://dl.google.com/linux/chrome/rpm/stable/x86_64/
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
systemctl disable cryptsetup.target

# Da um boost no terminal ===================================================================================================
wget --no-check-certificate http://legacy.techsytes.com/rpm/techmago.sh
mv techmago.sh /etc/profile.d/

# Remove programas inuteis ==================================================================================================
dnf remove -y abrt* postfix crash empathy hypervkvpdy qemu-guest-agent spice-vdagent open-vm-tools

# Executa a primeira atualização de sistema =================================================================================
dnf update -y --skip-broken

# Instala pacotes ===========================================================================================================
# Internet
pacotes="" # Limpa a variável
pacotes="${pacotes} transmission filezilla youtube-dl"
pacotes="${pacotes} flash-plugin firefox google-chrome-stable brave-browser"
pacotes="${pacotes} thunderbird"
pacotes="${pacotes} remmina remmina-plugins-nx remmina-gnome-session remmina-plugins-rdp remmina-plugins-vnc remmina-plugins-www remmina-plugins-spice remmina-plugins-xdmcp remmina-plugins-kwallet remmina-plugins-st remmina-plugins-secret remmina-plugins-exec"
dnf -y --skip-broken --best --allowerasing install ${pacotes}

# Multimidia
pacotes="" # Limpa a variável
pacotes="${pacotes} gstreamer1-libav gstreamer1 gstreamer-plugin-crystalhd gstreamer1-plugins-good PackageKit-gstreamer-plugin gstreamer1-plugins-bad-free gstreamer1-plugins-base gstreamer1-plugins-ugly gstreamer1-plugins-ugly-free gstreamer1-plugins-bad-freeworld gstreamer1-plugins-bad-nonfree gnome-video-effects"
pacotes="${pacotes} mplayer smplayer rhythmbox cheese brasero spotify-client vlc"
pacotes="${pacotes} ffmpeg HandBrake-{gui,cli}"

dnf -y --skip-broken --best --allowerasing install ${pacotes}

# Jogos
pacotes="" # Limpa a variável
if [ "${jogos}" = yes ]; then
  pacotes="${pacotes} aisleriot apx five-or-more gnome-klotski gnome-mahjongg vitetris gnome-sudoku gnome-mines gnome-tetravex gnome-nibbles gnome-robots lightsoff"
fi
if [ "${steam}" = yes ]; then
	pacotes="${pacotes} steam"
fi
dnf -y --skip-broken --best --allowerasing install ${pacotes}

# Utilidades
pacotes="" # Limpa a variável
pacotes="${pacotes} zlib unrar bzip2 xz-lzma-compat xz p7zip p7zip-plugins lzip lrzip cabextract pigz pxz pbzip2"
pacotes="${pacotes} htop iotop iftop pydf bmon pydf inxi nload"
pacotes="${pacotes} ntpdate fortune-mod gnome-disk-utility terminator bash-completion"
pacotes="${pacotes} net-tools mlocate psmisc hddtemp lm_sensors glances"
pacotes="${pacotes} ntfs-3g ntfsprogs fuse-exfat exfat-utils"
pacotes="${pacotes} wine winetricks"

if [ "${devel}" = yes ]; then
	pacotes="${pacotes} unison sshfs byobu nfs-utils gparted"
fi

if [$(rpm -q gnome-session > /dev/null) $? -eq 0 ]; then
  	pacotes="${pacotes} nautilus-dropbox nautilus-extensions evince-nautilus brasero-nautilus nextcloud-client-nautilus"
  	pacotes="${pacotes} gnome-tweak-tool chrome-gnome-shell gnome-system-monitor"
    pacotes="${pacotes} gnome-shell-extension-apps-menu gnome-shell-extension-top-icons gnome-shell-extension-places-menu gnome-shell-extension-window-list gnome-shell-extension-desktop-icons gnome-shell-extension-no-hot-corner gnome-shell-extension-launch-new-instance"
fi
dnf -y --skip-broken --best --allowerasing install ${pacotes}


# Escritorio
pacotes="" # Limpa a variável                                                       # Inicia a variável
pacotes="${pacotes} meld gimp kolourpaint geany terminator"
pacotes="${pacotes} libreoffice-langpack-pt-BR libreoffice-impress libreoffice-calc libreoffice-draw libreoffice-writer libreoffice-pdfimport"
pacotes="${pacotes} ubuntu-title-fonts freetype-freeworld"
dnf -y --skip-broken --best --allowerasing install ${pacotes}

# Broken
# pacotes="${pacotes} texmaker texlive-scheme-small texlive-collection-langportuguese texlive-supertabular texlive-tocloft texlive-hyphenat texlive-moderncv"

# Desenvolvimento
pacotes=""
pacotes="${pacotes} gtk2-immodules mono-core mono-devel"
pacotes="${pacotes} acpid elfutils-libelf-devel  kernel-tools-libs  kernel-tools kernel-modules-extra kernel-modules kernel-devel linux-firmware"
pacotes="${pacotes} mesa-dri-drivers.i686 mesa-dri-drivers.x86_64 mesa-filesystem.i686 mesa-filesystem.x86_64 mesa-libEGL.i686 mesa-libEGL.x86_64"
pacotes="${pacotes} mesa-libEGL-devel.i686 mesa-libEGL-devel.x86_64 mesa-libGL.i686 mesa-libGL.x86_64 mesa-libGL-devel.i686 mesa-libGL-devel.x86_64"
pacotes="${pacotes} mesa-libGLU.i686 mesa-libGLU.x86_64 mesa-libGLU-devel.i686"
pacotes="${pacotes} mesa-libGLU-devel.x86_64 mesa-libGLw-devel.i686 mesa-libGLw-devel.x86_64 mesa-libOSMesa.i686 mesa-libOSMesa.x86_64"
pacotes="${pacotes} mesa-libOSMesa-devel.i686 mesa-libgbm.i686 mesa-libgbm.x86_64 mesa-libgbm-devel.i686"
pacotes="${pacotes} mesa-libgbm-devel.x86_64 mesa-libglapi.i686 mesa-libglapi.x86_64 mesa-libGLw.x86_64 mesa-libGLw.i686"
pacotes="${pacotes} libmodplug-devel libv4l-devel libva-devel openal-soft-devel opus-devel schroedinger-devel"
pacotes="${pacotes} soxr-devel texinfo x265-devel ilbc-devel SDL-devel aalib-devel bzip2-devel alsa-lib-devel enca-devel faad2-devel"
pacotes="${pacotes} ffmpeg-devel fribidi-devel giflib-devel gsm-devel gtk2-devel ladspa-devel lame-devel libXinerama-devel libXScrnSaver-devel"
pacotes="${pacotes} libXv-devel libXvMC-devel libass-devel libbs2b-devel libcaca-devel libcdio-paranoia-devel libdca-devel"
pacotes="${pacotes} libdv-devel libmpeg2-devel libmpg123-devel librtmp-devel libtheora-devel libvdpau-devel libvorbis-devel"
pacotes="${pacotes} lirc-devel lzo-devel pulseaudio-libs-devel speex-devel x264-devel xvidcore-devel yasm dbus-glib-devel"
pacotes="${pacotes} gtk3-devel libcurl-devel libgpod-devel libnotify-devel nautilus-devel"
pacotes="${pacotes} qt5-linguist qt5-qtbase-devel qt5-qtscript-devel qt5-qttools-devel qt5-qtwebkit-devel qtsingleapplication-qt5-devel"
pacotes="${pacotes} dirac-devel"

dnf -y --skip-broken --best --allowerasing install ${pacotes}

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
wget --no-check-certificate http://legacy.techsytes.com/rpm/fontesWindows.txz
tar -xJf fontesWindows.txz
chown -R root:root fontesWindows
mv fontesWindows /usr/share/fonts/
rm -f fontesWindows.txz

# Flathub ====================================================================================================================
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Java =======================================================================================================================
wget --no-check-certificate http://legacy.techsytes.com/rpm/jre.rpm
dnf -y install --nogpgcheck jre.rpm
rm -f jre.rpm

#alternatives --install /usr/bin/java java /usr/java/latest/bin/java 20000
#alternatives --install /usr/bin/javaws javaws /usr/java/latest/bin/javaws 20000

#alternatives --config java
#alternatives --config javaws
