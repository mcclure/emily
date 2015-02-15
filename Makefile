VERSION = 0.2b
PREFIX := /usr/local
bindir = $(PREFIX)/bin
mandir = $(PREFIX)/share/man/man1

# Replace "native" with "byte" for debug build
BUILDTYPE=native

.PHONY: all
all: install/bin/emily install/man/emily.1 install/lib/emily/$(VERSION)

# Move final executable in place.
install/bin/emily: _build/src/main.$(BUILDTYPE)
	mkdir -p $(@D)
	cp $< $@

# Move manpage in place
install/man/emily.1: resources/emily.1
	mkdir -p $(@D)
	cp $< $@

# Move packages in place
install/lib/emily/$(VERSION):
	mkdir -p $@

# Use ocamlbuild to construct executable. Always run, ocamlbuild figures out freshness itself.
.PHONY: _build/src/main.$(BUILDTYPE)
_build/src/main.$(BUILDTYPE): _tags
	ocamlbuild -no-links -use-ocamlfind src/main.$(BUILDTYPE)

# Non-essential: This prevents ocamlbuild from emitting unhelpful "hints"
_tags:
	touch $@

# Non-essential: Shortcuts for regression test script
.PHONY: test
test:
	./develop/regression.py -a
.PHONY: test-all
test-all:
	./develop/regression.py -A

# Non-essential: Generate man page.
.PHONY: manpage
manpage:
	ronn -r --pipe --manual="Emily programming language" \
	               --date="2015-01-15" \
	               --organization="http://emilylang.org" \
	               doc/manpage.1.md > install/man/emily.1

# Install target
.PHONY: install install-makedirs
install-makedirs:
	install -d $(DESTDIR)$(bindir)
	install -d $(DESTDIR)$(mandir)

install: install-makedirs all
	install install/bin/emily   $(DESTDIR)$(bindir)
	install install/man/emily.1 $(DESTDIR)$(mandir)

# Clean target
.PHONY: clean
clean:
	ocamlbuild -clean
	rm -f _tags install/bin/emily install/man/emily.1
