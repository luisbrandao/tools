PREFIX ?= /usr
SYSTEMD_UNITDIR ?= $(PREFIX)/lib/systemd/system
SYSCONFDIR ?= /etc/sysconfig
VERSION=1.0.1
SRC_FILES=Makefile README.md list list.spec

install:
	install -d $(DESTDIR)$(PREFIX)/sbin
	install -m 0755 list $(DESTDIR)$(PREFIX)/sbin

.PHONY: clean
clean:
	rm -rf list-$(VERSION) list-$(VERSION).tar.bz2

.PHONY: tarball
tarball: clean
	mkdir list-$(VERSION)
	cp -a $(SRC_FILES) list-$(VERSION)/
	tar -cjvf list-$(VERSION).tar.bz2 list-$(VERSION)/
	rm -rf list-$(VERSION)

.PHONY: rpm
rpm: tarball
	rpmbuild -tb list-$(VERSION).tar.bz2
	rm -rf list-$(VERSION).tar.bz2

.PHONY: srpm
srpm: tarball
	rpmbuild -ts list-$(VERSION).tar.bz2
