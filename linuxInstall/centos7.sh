if [ -f $(cat /etc/yum.conf | grep clean_requirements_on_remove) ] ; then
        echo "Configurando yum"
        echo "clean_requirements_on_remove=1" >> /etc/yum.conf
fi

repos=""
repos="${repos} https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"
repos="${repos} http://rpms.remirepo.net/enterprise/remi-release-7.rpm"
repos="${repos} http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm"

yum -y install --nogpgcheck ${repos} yum-utils

echo '[google-chrome]
name=google-chrome
baseurl=http://dl.google.com/linux/chrome/rpm/stable/$basearch
enabled=1
gpgcheck=1
gpgkey=https://dl-ssl.google.com/linux/linux_signing_key.pub' > /etc/yum.repos.d/google-chrome.repo

systemctl stop auditd.service
systemctl disable auditd.service
systemctl mask auditd.service
systemctl stop ModemManager.service
systemctl disable ModemManager.service
systemctl mask ModemManager.service

yum remove -y abrt* postfix crash empathy hypervkvpdy qemu-guest-agent spice-vdagent open-vm-tools

yum install -y system-config-keyboard byobu vim wget flash-plugin google-chrome-stable brasero gstreamer-plugins-bad gstreamer-plugins-ugly gstreamer1-plugins-ugly gstreamer1-libav gstreamer-ffmpeg ffmpeg HandBrake-{gui,cli} libdvdcss gstreamer{,1}-plugins-ugly gstreamer-plugins-bad-nonfree gstreamer1-plugins-bad-freeworld gnome-tweak-tool gnome-terminal-nautilus gnome-games gnome-games-extra gnome-icon-theme gnome-icon-theme-extras gnome-mplayer gnome-online-accounts  gnome-themes-standard gnome-weather gnome-bluetooth gnome-calculator gnome-disk-utility gnome-mplayer gnome-mplayer-nautilus gnome-system-monitor gparted gtk2-immodules im-chooser htop iotop hddtemp lm_sensors
yum install -y mesa-dri-drivers.i686 mesa-dri-drivers.x86_64 mesa-filesystem.i686 mesa-filesystem.x86_64 mesa-libEGL.i686 mesa-libEGL.x86_64 mesa-libEGL-devel.i686 mesa-libEGL-devel.x86_64 mesa-libGL.i686 mesa-libGL.x86_64 mesa-libGL-devel.i686 mesa-libGL-devel.x86_64 mesa-libGLES.i686 mesa-libGLES.x86_64 mesa-libGLES-devel.i686 mesa-libGLES-devel.x86_64 mesa-libGLU.i686 mesa-libGLU.x86_64 mesa-libGLU-devel.i686 mesa-libGLU-devel.x86_64 mesa-libGLw-devel.i686 mesa-libGLw-devel.x86_64 mesa-libOSMesa.i686 mesa-libOSMesa.x86_64 mesa-libOSMesa-devel.i686 mesa-libOSMesa-devel.x86_64 mesa-libgbm.i686 mesa-libgbm.x86_64 mesa-libgbm-devel.i686 mesa-libgbm-devel.x86_64 mesa-libglapi.i686 mesa-libglapi.x86_64mesa-libGLw.x86_64 mesa-libGLw.i686

# Da um boost no terminal ==================================================================================================================
wget --no-check-certificate http://techmago.sytes.net/rpm/techmago.sh
mv techmago.sh /etc/profile.d/

#wget --no-check-certificate http://techmago.sytes.net/rpm/fontesWindows.tar.bz2
#tar -xjf fontesWindows.tar.bz2
#mv fontesWindows /usr/share/fonts/
#rm -f fontesWindows.tar.bz2

#wget --no-check-certificate http://techmago.sytes.net/rpm/fluendo-codecs-mp3-17-3.i386.rpm
#yum -y install --nogpgcheck fluendo-codecs-mp3-17-3.i386.rpm
#rm -f fluendo-codecs-mp3-17-3.i386.rpm

#wget --no-check-certificate http://techmago.sytes.net/rpm/jre.rpm
#yum -y install --nogpgcheck jre.rpm
#rm -f jre.rpm

#alternatives --install /usr/bin/java java /usr/java/latest/bin/java 20000
#alternatives --install /usr/bin/javaws javaws /usr/java/latest/bin/javaws 20000

#alternatives --config java
#alternatives --config javaws

yum update -y --skip-broken

yum-config-manager --add-repo=http://negativo17.org/repos/epel-negativo17.repo

yum remove -y mencoder mplayer gstreamer-plugins-ugly a52dec

yum install -y libdc1394-devel libmodplug-devel libv4l-devel libva-devel openal-soft-devel openjpeg-devel opus-devel schroedinger-devel soxr-devel texinfo x265-devel ilbc-devel SDL-devel a52dec-devel aalib-devel bzip2-devel alsa-lib-devel enca-devel faad2-devel ffmpeg-devel fribidi-devel giflib-devel gsm-devel gtk2-devel ladspa-devel lame-devel libXinerama-devel libXScrnSaver-devel libXv-devel libXvMC-devel libass-devel libbluray-devel libbs2b-devel libcaca-devel libcdio-paranoia-devel libdca-devel libdv-devel libdvdnav-devel libmpeg2-devel libmpg123-devel librtmp-devel libtheora-devel libvdpau-devel libvorbis-devel lirc-devel lzo-devel pulseaudio-libs-devel speex-devel twolame-devel x264-devel xvidcore-devel yasm dbus-glib-devel gtk3-devel libcurl-devel libgda-devel libgpod-devel libmusicbrainz3-devel libnotify-devel nautilus-devel nemo-devel qt5-linguist qt5-qtbase-devel qt5-qtscript-devel qt5-qttools-devel qt5-qtwebkit-devel qtsingleapplication-qt5-devel dirac-devel texi2html

# Atom =====================================================================================================================================
wget https://atom.io/download/rpm -O atom.rpm
yum -y install atom.rpm
rm -f atom.rpm
