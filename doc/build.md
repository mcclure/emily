[TOC]

# Quick start

Here are some canned commands to build and install the `emily` executable plus the Emily man page. If you don't want to build yourself, there may be install packages on [emilylang.org](http://emilylang.org) by the time you read this.

## Debian/Ubuntu

Run these commands:

    sudo add-apt-repository ppa:avsm/ppa
    sudo apt-get update
    sudo apt-get install opam
    opam install ocamlfind sedlex containers
    sudo make install

(The ppa steps are necessary in order to get OCaml 4.02.1, since as of this writing Ubuntu is still shipping 4.01.0.)

## Homebrew

Run these commands:

    sudo brew install opam
    opam install ocamlfind sedlex containers
    sudo make install

## Macports

Run these commands:

    sudo port install opam
    opam install ocamlfind sedlex containers
    sudo make install

# Building Emily by hand

## Source

In order to build this, you will need to install:

- ocaml -- I use 4.02.1 installed via MacPorts
- ocamlfind -- I use 1.5.5, installed via opam
- sedlex -- I use 1.99.2, installed via opam
- ppx_tools -- I use 0.99.2, installed via opam (Required by sedlex)
- containers -- I use 0.4.1, installed via opam

You should be able to just install ocaml and opam from your package manager, and then run `opam install ocamlfind sedlex containers`.

To build, this should be sufficient (assuming everything above is installed:

    make

The build product will be left in the "package" directory. To install it to a standard location, run `make install`.

### I'm on Windows

Okay! The bundled `Makefile` is not going to work for you. Luckily, the `Makefile` is just a thin wrapper on a tool called `ocamlbuild`, which in theory works on Windows and is installed along with the standard OCaml distribution. You will need to follow the `ocamlbuild` instructions to build the file `src/main.native` with ocamlfind enabled. Let me know if it works!

## Additional/optional builds

Building a new version of the manpage from the Markdown file requires the presence of:

- ruby -- I use 2.1.2p95, installed via MacPorts
- ronn -- I use 0.7.3, installed via RubyGems

With these installed, you can run `make manpage`. You do not need to do this unless you edit [manpage.md](manpage.md).

# It didn't work!

Please file an issue at <https://bitbucket.org/runhello/emily> (or <https://github.com/mcclure/emily> if you don't have a BitBucket account).