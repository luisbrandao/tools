PREFIX ?= /usr
SYSTEMD_UNITDIR ?= $(PREFIX)/lib/systemd/system
VERSION=1.0.0
SRC_FILES=Makefile README.md tech-fancontrol tech-fancontrol.spec tech-fancontrol.service tech-fancontrol.sysconfig

install:
	install -d $(DESTDIR)$(PREFIX)/sbin
	install -m 0755 tech-fancontrol $(DESTDIR)$(PREFIX)/sbin
	install -d $(DESTDIR)$(SYSTEMD_UNITDIR)
	install -m 0644 tech-fancontrol.service $(DESTDIR)$(SYSTEMD_UNITDIR)
	install -d $(DESTDIR)/etc/sysconfig
	install -m 0644 tech-fancontrol.sysconfig $(DESTDIR)/etc/sysconfig/tech-fancontrol

.PHONY: clean
clean:
	rm -rf tech-fancontrol-$(VERSION) tech-fancontrol-$(VERSION).tar.bz2

.PHONY: tarball
tarball: clean
	mkdir tech-fancontrol-$(VERSION)
	cp -a $(SRC_FILES) tech-fancontrol-$(VERSION)/
	tar -cjvf tech-fancontrol-$(VERSION).tar.bz2 tech-fancontrol-$(VERSION)/
	rm -rf tech-fancontrol-$(VERSION)

.PHONY: rpm
rpm: tarball
	rpmbuild -tb tech-fancontrol-$(VERSION).tar.bz2
	rm -rf tech-fancontrol-$(VERSION).tar.bz2

.PHONY: srpm
srpm: tarball
	rpmbuild -ts tech-fancontrol-$(VERSION).tar.bz2
