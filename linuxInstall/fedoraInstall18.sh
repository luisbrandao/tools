#!/bin/bash
# ---------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------[ Configuração ]-----------------------------------------------
temp=$(mktemp -t yumInstall.XXXX)    # Arquivo temporário

# ------------------------------------------------------[ Configuração ]-----------------------------------------------
# ---------------------------------------------------------------------------------------------------------------------

# Desabilita Programas inuteis no boot
systemctl mask fedora-configure.service
systemctl mask fedora-import-state.service
systemctl mask fedora-loadmodules.service
systemctl mask fedora-readonly.service
systemctl mask fedora-storage-init-late.service
systemctl mask fedora-storage-init.service
systemctl mask dm-event.service
systemctl mask dm-event.socket
systemctl mask mdmonitor.service
systemctl mask mdmonitor-takeover.service
systemctl mask firewalld.service

# Preparação do yum
if [ -f $(cat /etc/yum.conf | grep clean_requirements_on_remove) ] ; then
	echo "Configurando yum"
	echo "clean_requirements_on_remove=1" >> /etc/yum.conf
fi

#instalação dos repositorios:
yum -y localinstall --nogpgcheck http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-18.noarch.rpm
yum -y localinstall --nogpgcheck http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-18.noarch.rpm
yum -y localinstall --nogpgcheck http://linuxdownload.adobe.com/adobe-release/adobe-release-x86_64-1.0-1.noarch.rpm
yum -y localinstall --nogpgcheck http://mirror.yandex.ru/fedora/russianfedora/russianfedora/free/fedora/releases/18/Everything/i386/os/russianfedora-free-release-18-2.R.noarch.rpm
yum -y localinstall --nogpgcheck https://dl.dropbox.com/u/105479527/Mate-Desktop/fedora-release-extra-18/mate-desktop-fedora/noarch/mate-desktop-extra-release-18-1.fc18.noarch.rpm
yum -y localinstall --nogpgcheck https://dl.dropbox.com/u/105479527/Mate-Desktop/fedora-release-extra-20/mate-desktop-fedora/noarch/mate-desktop-extra-release-20-1.fc20.noarch.rpm

# Instala fontes da extras:
yum -y localinstall --nogpgcheck http://sabugo.net76.net/fedora/msttcore-fonts-2.0-5.noarch.rpm

# Remove porcarias:
yum -y remove abrt irqbalance mcelog sendmail spice-vdagent trousers iscsi-initiator-utils libvirt-client rpcbind tigervl vinagre selinux-policy yum-presto audit httpd tigervnc firstboot

# Fazer o cache do yum
yum -y yum-plugin-fastestmirror
yum clean all
yum makecache

# Instala o necessário:
# Utilidades
yum install -y zlib p7zip unrar bzip2 freetype-freeworld unison sshfs byobu
yum install -y mesa-libGLU-9.0.0-1.fc18.i686
yum install -y mate-applets mate-bluetooth mate-screensaver mate-themes mate-menu-editor
yum install -y htop iotop iftop
yum install -y mate-sensors-applet
# yum install -y file-roller

# Internet
yum install -y transmission
yum install -y flash-plugin
yum install -y nmap-frontend wireshark-gnome

# Multimidia
yum install -y mplayer2 smplayer mate-mplayer
yum install -y gstreamer-plugins-bad gstreamer-plugins-ugly gstreamer-ffmpeg
yum install -y gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly gstreamer1-libav
yum install -y rhythmbox pitivi cheese

# Escritorio
yum install -y calibre
yum install -y gimp
yum install -y texmaker texlive-collection-langportuguese texlive-supertabular texlive-tocloft texlive-hyphenat texlive-moderncv
yum install -y geany-themes
yum install -y mate-document-viewer

# Devel
yum install -y gcc gcc-c++ fpc curl make patch
yum install -y kernel-devel kernel-tools-libs-devel kernel-headers

yum install -y mysql-devel mysql-workbench mysql-bench
yum install -y sqliteman sqlite sqlite-devel sqlite2-devel
yum install -y opencv-devel-docs opencv opencv-devel chrpath libtiff-devel OpenEXR-devel numpy python-sphinx
yum install -y v8-devel zlib-devel nodejs
yum install -y cmake-gui openssl-libs git-core readline readline-devel zlib-devel libyaml-devel
yum install -y libffi-devel libxslt-devel openssl openssl-devel
yum install -y libpng.i686 cups-libs.i686

# Outros
yum install -y groupinstall "Nonfree packages for Mate Desktop (rpmfusion needed)"

# Instalar java
wget --no-check-certificate http://techmago.sytes.net/rpm/jre-7u25-linux-x64.rpm
yum -y localinstall --nogpgcheck jre-7u25-linux-x64.rpm
rm -f jre-7u25-linux-x64.rpm

alternatives --install /usr/bin/java java /usr/java/latest/bin/java 20000
alternatives --install /usr/bin/javaws javaws /usr/java/latest/bin/javaws 20000
alternatives --install /usr/lib64/mozilla/plugins/libjavaplugin.so libjavaplugin.so.x86_64 /usr/java/latest/lib/amd64/libnpjp2.so 20000

# Instalar crossover
wget --no-check-certificate http://techmago.sytes.net/rpm/crossover-11.3.1-1.i386.rpm
yum -y localinstall --nogpgcheck crossover-11.3.1-1.i386.rpm
rm -f crossover-11.3.1-1.i386.rpm

# Instala o fluendo Codecs
wget --no-check-certificate http://techmago.sytes.net/rpm/fluendo-codecs-mp3-17-3.i386.rpm
yum -y localinstall --nogpgcheck fluendo-codecs-mp3-17-3.i386.rpm
rm -f fluendo-codecs-mp3-17-3.i386.rpm

# Atualiza:
yum -y update

# Melhora as fontes
echo '<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="font">
    <edit name="hintstyle" mode="assign">
      <const>hintslight</const>
    </edit>
    <edit name="rgba" mode="assign">
      <const>rgb</const>
    </edit>
    <edit name="lcdfilter" mode="assign">
      <const>lcddefault</const>
    </edit>
  </match>
</fontconfig>' > /etc/fonts/local.conf

# Instala um pacote de senhas do windows ====================================================================================
wget --no-check-certificate http://techmago.sytes.net/rpm/fontesWindows.txz
tar -xJf fontesWindows.txz
mv fontesWindows /usr/share/fonts/
rm -f fontesWindows.txz

# ACABOU
echo "All done. Now reboot"
echo "reboot"
