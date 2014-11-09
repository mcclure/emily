package/emily: _build/src/main.native
	mkdir -p $(@D)
	cp $< $@

.PHONY: _build/src/main.native
_build/src/main.native:
	ocamlbuild -use-ocamlfind src/main.native

clean:
	ocamlbuild -clean
