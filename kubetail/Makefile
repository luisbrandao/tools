PREFIX ?= /usr
SYSTEMD_UNITDIR ?= $(PREFIX)/lib/systemd/system
SYSCONFDIR ?= /etc/sysconfig
VERSION=1.6.8
SRC_FILES=Makefile README.md kubetail kubetail.spec kubetail.bash

install:
	install -d $(DESTDIR)$(PREFIX)/sbin
	install -m 0755 kubetail $(DESTDIR)$(PREFIX)/sbin
	install -d $(DESTDIR)/etc/bash_completion.d
	install -m 0644 kubetail.bash $(DESTDIR)/etc/bash_completion.d

.PHONY: clean
clean:
	rm -rf kubetail-$(VERSION) kubetail-$(VERSION).tar.bz2

.PHONY: tarball
tarball: clean
	mkdir kubetail-$(VERSION)
	cp -a $(SRC_FILES) kubetail-$(VERSION)/
	tar -cjvf kubetail-$(VERSION).tar.bz2 kubetail-$(VERSION)/
	rm -rf kubetail-$(VERSION)

.PHONY: rpm
rpm: tarball
	rpmbuild -tb kubetail-$(VERSION).tar.bz2
	rm -rf kubetail-$(VERSION).tar.bz2

.PHONY: srpm
srpm: tarball
	rpmbuild -ts kubetail-$(VERSION).tar.bz2
