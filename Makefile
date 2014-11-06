package/emily: main.native
	mkdir -p $(@D)
	mv $< $@

.PHONY: src/main.native
src/main.native:
	ocamlbuild -use-ocamlfind src/main.native

clean:
	ocamlbuild -clean
