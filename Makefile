OCAMLBUILD ?= ocamlbuild
PREFIX ?= /usr/local

all:
	cd crunch && $(OCAMLBUILD) $(OCAMLBUILD_FLAGS) crunch.native

install:
	mkdir -p $(PREFIX)/bin
	cp crunch/_build/crunch.native $(PREFIX)/bin/ocaml-crunch

clean:
	cd crunch && $(OCAMLBUILD) -clean
