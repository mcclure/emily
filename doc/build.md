In order to build this, you will need to install:

- ocaml -- I use 4.02.1 installed via MacPorts
- ocamlfind -- I use 1.5.5, installed via opam
- sedlex -- I use 1.99.2, installed via opam
- ppx_tools -- I use 0.99.2, installed via opam (Required by sedlex)
- containers -- I use 0.4.1, installed via opam

You should be able to just install ocaml and opam from your package manager, and then run `opam install ocamlfind sedlex containers`.

To build, this should be sufficient:

    make

The build product will be left in the "package" directory.