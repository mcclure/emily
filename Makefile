PREFIX := /usr/local
bindir = $(PREFIX)/bin
mandir = $(PREFIX)/share/man/man1

.PHONY: all
all: package/emily package/emily.1

# Move final executable in place.
package/emily: _build/src/main.native
	mkdir -p $(@D)
	cp $< $@

# Move manpage in place
package/emily.1: resources/emily.1
	mkdir -p $(@D)
	cp $< $@

# Use ocamlbuild to construct executable. Always run, ocamlbuild figures out freshness itself.
.PHONY: _build/src/main.native
_build/src/main.native: _tags
	ocamlbuild -no-links -use-ocamlfind src/main.native

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
	               doc/manpage.1.md > resources/emily.1

# Clean target
clean:
	ocamlbuild -clean
	rm -f _tags package/emily

.PHONY: install install-makedirs
install-makedirs:
	install -d $(DESTDIR)$(bindir)
	install -d $(DESTDIR)$(mandir)

install: install-makedirs
	install package/emily $(bindir)
	install resources/emily.1 $(mandir)
