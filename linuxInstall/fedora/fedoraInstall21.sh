#!/bin/bash
# ---------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------[ Configuração ]-----------------------------------------------
temp=$(mktemp -t yumInstall.XXXX)                                       # Arquivo temporário
devel="yes"                                                              # Instala coisas do pseudogrupo "devel"
update_kernel="no"                                                     # Deixa o yum atualizar o kernel
mate="yes"                                                               # Instala coisas supondo que o ambiente gráfico é o mate
kde="no"                                                               # Kde vai ser instalado
jogos="no"                                                             # Instala os jogos básicos
steam="yes"                                                              # Instala a steam
repos=""                                                                # Inicia a variável
pacotes=""                                                              # Inicia a variável
# ------------------------------------------------------[ Configuração ]-----------------------------------------------
# ---------------------------------------------------------------------------------------------------------------------

# Desabilita Programas inuteis no boot =====================================================================================================
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
systemctl mask pcscd.service
systemctl mask ModemManager.service

# Preparação do yum ========================================================================================================================
if [ -f $(cat /etc/yum.conf | grep clean_requirements_on_remove) ] ; then
        echo "Configurando yum"
        echo "clean_requirements_on_remove=1" >> /etc/yum.conf
fi

#instalação dos repositorios: ==============================================================================================================
repos="${repos} http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-21.noarch.rpm"
repos="${repos} http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-21.noarch.rpm"
repos="${repos} http://linuxdownload.adobe.com/adobe-release/adobe-release-x86_64-1.0-1.noarch.rpm"
repos="${repos} http://mirror.yandex.ru/fedora/russianfedora/russianfedora/free/fedora/russianfedora-free-release-stable.noarch.rpm"
repos="${repos} http://mirror.yandex.ru/fedora/russianfedora/russianfedora/nonfree/fedora/russianfedora-nonfree-release-stable.noarch.rpm"

yum -y localinstall --nogpgcheck ${repos}

wget http://negativo17.org/repos/fedora-negativo17.repo
mv fedora-negativo17.repo /etc/yum.repos.d/

# Remove porcarias: ========================================================================================================================
yum -y remove abrt irqbalance mcelog open-vm-tools sendmail spice-vdagent iscsi-initiator-utils libvirt-client tigervl vinagre selinux-policy audit httpd tigervnc firstboot hexchat claws-mail

# Reinstala o que nao devia ter saido
yum -y install dracut binutils dmidecode isomd5sum nfs-utils

# Fazer o cache do yum =====================================================================================================================
yum -y install yum-plugin-fastestmirror
yum clean all
yum makecache

# Instala o necessário:
# Atualiza =================================================================================================================================
if [ "${update_kernel}" = yes ]; then
        yum -y update
else
        yum -y update -x kernel*
fi

# Utilidades ===============================================================================================================================
pacotes="${pacotes} zlib p7zip unrar bzip2 freetype-freeworld xz-lzma-compat xz"
pacotes="${pacotes} htop iotop iftop pydf bmon pydf inxi nload"
pacotes="${pacotes} ntpdate fortune-mod"

if [ "${kde}" = yes ]; then
        pacotes="${pacotes} kde-plasma-akonadi-calendars kde-plasma-translatoid kde-plasma-ktorrent kde-plasma-yawp"
        pacotes="${pacotes} kde-plasma-alsa-volume kde-plasma-daisy kde-plasma-yawp kde-plasma-nm kde-plasma-activitymanager"
        pacotes="${pacotes} kde-plasma-folderview kde-plasma-ktorrent kde-plasma-nm kde-plasma-publictransport"
        pacotes="${pacotes} kde-plasma-qstardict kde-plasma-quickaccess kmymoney"
        pacotes="${pacotes} gnome-system-monitor"
fi
if [ "${devel}" = yes ]; then
        pacotes="${pacotes} unison sshfs byobu nfs-utils "
fi
if [ "${mate}" = yes ]; then
        pacotes="${pacotes} mate-applets mate-screensaver mate-themes mate-menu-editor"
fi
if [$(rpm -q gnome-session > /dev/null) $? -eq 0 ]; then
        pacotes="${pacotes} gnome-tweak-tool"
fi

# Internet =================================================================================================================================
pacotes="${pacotes} transmission filezilla"
pacotes="${pacotes} flash-plugin firefox"
pacotes="${pacotes} mirall"
pacotes="${pacotes} thunderbird thunderbird-lightning mozilla-firetray-thunderbird"
if [ "${devel}" = yes ]; then
        pacotes="${pacotes} nmap-frontend wireshark-gnome"
fi

# Multimidia ===============================================================================================================================
pacotes="${pacotes} smplayer"
pacotes="${pacotes} gstreamer-plugins-bad gstreamer-plugins-ugly gstreamer-ffmpeg"
pacotes="${pacotes} gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly gstreamer1-libav"
pacotes="${pacotes} rhythmbox pitivi cheese"
pacotes="${pacotes} brasero"
if [ "${mate}" = yes ]; then
        pacotes="${pacotes} mate-mplayer mate-mplayer-caja"
fi

# Jogos ====================================================================================================================================
if [ "${jogos}" = yes ]; then
        pacotes="${pacotes} five-or-more four-in-a-row gnome-klotski gnome-mahjongg gnome-nibbles gnome-robots aisleriot"
        pacotes="${pacotes} gnome-tetravex lightsoff quadrapassel tali  gnome-mines gnome-sudoku iagno swell-foop"
fi
if [ "${steam}" = yes ]; then
        pacotes="${pacotes} steam"
fi

