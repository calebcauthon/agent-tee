.PHONY: install uninstall test lint

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

install:
	install -d $(BINDIR)
	install -m 755 t $(BINDIR)/t
	@if [ ! -f $(HOME)/.agent-tee/config ]; then \
		mkdir -p $(HOME)/.agent-tee && \
		echo "CLIPBOARD_TEMPLATE='---'" > $(HOME)/.agent-tee/config && \
		echo "Ran: {{command}}" >> $(HOME)/.agent-tee/config && \
		echo "Duration: {{duration}}ms" >> $(HOME)/.agent-tee/config && \
		echo "Output:" >> $(HOME)/.agent-tee/config && \
		echo "{{output}}" >> $(HOME)/.agent-tee/config && \
		echo "---'" >> $(HOME)/.agent-tee/config && \
		echo "Created default config at $(HOME)/.agent-tee/config"; \
	fi

uninstall:
	rm -f $(BINDIR)/t
	rm -f $(HOME)/.agent-tee/config

test:
	./t --version
	./t --help

lint:
	@which shellcheck >/dev/null 2>&1 || { echo "shellcheck not installed"; exit 1; }
	shellcheck t
