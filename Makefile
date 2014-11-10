# Move final executable in place.
package/emily: _build/src/main.native
	mkdir -p $(@D)
	cp $< $@

# Use ocamlbuild to construct executable. Always run, ocamlbuild figures out freshness itself.
.PHONY: _build/src/main.native
_build/src/main.native: _tags
	ocamlbuild -use-ocamlfind src/main.native

# Non-essential: This prevents ocamlbuild from emitting unhelpful "hints"
_tags:
	touch $@

# Non-essential: Just in case someone expects this.
.PHONY: all
all: package/emily

clean:
	ocamlbuild -clean
	rm -f _tags package/emily
