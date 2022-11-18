#!/bin/bash
# ---------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------[ Configuração ]-----------------------------------------------------
repos=""                                                               # Inicia a variável
local="true"                                                           # Inicia a variável
devel="yes"                                                            # Instala coisas do pseudogrupo "devel"
jogos="yes"                                                            # Instala os jogos básicos
steam="yes"                                                            # Instala a steam
# ------------------------------------------------------[ Configuração ]-----------------------------------------------------
# ---------------------------------------------------------------------------------------------------------------------------
# Checa SELINUX =============================================================================================================
# if [ ! -n $(cat /etc/selinux/config | grep 'SELINUX=disabled') ] ; then
# 	echo "SELINUX Ativado!"
# 	echo "Deactive and reboot"
# 	echo "vim /etc/selinux/config"
# 
# 	exit 1
# fi

# retenta instalar se necessário
function recheck_retry {
  for file in ${1} ; do
    rpm -q $file > /dev/null
    rpmstat=$?
    if [[ "${rpmstat}" -eq "1" ]] ; then
      echo "Reinstalando: ${file}"
      dnf -y --nogpg --skip-broken --best --allowerasing install ${file}
    fi
  done
}

# Seta o timezone ===========================================================================================================
ln -sf ../usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

dnf config-manager --add-repo https://raw.githubusercontent.com/luisbrandao/tools/master/packages/techmago-settings/rhel9/workdir/etc/yum.repos.d/rocky9-techsytes.repo
dnf config-manager --add-repo https://negativo17.org/repos/epel-spotify.repo
dnf config-manager --add-repo https://negativo17.org/repos/epel-steam.repo
dnf config-manager --add-repo https://raw.githubusercontent.com/luisbrandao/tools/master/linuxInstall/rocky9/repos/brave.repo
dnf config-manager --add-repo https://raw.githubusercontent.com/luisbrandao/tools/master/linuxInstall/rocky9/repos/google-chrome.repo
dnf config-manager --add-repo https://raw.githubusercontent.com/luisbrandao/tools/master/linuxInstall/rocky9/repos/docker-ce.repo
dnf config-manager --add-repo https://raw.githubusercontent.com/luisbrandao/tools/master/linuxInstall/rocky9/repos/slack.repo

dnf install -y epel-release rpmfusion-free-release  rpmfusion-nonfree-release techmago-settings

# Configuração de repositórios ==============================================================================================
if ${local} ; then
  dnf config-manager --disable appstream baseos crb extras
  dnf config-manager --disable epel
  dnf config-manager --enable techsytes-9-appstream techsytes-9-baseos techsytes-9-extra techsytes-9-crb techsytes-9-epel
else
  dnf config-manager --enable epel
  dnf config-manager --enable appstream baseos crb extras
  dnf config-manager --disable techsytes-9-appstream techsytes-9-baseos techsytes-9-extra techsytes-9-crb techsytes-9-epel
fi

rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
echo 'repo_add_once="false"' > /etc/default/google-chrome

dnf clean all
dnf makecache

# Desabilita serviços desnecessários ========================================================================================
# systemctl disable wpa_supplicant.service # Notebook?
systemctl mask auditd.service
systemctl mask ModemManager.service
systemctl disable firewalld.service
systemctl disable cryptsetup.target
systemctl disable lvm2-monitor.service
systemctl mask kdump.service
# Da um boost no terminal ===================================================================================================
wget --no-check-certificate https://raw.githubusercontent.com/luisbrandao/tools/master/linuxInstall/techmago.sh
mv techmago.sh /etc/profile.d/

# Remove programas inuteis ==================================================================================================
dnf remove -y abrt* postfix crash empathy hypervkvpdy qemu-guest-agent spice-vdagent open-vm-tools gnome-boxes orca

# Instala pacotes ===========================================================================================================
# Internet
pacotes="" # Limpa a variável
pacotes="${pacotes} filezilla youtube-dl"
pacotes="${pacotes} firefox google-chrome-stable brave-browser"
pacotes="${pacotes} thunderbird wget curl"
pacotes="${pacotes} remmina remmina-plugins-exec remmina-plugins-rdp remmina-plugins-secret remmina-plugins-vnc remmina-plugins-www"
dnf -y --nogpg --skip-broken --best --allowerasing install ${pacotes} ; recheck_retry "${pacotes}"

# Multimidia
pacotes="" # Limpa a variável
pacotes="${pacotes} gstreamer1 gstreamer1-libav gstreamer1-plugins-bad-free gstreamer1-plugins-bad-freeworld gstreamer1-plugins-base gstreamer1-plugins-base-devel gstreamer1-plugins-good gstreamer1-plugins-good-gtk gstreamer1-plugins-ugly gstreamer1-plugins-ugly-free gstreamer1-vaapi"
pacotes="${pacotes} gnome-video-effects"
pacotes="${pacotes} mplayer smplayer mpv ffmpeg vlc"
pacotes="${pacotes} cheese brasero spotify-client"

dnf -y --nogpg --skip-broken --best --allowerasing install ${pacotes} ; recheck_retry "${pacotes}"

# Jogos
pacotes="" # Limpa a variável
#if [ "${jogos}" = yes ]; then
#  pacotes="${pacotes} aisleriot apx five-or-more gnome-klotski gnome-mahjongg vitetris gnome-sudoku gnome-mines gnome-tetravex gnome-nibbles gnome-robots #lightsoff"
#fi
if [ "${steam}" = yes ]; then
	pacotes="${pacotes} steam"
fi
dnf -y --nogpg --skip-broken --best --allowerasing install ${pacotes} ; recheck_retry "${pacotes}"

