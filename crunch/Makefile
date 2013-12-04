OCAMLBUILD ?= ocamlbuild
PREFIX ?= /usr/local

all:
	$(OCAMLBUILD) $(OCAMLBUILD_FLAGS) crunch.native

install:
	mkdir -p $(PREFIX)/bin
	cp _build/crunch.native $(PREFIX)/bin/mir-crunch
