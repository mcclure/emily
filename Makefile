VERSION = 0.3b
ifdef EMILY_BUILD_LOCAL
	PREFIX := ..
else
	PREFIX := /usr/local
endif
bindir = $(PREFIX)/bin
libdir = $(PREFIX)/lib
mandir = $(PREFIX)/share/man/man1
INSTALL := install
# TODO: Also delete?
RSYNC := rsync

#TODO: Remove now that we always make a libdir?
CREATE_LIBDIR=1

# Replace "native" with "byte" for debug build
BUILDTYPE=native

PACKAGE_DIR=emily/$(VERSION)

export BUILD_PACKAGE_DIR=$(libdir)/$(PACKAGE_DIR)
export BUILD_INCLUDE_REPL=1

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
.PHONY: install/lib/$(PACKAGE_DIR)
install/lib/$(PACKAGE_DIR):
ifdef CREATE_LIBDIR
	mkdir -p $@
	$(RSYNC) -r library/ $@/
endif

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
	               --date="2015-04-07" \
	               --organization="http://emilylang.org" \
	               doc/manpage.1.md > resources/emily.1

# Install target
.PHONY: install install-makedirs
install-makedirs:
	$(INSTALL) -d $(DESTDIR)$(bindir)
	$(INSTALL) -d $(DESTDIR)$(mandir)
	$(INSTALL) -d $(DESTDIR)$(libdir)/$(PACKAGE_DIR)

install: install-makedirs all
	$(INSTALL) install/bin/emily   $(DESTDIR)$(bindir)
	$(INSTALL) install/man/emily.1 $(DESTDIR)$(mandir)
ifdef CREATE_LIBDIR
	$(RSYNC) -r install/lib/$(PACKAGE_DIR)/ $(DESTDIR)$(libdir)/$(PACKAGE_DIR)
endif

# Clean target
.PHONY: clean
clean:
	ocamlbuild -clean
	rm -f _tags install/bin/emily install/man/emily.1
ifdef CREATE_LIBDIR
	rm -rf install/lib
endif