# Utilidades
pacotes="" # Limpa a variável
pacotes="${pacotes} zlib unrar bzip2 xz-lzma-compat xz p7zip p7zip-plugins lzip lrzip cabextract pigz pxz pbzip2"
pacotes="${pacotes} htop iotop iftop pydf bmon pydf inxi nload"
pacotes="${pacotes} fortune-mod gnome-disk-utility terminator bash-completion"
pacotes="${pacotes} net-tools mlocate psmisc hddtemp lm_sensors glances"
pacotes="${pacotes} ntfs-3g ntfsprogs fuse-exfat"
pacotes="${pacotes} flatpak stress"
pacotes="${pacotes} xprop libwnck3 xwininfo xdotool"

if [ "${devel}" = yes ]; then
	pacotes="${pacotes} sshfs byobu nfs-utils gparted"
fi

if [$(rpm -q gnome-session > /dev/null) $? -eq 0 ]; then
  pacotes="${pacotes} nautilus-dropbox nautilus-extensions evince-nautilus brasero-nautilus nextcloud-client-nautilus"
  pacotes="${pacotes} gnome-tweaks gnome-extensions-app chrome-gnome-shell gnome-system-monitor"
  pacotes="${pacotes} gnome-shell-extension-appindicator gnome-shell-extension-apps-menu gnome-shell-extension-background-logo gnome-shell-extension-common gnome-shell-extension-desktop-icons gnome-shell-extension-launch-new-instance gnome-shell-extension-panel-favorites gnome-shell-extension-places-menu gnome-shell-extension-top-icons gnome-shell-extension-user-theme gnome-shell-extension-vertical-workspaces gnome-shell-extension-window-list "
fi
dnf -y --nogpg --skip-broken --best --allowerasing install ${pacotes} ; recheck_retry "${pacotes}"


# Escritorio
pacotes="" # Limpa a variável                                                       # Inicia a variável
pacotes="${pacotes} pulsar meld kolourpaint geany terminator"
pacotes="${pacotes} libreoffice-langpack-pt-BR libreoffice-impress libreoffice-calc libreoffice-draw libreoffice-writer libreoffice-pdfimport"
dnf -y --nogpg --skip-broken --best --allowerasing install ${pacotes} ; recheck_retry "${pacotes}"

# Broken
# pacotes="${pacotes} texmaker texlive-scheme-small texlive-collection-langportuguese texlive-supertabular texlive-tocloft texlive-hyphenat texlive-moderncv"

# Desenvolvimento
if [ "${devel}" = yes ]; then
  pacotes=""
  pacotes="${pacotes} java-11-openjdk java-11-openjdk-devel maven"
  pacotes="${pacotes} java-1.8.0-openjdk java-1.8.0-openjdk-devel"
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
  pacotes="${pacotes} libXv-devel libass-devel libbs2b-devel libcaca-devel libcdio-paranoia-devel libdca-devel"
  pacotes="${pacotes} libdv-devel libmpg123-devel librtmp-devel libtheora-devel libvdpau-devel libvorbis-devel"
  pacotes="${pacotes} lirc-devel lzo-devel pulseaudio-libs-devel speex-devel x264-devel xvidcore-devel yasm dbus-glib-devel"
  pacotes="${pacotes} gtk3-devel libcurl-devel libnotify-devel nautilus-devel"
  pacotes="${pacotes} qt5-linguist qt5-qtbase-devel qt5-qtscript-devel qt5-qttools-devel qt5-qtwebkit-devel qtsingleapplication-qt5-devel"

  dnf -y --nogpg --skip-broken --best --allowerasing install ${pacotes} ; recheck_retry "${pacotes}"
fi

# Hack para deletar arquivos no atom ========================================================================================
# echo '#!/usr/bin/env bash
# # GVFS updated and dropped gvfs-trash to gio, but Atom didnt update.
# # https://github.com/atom/tree-view/issues/1237
# /usr/bin/gio trash "$@"
# ' | tee /usr/local/bin/gvfs-trash && chmod +x /usr/local/bin/gvfs-trash

# Instala um pacote de senhas do windows ====================================================================================
wget https://repo.techsytes.com/repository/static/fontesWindows.txz
tar -xJf fontesWindows.txz
chown -R root:root fontesWindows
mv fontesWindows /usr/share/fonts/
rm -f fontesWindows.txz

# Flathub ====================================================================================================================
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# chronyd  ===================================================================================================================
systemctl enable chronyd
wget https://raw.githubusercontent.com/luisbrandao/tools/master/linuxInstall/rocky9/confs/chrony.conf -O /etc/chrony.conf

# Java =======================================================================================================================
#wget --no-check-certificate http://legacy.techsytes.com/rpm/jre.rpm
#dnf -y install --nogpgcheck jre.rpm
#rm -f jre.rpm

#alternatives --install /usr/bin/java java /usr/java/latest/bin/java 20000
#alternatives --install /usr/bin/javaws javaws /usr/java/latest/bin/javaws 20000

#alternatives --config java
#alternatives --config javaws

# Atualiza o sistema =========================================================================================================
dnf update -y --nogpg --skip-broken --allowerasing --nobest


# Checa limits =============================================================================================================
if [ ! -n "$(cat /etc/security/limits.conf | grep 'hard nofile')" ] ; then
  echo "Aumentado ulimit"
  echo '* soft nofile 8192' >> /etc/security/limits.conf
  echo '* hard nofile 524288' >> /etc/security/limits.conf
else
  echo "ulimit já configurado"
fi