# Escritorio ===============================================================================================================================
pacotes="${pacotes} calibre"
pacotes="${pacotes} gimp"
pacotes="${pacotes} texmaker texlive-collection-langportuguese texlive-supertabular texlive-tocloft texlive-hyphenat texlive-moderncv"
pacotes="${pacotes} geany-themes geany geany-plugins-addons geany-plugins-autoclose geany-plugins-codenav geany-plugins-commander geany-plugins-debugger geany-plugins-defineformat geany-plugins-geanydoc geany-plugins-devhelp geany-plugins-geanyextrasel geany-plugins-geanygendoc geany-plugins-geanyinsertnum geany-plugins-geanylatex geany-plugins-geanylipsum geany-plugins-geanylua geany-plugins-geanymacro geany-plugins-geanyminiscript geany-plugins-geanynumberedbookmarks geany-plugins-geanypg geany-plugins-geanyprj geany-plugins-geanypy geany-plugins-geanysendmail geany-plugins-geanyvc geany-plugins-geniuspaste geany-plugins-gproject geany-plugins-markdown geany-plugins-multiterm geany-plugins-pairtaghighlighter geany-plugins-pohelper geany-plugins-pretty-printer geany-plugins-scope geany-plugins-shiftcolumn geany-plugins-spellcheck geany-plugins-tableconvert geany-plugins-treebrowser geany-plugins-updatechecker geany-plugins-webhelper geany-plugins-xmlsnippets"
pacotes="${pacotes} libreoffice-langpack-pt-BR"
if [ "${mate}" = yes ]; then
        pacotes="${pacotes} mate-document-viewer"
fi

# Devel e bibliotecas ======================================================================================================================
pacotes="${pacotes} mesa-libGLU.i686 mesa-libGLU.x86_64"
pacotes="${pacotes} libpng libpng.i686 cups-libs cups-libs.i686 nss-mdns nss-mdns.i686 lcms-libs lcms-libs.i686 libmpg123.i686 lcms2.i686 lcms2"
if [ "${devel}" = yes ]; then
        pacotes="${pacotes} gcc gcc-c++ fpc curl make patch glib2-devel glib-devel"
        pacotes="${pacotes} kernel-devel kernel-tools-libs-devel kernel-headers"
        pacotes="${pacotes} sqliteman sqlite sqlite-devel sqlite2-devel"
        pacotes="${pacotes} opencv-devel-docs opencv opencv-devel chrpath libtiff-devel OpenEXR-devel numpy python-sphinx"
        pacotes="${pacotes} v8-devel zlib-devel nodejs"
        pacotes="${pacotes} cmake-gui openssl-libs git-core readline readline-devel zlib-devel libyaml-devel"
        pacotes="${pacotes} libffi-devel libxslt-devel openssl openssl-devel"
        pacotes="${pacotes} bison-devel bison-devel.i686 flex-devel flex-devel.i686 glibc-devel glibc-devel.i686"
        pacotes="${pacotes} python-pep8 pyflakes"
fi

yum install ${pacotes} --skip-broken -y

# Instalar crossover =======================================================================================================================
wget --no-check-certificate http://techmago.sytes.net/rpm/crossover-13.1.2-1.rpm
wget --no-check-certificate http://techmago.sytes.net/rpm/winewrapper.exe.so
yum -y localinstall --nogpgcheck crossover-13.1.2-1.rpm
mv -f winewrapper.exe.so /opt/cxoffice/lib/wine/winewrapper.exe.so
chown root.root /opt/cxoffice/lib/wine/winewrapper.exe.so
chmod 755 /opt/cxoffice/lib/wine/winewrapper.exe.so
rm -f crossover-13.1.2-1.rpm

# Instala o fluendo Codecs =================================================================================================================
wget --no-check-certificate http://techmago.sytes.net/rpm/fluendo-codecs-mp3-17-3.i386.rpm
yum -y localinstall --nogpgcheck fluendo-codecs-mp3-17-3.i386.rpm
rm -f fluendo-codecs-mp3-17-3.i386.rpm

# Melhora as fontes ========================================================================================================================
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

# Virtual Box ==============================================================================================================================
if [ "${devel}" = yes ]; then
        wget http://download.virtualbox.org/virtualbox/rpm/fedora/virtualbox.repo
        mv virtualbox.repo /etc/yum.repos.d/
        yum -y install binutils gcc make patch libgomp glibc-headers glibc-devel kernel-headers kernel-devel dkms VirtualBox-4.3
        service vboxdrv setup
fi

# Da um boost no terminal ==================================================================================================================
wget --no-check-certificate http://techmago.sytes.net/rpm/techmago.sh
mv techmago.sh /etc/profile.d/

# Instala o pacote de linguas ==============================================================================================================
if [ "${kde}" = yes ]; then
        yum -y install kde-i18n-Brazil kde-l10n-Brazil
fi

# Instalar java ============================================================================================================================
wget --no-check-certificate http://techmago.sytes.net/rpm/jre.rpm
yum -y localinstall --nogpgcheck jre.rpm
rm -f jre.rpm

alternatives --install /usr/bin/java java /usr/java/latest/bin/java 20000
alternatives --install /usr/bin/javaws javaws /usr/java/latest/bin/javaws 20000
alternatives --install /usr/lib64/mozilla/plugins/libjavaplugin.so libjavaplugin.so.x86_64 /usr/java/latest/lib/amd64/libnpjp2.so 20000

alternatives --config java
alternatives --config javaws
alternatives --config libjavaplugin.so.x86_64

# ACABOU ===================================================================================================================================
echo "All done. Now reboot"
echo "reboot"

echo "rhythmbox fix:"
echo "wget https://github.com/mendhak/rhythmbox-tray-icon/raw/master/rhythmbox-tray-icon.zip"
echo "unzip -u rhythmbox-tray-icon.zip -d ~/.local/share/rhythmbox/plugins"
