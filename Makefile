.PHONY: install uninstall test lint

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

install:
	install -d $(BINDIR)
	install -m 755 t $(BINDIR)/t

uninstall:
	rm -f $(BINDIR)/t

test:
	./t --version
	./t --help

lint:
	@which shellcheck >/dev/null 2>&1 || { echo "shellcheck not installed"; exit 1; }
	shellcheck t
