PREFIX ?= /usr/local
MAN ?= $(PREFIX)/share/man/man1

.PHONY: all clean install build
all: build test doc

setup.bin: setup.ml
	ocamlopt.opt -o $@ $< || ocamlopt -o $@ $< || ocamlc -o $@ $<
	rm -f setup.cmx setup.cmi setup.o setup.cmo

setup.data: setup.bin
	./setup.bin -configure

build: setup.data setup.bin
	./setup.bin -build -classic-display

doc: setup.data setup.bin
	./setup.bin -doc

install: setup.bin
	mkdir -p $(PREFIX)/bin
	cp _build/crunch/crunch.native $(PREFIX)/bin/ocaml-crunch
	mkdir -p $(MAN)
	./_build/crunch/crunch.native --help=groff > $(MAN)/ocaml-crunch.1 || true

test: setup.bin build
	./setup.bin -test

fulltest: setup.bin build
	./setup.bin -test

reinstall: setup.bin
	./setup.bin -reinstall

clean:
	ocamlbuild -clean
	rm -f setup.data setup.log setup.bin
